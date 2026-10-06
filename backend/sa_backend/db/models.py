"""SQLAlchemy models. Reference design: docs/schema.sql.

Enum-like columns are VARCHAR + CHECK (not native PG enums) so adding a value is a one-line migration.
"""

import uuid
from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Computed,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, TSVECTOR, UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

DEPARTMENTS = ("deck", "engine", "electrical", "catering", "other")
LEVELS = ("officer", "rating", "cadet")
DOC_TYPES = ("circular", "order", "notice", "exam_schedule", "result", "advisory", "rules", "unknown")
# 'archived' = older than the processing window; listing metadata only, not downloaded or alerted.
DOC_STATUSES = ("new", "extracted", "processed", "needs_review", "failed", "archived")
PRIORITIES = ("critical", "normal", "low")
CHANNELS = ("in_app", "push", "whatsapp", "sms", "email")
CERT_TYPES = ("coc", "cop", "stcw_basic", "stcw_advanced", "medical", "cdc", "passport", "bsid", "visa", "other")
TAG_KINDS = ("department", "level", "rank", "ship_type", "mmd", "topic", "certificate_type", "exam_grade", "audience")
LANGS = ("en", "hi", "mr", "ta", "ml", "bn", "te", "gu")


def _in(col: str, values: tuple[str, ...]) -> str:
    return f"{col} IN ({', '.join(repr(v) for v in values)})"


class Base(DeclarativeBase):
    pass


def _uuid_pk() -> Mapped[uuid.UUID]:
    return mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)


def _now() -> Mapped[datetime]:
    return mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)


