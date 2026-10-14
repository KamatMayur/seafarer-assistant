from __future__ import annotations

import uuid
from datetime import date, datetime

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import RedirectResponse
from sqlalchemy import and_, func, or_, select, text
from sqlalchemy.orm import Session

from sa_backend.api.deps import DB, CurrentUser
from sa_backend.api.schemas import (
    DocumentCard,
    DocumentDetail,
    FeedItem,
    FeedPage,
    Impact,
    Lang,
    Passage,
    PassagePage,
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


# Cited search (R1: quotes only, no generated answer). raw_text keeps pages separated by \f (see extract.py), so
# pages are split at query time: nothing to backfill, and admin edits / reprocessing are always reflected.
_START, _STOP = "⟦", "⟧"  # match markers; stripped before the quote is returned
_PASSAGES_SQL = text(
    """
    WITH tsq AS (SELECT websearch_to_tsquery('english', :q) AS q),
    cand AS (
        SELECT d.id, d.raw_text, ts_rank(d.fts, tsq.q) AS doc_rank
        FROM documents d, tsq
        WHERE d.fts @@ tsq.q AND d.raw_text IS NOT NULL
          AND d.id NOT IN (SELECT document_id FROM document_tags WHERE kind = 'audience' AND value = 'internal')
        ORDER BY doc_rank DESC, d.published_date DESC NULLS LAST
        LIMIT 40
    ),
    pages AS (
        SELECT c.id, c.doc_rank, p.page::int AS page, p.txt
        FROM cand c, regexp_split_to_table(c.raw_text, E'\\f') WITH ORDINALITY AS p(txt, page)
    ),
    scored AS (
        SELECT pages.*, ts_rank_cd(to_tsvector('english', txt), tsq.q) AS page_rank,
               row_number() OVER (PARTITION BY id ORDER BY ts_rank_cd(to_tsvector('english', txt), tsq.q) DESC,
                                  page) AS nth
        FROM pages, tsq
        WHERE to_tsvector('english', txt) @@ tsq.q
    )
    SELECT s.id, s.page,
           ts_headline('english', s.txt, tsq.q, :opts) AS quote
    FROM scored s, tsq
    WHERE s.nth <= 2
    ORDER BY s.page_rank + s.doc_rank DESC, s.page
    LIMIT :limit
    """
)
_HEADLINE_OPTS = (
    f'StartSel="{_START}", StopSel="{_STOP}", MaxFragments=2, MaxWords=40, MinWords=15, FragmentDelimiter=" … "'
)


def split_marks(headline: str) -> tuple[str, list[tuple[int, int]]]:
    """Turn ts_headline output into plain text plus [start, end) offsets of the highlighted words."""
    out: list[str] = []
    marks: list[tuple[int, int]] = []
    pos, start = 0, None
    for ch in headline:
        if ch == _START:
            start = pos
        elif ch == _STOP:
            if start is not None and pos > start:
                marks.append((start, pos))
            start = None
        else:
            out.append(ch)
            pos += 1
    return "".join(out), marks


@router.get("/search/passages", response_model=PassagePage)
def search_passages(
    _: CurrentUser,
    db: DB,
    q: str = Query(..., min_length=2, max_length=200),
    limit: int = Query(10, ge=1, le=30),
    lang: Lang = "en",
) -> PassagePage:
    rows = db.execute(_PASSAGES_SQL, {"q": q, "opts": _HEADLINE_OPTS, "limit": limit}).all()
    docs = {d.id: d for d in db.scalars(select(Document).where(Document.id.in_({r.id for r in rows})))} if rows else {}
    items = []
    for r in rows:
        quote, marks = split_marks(r.quote)
        doc = docs[r.id]
        items.append(
            Passage(
                document=card(doc, lang), page=r.page, quote=quote, marks=marks, pdf_url=f"{doc.pdf_url}#page={r.page}"
            )
        )
    return PassagePage(query=q, items=items)


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
