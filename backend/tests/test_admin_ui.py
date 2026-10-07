import re
import uuid
from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from sa_backend.db.models import AdminAuditLog, AdminEvent, Alert, Document, DocumentSummary, DocumentTag, Source, User

TOKEN = "test-admin-token"


@pytest.fixture
def client(db, monkeypatch):
    monkeypatch.setenv("SA_ADMIN_TOKEN", TOKEN)
    from sa_backend.settings import get_settings

    get_settings.cache_clear()
    from sa_backend.api.app import create_app

    return TestClient(create_app())


def login(client) -> str:
    r = client.post("/admin/login", data={"token": TOKEN}, follow_redirects=False)
    assert r.status_code == 303
    page = client.get("/admin")
    assert page.status_code == 200
    return re.search(r'name="csrf" value="([^"]+)"', page.text).group(1)


def _held_document(db) -> uuid.UUID:
    with db() as s:
        s.add(Source(id="yl_dgs_circulars", url="https://dgma.gov.in/x"))
        s.add(User(email="engine@example.com", department="engine", level="officer"))
        s.add(User(email="deck@example.com", department="deck", level="officer"))
        s.flush()
        doc = Document(
            source_id="yl_dgs_circulars",
            source_url="https://dgma.gov.in/x",
            pdf_url=f"https://dgma.gov.in/download/{uuid.uuid4()}.pdf",
            pdf_hash="abc",
            title="FAKE notice about something unclear",
            published_date=date.today() - timedelta(days=2),
            doc_type="unknown",
            status="needs_review",
            classify_confidence=0.4,
            raw_text="FAKE body",
        )
        s.add(doc)
        s.flush()
        s.add_all(
            [
                DocumentTag(document_id=doc.id, kind="audience", value="general", strength="title", evidence="x"),
                DocumentTag(document_id=doc.id, kind="topic", value="exams", strength="body", evidence="exam"),
                DocumentSummary(
                    document_id=doc.id,
                    language="en",
                    summary_short="FAKE extract",
                    method="extractive",
                    model_version="extractive-rules-v1",
                    uncertain_fields=["date"],
                ),
            ]
        )
        s.commit()
        return doc.id


def _form(csrf, action, **extra):
    data = {
        "csrf": csrf,
        "action": action,
        "doc_type": "circular",
        "priority": "normal",
        "audience": "seafarers",
        "tag": ["department:engine", "topic:exams"],
        "summary_short": "Engine officers: FAKE corrected summary",
        "summary_detailed": "",
        "key_points": "point one\n\n point two ",
        "action_deadline": "",
    }
    return data | extra


def test_pages_need_login(client):
    for path in ("/admin", "/admin/review", "/admin/documents", "/admin/audit"):
        r = client.get(path, follow_redirects=False)
        assert r.status_code == 303 and r.headers["location"] == "/admin/login", path
    assert client.post("/admin/login", data={"token": "wrong"}).status_code == 401


def test_admin_ui_disabled_without_token(db, monkeypatch):
    monkeypatch.setenv("SA_ADMIN_TOKEN", "")
    from sa_backend.settings import get_settings

    get_settings.cache_clear()
    from sa_backend.api.app import create_app

    c = TestClient(create_app())
    assert "disabled" in c.get("/admin/login").text
    assert c.post("/admin/login", data={"token": ""}).status_code == 401


def test_rotating_admin_token_ends_sessions(client, monkeypatch):
    login(client)
    from sa_backend.settings import get_settings

    monkeypatch.setenv("SA_ADMIN_TOKEN", "rotated")
    get_settings.cache_clear()
    assert client.get("/admin", follow_redirects=False).status_code == 303


