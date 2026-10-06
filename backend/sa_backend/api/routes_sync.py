"""Offline-first sync for certificates and sea service.

Each row carries the server version the client last saw. The server applies a change only if that version is
still current; otherwise it returns a conflict with the server copy and changes nothing (no silent overwrite).
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import select

from sa_backend.api.deps import DB, CurrentUser
from sa_backend.api.schemas import (
    CertificateSync,
    Conflict,
    SeaServiceSync,
    SyncChanges,
    SyncPush,
    SyncPushResult,
)
from sa_backend.db.models import CertDocumentLink, Certificate, Document, SeaService

router = APIRouter(tags=["sync"])

CERT_FIELDS = ("type", "subtype", "number", "issuing_authority", "issue_date", "expiry_date", "deleted_at")
SEA_FIELDS = ("vessel_name", "imo", "rank", "sign_on", "sign_off", "ship_type", "flag", "deleted_at")


def _apply(db, model, item, fields, user, entity, applied, conflicts, now) -> None:
    row = db.get(model, item.id)
    if row is not None and row.user_id != user.id:
        raise HTTPException(409, "id belongs to another account")  # client UUIDs are random; never happens
    if row is None:
        if item.version not in (0, 1):
            conflicts.append(Conflict(id=item.id, entity=entity, server={"deleted": True}))
            return
        row = model(id=item.id, user_id=user.id, version=1, updated_at=now, **{f: getattr(item, f) for f in fields})
        db.add(row)
        applied[item.id] = 1
        return
    if row.version != item.version:
        server = {c.name: getattr(row, c.name) for c in model.__table__.columns if c.name != "user_id"}
        conflicts.append(Conflict(id=item.id, entity=entity, server=server))
        return
    for f in fields:
        setattr(row, f, getattr(item, f))
    row.version += 1
    row.updated_at = now
    applied[item.id] = row.version


@router.post("/sync/push", response_model=SyncPushResult)
def push(body: SyncPush, user: CurrentUser, db: DB) -> SyncPushResult:
    now = datetime.now(UTC)
    applied: dict[uuid.UUID, int] = {}
    conflicts: list[Conflict] = []
    for c in body.certificates:
        if c.expiry_date and c.issue_date and c.expiry_date < c.issue_date:
            raise HTTPException(422, f"certificate {c.id}: expiry before issue date")
        _apply(db, Certificate, c, CERT_FIELDS, user, "certificate", applied, conflicts, now)
    for s in body.sea_service:
        if s.sign_off and s.sign_off < s.sign_on:
            raise HTTPException(422, f"sea service {s.id}: sign-off before sign-on")
        _apply(db, SeaService, s, SEA_FIELDS, user, "sea_service", applied, conflicts, now)
    return SyncPushResult(applied=applied, conflicts=conflicts)


@router.get("/sync/changes", response_model=SyncChanges)
def changes(user: CurrentUser, db: DB, since: datetime | None = Query(None)) -> SyncChanges:
    cursor = datetime.now(UTC)
    cq = select(Certificate).where(Certificate.user_id == user.id)
    sq = select(SeaService).where(SeaService.user_id == user.id)
    if since:
        cq, sq = cq.where(Certificate.updated_at > since), sq.where(SeaService.updated_at > since)
    certs = [CertificateSync.model_validate(c, from_attributes=True) for c in db.scalars(cq)]
    sea = [SeaServiceSync.model_validate(s, from_attributes=True) for s in db.scalars(sq)]
    return SyncChanges(certificates=certs, sea_service=sea, cursor=cursor)


@router.get("/certificates/{cert_id}/linked-documents")
def linked_documents(cert_id: uuid.UUID, user: CurrentUser, db: DB) -> list[dict]:
    cert = db.get(Certificate, cert_id)
    if cert is None or cert.user_id != user.id:
        raise HTTPException(404, "certificate not found")
    rows = db.execute(
        select(CertDocumentLink, Document)
        .join(Document, Document.id == CertDocumentLink.document_id)
        .where(CertDocumentLink.certificate_id == cert_id)
        .order_by(Document.published_date.desc())
    ).all()
    return [
        {
            "document_id": str(d.id),
            "title": d.title,
            "circular_number": d.circular_number,
            "published_date": d.published_date,
            "reason": link.reason,
        }
        for link, d in rows
    ]
