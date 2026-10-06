"""The document pipeline: scrape listings -> record new/changed items -> extract -> classify -> summarise -> tag
-> alert. Every step is idempotent, so a crash or rerun never duplicates documents or alerts."""

from __future__ import annotations

import hashlib
import logging
import re
from collections.abc import Callable
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path

from sqlalchemy import or_, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from sa_backend.db.models import (
    Document,
    DocumentSighting,
    DocumentSummary,
    DocumentTag,
    DocumentVersion,
    ScrapeRun,
    Source,
)
from sa_backend.services.admin_events import raise_event
from sa_backend.services.alerts import create_document_alerts
from sa_backend.settings import get_settings
from sa_scraper.classify import Classification, classify, load_rules
from sa_scraper.config import IST, SourceConfig
from sa_scraper.extract import ExtractResult, extract_text, text_quality
from sa_scraper.http import FetchError, PoliteClient
from sa_scraper.parse import ListingItem, parse_listing
from sa_scraper.summarise import summarise

log = logging.getLogger(__name__)

MAX_ATTEMPTS = 5
PROCESS_WINDOW_DAYS = 183  # older listing rows are stored as 'archived' (metadata only)
RECHECK_DAYS = 14  # re-hash PDFs published in the last N days ...
RECHECK_EVERY = timedelta(hours=24)  # ... once a day, to catch silently replaced files
# Lists of individual candidates (personal data): never download or store their text.
METADATA_ONLY_TITLE = re.compile(
    r"\bresults?\b|dispatch list|speed post|unclaimed list|pass(ed)? list|list of (suspended|candidates)", re.I
)

SessionFactory = Callable[[], Session]


@dataclass
class ScrapeOutcome:
    source_id: str
    items: int
    new: int
    changed: int
    problems: list[str]
    error: str | None = None


# ------------------------------------------------------------------------------------------- sources
def sync_sources(session: Session, configs: dict[str, SourceConfig]) -> None:
    for cfg in configs.values():
        stmt = insert(Source).values(id=cfg.id, url=cfg.url(), enabled=cfg.enabled, poll_minutes=cfg.poll_minutes)
        session.execute(
            stmt.on_conflict_do_update(
                index_elements=[Source.id],
                set_={
                    "url": stmt.excluded.url,
                    "enabled": stmt.excluded.enabled,
                    "poll_minutes": stmt.excluded.poll_minutes,
                },
            )
        )


def due_sources(session: Session, configs: dict[str, SourceConfig], now: datetime) -> list[SourceConfig]:
    out = []
    for src in session.scalars(select(Source).where(Source.enabled.is_(True))):
        cfg = configs.get(src.id)
        if cfg and (src.last_run_at is None or src.last_run_at + timedelta(minutes=src.poll_minutes) <= now):
            out.append(cfg)
    return out


# ------------------------------------------------------------------------------------------- listings
def text_policy_for(cfg: SourceConfig, title: str) -> str:
    return "metadata_only" if cfg.text_policy == "metadata_only" or METADATA_ONLY_TITLE.search(title) else "full"


def record_listing(session: Session, cfg: SourceConfig, page_url: str, items: list[ListingItem]) -> tuple[int, int]:
    """Insert new documents, refresh changed listing data, and record which pages each document is on."""
    new = changed = 0
    archive_before = (datetime.now(IST) - timedelta(days=PROCESS_WINDOW_DAYS)).date()
    for item in items:
        doc = session.scalar(select(Document).where(Document.pdf_url == item.pdf_url))
        if doc is None:
            old = item.published_date is not None and item.published_date < archive_before
            doc = Document(
                source_id=cfg.id,
                source_url=page_url,
                pdf_url=item.pdf_url,
                title=item.title,
                circular_number=item.circular_number,
                issuing_branch=item.branch,
                site_type=item.site_type,
                published_date=item.published_date,
                text_policy=text_policy_for(cfg, item.title),
                status="archived" if old else "new",
            )
            session.add(doc)
            session.flush()
            new += 1
        else:
            updates = {
                "title": item.title if item.title != doc.title else None,
                "published_date": item.published_date if item.published_date != doc.published_date else None,
                "circular_number": item.circular_number if item.circular_number and not doc.circular_number else None,
            }
            enrich = {
                "issuing_branch": item.branch if item.branch and not doc.issuing_branch else None,
                "site_type": item.site_type if item.site_type and not doc.site_type else None,
            }
            if any(v is not None for v in updates.values()):
                for k, v in updates.items():
                    if v is not None:
                        setattr(doc, k, v)
                if doc.status != "archived":
                    doc.status = "extracted" if doc.raw_text else "new"  # re-classify with the new listing data
                changed += 1
            for k, v in enrich.items():
                if v is not None:
                    setattr(doc, k, v)
                    if doc.status in ("processed", "needs_review"):
                        doc.status = "extracted"  # branch/type improve classification
        session.execute(insert(DocumentSighting).values(document_id=doc.id, source_id=cfg.id).on_conflict_do_nothing())
    return new, changed


