"""Operational alerts for the admin (scraper failures, layout drift). Never fail silently."""

from __future__ import annotations

import logging
import smtplib
from datetime import datetime, timedelta
from email.message import EmailMessage
from zoneinfo import ZoneInfo

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from sa_backend.db.models import AdminEvent
from sa_backend.settings import Settings, get_settings

log = logging.getLogger(__name__)
IST = ZoneInfo("Asia/Kolkata")
REPEAT_AFTER = timedelta(hours=12)  # the same problem is re-sent at most twice a day


def raise_event(
    session: Session,
    severity: str,
    message: str,
    source_id: str | None = None,
    settings: Settings | None = None,
    now: datetime | None = None,
) -> AdminEvent | None:
    s = settings or get_settings()
    now = now or datetime.now(IST)
    recent = session.scalar(
        select(AdminEvent).where(
            AdminEvent.message == message,
            AdminEvent.source_id.is_(source_id) if source_id is None else AdminEvent.source_id == source_id,
            AdminEvent.created_at > now - REPEAT_AFTER,
        )
    )
    if recent:
        return None
    event = AdminEvent(severity=severity, source_id=source_id, message=message, delivered_via=["log"])
    getattr(log, "error" if severity == "error" else "warning")("ADMIN %s [%s] %s", severity, source_id, message)
    text = f"[{severity.upper()}] {source_id or 'system'}: {message}"
    if s.admin_alert_slack_webhook:
        try:
            httpx.post(s.admin_alert_slack_webhook, json={"text": text}, timeout=15).raise_for_status()
            event.delivered_via.append("slack")
        except httpx.HTTPError as e:
            log.error("slack admin alert failed: %s", e)
    if s.admin_alert_email and s.smtp_host:
        try:
            msg = EmailMessage()
            msg["From"], msg["To"] = s.smtp_from, s.admin_alert_email
            msg["Subject"] = f"[Seafarer app] {severity}: {source_id or 'system'}"
            msg.set_content(text)
            with smtplib.SMTP(s.smtp_host, s.smtp_port, timeout=30) as smtp:
                smtp.starttls()
                if s.smtp_user:
                    smtp.login(s.smtp_user, s.smtp_password)
                smtp.send_message(msg)
            event.delivered_via.append("email")
        except (OSError, smtplib.SMTPException) as e:
            log.error("email admin alert failed: %s", e)
    session.add(event)
    return event
