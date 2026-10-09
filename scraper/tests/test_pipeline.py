"""Integration tests: scrape -> process -> alerts against a real PostgreSQL test database, with HTTP faked.

Covers test checklist P1, P2, P3, P5, P6, P10 and the privacy rule for candidate lists.
"""

import uuid
from datetime import date, datetime, timedelta
from pathlib import Path

import httpx
import pytest
from sqlalchemy import func, select

from sa_backend.db.models import (
    AdminEvent,
    Alert,
    Certificate,
    Document,
    DocumentSummary,
    DocumentTag,
    Source,
    User,
)
from sa_scraper.config import IST, load_sources
from sa_scraper.http import PoliteClient
from sa_scraper.pipeline import process_pending, recheck_recent, scrape_source, sync_sources

FIX = Path(__file__).parent / "fixtures"
TODAY = datetime.now(IST).date()
PDF_65 = (FIX / "circular_65_of_2026.pdf").read_bytes()


def listing(rows: list[tuple[str, str, str, str]]) -> bytes:
    """FAKE year-list page. rows: (number, title, date dd-Mon-YYYY, pdf path)."""
    body = "".join(
        f"<tr><td>{n}</td><td>{t}</td><td>Engineering Wing</td><td>{d}</td><td>DGS Circulars</td>"
        f"<td>1 KB</td><td><a href='{p}'>Download</a></td></tr>"
        for n, t, d, p in rows
    )
    return (
        "<table class='data-table'><tr><th>No of Year.</th><th>Title</th><th>Wing/Branch</th><th>Publish Date</th>"
        f"<th>Type</th><th>Size / Format</th><th>Download</th></tr>{body}</table>"
    ).encode()


class FakeSite:
    def __init__(self):
        self.pages: dict[str, bytes] = {}
        self.files: dict[str, bytes] = {}
        self.requests: list[str] = []

    def handler(self, req: httpx.Request) -> httpx.Response:
        self.requests.append(req.url.path)
        if req.url.path == "/robots.txt":
            return httpx.Response(200, text="User-agent: *\nDisallow:")
        if req.url.path in self.files:
            return httpx.Response(200, content=self.files[req.url.path], headers={"content-type": "application/pdf"})
        if req.url.path in self.pages:
            return httpx.Response(200, content=self.pages[req.url.path])
        return httpx.Response(404)

    def client(self) -> PoliteClient:
        return PoliteClient("TestBot", min_interval_s=0, transport=httpx.MockTransport(self.handler))


D = (TODAY - timedelta(days=3)).strftime("%d-%b-%Y")
OLD = (TODAY - timedelta(days=400)).strftime("%d-%b-%Y")
ENGINE_CIRCULAR = (
    "65 of 2026",
    "Clarification to existing provision within TEAP Manual Part A, Chapter III related to issuance of "
    "steam/motor endorsement to MEO Class I / Class II CoC holders, reg.",
    D,
    "/download/c65.pdf",
)


@pytest.fixture
def site():
    s = FakeSite()
    s.files["/download/c65.pdf"] = PDF_65
    s.pages["/year-list"] = listing([ENGINE_CIRCULAR])
    return s


@pytest.fixture
def configs():
    return {"yl_dgs_circulars": load_sources()["yl_dgs_circulars"]}


def add_users(sessions):
    with sessions() as s:
        engine = User(email="engine@test.invalid", department="engine", level="officer", home_mmd="mumbai")
        deck = User(email="deck@test.invalid", department="deck", level="officer", home_mmd="kolkata")
        s.add_all([engine, deck])
        s.flush()
        cert = Certificate(
            id=uuid.uuid4(), user_id=engine.id, type="coc", subtype="MEO_CL2", expiry_date=date(2030, 1, 1)
        )
        s.add(cert)
        s.commit()
        return engine.id, deck.id, cert.id


def scrape(sessions, site, configs):
    with site.client() as client, sessions() as s:
        sync_sources(s, configs)
        out = scrape_source(s, client, configs["yl_dgs_circulars"])
        s.commit()
    return out


def test_new_circular_detected_processed_and_alerted_once(db, site, configs):
    engine_id, deck_id, cert_id = add_users(db)
    out = scrape(db, site, configs)
    assert (out.items, out.new) == (1, 1)

    with site.client() as client:
        assert process_pending(db, client, configs) == {"processed": 1}

    with db() as s:
        doc = s.scalar(select(Document))
        assert doc.status == "processed" and doc.doc_type == "circular" and doc.pdf_hash
        assert doc.raw_text and "TEAP" in doc.raw_text
        summary = s.get(DocumentSummary, (doc.id, "en"))
        assert summary.method == "extractive" and summary.key_points
        tags = {(t.kind, t.value) for t in s.scalars(select(DocumentTag).where(DocumentTag.document_id == doc.id))}
        assert ("department", "engine") in tags and ("audience", "seafarers") in tags
        alerts = s.scalars(select(Alert)).all()
        kinds = {(a.user_id, a.kind) for a in alerts}
        assert (engine_id, "new_document") in kinds
        assert (engine_id, "cert_impact") in kinds  # holds a CoC; circular is about CoCs
        assert all(a.user_id != deck_id for a in alerts)  # engine-only circular

    # P2/P10: scraping and processing again creates nothing new
    out = scrape(db, site, configs)
    assert (out.new, out.changed) == (0, 0)
    with site.client() as client:
        assert process_pending(db, client, configs) == {}
    with db() as s:
        assert s.scalar(select(func.count()).select_from(Document)) == 1
        assert s.scalar(select(func.count()).select_from(Alert)) == len(alerts)


