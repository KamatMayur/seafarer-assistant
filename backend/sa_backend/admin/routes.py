"""Admin pages under /admin. Every change is written to admin_audit_log."""

from __future__ import annotations

import uuid
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, Form, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, RedirectResponse, Response
from fastapi.templating import Jinja2Templates
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from sa_backend import reference
from sa_backend.admin import auth
from sa_backend.api.deps import DB
from sa_backend.db.models import (
    DOC_STATUSES,
    DOC_TYPES,
    PRIORITIES,
    AdminAuditLog,
    AdminEvent,
    Alert,
    Document,
    DocumentSummary,
    DocumentTag,
    Source,
    User,
    UserFeedback,
)
from sa_backend.db.session import make_sessionmaker
from sa_backend.services.alerts import create_document_alerts
from sa_backend.settings import get_settings

HERE = Path(__file__).parent
templates = Jinja2Templates(directory=HERE / "templates")
router = APIRouter(prefix="/admin", include_in_schema=False)

Session_ = Annotated[str, Depends(auth.require_session)]
Csrf = Depends(auth.require_csrf)
PAGE_SIZE = 50

# Title-strength tags an admin may set. 'rank' is not produced by the classifier, 'audience' has its own field.
EDITABLE_TAGS: dict[str, dict[str, str]] = {
    "department": reference.DEPARTMENTS,
    "level": reference.LEVELS,
    "ship_type": reference.SHIP_TYPES,
    "mmd": reference.MMDS,
    "exam_grade": reference.EXAM_GRADES,
    "certificate_type": reference.CERT_TYPES,
    "topic": reference.TOPICS,
}
AUDIENCES = {
    "seafarers": "Seafarers (matched by tags)",
    "general": "General (followers of its topics only)",
    "industry": "Industry (followers of its topics only)",
    "internal": "Internal (never alerted)",
}


def _render(request: Request, name: str, sid: str | None, **ctx) -> HTMLResponse:
    open_feedback = 0
    if sid:
        with make_sessionmaker()() as s:
            open_feedback = s.scalar(
                select(func.count()).select_from(UserFeedback).where(UserFeedback.resolved_at.is_(None))
            )
    ctx |= {
        "csrf": auth.csrf_for(sid) if sid else "",
        "unofficial": reference.UNOFFICIAL,
        "admin": getattr(request.state, "admin", None),
        "open_feedback": open_feedback,
    }
    return templates.TemplateResponse(request, name, ctx)


def _audit(
    request: Request, db: Session, action: str, target: str | None, diff: dict | None = None, who: str | None = None
) -> None:
    ident = getattr(request.state, "admin", None)
    admin = who or (ident.email if ident else "anonymous")
    db.add(AdminAuditLog(admin=admin, action=action, target=target, diff=diff))


# ---------------------------------------------------------------- login
@router.get("/login", response_class=HTMLResponse)
def login_page(request: Request, db: DB) -> HTMLResponse:
    return _login_form(request, db, None)


def _login_form(request: Request, db: Session, error: str | None, status_code: int = 200) -> HTMLResponse:
    accounts = auth.accounts_exist(db)
    resp = _render(
        request,
        "login.html",
        None,
        error=error,
        accounts=accounts,
        configured=accounts or bool(get_settings().admin_token),
    )
    resp.status_code = status_code
    return resp


@router.post("/login")
def login(
    request: Request,
    db: DB,
    token: Annotated[str, Form()] = "",
    email: Annotated[str, Form()] = "",
    password: Annotated[str, Form()] = "",
    code: Annotated[str, Form()] = "",
) -> Response:
    ip = request.client.host if request.client else None
    acct = None
    if auth.accounts_exist(db):
        try:
            acct = auth.authenticate(db, email, password, code)
        except auth.LoginError as e:
            _audit(request, db, "login_failed", ip, {"email": email.strip().lower()[:320]}, who="anonymous")
            db.commit()  # keep the failed-attempt counter even though we return an error page
            return _login_form(request, db, str(e), 401)
    elif not auth.token_matches(token):
        _audit(request, db, "login_failed", ip, who="anonymous")
        return _login_form(request, db, "Wrong admin token.", 401)
    _audit(request, db, "login", ip, who=acct.email if acct else auth.TOKEN_ADMIN)
    resp = RedirectResponse("/admin", status_code=303)
    resp.set_cookie(
        auth.COOKIE,
        auth.new_session(acct),
        max_age=auth.SESSION_HOURS * 3600,
        httponly=True,
        samesite="strict",
        secure=get_settings().env != "dev",
        path="/admin",
    )
    return resp


@router.post("/logout", dependencies=[Csrf])
def logout() -> Response:
    resp = RedirectResponse("/admin/login", status_code=303)
    resp.delete_cookie(auth.COOKIE, path="/admin")
    return resp


