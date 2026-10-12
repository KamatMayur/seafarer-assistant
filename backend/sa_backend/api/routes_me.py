from __future__ import annotations

import io
import json
import zipfile
from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
from sqlalchemy import delete, select

from sa_backend import reference
from sa_backend.api.deps import DB, CurrentUser
from sa_backend.api.schemas import DeviceIn, Profile, ProfileUpdate, QuietHours, TopicPref
from sa_backend.db.models import (
    AdminAuditLog,
    Alert,
    Certificate,
    Consent,
    Device,
    SeaService,
    User,
    UserTopicPref,
)
from sa_backend.services.alerts import backfill_user_alerts

router = APIRouter(prefix="/me", tags=["me"])


def _hhmm(minutes: int) -> str:
    return f"{minutes // 60:02d}:{minutes % 60:02d}"


def _minutes(hhmm: str) -> int:
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def to_profile(u: User) -> Profile:
    quiet = (
        QuietHours(start=_hhmm(u.quiet_start_min), end=_hhmm(u.quiet_end_min))
        if u.quiet_start_min is not None and u.quiet_end_min is not None
        else None
    )
    return Profile(
        id=u.id,
        email=u.email,
        name=u.name,
        preferred_language=u.preferred_language,
        rank=u.rank,
        department=u.department,
        level=u.level,
        ship_types=u.ship_types or [],
        home_mmd=u.home_mmd,
        exam_grades=u.exam_grades or [],
        alert_channels=u.alert_channels or [],
        quiet_hours=quiet,
        plan=u.plan,
        created_at=u.created_at,
    )


@router.get("", response_model=Profile)
def get_me(user: CurrentUser) -> Profile:
    return to_profile(user)


@router.patch("", response_model=Profile)
def update_me(body: ProfileUpdate, user: CurrentUser, db: DB) -> Profile:
    data = body.model_dump(exclude_unset=True)
    if data.keys() & {"department", "level", "rank", "exam_grades"}:
        # Check the profile as it will be after this change (e.g. a new department with the old rank).
        merged = {k: data.get(k, getattr(user, k)) for k in ("department", "level", "rank", "exam_grades")}
        problems = reference.profile_problems(
            merged["department"], merged["level"], merged["rank"], merged["exam_grades"] or []
        )
        if problems:
            raise HTTPException(422, "; ".join(problems))
    if "quiet_hours" in data:
        q = body.quiet_hours
        user.quiet_start_min = _minutes(q.start) if q else None
        user.quiet_end_min = _minutes(q.end) if q else None
        data.pop("quiet_hours")
    for k, v in data.items():
        setattr(user, k, v)
    db.flush()
    backfill_user_alerts(db, user)  # recent matching documents appear in the feed right away
    return to_profile(user)


@router.get("/topics", response_model=list[TopicPref])
def get_topics(user: CurrentUser) -> list[TopicPref]:
    return [TopicPref(topic=p.topic, mode=p.mode) for p in user.topic_prefs]


@router.put("/topics", status_code=204)
def put_topics(body: list[TopicPref], user: CurrentUser, db: DB) -> None:
    db.execute(delete(UserTopicPref).where(UserTopicPref.user_id == user.id))
    for p in {p.topic: p for p in body}.values():
        db.add(UserTopicPref(user_id=user.id, topic=p.topic, mode=p.mode))
    db.flush()
    db.expire(user, ["topic_prefs"])
    backfill_user_alerts(db, user)


@router.post("/devices")
def register_device(body: DeviceIn, user: CurrentUser, db: DB) -> dict:
    device = None
    if body.fcm_token:
        device = db.scalar(select(Device).where(Device.fcm_token == body.fcm_token))
    if device is None:
        device = Device(user_id=user.id, platform=body.platform)
        db.add(device)
    device.user_id, device.fcm_token, device.app_version = user.id, body.fcm_token, body.app_version
    device.last_seen = datetime.now(UTC)
    db.flush()
    return {"device_id": str(device.id)}


def _rows(db, model, user_id) -> list[dict]:
    out = []
    for obj in db.scalars(select(model).where(model.user_id == user_id)):
        out.append({c.name: getattr(obj, c.name) for c in model.__table__.columns})
    return out


@router.get("/export")
def export_me(user: CurrentUser, db: DB) -> Response:
    """DPDP: everything the server holds about the user, as JSON files in a ZIP."""
    data = {
        "profile.json": {c.name: getattr(user, c.name) for c in User.__table__.columns},
        "topics.json": _rows(db, UserTopicPref, user.id),
        "consents.json": _rows(db, Consent, user.id),
        "devices.json": _rows(db, Device, user.id),
        "certificates.json": _rows(db, Certificate, user.id),
        "sea_service.json": _rows(db, SeaService, user.id),
        "alerts.json": _rows(db, Alert, user.id),
    }
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for name, payload in data.items():
            z.writestr(name, json.dumps(payload, default=str, indent=2, ensure_ascii=False))
        z.writestr("README.txt", "Certificate images are stored only on your device and are not included.\n")
    return Response(
        buf.getvalue(),
        media_type="application/zip",
        headers={"Content-Disposition": 'attachment; filename="my-data.zip"'},
    )


@router.delete("", status_code=202)
def delete_me(user: CurrentUser, db: DB) -> dict:
    """Hard delete now (cascades to all user rows). The audit entry holds no personal data."""
    db.add(
        AdminAuditLog(
            admin="self-service", action="user.delete", target=None, diff={"certificates": len(user.certificates)}
        )
    )
    db.delete(user)
    return {"status": "deleted"}
