"""Turn a processed document into alert rows. Idempotent: re-running creates nothing new (unique dedupe key)."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from sa_backend.db.models import Alert, CertDocumentLink, Certificate, Device, Document, User
from sa_backend.services.matching import DocFacts, Match, UserFacts, match
from sa_backend.services.notify import available_channels

log = logging.getLogger(__name__)
IST = ZoneInfo("Asia/Kolkata")
# Only recent documents alert. Backfilled history is searchable but must never flood users' feeds.
ALERT_WINDOW_DAYS = 30


def doc_facts(doc: Document) -> DocFacts:
    def title_values(kind: str) -> frozenset[str]:
        return frozenset(t.value for t in doc.tags if t.kind == kind and t.strength == "title")

    audience = next((t.value for t in doc.tags if t.kind == "audience"), "general")
    return DocFacts(
        id=doc.id,
        doc_type=doc.doc_type,
        audience=audience,
        priority=doc.priority,
        departments=title_values("department"),
        levels=title_values("level"),
        ship_types=title_values("ship_type"),
        mmds=title_values("mmd"),
        exam_grades=title_values("exam_grade"),
        cert_types=title_values("certificate_type"),
        topics=frozenset(t.value for t in doc.tags if t.kind == "topic"),
    )


def user_facts(user: User, certificates: list[Certificate]) -> UserFacts:
    return UserFacts(
        id=user.id,
        department=user.department,
        level=user.level,
        ship_types=frozenset(user.ship_types or []),
        home_mmd=user.home_mmd,
        exam_grades=frozenset(user.exam_grades or []),
        followed_topics=frozenset(p.topic for p in user.topic_prefs if p.mode == "follow"),
        muted_topics=frozenset(p.topic for p in user.topic_prefs if p.mode == "mute"),
        certificates=tuple((c.id, c.type) for c in certificates if c.deleted_at is None),
    )


def quiet_until(user: User, now: datetime) -> datetime | None:
    """If `now` is inside the user's quiet hours (IST), return when they end."""
    if user.quiet_start_min is None or user.quiet_end_min is None or user.quiet_start_min == user.quiet_end_min:
        return None
    local = now.astimezone(IST)
    minute = local.hour * 60 + local.minute
    start, end = user.quiet_start_min, user.quiet_end_min
    inside = (start <= minute < end) if start < end else (minute >= start or minute < end)
    if not inside:
        return None
    end_today = datetime.combine(local.date(), time(end // 60, end % 60), IST)
    return end_today if end_today > local else end_today + timedelta(days=1)


def _insert_alert(session: Session, **values) -> bool:
    stmt = (
        insert(Alert)
        .values(id=uuid.uuid4(), **values)
        .on_conflict_do_nothing(constraint="alerts_dedupe")
        .returning(Alert.id)  # rowcount is not reliable for INSERT on SQLAlchemy 2.1
    )
    return session.execute(stmt).first() is not None


def create_document_alerts(session: Session, doc: Document, now: datetime | None = None) -> int:
    """Create alerts for every user the document concerns. Returns the number of new alert rows."""
    now = now or datetime.now(IST)
    if doc.published_date and doc.published_date < (now - timedelta(days=ALERT_WINDOW_DAYS)).date():
        return 0
    facts = doc_facts(doc)
    version = doc.pdf_hash or "listing"
    dedupe = f"doc:{doc.id}:{version}"
    is_update = (
        session.scalar(select(Alert.id).where(Alert.document_id == doc.id, Alert.dedupe_key != dedupe).limit(1))
        is not None
    )
    users = session.scalars(select(User).where(User.deleted_at.is_(None))).all()
    certs_by_user: dict[uuid.UUID, list[Certificate]] = {}
    for cert in session.scalars(select(Certificate).where(Certificate.deleted_at.is_(None))):
        certs_by_user.setdefault(cert.user_id, []).append(cert)
    push_users = set(session.scalars(select(Device.user_id).where(Device.fcm_token.is_not(None))))

    created = 0
    for user in users:
        m: Match | None = match(facts, user_facts(user, certs_by_user.get(user.id, [])))
        if m is None:
            continue
        kind = "updated_document" if is_update else m.kind
        for channel in available_channels(user, has_push_device=user.id in push_users):
            deferred = None if (channel == "in_app" or m.priority == "critical") else quiet_until(user, now)
            created += _insert_alert(
                session,
                user_id=user.id,
                document_id=doc.id,
                kind=kind,
                channel=channel,
                priority=m.priority,
                reason=m.reason,
                dedupe_key=dedupe,
                scheduled_for=deferred,
                sent_at=now if channel == "in_app" else None,
            )
        for cert_id, reason in m.cert_impacts:
            session.execute(
                insert(CertDocumentLink)
                .values(certificate_id=cert_id, document_id=doc.id, reason=reason, notified_at=now)
                .on_conflict_do_nothing()
            )
            created += _insert_alert(
                session,
                user_id=user.id,
                document_id=doc.id,
                certificate_id=cert_id,
                kind="cert_impact",
                channel="in_app",
                priority="normal",
                reason=reason,
                dedupe_key=f"cert:{cert_id}:doc:{doc.id}",
                sent_at=now,
            )
    log.info("alerts for %s (%s): %d new", doc.circular_number or doc.title[:40], facts.audience, created)
    return created