# ---------------------------------------------------------------- users
class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("phone IS NOT NULL OR email IS NOT NULL", name="users_contact"),
        CheckConstraint(_in("preferred_language", LANGS), name="users_lang"),
        CheckConstraint(f"department IS NULL OR {_in('department', DEPARTMENTS)}", name="users_department"),
        CheckConstraint(f"level IS NULL OR {_in('level', LEVELS)}", name="users_level"),
        Index("users_email_lower", text("lower(email)"), unique=True),
    )

    id: Mapped[uuid.UUID] = _uuid_pk()
    phone: Mapped[str | None] = mapped_column(String(20), unique=True)
    email: Mapped[str | None] = mapped_column(String(320))
    name: Mapped[str | None] = mapped_column(String(200))
    preferred_language: Mapped[str] = mapped_column(String(2), default="en", server_default="en")
    rank: Mapped[str | None] = mapped_column(String(40))
    department: Mapped[str | None] = mapped_column(String(20))
    level: Mapped[str | None] = mapped_column(String(20))
    ship_types: Mapped[list[str]] = mapped_column(ARRAY(String), default=list, server_default="{}")
    home_mmd: Mapped[str | None] = mapped_column(String(40))
    exam_grades: Mapped[list[str]] = mapped_column(ARRAY(String), default=list, server_default="{}")
    alert_channels: Mapped[list[str]] = mapped_column(
        ARRAY(String), default=lambda: ["in_app", "push"], server_default="{in_app,push}"
    )
    quiet_start_min: Mapped[int | None] = mapped_column(Integer)  # minutes after IST midnight
    quiet_end_min: Mapped[int | None] = mapped_column(Integer)
    plan: Mapped[str] = mapped_column(String(20), default="free", server_default="free")
    created_at: Mapped[datetime] = _now()
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    topic_prefs: Mapped[list["UserTopicPref"]] = relationship(cascade="all, delete-orphan", lazy="selectin")
    certificates: Mapped[list["Certificate"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class UserTopicPref(Base):
    __tablename__ = "user_topic_prefs"
    __table_args__ = (CheckConstraint("mode IN ('follow','mute')", name="topic_mode"),)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    topic: Mapped[str] = mapped_column(String(60), primary_key=True)
    mode: Mapped[str] = mapped_column(String(10))


class Consent(Base):
    __tablename__ = "consents"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    purpose: Mapped[str] = mapped_column(String(40))
    granted: Mapped[bool] = mapped_column(Boolean)
    policy_version: Mapped[str] = mapped_column(String(20))
    at: Mapped[datetime] = _now()


class LoginCode(Base):
    """One-time email login codes (stored hashed)."""

    __tablename__ = "login_codes"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    identifier: Mapped[str] = mapped_column(String(320), index=True)
    code_hash: Mapped[str] = mapped_column(String(128))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = _now()


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"
    id: Mapped[uuid.UUID] = _uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(128), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = _now()


class Device(Base):
    __tablename__ = "devices"
    __table_args__ = (CheckConstraint("platform IN ('windows','android','ios')", name="device_platform"),)
    id: Mapped[uuid.UUID] = _uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    platform: Mapped[str] = mapped_column(String(10))
    fcm_token: Mapped[str | None] = mapped_column(Text)
    app_version: Mapped[str | None] = mapped_column(String(20))
    last_seen: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


# ---------------------------------------------------------------- sources & documents
class Source(Base):
    __tablename__ = "sources"
    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    url: Mapped[str] = mapped_column(Text)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    poll_minutes: Mapped[int] = mapped_column(Integer, default=180, server_default="180")
    last_run_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_success_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    last_item_count: Mapped[int | None] = mapped_column(Integer)
    structure_hash: Mapped[str | None] = mapped_column(String(64))
    health: Mapped[str] = mapped_column(String(20), default="unknown", server_default="unknown")


class ScrapeRun(Base):
    __tablename__ = "scrape_runs"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    source_id: Mapped[str] = mapped_column(ForeignKey("sources.id"), index=True)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    http_status: Mapped[int | None] = mapped_column(Integer)
    items_found: Mapped[int | None] = mapped_column(Integer)
    new_items: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    changed_items: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    problems: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    error: Mapped[str | None] = mapped_column(Text)


class Document(Base):
    __tablename__ = "documents"
    __table_args__ = (
        CheckConstraint(_in("doc_type", DOC_TYPES), name="doc_type_chk"),
        CheckConstraint(_in("status", DOC_STATUSES), name="doc_status_chk"),
        CheckConstraint(_in("priority", PRIORITIES), name="doc_priority_chk"),
        Index("documents_fts_idx", "fts", postgresql_using="gin"),
        Index("documents_pub_idx", text("published_date DESC")),
    )

    id: Mapped[uuid.UUID] = _uuid_pk()
    source_id: Mapped[str] = mapped_column(ForeignKey("sources.id"))
    source_url: Mapped[str] = mapped_column(Text)
    pdf_url: Mapped[str] = mapped_column(Text, unique=True)
    pdf_hash: Mapped[str | None] = mapped_column(String(64))
    title: Mapped[str] = mapped_column(Text)
    circular_number: Mapped[str | None] = mapped_column(String(40))
    issuing_branch: Mapped[str | None] = mapped_column(String(200))
    published_date: Mapped[date | None] = mapped_column(Date)
    site_type: Mapped[str | None] = mapped_column(String(80))  # 'Type' column as published, when present
    doc_type: Mapped[str] = mapped_column(String(20), default="unknown", server_default="unknown")
    priority: Mapped[str] = mapped_column(String(10), default="normal", server_default="normal")
    related_document_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("documents.id"))
    relation: Mapped[str | None] = mapped_column(String(20))
    raw_text: Mapped[str | None] = mapped_column(Text)
    page_count: Mapped[int | None] = mapped_column(Integer)
    extraction_method: Mapped[str | None] = mapped_column(String(20))
    text_policy: Mapped[str] = mapped_column(String(20), default="full", server_default="full")
    classify_confidence: Mapped[float | None] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String(20), default="new", server_default="new", index=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    last_error: Mapped[str | None] = mapped_column(Text)
    text_quality: Mapped[float | None] = mapped_column(Float)
    last_checked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))  # last PDF re-hash
    fts = mapped_column(
        TSVECTOR,
        Computed("to_tsvector('english', coalesce(title,'') || ' ' || coalesce(raw_text,''))", persisted=True),
    )
    first_seen_at: Mapped[datetime] = _now()
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    tags: Mapped[list["DocumentTag"]] = relationship(cascade="all, delete-orphan", lazy="selectin")
    summaries: Mapped[list["DocumentSummary"]] = relationship(cascade="all, delete-orphan", lazy="selectin")
    sightings: Mapped[list["DocumentSighting"]] = relationship(cascade="all, delete-orphan", lazy="selectin")


class DocumentSighting(Base):
    """Every listing page a document appears on. The pages are hints for classification (e.g. piracy page)."""

    __tablename__ = "document_sightings"
    document_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("documents.id", ondelete="CASCADE"), primary_key=True)
    source_id: Mapped[str] = mapped_column(ForeignKey("sources.id"), primary_key=True)
    first_seen_at: Mapped[datetime] = _now()


class DocumentVersion(Base):
    __tablename__ = "document_versions"
    document_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("documents.id", ondelete="CASCADE"), primary_key=True)
    pdf_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    seen_at: Mapped[datetime] = _now()


class DocumentSummary(Base):
    __tablename__ = "document_summaries"
    __table_args__ = (CheckConstraint(_in("language", LANGS), name="summary_lang"),)
    document_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("documents.id", ondelete="CASCADE"), primary_key=True)
    language: Mapped[str] = mapped_column(String(2), primary_key=True)
    summary_short: Mapped[str] = mapped_column(Text)
    summary_detailed: Mapped[str | None] = mapped_column(Text)
    action_required: Mapped[bool] = mapped_column(Boolean, default=False)
    action_deadline: Mapped[date | None] = mapped_column(Date)
    affected_groups: Mapped[dict] = mapped_column(JSONB, default=dict, server_default="{}")
    key_points: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    uncertain_fields: Mapped[list[str]] = mapped_column(ARRAY(Text), default=list, server_default="{}")
    method: Mapped[str] = mapped_column(String(20))  # 'extractive' | 'llm' | 'human'
    model_version: Mapped[str] = mapped_column(String(60))
    verified_by_human: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    verified_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    created_at: Mapped[datetime] = _now()


