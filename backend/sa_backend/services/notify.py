"""Deliver alerts over outbound channels. 'in_app' alerts are the feed itself and need no delivery.

Providers are enabled only when configured (env vars). Unconfigured channels are never offered, so no alert is
ever queued for a channel that cannot send.
"""

from __future__ import annotations

import logging
import smtplib
from datetime import datetime, timedelta
from email.message import EmailMessage
from typing import Protocol
from zoneinfo import ZoneInfo

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from sa_backend.db.models import Alert, Document, User
from sa_backend.settings import Settings, get_settings

log = logging.getLogger(__name__)
IST = ZoneInfo("Asia/Kolkata")
MAX_ATTEMPTS = 3
DISCLAIMER = "Automatic extract from the official document. Always verify with the official circular."


class Provider(Protocol):
    channel: str

    def send(self, user: User, alert: Alert, doc: Document | None) -> None: ...


class EmailProvider:
    channel = "email"

    def __init__(self, settings: Settings):
        self.s = settings

    def send(self, user: User, alert: Alert, doc: Document | None) -> None:
        if not user.email:
            raise ValueError("user has no email")
        msg = EmailMessage()
        msg["From"] = self.s.smtp_from
        msg["To"] = user.email
        title = doc.title if doc else "Reminder"
        prefix = "[URGENT] " if alert.priority == "critical" else ""
        msg["Subject"] = f"{prefix}{title[:150]}"
        lines = [title, "", f"Why you got this: {alert.reason or '-'}"]
        if doc:
            lines += ["", f"Official PDF: {doc.pdf_url}"]
        lines += ["", DISCLAIMER, "Independent app. Not affiliated with DGMA or the Government of India."]
        msg.set_content("\n".join(lines))
        with smtplib.SMTP(self.s.smtp_host, self.s.smtp_port, timeout=30) as smtp:
            smtp.starttls()
            if self.s.smtp_user:
                smtp.login(self.s.smtp_user, self.s.smtp_password)
            smtp.send_message(msg)


def configured_providers(settings: Settings | None = None) -> dict[str, Provider]:
    s = settings or get_settings()
    providers: dict[str, Provider] = {}
    if s.smtp_host and s.smtp_from:
        providers["email"] = EmailProvider(s)
    # 'push' (FCM) arrives in Phase 5; WhatsApp/SMS need paid accounts (decisions.md D2).
    return providers


def available_channels(user: User, has_push_device: bool, settings: Settings | None = None) -> list[str]:
    providers = configured_providers(settings)
    wanted = set(user.alert_channels or []) | {"in_app"}
    out = ["in_app"]
    if "push" in wanted and "push" in providers and has_push_device:
        out.append("push")
    if "email" in wanted and "email" in providers and user.email:
        out.append("email")
    return out


def deliver_due(session: Session, providers: dict[str, Provider] | None = None, now: datetime | None = None) -> int:
    providers = configured_providers() if providers is None else providers
    now = now or datetime.now(IST)
    due = session.scalars(
        select(Alert)
        .where(
            Alert.sent_at.is_(None),
            Alert.channel != "in_app",
            Alert.delivery_attempts < MAX_ATTEMPTS,
            or_(Alert.scheduled_for.is_(None), Alert.scheduled_for <= now),
        )
        .order_by((Alert.priority == "critical").desc(), Alert.created_at)
        .limit(500)
    ).all()
    sent = 0
    for alert in due:
        provider = providers.get(alert.channel)
        if provider is None:
            continue
        user = session.get(User, alert.user_id)
        doc = session.get(Document, alert.document_id) if alert.document_id else None
        alert.delivery_attempts += 1
        try:
            provider.send(user, alert, doc)
            alert.sent_at = now
            alert.delivery_error = None
            sent += 1
        except Exception as e:  # provider errors are recorded and retried later
            alert.delivery_error = f"{type(e).__name__}: {e}"[:500]
            alert.scheduled_for = now + timedelta(minutes=30 * alert.delivery_attempts)
            log.warning("delivery failed alert=%s channel=%s: %s", alert.id, alert.channel, e)
    return sent
