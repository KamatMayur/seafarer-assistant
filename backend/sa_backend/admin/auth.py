"""Admin login and browser sessions.

Two modes:
- **Accounts** (normal): each admin logs in with email + password + a 6-digit authenticator (TOTP) code.
  Accounts are managed with `python -m sa_backend.admin.manage`. Once any enabled account exists, the shared
  token below stops working.
- **Bootstrap token**: before the first account exists, `SA_ADMIN_TOKEN` alone logs in (local dev / first setup).

A successful login gives a signed, short-lived cookie bound to the account's current credentials: changing the
password, resetting TOTP or disabling the account ends its sessions. POSTs also need a CSRF token derived from the
session, sent as a form field or the X-CSRF-Token header (HTMX).
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import struct
import time
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

import jwt
from cryptography.fernet import Fernet, InvalidToken
from fastapi import HTTPException, Request, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from sa_backend.db.models import AdminAccount
from sa_backend.db.session import make_sessionmaker
from sa_backend.settings import get_settings

COOKIE = "sa_admin"
SESSION_HOURS = 12
ALGORITHM = "HS256"
TOTP_STEP_S = 30
TOTP_DIGITS = 6
MAX_FAILED = 5
LOCK_MINUTES = 15
MIN_PASSWORD = 12
TOKEN_ADMIN = "admin-token"  # audit identity in bootstrap-token mode


def _mac(value: str) -> str:
    return hmac.new(get_settings().jwt_secret.encode(), value.encode(), hashlib.sha256).hexdigest()


# ---------------------------------------------------------------- passwords (scrypt, stdlib)
def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1, dklen=32)
    return f"scrypt$16384$8$1${base64.b64encode(salt).decode()}${base64.b64encode(digest).decode()}"


def verify_password(password: str, stored: str) -> bool:
    try:
        _, n, r, p, salt, digest = stored.split("$")
        got = hashlib.scrypt(password.encode(), salt=base64.b64decode(salt), n=int(n), r=int(r), p=int(p), dklen=32)
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(got, base64.b64decode(digest))


# ---------------------------------------------------------------- TOTP (RFC 6238)
def new_totp_secret() -> str:
    return base64.b32encode(secrets.token_bytes(20)).decode().rstrip("=")


def totp_code(secret: str, step: int) -> str:
    key = base64.b32decode(secret + "=" * (-len(secret) % 8), casefold=True)
    mac = hmac.new(key, struct.pack(">Q", step), hashlib.sha1).digest()
    offset = mac[-1] & 0x0F
    value = struct.unpack(">I", mac[offset : offset + 4])[0] & 0x7FFFFFFF
    return str(value % 10**TOTP_DIGITS).zfill(TOTP_DIGITS)


def current_step(now: float | None = None) -> int:
    return int((now if now is not None else time.time()) // TOTP_STEP_S)


def verify_totp(secret: str, code: str, last_step: int, now: float | None = None) -> int | None:
    """The matching time step (±1 for clock drift), or None. Steps at or before last_step are replays."""
    code = code.strip().replace(" ", "")
    if not code.isdigit() or len(code) != TOTP_DIGITS:
        return None
    step = current_step(now)
    for candidate in (step - 1, step, step + 1):
        if candidate > last_step and hmac.compare_digest(totp_code(secret, candidate), code):
            return candidate
    return None


def provisioning_uri(email: str, secret: str) -> str:
    return f"otpauth://totp/SeafarerAssistant:{email}?secret={secret}&issuer=SeafarerAssistant&digits=6&period=30"


# ---------------------------------------------------------------- secret encryption
def _fernet() -> Fernet:
    key = hashlib.sha256(f"admin-totp:{get_settings().jwt_secret}".encode()).digest()
    return Fernet(base64.urlsafe_b64encode(key))


def encrypt_secret(secret: str) -> str:
    return _fernet().encrypt(secret.encode()).decode()


def decrypt_secret(token: str) -> str | None:
    """None if SA_JWT_SECRET changed since enrolment (re-enrol with `manage reset-totp`)."""
    try:
        return _fernet().decrypt(token.encode()).decode()
    except InvalidToken:
        return None


# ---------------------------------------------------------------- accounts
def accounts_exist(db: Session) -> bool:
    return bool(db.scalar(select(func.count()).select_from(AdminAccount).where(AdminAccount.disabled_at.is_(None))))


def find_account(db: Session, email: str) -> AdminAccount | None:
    return db.scalar(select(AdminAccount).where(func.lower(AdminAccount.email) == email.strip().lower()))


class LoginError(Exception):
    pass


def authenticate(db: Session, email: str, password: str, code: str, now: datetime | None = None) -> AdminAccount:
    """Check all three factors. Raises LoginError with a message safe to show (no account enumeration)."""
    now = now or datetime.now(UTC)
    generic = "Wrong email, password or code."
    acct = find_account(db, email)
    if acct is None or acct.disabled_at is not None:
        verify_password(password, hash_password("timing-equaliser"))  # similar time whether or not it exists
        raise LoginError(generic)
    if acct.locked_until and acct.locked_until > now:
        raise LoginError(f"Too many failed attempts. Try again after {acct.locked_until:%H:%M} UTC.")
    secret = decrypt_secret(acct.totp_secret_enc)
    step = verify_totp(secret, code, acct.totp_last_step, now.timestamp()) if secret else None
    if not verify_password(password, acct.password_hash) or step is None:
        acct.failed_attempts += 1
        if acct.failed_attempts >= MAX_FAILED:
            acct.locked_until = now + timedelta(minutes=LOCK_MINUTES)
            acct.failed_attempts = 0
        raise LoginError(generic)
    acct.totp_last_step = step
    acct.failed_attempts = 0
    acct.locked_until = None
    acct.last_login_at = now
    return acct


def token_matches(supplied: str) -> bool:
    token = get_settings().admin_token
    return bool(token) and hmac.compare_digest(supplied.strip().encode(), token.encode())


# ---------------------------------------------------------------- sessions
def _fingerprint(acct: AdminAccount) -> str:
    return _mac(f"acct:{acct.id}:{acct.password_hash}:{acct.totp_secret_enc}:{acct.disabled_at}")[:32]


def _token_fingerprint() -> str:
    return _mac(f"admin-token:{get_settings().admin_token}")[:32]


def new_session(acct: AdminAccount | None = None) -> str:
    now = datetime.now(UTC)
    payload = {
        "typ": "admin",
        "sid": secrets.token_urlsafe(16),
        "aid": str(acct.id) if acct else "token",
        "fp": _fingerprint(acct) if acct else _token_fingerprint(),
        "iat": now,
        "exp": now + timedelta(hours=SESSION_HOURS),
    }
    return jwt.encode(payload, get_settings().jwt_secret, algorithm=ALGORITHM)


@dataclass(frozen=True)
class AdminIdentity:
    sid: str
    email: str  # used in the audit log
    role: str


def identify(request: Request) -> AdminIdentity | None:
    raw = request.cookies.get(COOKIE)
    if not raw:
        return None
    try:
        payload = jwt.decode(raw, get_settings().jwt_secret, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None
    if payload.get("typ") != "admin":
        return None
    with make_sessionmaker()() as db:
        if payload.get("aid") == "token":
            ok = (
                bool(get_settings().admin_token)
                and not accounts_exist(db)
                and hmac.compare_digest(payload.get("fp", ""), _token_fingerprint())
            )
            return AdminIdentity(payload["sid"], TOKEN_ADMIN, "owner") if ok else None
        try:
            acct = db.get(AdminAccount, uuid.UUID(payload.get("aid", "")))
        except ValueError:
            return None
        if acct is None or acct.disabled_at or not hmac.compare_digest(payload.get("fp", ""), _fingerprint(acct)):
            return None
        return AdminIdentity(payload["sid"], acct.email, acct.role)


def csrf_for(sid: str) -> str:
    return _mac(f"csrf:{sid}")[:40]


class LoginRequired(Exception):
    """Raised by the dependency below; turned into a redirect to the login page."""


def require_session(request: Request) -> str:
    ident = identify(request)
    if ident is None:
        raise LoginRequired
    request.state.admin = ident
    return ident.sid


async def require_csrf(request: Request) -> None:
    sid = require_session(request)
    supplied = request.headers.get("x-csrf-token")
    if supplied is None:
        form = await request.form()
        supplied = str(form.get("csrf", ""))
    if not hmac.compare_digest(supplied, csrf_for(sid)):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "bad CSRF token; reload the page")
