"""Certificate expiry reminders (server side; the app also schedules them locally so they work offline)."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from sa_backend.db.models import Alert, Certificate, User

IST = ZoneInfo("Asia/Kolkata")
DEFAULT_OFFSETS_DAYS = (180, 90, 30, 7, 0)
EXPIRED = -1


def due_bucket(expiry: date, today: date, offsets: tuple[int, ...] = DEFAULT_OFFSETS_DAYS) -> int | None:
    """The most urgent reminder bucket that applies today, or None.

    A certificate added with 20 days left gets the 30-day reminder once, then 7, then 0, then 'expired'.
    """
    days_left = (expiry - today).days
    if days_left < 0:
        return EXPIRED
    due = [o for o in offsets if days_left <= o]
    return min(due) if due else None


def describe(bucket: int, expiry: date, today: date) -> str:
    days_left = (expiry - today).days
    if bucket == EXPIRED:
        return f"Expired on {expiry:%d %b %Y}."
    if days_left == 0:
        return "Expires today."
    return f"Expires on {expiry:%d %b %Y} ({days_left} days left)."


def create_expiry_alerts(session: Session, today: date | None = None) -> int:
    today = today or datetime.now(IST).date()
    rows = session.execute(
        select(Certificate, User)
        .join(User, User.id == Certificate.user_id)
        .where(Certificate.deleted_at.is_(None), Certificate.expiry_date.is_not(None), User.deleted_at.is_(None))
    ).all()
    created = 0
    now = datetime.now(IST)
    for cert, _user in rows:
        bucket = due_bucket(cert.expiry_date, today)
        if bucket is None:
            continue
        stmt = (
            insert(Alert)
            .values(
                id=uuid.uuid4(),
                user_id=cert.user_id,
                certificate_id=cert.id,
                kind="cert_expiry",
                channel="in_app",
                priority="normal",
                reason=describe(bucket, cert.expiry_date, today),
                # expiry date in the key: renewing the certificate (new date) restarts the reminders
                dedupe_key=f"expiry:{cert.id}:{cert.expiry_date.isoformat()}:{bucket}",
                sent_at=now,
            )
            .on_conflict_do_nothing(constraint="alerts_dedupe")
        )
        created += session.execute(stmt).rowcount
    return created
