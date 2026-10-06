from __future__ import annotations

from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select, text

from sa_backend import reference
from sa_backend.api.deps import DB, require_admin
from sa_backend.db.models import AdminEvent, Document, Source, User

router = APIRouter()


@router.get("/healthz", tags=["ops"])
def healthz() -> dict:
    return {"status": "ok"}


@router.get("/readyz", tags=["ops"])
def readyz(db: DB) -> dict:
    try:
        db.execute(text("select 1"))
    except Exception as e:
        raise HTTPException(503, "database unavailable") from e
    return {"status": "ready"}


@router.get("/v1/meta", tags=["meta"])
def meta() -> dict:
    """Reference lists for onboarding and filters (cache on the client)."""
    return {
        "departments": reference.DEPARTMENTS,
        "levels": reference.LEVELS,
        "ranks": reference.RANKS,
        "ship_types": reference.SHIP_TYPES,
        "mmds": reference.MMDS,
        "exam_grades": reference.EXAM_GRADES,
        "topics": reference.TOPICS,
        "cert_types": reference.CERT_TYPES,
        "languages": reference.LANGUAGES,
        "disclaimer": reference.DISCLAIMER,
        "unofficial_notice": reference.UNOFFICIAL,
        "privacy_policy_version": "draft-0.1",
    }


@router.get("/v1/admin/status", tags=["admin"], dependencies=[Depends(require_admin)])
def admin_status(db: DB) -> dict:
    since = datetime.now(UTC) - timedelta(days=7)
    return {
        "sources": [
            {"id": s.id, "health": s.health, "last_success_at": s.last_success_at, "items": s.last_item_count}
            for s in db.scalars(select(Source).order_by(Source.id))
        ],
        "documents": dict(db.execute(select(Document.status, func.count()).group_by(Document.status)).all()),
        "needs_review": [
            {"id": str(d.id), "title": d.title, "confidence": d.classify_confidence}
            for d in db.scalars(
                select(Document)
                .where(Document.status == "needs_review")
                .order_by(Document.published_date.desc())
                .limit(50)
            )
        ],
        "events": [
            {"at": e.created_at, "severity": e.severity, "source": e.source_id, "message": e.message}
            for e in db.scalars(
                select(AdminEvent).where(AdminEvent.created_at > since).order_by(AdminEvent.id.desc()).limit(50)
            )
        ],
        "users": db.scalar(select(func.count()).select_from(User).where(User.deleted_at.is_(None))),
    }