# ---------------------------------------------------------------- dashboard
@router.get("", response_class=HTMLResponse)
def dashboard(request: Request, db: DB, sid: Session_) -> HTMLResponse:
    since = datetime.now(UTC) - timedelta(days=7)
    counts = dict(db.execute(select(Document.status, func.count()).group_by(Document.status)).all())
    events = db.scalars(
        select(AdminEvent)
        .where(or_(AdminEvent.created_at > since, AdminEvent.acknowledged_at.is_(None)))
        .order_by(AdminEvent.acknowledged_at.is_not(None), AdminEvent.id.desc())
        .limit(50)
    ).all()
    return _render(
        request,
        "dashboard.html",
        sid,
        sources=db.scalars(select(Source).order_by(Source.id)).all(),
        counts={s: counts.get(s, 0) for s in DOC_STATUSES},
        events=events,
        users=db.scalar(select(func.count()).select_from(User).where(User.deleted_at.is_(None))),
        alerts_7d=db.scalar(select(func.count()).select_from(Alert).where(Alert.created_at > since)),
    )


@router.post("/events/{event_id}/ack", response_class=HTMLResponse, dependencies=[Csrf])
def ack_event(event_id: int, request: Request, db: DB, sid: Session_) -> HTMLResponse:
    ev = db.get(AdminEvent, event_id)
    if ev is None:
        raise HTTPException(404)
    if ev.acknowledged_at is None:
        ev.acknowledged_at = datetime.now(UTC)
        _audit(request, db, "ack_event", str(event_id))
    return _render(request, "_event_row.html", sid, e=ev)


# ---------------------------------------------------------------- documents
@router.get("/review", response_class=HTMLResponse)
def review_queue(request: Request, db: DB, sid: Session_) -> Response:
    return documents(request, db, sid, status="needs_review", q="", page=1)