class DocumentTag(Base):
    __tablename__ = "document_tags"
    __table_args__ = (
        CheckConstraint(_in("kind", TAG_KINDS), name="tag_kind_chk"),
        Index("document_tags_lookup", "kind", "value"),
    )
    document_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("documents.id", ondelete="CASCADE"), primary_key=True)
    kind: Mapped[str] = mapped_column(String(20), primary_key=True)
    value: Mapped[str] = mapped_column(String(60), primary_key=True)
    # 'title' tags restrict who is alerted; 'body' tags are weaker mentions (shown, used for topics only).
    strength: Mapped[str] = mapped_column(String(5), default="title", server_default="title")
    evidence: Mapped[str | None] = mapped_column(Text)  # matched phrase, for admin review


# ---------------------------------------------------------------- user data (offline-first)
class Certificate(Base):
    __tablename__ = "certificates"
    __table_args__ = (CheckConstraint(_in("type", CERT_TYPES), name="cert_type_chk"),)
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)  # generated on device
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    type: Mapped[str] = mapped_column(String(20))
    subtype: Mapped[str | None] = mapped_column(String(40))
    number: Mapped[str | None] = mapped_column(String(80))
    issuing_authority: Mapped[str | None] = mapped_column(String(200))
    issue_date: Mapped[date | None] = mapped_column(Date)
    expiry_date: Mapped[date | None] = mapped_column(Date)
    version: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = _now()

    user: Mapped[User] = relationship(back_populates="certificates")


class CertDocumentLink(Base):
    __tablename__ = "cert_document_links"
    certificate_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("certificates.id", ondelete="CASCADE"), primary_key=True
    )
    document_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("documents.id", ondelete="CASCADE"), primary_key=True)
    reason: Mapped[str] = mapped_column(Text)
    notified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class Alert(Base):
    __tablename__ = "alerts"
    __table_args__ = (
        CheckConstraint(_in("channel", CHANNELS), name="alert_channel_chk"),
        CheckConstraint(_in("priority", PRIORITIES), name="alert_priority_chk"),
        CheckConstraint(
            "kind IN ('new_document','updated_document','cert_impact','cert_expiry','exam','broadcast')",
            name="alert_kind_chk",
        ),
        UniqueConstraint("user_id", "channel", "dedupe_key", name="alerts_dedupe"),
        Index("alerts_feed", "user_id", "channel", text("created_at DESC")),
        Index("alerts_due", "sent_at", "scheduled_for"),
    )
    id: Mapped[uuid.UUID] = _uuid_pk()
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    document_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("documents.id", ondelete="CASCADE"))
    certificate_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("certificates.id", ondelete="CASCADE"))
    kind: Mapped[str] = mapped_column(String(20))
    channel: Mapped[str] = mapped_column(String(10))
    priority: Mapped[str] = mapped_column(String(10))
    reason: Mapped[str | None] = mapped_column(Text)
    dedupe_key: Mapped[str] = mapped_column(String(200))
    scheduled_for: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    delivery_attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    delivery_error: Mapped[str | None] = mapped_column(Text)
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = _now()


class SeaService(Base):
    __tablename__ = "sea_service"
    __table_args__ = (
        CheckConstraint("imo IS NULL OR imo ~ '^[0-9]{7}$'", name="sea_imo"),
        CheckConstraint("sign_off IS NULL OR sign_off >= sign_on", name="sea_dates"),
    )
    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    vessel_name: Mapped[str] = mapped_column(String(200))
    imo: Mapped[str | None] = mapped_column(String(7))
    rank: Mapped[str | None] = mapped_column(String(40))
    sign_on: Mapped[date] = mapped_column(Date)
    sign_off: Mapped[date | None] = mapped_column(Date)
    ship_type: Mapped[str | None] = mapped_column(String(40))
    flag: Mapped[str | None] = mapped_column(String(60))
    version: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


# ---------------------------------------------------------------- admin
class AdminEvent(Base):
    """Operational alerts (scraper failures, layout drift). Also emailed or sent to Slack when configured."""

    __tablename__ = "admin_events"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    severity: Mapped[str] = mapped_column(String(10))  # 'error' | 'warning' | 'info'
    source_id: Mapped[str | None] = mapped_column(String(80))
    message: Mapped[str] = mapped_column(Text)
    delivered_via: Mapped[list[str]] = mapped_column(ARRAY(String), default=list, server_default="{}")
    acknowledged_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = _now()


class AdminAuditLog(Base):
    __tablename__ = "admin_audit_log"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    admin: Mapped[str] = mapped_column(String(320))
    action: Mapped[str] = mapped_column(String(60))
    target: Mapped[str | None] = mapped_column(Text)
    diff: Mapped[dict | None] = mapped_column(JSONB)  # never user PII
    at: Mapped[datetime] = _now()