def test_old_listing_rows_are_archived_not_processed_or_alerted(db, site, configs):
    add_users(db)
    site.pages["/year-list"] = listing([("1 of 2025", "FAKE old circular for seafarers", OLD, "/download/old.pdf")])
    scrape(db, site, configs)
    with site.client() as client:
        assert process_pending(db, client, configs) == {}
    with db() as s:
        assert s.scalar(select(Document.status)) == "archived"
        assert s.scalar(select(func.count()).select_from(Alert)) == 0
    assert "/download/old.pdf" not in site.requests


def test_candidate_lists_are_never_downloaded(db, site, configs):
    site.pages["/year-list"] = listing(
        [("", "COC Dispatch List of Engineering Wing of Dated 06.10.2026", D, "/download/dispatch.pdf")]
    )
    scrape(db, site, configs)
    with site.client() as client:
        process_pending(db, client, configs)
    with db() as s:
        doc = s.scalar(select(Document))
        assert doc.text_policy == "metadata_only" and doc.raw_text is None
    assert "/download/dispatch.pdf" not in site.requests


def test_changed_pdf_is_reprocessed_and_alerted_as_update(db, site, configs):
    engine_id, _, _ = add_users(db)
    scrape(db, site, configs)
    with site.client() as client:
        process_pending(db, client, configs)
    site.files["/download/c65.pdf"] = PDF_65 + b"\n% FAKE corrigendum bytes"
    with db() as s:  # pretend the last check was yesterday
        s.execute(Document.__table__.update().values(last_checked_at=datetime.now(IST) - timedelta(days=2)))
        s.commit()
    with site.client() as client:
        assert recheck_recent(db, client) == 1
        process_pending(db, client, configs)
    with db() as s:
        kinds = s.scalars(select(Alert.kind).where(Alert.user_id == engine_id, Alert.channel == "in_app")).all()
        assert "updated_document" in kinds


def test_title_change_is_detected(db, site, configs):
    scrape(db, site, configs)
    n, t, d, p = ENGINE_CIRCULAR
    site.pages["/year-list"] = listing([(n, t + " (revised)", d, p)])
    out = scrape(db, site, configs)
    assert out.changed == 1


def test_zero_items_raises_admin_event(db, site, configs):
    site.pages["/year-list"] = b"<html><body>FAKE: site under maintenance</body></html>"
    out = scrape(db, site, configs)
    assert out.items == 0
    with db() as s:
        event = s.scalar(select(AdminEvent))
        assert event.severity == "error" and event.source_id == "yl_dgs_circulars"
        assert s.get(Source, "yl_dgs_circulars").health == "failing"
    # the same problem is not re-sent on the next run
    scrape(db, site, configs)
    with db() as s:
        assert s.scalar(select(func.count()).select_from(AdminEvent)) == 1


def test_http_error_raises_admin_event(db, site, configs):
    site.pages.pop("/year-list")
    out = scrape(db, site, configs)
    assert out.error and "404" in out.error
    with db() as s:
        assert s.scalar(select(AdminEvent.severity)) == "error"


def test_failing_pdf_is_retried_then_marked_failed(db, site, configs):
    site.files.pop("/download/c65.pdf")
    scrape(db, site, configs)
    with site.client() as client:
        for _ in range(5):
            process_pending(db, client, configs)
    with db() as s:
        doc = s.scalar(select(Document))
        assert doc.status == "failed" and doc.attempts == 5 and "404" in doc.last_error
        assert s.scalar(select(func.count()).select_from(AdminEvent).where(AdminEvent.severity == "error")) >= 1


def test_reprocess_skips_admin_reviewed_documents(db, site, configs, capsys):
    import argparse

    from sa_scraper.cli import cmd_reprocess

    scrape(db, site, configs)
    with site.client() as client:
        process_pending(db, client, configs)
    with db() as s:
        doc = s.scalar(select(Document))
        doc.doc_type = "order"  # an admin's correction
        s.get(DocumentSummary, (doc.id, "en")).verified_by_human = True
        s.commit()

    cmd_reprocess(argparse.Namespace(status="processed,needs_review", limit=10))
    assert "0 documents queued" in capsys.readouterr().out
    with db() as s:
        assert s.scalar(select(Document.doc_type)) == "order"
        s.execute(DocumentSummary.__table__.update().values(verified_by_human=False))
        s.commit()

    cmd_reprocess(argparse.Namespace(status="processed,needs_review", limit=10))
    assert "1 documents queued" in capsys.readouterr().out
    with db() as s:
        assert s.scalar(select(Document.doc_type)) == "circular"


def test_reprocess_includes_documents_without_text(db, site, configs, capsys):
    """Scanned PDFs have no text layer; they must still be re-classified (from the title) after rule changes."""
    import argparse

    from sa_scraper.cli import cmd_reprocess

    scrape(db, site, configs)
    with site.client() as client:
        process_pending(db, client, configs)
    with db() as s:
        doc = s.scalar(select(Document))
        doc.raw_text = None  # as for a scan
        s.query(DocumentTag).filter(DocumentTag.kind == "department").delete()  # stale classification
        s.commit()
    cmd_reprocess(argparse.Namespace(status="processed,needs_review", limit=10))
    assert "1 documents queued" in capsys.readouterr().out
    with db() as s:
        depts = s.scalars(select(DocumentTag.value).where(DocumentTag.kind == "department")).all()
        assert depts == ["engine"]
    assert "/download/c65.pdf" in site.requests and site.requests.count("/download/c65.pdf") == 1  # no re-download
