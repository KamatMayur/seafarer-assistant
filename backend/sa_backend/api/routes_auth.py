"""Email login with a 6-digit code (decision D4). Phone OTP is added when an SMS provider is approved."""

from __future__ import annotations

import logging
import smtplib
from datetime import UTC, datetime, timedelta
from email.message import EmailMessage

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select

from sa_backend import reference
from sa_backend.api.deps import DB
from sa_backend.api.schemas import EmailStart, RefreshIn, Tokens, Verify
from sa_backend.api.security import (
    create_access_token,
    hash_login_code,
    hash_refresh_token,
    new_login_code,
    new_refresh_token,
)
from sa_backend.db.models import Consent, LoginCode, RefreshToken, User
from sa_backend.settings import get_settings

log = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["auth"])
MAX_CODES_PER_HOUR = 5
MAX_ATTEMPTS = 5


def _send_code(email: str, code: str) -> None:
    s = get_settings()
    if not (s.smtp_host and s.smtp_from):
        if s.env == "dev":
            log.warning("DEV LOGIN CODE for %s: %s (SMTP not configured)", email, code)
            return
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "email sending is not configured")
    msg = EmailMessage()
    msg["From"], msg["To"], msg["Subject"] = s.smtp_from, email, f"Your sign-in code: {code}"
    msg.set_content(
        f"Your sign-in code is {code}. It expires in {s.login_code_minutes} minutes.\n\n"
        f"If you did not ask for it, ignore this email.\n\n{reference.UNOFFICIAL}"
    )
    with smtplib.SMTP(s.smtp_host, s.smtp_port, timeout=30) as smtp:
        smtp.starttls()
        if s.smtp_user:
            smtp.login(s.smtp_user, s.smtp_password)
        smtp.send_message(msg)


def _issue_tokens(db, user: User, new_user: bool = False) -> Tokens:
    access, expires = create_access_token(user.id)
    refresh, refresh_hash = new_refresh_token()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=refresh_hash,
            expires_at=datetime.now(UTC) + timedelta(days=get_settings().refresh_token_days),
        )
    )
    return Tokens(access_token=access, refresh_token=refresh, expires_in=expires, new_user=new_user)


@router.post("/email/start", status_code=202)
def email_start(body: EmailStart, db: DB) -> dict:
    email = body.email.lower()
    recent = db.scalar(
        select(func.count())
        .select_from(LoginCode)
        .where(LoginCode.identifier == email, LoginCode.created_at > datetime.now(UTC) - timedelta(hours=1))
    )
    if recent >= MAX_CODES_PER_HOUR:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "too many codes requested; try again later")
    code = new_login_code()
    db.add(
        LoginCode(
            identifier=email,
            code_hash=hash_login_code(email, code),
            expires_at=datetime.now(UTC) + timedelta(minutes=get_settings().login_code_minutes),
        )
    )
    db.flush()
    _send_code(email, code)
    return {"status": "sent"}


@router.post("/verify", response_model=Tokens)
def verify(body: Verify, db: DB) -> Tokens:
    email = str(body.identifier).lower()
    now = datetime.now(UTC)
    row = db.scalar(
        select(LoginCode)
        .where(LoginCode.identifier == email, LoginCode.used_at.is_(None), LoginCode.expires_at > now)
        .order_by(LoginCode.id.desc())
        .limit(1)
    )
    if row is None or row.attempts >= MAX_ATTEMPTS:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "code expired; request a new one")
    if row.code_hash != hash_login_code(email, body.code):
        row.attempts += 1
        db.commit()
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "wrong code")
    row.used_at = now

    user = db.scalar(select(User).where(func.lower(User.email) == email, User.deleted_at.is_(None)))
    new_user = user is None
    if new_user:
        if not any(c.purpose == "core_service" and c.granted for c in body.consents):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "consent to the core service is required to sign up")
        user = User(email=email)
        db.add(user)
        db.flush()
    for c in body.consents:
        db.add(Consent(user_id=user.id, purpose=c.purpose, granted=c.granted, policy_version=c.policy_version))
    return _issue_tokens(db, user, new_user)


@router.post("/refresh", response_model=Tokens)
def refresh(body: RefreshIn, db: DB) -> Tokens:
    row = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(body.refresh_token)))
    now = datetime.now(UTC)
    if row is None or row.revoked_at is not None or row.expires_at < now:
        if row is not None and row.revoked_at is not None:
            # A revoked token was replayed: someone may have stolen it. Revoke the whole family.
            db.execute(
                RefreshToken.__table__.update().where(RefreshToken.user_id == row.user_id).values(revoked_at=now)
            )
            db.commit()
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid refresh token")
    row.revoked_at = now
    user = db.get(User, row.user_id)
    if user is None or user.deleted_at is not None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "account not found")
    return _issue_tokens(db, user)
