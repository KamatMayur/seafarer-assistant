from __future__ import annotations

import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator

from sa_backend import reference

Lang = Literal["en", "hi", "mr", "ta", "ml", "bn", "te", "gu"]


class EmailStart(BaseModel):
    email: EmailStr


class ConsentIn(BaseModel):
    purpose: Literal["core_service", "email_alerts", "analytics", "cloud_backup"]
    granted: bool
    policy_version: str = Field(max_length=20)


class Verify(BaseModel):
    identifier: EmailStr
    code: str = Field(pattern=r"^\d{6}$")
    consents: list[ConsentIn] = []


class RefreshIn(BaseModel):
    refresh_token: str


class Tokens(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
    new_user: bool = False


class QuietHours(BaseModel):
    start: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    end: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")


class ProfileUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=200)
    preferred_language: Lang | None = None
    rank: str | None = Field(default=None, max_length=40)
    department: Literal["deck", "engine", "electrical", "catering", "other"] | None = None
    level: Literal["officer", "rating", "cadet"] | None = None
    ship_types: list[str] | None = None
    home_mmd: str | None = None
    exam_grades: list[str] | None = None
    alert_channels: list[Literal["in_app", "push", "email"]] | None = None
    quiet_hours: QuietHours | None = None

    @field_validator("ship_types")
    @classmethod
    def _ship_types(cls, v):
        if v is not None and not set(v) <= set(reference.SHIP_TYPES):
            raise ValueError(f"unknown ship types {set(v) - set(reference.SHIP_TYPES)}")
        return v

    @field_validator("home_mmd")
    @classmethod
    def _mmd(cls, v):
        if v is not None and v not in reference.MMDS:
            raise ValueError("unknown MMD")
        return v

    @field_validator("exam_grades")
    @classmethod
    def _grades(cls, v):
        if v is not None and not set(v) <= set(reference.EXAM_GRADES):
            raise ValueError("unknown exam grade")
        return v


class Profile(BaseModel):
    id: uuid.UUID
    email: str | None
    name: str | None
    preferred_language: str
    rank: str | None
    department: str | None
    level: str | None
    ship_types: list[str]
    home_mmd: str | None
    exam_grades: list[str]
    alert_channels: list[str]
    quiet_hours: QuietHours | None
    plan: str
    created_at: datetime


class TopicPref(BaseModel):
    topic: str
    mode: Literal["follow", "mute"]

    @field_validator("topic")
    @classmethod
    def _topic(cls, v):
        if v not in reference.TOPICS:
            raise ValueError("unknown topic")
        return v


class DeviceIn(BaseModel):
    platform: Literal["windows", "android", "ios"]
    fcm_token: str | None = None
    app_version: str | None = Field(default=None, max_length=20)


class DocumentCard(BaseModel):
    id: uuid.UUID
    title: str
    circular_number: str | None
    issuing_branch: str | None
    published_date: date | None
    doc_type: str
    priority: str
    status: str
    summary_short: str | None
    action_required: bool = False
    action_deadline: date | None = None


class Summary(BaseModel):
    language: str
    language_fallback: bool = False
    summary_short: str
    summary_detailed: str | None
    action_required: bool
    action_deadline: date | None
    affected_groups: dict[str, list[str]]
    key_points: list[str]
    uncertain_fields: list[str]
    method: str
    model_version: str
    verified_by_human: bool
    disclaimer: str = reference.DISCLAIMER


class Related(BaseModel):
    document_id: uuid.UUID
    relation: str
    title: str
    circular_number: str | None


class Impact(BaseModel):
    certificate_id: uuid.UUID
    reason: str


class DocumentDetail(DocumentCard):
    pdf_url: str
    source_url: str
    summary: Summary | None
    tags: dict[str, list[str]]
    mentions: dict[str, list[str]]
    related: list[Related]
    your_impact: list[Impact]
    text_available: bool


class FeedItem(BaseModel):
    alert_id: uuid.UUID
    kind: str
    priority: str
    created_at: datetime
    read: bool
    reason: str | None
    document: DocumentCard | None
    certificate_id: uuid.UUID | None


class FeedPage(BaseModel):
    items: list[FeedItem]
    next_before: datetime | None


class SearchPage(BaseModel):
    items: list[DocumentCard]
    total: int
    page: int


class Passage(BaseModel):
    """A quoted passage from one page of a circular. `quote` is verbatim PDF text (fragments joined by ' … ');
    `marks` are [start, end) character offsets of the matched words inside `quote`."""

    document: DocumentCard
    page: int
    quote: str
    marks: list[tuple[int, int]]
    pdf_url: str  # official PDF, opened at the page


class PassagePage(BaseModel):
    query: str
    items: list[Passage]
    disclaimer: str = reference.SEARCH_DISCLAIMER


class CertificateSync(BaseModel):
    id: uuid.UUID
    type: Literal["coc", "cop", "stcw_basic", "stcw_advanced", "medical", "cdc", "passport", "bsid", "visa", "other"]
    subtype: str | None = Field(default=None, max_length=40)
    number: str | None = Field(default=None, max_length=80)
    issuing_authority: str | None = Field(default=None, max_length=200)
    issue_date: date | None = None
    expiry_date: date | None = None
    version: int = 0  # the server version the client last saw (0 = new)
    deleted_at: datetime | None = None
    updated_at: datetime | None = None


class SeaServiceSync(BaseModel):
    id: uuid.UUID
    vessel_name: str = Field(max_length=200)
    imo: str | None = Field(default=None, pattern=r"^\d{7}$")
    rank: str | None = Field(default=None, max_length=40)
    sign_on: date
    sign_off: date | None = None
    ship_type: str | None = None
    flag: str | None = Field(default=None, max_length=60)
    version: int = 0
    deleted_at: datetime | None = None
    updated_at: datetime | None = None


class SyncPush(BaseModel):
    certificates: list[CertificateSync] = []
    sea_service: list[SeaServiceSync] = []


class Conflict(BaseModel):
    id: uuid.UUID
    entity: Literal["certificate", "sea_service"]
    server: dict


class SyncPushResult(BaseModel):
    applied: dict[uuid.UUID, int]  # id -> new server version
    conflicts: list[Conflict]


class SyncChanges(BaseModel):
    certificates: list[CertificateSync]
    sea_service: list[SeaServiceSync]
    cursor: datetime
