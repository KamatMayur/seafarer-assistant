from __future__ import annotations

import uuid
from datetime import date, datetime

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import RedirectResponse
from sqlalchemy import and_, func, or_, select
from sqlalchemy.orm import Session

from sa_backend.api.deps import DB, CurrentUser
from sa_backend.api.schemas import (
    DocumentCard,
    DocumentDetail,
    FeedItem,
    FeedPage,
    Impact,
    Lang,
    Related,
    SearchPage,
    Summary,
)
from sa_backend.db.models import Alert, CertDocumentLink, Certificate, Document, DocumentSummary, DocumentTag

router = APIRouter(tags=["documents"])


def _summary_for(doc: Document, lang: str) -> tuple[DocumentSummary | None, bool]:
    by_lang = {s.language: s for s in doc.summaries}
    if lang in by_lang:
        return by_lang[lang], False
    return by_lang.get("en"), lang != "en"


def card(doc: Document, lang: str = "en") -> DocumentCard:
    s, _ = _summary_for(doc, lang)
    return DocumentCard(
        id=doc.id,
        title=doc.title,
        circular_number=doc.circular_number,
        issuing_branch=doc.issuing_branch,
        published_date=doc.published_date,
        doc_type=doc.doc_type,
        priority=doc.priority,
        status=doc.status,
        summary_short=s.summary_short if s else None,
        action_required=bool(s and s.action_required),
        action_deadline=s.action_deadline if s else None,
    )


@router.get("/feed", response_model=FeedPage)
def feed(
    user: CurrentUser,
    db: DB,
    after: datetime | None = Query(None, description="only alerts newer than this (polling)"),
    before: datetime | None = Query(None, description="older page (pagination)"),
    limit: int = Query(30, ge=1, le=100),
    lang: Lang = "en",
) -> FeedPage:
    q = select(Alert).where(Alert.user_id == user.id, Alert.channel == "in_app")
    if after:
        q = q.where(Alert.created_at > after)
    if before:
        q = q.where(Alert.created_at < before)
    alerts = db.scalars(q.order_by(Alert.created_at.desc()).limit(limit)).all()
    doc_ids = {a.document_id for a in alerts if a.document_id}
    docs = {d.id: d for d in db.scalars(select(Document).where(Document.id.in_(doc_ids)))} if doc_ids else {}
    items = [
        FeedItem(
            alert_id=a.id,
            kind=a.kind,
            priority=a.priority,
            created_at=a.created_at,
            read=a.read_at is not None,
            reason=a.reason,
            document=card(docs[a.document_id], lang) if a.document_id in docs else None,
            certificate_id=a.certificate_id,
        )
        for a in alerts
    ]
    return FeedPage(items=items, next_before=alerts[-1].created_at if len(alerts) == limit else None)


@router.post("/feed/{alert_id}/read", status_code=204)
def mark_read(alert_id: uuid.UUID, user: CurrentUser, db: DB) -> None:
    alert = db.get(Alert, alert_id)
    if alert is None or alert.user_id != user.id:
        raise HTTPException(404, "alert not found")
    alert.read_at = alert.read_at or datetime.now(alert.created_at.tzinfo)


@router.get("/documents", response_model=SearchPage)
def search(
    _: CurrentUser,
    db: DB,
    q: str | None = Query(None, max_length=200),
    doc_type: str | None = None,
    department: str | None = None,
    date_from: date | None = Query(None, alias="from"),
    date_to: date | None = Query(None, alias="to"),
    include_archived: bool = True,
    page: int = Query(1, ge=1, le=200),
    lang: Lang = "en",
) -> SearchPage:
    internal = select(DocumentTag.document_id).where(DocumentTag.kind == "audience", DocumentTag.value == "internal")
    conds = [Document.id.not_in(internal)]
    order = [Document.published_date.desc().nulls_last()]
    if q:
        tsq = func.websearch_to_tsquery("english", q)
        conds.append(
            or_(Document.fts.op("@@")(tsq), Document.title.ilike(f"%{q}%"), Document.circular_number.ilike(f"%{q}%"))
        )
        order.insert(0, func.ts_rank(Document.fts, tsq).desc())
    if doc_type:
        conds.append(Document.doc_type == doc_type)
    if department:
        conds.append(
            Document.id.in_(
                select(DocumentTag.document_id).where(DocumentTag.kind == "department", DocumentTag.value == department)
            )
        )
    if date_from:
        conds.append(Document.published_date >= date_from)
    if date_to:
        conds.append(Document.published_date <= date_to)
    if not include_archived:
        conds.append(Document.status != "archived")
    where = and_(*conds)
    total = db.scalar(select(func.count()).select_from(Document).where(where))
    rows = db.scalars(select(Document).where(where).order_by(*order).offset((page - 1) * 20).limit(20)).all()
    return SearchPage(items=[card(d, lang) for d in rows], total=total, page=page)


def _related(db: Session, doc: Document) -> list[Related]:
    out = []
    if doc.related_document_id:
        r = db.get(Document, doc.related_document_id)
        out.append(
            Related(
                document_id=r.id,
                relation=f"this is a {doc.relation} of",
                title=r.title,
                circular_number=r.circular_number,
            )
        )
    for r in db.scalars(select(Document).where(Document.related_document_id == doc.id)):
        out.append(
            Related(
                document_id=r.id,
                relation=f"{r.relation or 'update'} issued",
                title=r.title,
                circular_number=r.circular_number,
            )
        )
    return out


@router.get("/documents/{doc_id}", response_model=DocumentDetail)
def document_detail(doc_id: uuid.UUID, user: CurrentUser, db: DB, lang: Lang = "en") -> DocumentDetail:
    doc = db.get(Document, doc_id)
    if doc is None:
        raise HTTPException(404, "document not found")
    s, fallback = _summary_for(doc, lang)
    summary = None
    if s:
        summary = Summary(
            language=s.language,
            language_fallback=fallback,
            summary_short=s.summary_short,
            summary_detailed=s.summary_detailed,
            action_required=s.action_required,
            action_deadline=s.action_deadline,
            affected_groups=s.affected_groups or {},
            key_points=s.key_points,
            uncertain_fields=s.uncertain_fields,
            method=s.method,
            model_version=s.model_version,
            verified_by_human=s.verified_by_human,
        )
    tags: dict[str, list[str]] = {}
    mentions: dict[str, list[str]] = {}
    for t in doc.tags:
        if t.kind == "audience":
            continue
        (tags if t.strength == "title" else mentions).setdefault(t.kind, []).append(t.value)
    impacts = (
        db.execute(
            select(CertDocumentLink)
            .join(Certificate, Certificate.id == CertDocumentLink.certificate_id)
            .where(CertDocumentLink.document_id == doc.id, Certificate.user_id == user.id)
        )
        .scalars()
        .all()
    )
    base = card(doc, lang)
    return DocumentDetail(
        **base.model_dump(),
        pdf_url=doc.pdf_url,
        source_url=doc.source_url,
        summary=summary,
        tags={k: sorted(v) for k, v in tags.items()},
        mentions={k: sorted(v) for k, v in mentions.items()},
        related=_related(db, doc),
        your_impact=[Impact(certificate_id=i.certificate_id, reason=i.reason) for i in impacts],
        text_available=doc.raw_text is not None,
    )


@router.get("/documents/{doc_id}/pdf")
def document_pdf(doc_id: uuid.UUID, _: CurrentUser, db: DB) -> RedirectResponse:
    doc = db.get(Document, doc_id)
    if doc is None:
        raise HTTPException(404, "document not found")
    return RedirectResponse(doc.pdf_url, status_code=302)  # always the official copy