def test_review_save_then_approve_sends_alerts(client, db):
    doc_id = _held_document(db)
    csrf = login(client)
    assert "FAKE notice about something unclear" in client.get("/admin/review").text
    assert "FAKE body" in client.get(f"/admin/documents/{doc_id}").text

    # POST without CSRF is refused
    r = client.post(f"/admin/documents/{doc_id}", data=_form("nope", "save"))
    assert r.status_code == 403

    r = client.post(f"/admin/documents/{doc_id}", data=_form(csrf, "save"), follow_redirects=False)
    assert r.status_code == 303
    with db() as s:
        doc = s.get(Document, doc_id)
        assert doc.status == "needs_review" and doc.doc_type == "circular"
        tags = {(t.kind, t.value): t.strength for t in doc.tags}
        assert tags == {
            ("department", "engine"): "title",
            ("topic", "exams"): "title",
            ("audience", "seafarers"): "title",
        }
        summary = s.get(DocumentSummary, (doc_id, "en"))
        assert summary.verified_by_human and summary.method == "human"
        assert summary.key_points == ["point one", "point two"] and summary.uncertain_fields == []
        assert s.scalar(select(func.count()).select_from(Alert)) == 0

    r = client.post(f"/admin/documents/{doc_id}", data=_form(csrf, "approve"))
    assert "1 new alert" in r.text
    with db() as s:
        assert s.get(Document, doc_id).status == "processed"
        emails = s.scalars(select(User.email).join(Alert, Alert.user_id == User.id)).all()
        assert set(emails) == {"engine@example.com"}
        actions = s.scalars(select(AdminAuditLog.action).order_by(AdminAuditLog.id)).all()
        assert actions == ["login", "save", "approve"]


def test_publish_without_alerts_and_unchecking_tags(client, db):
    doc_id = _held_document(db)
    csrf = login(client)
    client.post(f"/admin/documents/{doc_id}", data=_form(csrf, "save"))
    r = client.post(f"/admin/documents/{doc_id}", data=_form(csrf, "publish", tag=["mmd:mumbai"], audience="internal"))
    assert "Published without alerts" in r.text
    with db() as s:
        doc = s.get(Document, doc_id)
        assert doc.status == "processed"
        assert {(t.kind, t.value) for t in doc.tags} == {("mmd", "mumbai"), ("audience", "internal")}
        assert s.scalar(select(func.count()).select_from(Alert)) == 0


def test_rejects_bad_input(client, db):
    doc_id = _held_document(db)
    csrf = login(client)
    assert client.post(f"/admin/documents/{doc_id}", data=_form(csrf, "save", doc_type="memo")).status_code == 422
    assert client.post(f"/admin/documents/{doc_id}", data=_form(csrf, "save", summary_short=" ")).status_code == 422
    assert client.post(f"/admin/documents/{doc_id}", data=_form(csrf, "delete")).status_code == 422
    r = client.post(f"/admin/documents/{doc_id}", data=_form(csrf, "save", action_deadline="31-12-2026"))
    assert r.status_code == 422
    # unknown tag values are ignored rather than stored
    client.post(f"/admin/documents/{doc_id}", data=_form(csrf, "save", tag=["department:pilot", "rank:master"]))
    with db() as s:
        assert {t.kind for t in s.get(Document, doc_id).tags} == {"audience", "topic"}  # body mention kept
    assert client.get(f"/admin/documents/{uuid.uuid4()}").status_code == 404


def test_dashboard_and_event_ack(client, db):
    with db() as s:
        s.add(AdminEvent(severity="error", source_id="yl_x", message="FAKE layout drift"))
        s.commit()
        ev_id = s.scalar(select(AdminEvent.id))
    csrf = login(client)
    assert "FAKE layout drift" in client.get("/admin").text
    assert client.post(f"/admin/events/{ev_id}/ack").status_code == 403
    r = client.post(f"/admin/events/{ev_id}/ack", headers={"X-CSRF-Token": csrf})
    assert r.status_code == 200 and "acknowledged" in r.text
    with db() as s:
        assert s.get(AdminEvent, ev_id).acknowledged_at is not None
    assert "ack_event" in client.get("/admin/audit").text


def test_document_list_filters(client, db):
    _held_document(db)
    login(client)
    assert "FAKE notice" in client.get("/admin/documents", params={"q": "unclear"}).text
    assert "FAKE notice" not in client.get("/admin/documents", params={"q": "zzz"}).text
    assert "FAKE notice" not in client.get("/admin/documents", params={"status": "processed"}).text
    assert client.get("/admin/static/htmx.min.js").status_code == 200