def scrape_source(
    session: Session, client: PoliteClient, cfg: SourceConfig, years: list[int] | None = None
) -> ScrapeOutcome:
    now = datetime.now(IST)
    run = ScrapeRun(source_id=cfg.id, started_at=now)
    session.add(run)
    source = session.get(Source, cfg.id)
    years = years if cfg.is_yearly and years else [now.year]
    problems: list[str] = []
    total = new = changed = 0
    structure_hash = None
    try:
        for year in years:
            url: str | None = cfg.url(year)
            pages = 0
            max_pages = (cfg.layout.pagination or {}).get("max_pages", 1)
            while url and pages < max_pages:
                res = client.get(url)
                run.http_status = res.status
                if res.status >= 400:
                    raise FetchError(url, f"HTTP {res.status}", res.status)
                parsed = parse_listing(res.content, cfg.layout, url)
                problems += parsed.problems
                structure_hash = structure_hash or parsed.structure_hash
                n, c = record_listing(session, cfg, url, parsed.items)
                total, new, changed = total + len(parsed.items), new + n, changed + c
                pages += 1
                url = parsed.next_page_url if parsed.items else None
    except FetchError as e:
        run.error = str(e)
        log.error("scrape %s failed: %s", cfg.id, e)

    run.finished_at = datetime.now(IST)
    run.items_found, run.new_items, run.changed_items, run.problems = total, new, changed, problems[:20]
    if source:
        source.last_run_at = run.finished_at
        early_january = cfg.is_yearly and now.month == 1 and now.day <= 31
        if run.error:
            source.health = "failing"
            raise_event(session, "error", f"Fetch failed: {run.error}", cfg.id)
        elif total == 0 and not early_january:
            source.health = "failing"
            raise_event(session, "error", f"0 items parsed (layout change?). Problems: {problems[:3]}", cfg.id)
        elif problems:
            source.health = "degraded"
            raise_event(session, "warning", f"{len(problems)} parse problems, e.g. {problems[0]}", cfg.id)
        else:
            source.health = "ok"
        if structure_hash and source.structure_hash and structure_hash != source.structure_hash:
            raise_event(session, "warning", "Table headers changed; check selectors in sources YAML", cfg.id)
        if total:
            source.last_success_at = run.finished_at
            source.last_item_count = total
            source.structure_hash = structure_hash or source.structure_hash
    return ScrapeOutcome(cfg.id, total, new, changed, problems, run.error)


# ------------------------------------------------------------------------------------------- documents
def _pdf_cache_path(sha: str) -> Path:
    d = get_settings().data_dir / "pdfs"
    d.mkdir(parents=True, exist_ok=True)
    return d / f"{sha}.pdf"


def fetch_and_extract(client: PoliteClient, doc: Document) -> ExtractResult:
    res = client.get(doc.pdf_url)
    if res.status >= 400:
        raise FetchError(doc.pdf_url, f"HTTP {res.status}", res.status)
    sha = hashlib.sha256(res.content).hexdigest()
    if doc.pdf_hash and doc.pdf_hash != sha:
        log.info("PDF changed for %s", doc.pdf_url)
    doc.pdf_hash = sha
    doc.last_checked_at = datetime.now(IST)
    _pdf_cache_path(sha).write_bytes(res.content)
    if not res.content.startswith(b"%PDF"):
        return ExtractResult("", 0, "none", 0.0)  # e.g. an image or Word file
    return extract_text(res.content)


def _hints_for(session: Session, doc: Document, configs: dict[str, SourceConfig]) -> dict:
    """Merge hints from every listing page the document appeared on (e.g. the piracy page marks it critical)."""
    merged: dict = {"topics": []}
    for s in doc.sightings:
        cfg = configs.get(s.source_id)
        if not cfg:
            continue
        for k, v in cfg.hints.items():
            if k == "topics":
                merged["topics"] += [t for t in v if t not in merged["topics"]]
            elif k == "priority" and v == "critical":
                merged["priority"] = "critical"
            else:
                merged.setdefault(k, v)
    return merged


def apply_classification(session: Session, doc: Document, c: Classification) -> None:
    doc.doc_type = c.doc_type
    doc.priority = c.priority
    doc.classify_confidence = c.confidence
    session.query(DocumentTag).filter(DocumentTag.document_id == doc.id).delete()
    session.flush()
    rows = {(t.kind, t.value): t for t in c.tags}  # one row per kind/value; title beats body
    for t in c.tags:
        if t.strength == "title":
            rows[(t.kind, t.value)] = t
    for t in rows.values():
        session.add(
            DocumentTag(document_id=doc.id, kind=t.kind, value=t.value, strength=t.strength, evidence=t.evidence[:200])
        )
    session.add(
        DocumentTag(
            document_id=doc.id, kind="audience", value=c.audience, strength="title", evidence="; ".join(c.reasons)[:500]
        )
    )
    if c.related_reference:
        related = session.scalar(  # the original is the earliest document carrying that number
            select(Document)
            .where(
                Document.circular_number == c.related_reference,
                Document.id != doc.id,
                Document.related_document_id.is_(None),
            )
            .order_by(Document.published_date.asc().nulls_last())
            .limit(1)
        )
        if related:
            doc.related_document_id, doc.relation = related.id, c.relation