@router.get("/documents", response_class=HTMLResponse)
def documents(
    request: Request,
    db: DB,
    sid: Session_,
    status: Annotated[str, Query()] = "",
    q: Annotated[str, Query(max_length=200)] = "",
    page: Annotated[int, Query(ge=1)] = 1,
) -> HTMLResponse:
    stmt = select(Document)
    if status:
        stmt = stmt.where(Document.status == status)
    if q.strip():
        like = f"%{q.strip()}%"
        stmt = stmt.where(or_(Document.title.ilike(like), Document.circular_number.ilike(like)))
    total = db.scalar(select(func.count()).select_from(stmt.subquery()))
    docs = db.scalars(
        stmt.order_by(Document.published_date.desc().nulls_last(), Document.first_seen_at.desc())
        .offset((page - 1) * PAGE_SIZE)
        .limit(PAGE_SIZE)
    ).all()
    return _render(
        request,
        "documents.html",
        sid,
        docs=docs,
        total=total,
        page=page,
        pages=max(1, -(-total // PAGE_SIZE)),
        status=status,
        q=q,
        statuses=DOC_STATUSES,
    )


def _get_doc(db: Session, doc_id: uuid.UUID) -> Document:
    doc = db.get(Document, doc_id)
    if doc is None:
        raise HTTPException(404, "document not found")
    return doc


@router.get("/documents/{doc_id}", response_class=HTMLResponse)
def document_page(request: Request, doc_id: uuid.UUID, db: DB, sid: Session_, msg: str = "") -> HTMLResponse:
    doc = _get_doc(db, doc_id)
    summary = next((s for s in doc.summaries if s.language == "en"), None)
    title_tags = {(t.kind, t.value) for t in doc.tags if t.strength == "title"}
    return _render(
        request,
        "document.html",
        sid,
        doc=doc,
        summary=summary,
        title_tags=title_tags,
        body_tags=[t for t in doc.tags if t.strength == "body"],
        audience=next((t for t in doc.tags if t.kind == "audience"), None),
        editable=EDITABLE_TAGS,
        audiences=AUDIENCES,
        doc_types=DOC_TYPES,
        priorities=PRIORITIES,
        alert_count=db.scalar(select(func.count()).select_from(Alert).where(Alert.document_id == doc.id)),
        msg=msg,
    )


def _apply_tags(db: Session, doc: Document, checked: set[tuple[str, str]], audience: str) -> dict:
    """Make the title-strength tags of the editable kinds exactly `checked`. Returns what changed (for audit)."""
    current = {(t.kind, t.value): t for t in doc.tags}
    added, removed = [], []
    for key in checked:
        tag = current.get(key)
        if tag is None:
            db.add(DocumentTag(document_id=doc.id, kind=key[0], value=key[1], strength="title", evidence="admin"))
            added.append(":".join(key))
        elif tag.strength != "title":
            tag.strength, tag.evidence = "title", "admin (was body mention)"
            added.append(":".join(key))
    for key, tag in current.items():
        if key[0] in EDITABLE_TAGS and tag.strength == "title" and key not in checked:
            db.delete(tag)
            removed.append(":".join(key))
    aud = next((t for t in doc.tags if t.kind == "audience"), None)
    if aud is None or aud.value != audience:
        if aud is not None:
            db.delete(aud)
        db.add(DocumentTag(document_id=doc.id, kind="audience", value=audience, strength="title", evidence="admin"))
        added.append(f"audience:{audience}")
    return {"tags_added": added, "tags_removed": removed}


def _parse_date(value: str) -> date | None:
    try:
        return date.fromisoformat(value) if value.strip() else None
    except ValueError as e:
        raise HTTPException(422, f"bad date: {value}") from e


@router.post("/documents/{doc_id}", dependencies=[Csrf])
async def save_document(request: Request, doc_id: uuid.UUID, db: DB, _: Session_) -> Response:
    form = await request.form()
    action = str(form.get("action", "save"))
    if action not in ("save", "approve", "publish"):
        raise HTTPException(422, "unknown action")
    doc = _get_doc(db, doc_id)

    doc_type, priority, audience = str(form.get("doc_type")), str(form.get("priority")), str(form.get("audience"))
    if doc_type not in DOC_TYPES or priority not in PRIORITIES or audience not in AUDIENCES:
        raise HTTPException(422, "bad doc_type, priority or audience")
    checked = {
        (kind, value)
        for item in form.getlist("tag")
        for kind, _, value in [str(item).partition(":")]
        if value in EDITABLE_TAGS.get(kind, {})
    }
    diff: dict = {}
    if (doc.doc_type, doc.priority) != (doc_type, priority):
        diff["classification"] = [[doc.doc_type, doc.priority], [doc_type, priority]]
        doc.doc_type, doc.priority = doc_type, priority
    diff |= _apply_tags(db, doc, checked, audience)

    short = str(form.get("summary_short", "")).strip()
    if not short:
        raise HTTPException(422, "the short summary cannot be empty")
    values = dict(
        summary_short=short,
        summary_detailed=str(form.get("summary_detailed", "")).strip() or None,
        key_points=[p.strip() for p in str(form.get("key_points", "")).splitlines() if p.strip()],
        action_required=form.get("action_required") == "on",
        action_deadline=_parse_date(str(form.get("action_deadline", ""))),
        uncertain_fields=[],
        method="human",
        verified_by_human=True,
    )
    summary = db.get(DocumentSummary, (doc.id, "en"))
    if summary is None:
        db.add(DocumentSummary(document_id=doc.id, language="en", model_version="admin", **values))
        diff["summary"] = "created"
    else:
        changed = [k for k, v in values.items() if getattr(summary, k) != v]
        for k in changed:
            setattr(summary, k, values[k])
        if changed:
            diff["summary_fields"] = changed

    msg = "Saved."
    if action in ("approve", "publish"):
        diff["status"] = [doc.status, "processed"]
        doc.status = "processed"
    db.flush()
    if action == "approve":
        db.expire(doc, ["tags", "summaries"])
        n = create_document_alerts(db, doc)
        diff["alerts_created"] = n
        msg = f"Approved. {n} new alert(s) created."
    elif action == "publish":
        msg = "Published without alerts."
    _audit(request, db, action, str(doc.id), diff)
    return RedirectResponse(f"/admin/documents/{doc.id}?msg={msg}", status_code=303)


# ---------------------------------------------------------------- audit
@router.get("/audit", response_class=HTMLResponse)
def audit_log(request: Request, db: DB, sid: Session_) -> HTMLResponse:
    rows = db.scalars(select(AdminAuditLog).order_by(AdminAuditLog.id.desc()).limit(200)).all()
    return _render(request, "audit.html", sid, rows=rows)


# ---------------------------------------------------------------- tester feedback
@router.get("/feedback", response_class=HTMLResponse)
def feedback(request: Request, db: DB, sid: Session_, show: str = "") -> HTMLResponse:
    q = select(UserFeedback, User.email).join(User, User.id == UserFeedback.user_id)
    if show != "all":
        q = q.where(UserFeedback.resolved_at.is_(None))
    rows = db.execute(q.order_by(UserFeedback.id.desc()).limit(200)).all()
    return _render(request, "feedback.html", sid, rows=rows, show_all=show == "all")


@router.post("/feedback/{feedback_id}/resolve", dependencies=[Csrf])
def resolve_feedback(feedback_id: int, request: Request, db: DB, _: Session_) -> Response:
    f = db.get(UserFeedback, feedback_id)
    if f is None:
        raise HTTPException(404)
    if f.resolved_at is None:
        f.resolved_at = datetime.now(UTC)
        _audit(request, db, "feedback.resolve", str(feedback_id))
    return RedirectResponse("/admin/feedback", status_code=303)