def process_document(session: Session, client: PoliteClient, doc: Document, configs: dict[str, SourceConfig]) -> str:
    rules = load_rules()
    if doc.status == "new" and doc.text_policy == "full":
        result = fetch_and_extract(client, doc)
        doc.raw_text, doc.page_count, doc.extraction_method = result.text or None, result.pages, result.method
        doc.text_quality = text_quality(result.text, doc.title) if result.text else 0.0
        session.execute(
            insert(DocumentVersion).values(document_id=doc.id, pdf_hash=doc.pdf_hash).on_conflict_do_nothing()
        )
    doc.status = "extracted"

    c = classify(
        doc.title,
        site_type=doc.site_type,
        branch=doc.issuing_branch,
        body=doc.raw_text,
        circular_number=doc.circular_number,
        hints=_hints_for(session, doc, configs),
    )
    apply_classification(session, doc, c)
    draft = summarise(
        doc.title,
        doc.raw_text,
        c,
        metadata_only=doc.text_policy == "metadata_only",
        text_quality=doc.text_quality if doc.text_quality is not None else 1.0,
    )
    existing = session.get(DocumentSummary, (doc.id, "en"))
    if existing is None or not existing.verified_by_human:  # never overwrite a human-verified summary
        values = dict(
            summary_short=draft.summary_short,
            summary_detailed=draft.summary_detailed,
            action_required=draft.action_required,
            action_deadline=draft.action_deadline,
            affected_groups=draft.affected_groups,
            key_points=draft.key_points,
            uncertain_fields=draft.uncertain_fields,
            method=draft.method,
            model_version=draft.model_version,
        )
        stmt = insert(DocumentSummary).values(document_id=doc.id, language="en", **values)
        session.execute(stmt.on_conflict_do_update(index_elements=["document_id", "language"], set_=values))

    held = c.confidence < rules.review_threshold and c.priority != "critical"
    doc.status = "needs_review" if held else "processed"
    doc.last_error = None
    session.flush()
    session.expire(doc, ["tags", "summaries", "sightings"])  # tags were rewritten above; reload before matching
    if not held:
        create_document_alerts(session, doc)
    return doc.status


def process_pending(
    session_factory: SessionFactory,
    client: PoliteClient,
    configs: dict[str, SourceConfig],
    limit: int = 200,
    published_since: date | None = None,
) -> dict[str, int]:
    counts: dict[str, int] = {}
    with session_factory() as s:
        q = select(Document.id).where(Document.status.in_(("new", "extracted")), Document.attempts < MAX_ATTEMPTS)
        if published_since:
            q = q.where(or_(Document.published_date.is_(None), Document.published_date >= published_since))
        # newest first so fresh circulars are never stuck behind a backfill
        ids = s.scalars(q.order_by(Document.published_date.desc().nulls_last()).limit(limit)).all()
    for doc_id in ids:
        session = session_factory()
        try:
            doc = session.get(Document, doc_id)
            status = process_document(session, client, doc, configs)
            session.commit()
        except Exception as e:  # one bad PDF must not stop the run
            session.rollback()
            doc = session.get(Document, doc_id)
            doc.attempts += 1
            doc.last_error = f"{type(e).__name__}: {e}"[:1000]
            status = "failed" if doc.attempts >= MAX_ATTEMPTS else "retry"
            if status == "failed":
                doc.status = "failed"
                raise_event(session, "error", f"Document failed {MAX_ATTEMPTS} times: {doc.pdf_url} ({e})")
            session.commit()
            log.warning("process %s failed (%s): %s", doc_id, status, e)
        finally:
            session.close()
        counts[status] = counts.get(status, 0) + 1
    return counts


def recheck_recent(session_factory: SessionFactory, client: PoliteClient, limit: int = 30) -> int:
    """Re-download recent PDFs once a day; a different hash means the file was silently replaced."""
    now = datetime.now(IST)
    with session_factory() as s:
        ids = s.scalars(
            select(Document.id)
            .where(
                Document.text_policy == "full",
                Document.pdf_hash.is_not(None),
                Document.published_date >= (now - timedelta(days=RECHECK_DAYS)).date(),
                or_(Document.last_checked_at.is_(None), Document.last_checked_at < now - RECHECK_EVERY),
            )
            .limit(limit)
        ).all()
    changed = 0
    for doc_id in ids:
        with session_factory() as s:
            doc = s.get(Document, doc_id)
            old = doc.pdf_hash
            try:
                res = client.get(doc.pdf_url)
            except FetchError as e:
                log.warning("recheck failed for %s: %s", doc.pdf_url, e)
                continue
            sha = hashlib.sha256(res.content).hexdigest()
            doc.last_checked_at = now
            if sha != old:
                doc.status = "new"  # full reprocess; alerts go out as 'updated_document'
                changed += 1
                raise_event(s, "info", f"PDF replaced on site: {doc.title[:100]}", doc.source_id)
            s.commit()
    return changed
