import io
import json
import logging
import re
import uuid
import zipfile
from datetime import date, datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from sa_backend.db.models import Alert, Certificate, Document, DocumentSummary, DocumentTag, Source, User

CONSENT = [{"purpose": "core_service", "granted": True, "policy_version": "draft-0.1"}]


@pytest.fixture
def client(db, monkeypatch):
    monkeypatch.setenv("SA_ENV", "dev")
    monkeypatch.setenv("SA_ADMIN_TOKEN", "test-admin-token")
    from sa_backend.settings import get_settings

    get_settings.cache_clear()
    from sa_backend.api.app import create_app

    return TestClient(create_app())


def login(client, caplog, email="sailor@example.com", consents=CONSENT):
    with caplog.at_level(logging.WARNING):
        caplog.clear()
        assert client.post("/v1/auth/email/start", json={"email": email}).status_code == 202
    code = re.search(r"DEV LOGIN CODE for \S+: (\d{6})", caplog.text).group(1)
    r = client.post("/v1/auth/verify", json={"identifier": email, "code": code, "consents": consents})
    assert r.status_code == 200, r.text
    return r.json()


def auth(tokens):
    return {"Authorization": f"Bearer {tokens['access_token']}"}


def test_signup_requires_consent(client, caplog):
    with caplog.at_level(logging.WARNING):
        client.post("/v1/auth/email/start", json={"email": "x@example.com"})
    code = re.search(r": (\d{6})", caplog.text).group(1)
    r = client.post("/v1/auth/verify", json={"identifier": "x@example.com", "code": code, "consents": []})
    assert r.status_code == 400


def test_wrong_code_and_rate_limit(client):
    for _ in range(5):
        assert client.post("/v1/auth/email/start", json={"email": "y@example.com"}).status_code == 202
    assert client.post("/v1/auth/email/start", json={"email": "y@example.com"}).status_code == 429
    r = client.post("/v1/auth/verify", json={"identifier": "y@example.com", "code": "000000", "consents": CONSENT})
    assert r.status_code == 401


def test_login_profile_and_refresh_rotation(client, caplog):
    tokens = login(client, caplog)
    assert tokens["new_user"] is True
    assert client.get("/v1/me").status_code == 401
    r = client.patch(
        "/v1/me",
        headers=auth(tokens),
        json={
            "department": "engine",
            "level": "officer",
            "home_mmd": "mumbai",
            "ship_types": ["tanker"],
            "exam_grades": ["meo_class_2"],
            "quiet_hours": {"start": "22:00", "end": "07:00"},
        },
    )
    assert r.status_code == 200 and r.json()["quiet_hours"] == {"start": "22:00", "end": "07:00"}
    assert client.patch("/v1/me", headers=auth(tokens), json={"home_mmd": "atlantis"}).status_code == 422

    new = client.post("/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert new.status_code == 200
    # replaying the old refresh token is refused and revokes the family
    assert client.post("/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}).status_code == 401
    assert client.post("/v1/auth/refresh", json={"refresh_token": new.json()["refresh_token"]}).status_code == 401


def _seed_document(db, title="FAKE circular for engine officers", dept="engine"):
    with db() as s:
        s.add(Source(id="yl_dgs_circulars", url="https://dgma.gov.in/x"))
        s.flush()
        doc = Document(
            source_id="yl_dgs_circulars",
            source_url="https://dgma.gov.in/x",
            pdf_url=f"https://dgma.gov.in/download/{uuid.uuid4()}.pdf",
            title=title,
            circular_number="99 of 2026",
            published_date=date.today() - timedelta(days=1),
            doc_type="circular",
            status="processed",
            raw_text="FAKE body about revalidation of CoC",
        )
        s.add(doc)
        s.flush()
        s.add_all(
            [
                DocumentTag(document_id=doc.id, kind="department", value=dept, strength="title"),
                DocumentTag(document_id=doc.id, kind="audience", value="seafarers", strength="title"),
                DocumentTag(document_id=doc.id, kind="certificate_type", value="coc", strength="title"),
                DocumentSummary(
                    document_id=doc.id,
                    language="en",
                    summary_short="FAKE short summary",
                    key_points=["FAKE point"],
                    method="extractive",
                    model_version="extractive-rules-v1",
                ),
            ]
        )
        s.commit()
        return doc


def test_feed_document_detail_and_search(client, caplog, db):
    from sa_backend.services.alerts import create_document_alerts

    tokens = login(client, caplog)
    client.patch("/v1/me", headers=auth(tokens), json={"department": "engine", "level": "officer"})
    cert_id = str(uuid.uuid4())
    client.post(
        "/v1/sync/push",
        headers=auth(tokens),
        json={"certificates": [{"id": cert_id, "type": "coc", "expiry_date": "2030-01-01", "version": 0}]},
    )
    doc = _seed_document(db)
    with db() as s:
        create_document_alerts(s, s.get(Document, doc.id))
        s.commit()

    feed = client.get("/v1/feed", headers=auth(tokens)).json()
    kinds = {i["kind"] for i in feed["items"]}
    assert kinds == {"new_document", "cert_impact"}
    item = next(i for i in feed["items"] if i["kind"] == "new_document")
    assert item["document"]["summary_short"] == "FAKE short summary"
    assert client.post(f"/v1/feed/{item['alert_id']}/read", headers=auth(tokens)).status_code == 204

    detail = client.get(f"/v1/documents/{doc.id}?lang=hi", headers=auth(tokens)).json()
    assert detail["summary"]["language_fallback"] is True  # Hindi not available yet -> English
    assert detail["summary"]["disclaimer"].startswith("Automatic extract")
    assert detail["your_impact"][0]["certificate_id"] == cert_id
    assert detail["tags"]["department"] == ["engine"]

    res = client.get("/v1/documents?q=revalidation", headers=auth(tokens)).json()
    assert res["total"] == 1 and res["items"][0]["id"] == str(doc.id)
    assert client.get("/v1/documents?q=nothingmatches", headers=auth(tokens)).json()["total"] == 0
    r = client.get(f"/v1/documents/{doc.id}/pdf", headers=auth(tokens), follow_redirects=False)
    assert r.status_code == 302 and r.headers["location"].startswith("https://dgma.gov.in/")


def test_sync_conflict_is_not_silently_overwritten(client, caplog):
    tokens = login(client, caplog)
    cid = str(uuid.uuid4())
    r = client.post(
        "/v1/sync/push",
        headers=auth(tokens),
        json={"certificates": [{"id": cid, "type": "medical", "expiry_date": "2027-01-01", "version": 0}]},
    ).json()
    assert r["applied"][cid] == 1
    # device A edits from version 1
    r = client.post(
        "/v1/sync/push",
        headers=auth(tokens),
        json={"certificates": [{"id": cid, "type": "medical", "expiry_date": "2027-06-01", "version": 1}]},
    ).json()
    assert r["applied"][cid] == 2
    # device B also edited from version 1 while offline -> conflict, server keeps A's value
    r = client.post(
        "/v1/sync/push",
        headers=auth(tokens),
        json={"certificates": [{"id": cid, "type": "medical", "expiry_date": "2026-12-01", "version": 1}]},
    ).json()
    assert r["applied"] == {} and r["conflicts"][0]["server"]["expiry_date"] == "2027-06-01"
    # tombstone delete syncs
    r = client.post(
        "/v1/sync/push",
        headers=auth(tokens),
        json={"certificates": [{"id": cid, "type": "medical", "version": 2, "deleted_at": datetime.now().isoformat()}]},
    ).json()
    assert r["applied"][cid] == 3
    changes = client.get("/v1/sync/changes", headers=auth(tokens)).json()
    assert changes["certificates"][0]["deleted_at"] is not None
    later = client.get(f"/v1/sync/changes?since={changes['cursor']}", headers=auth(tokens)).json()
    assert later["certificates"] == []


def test_sync_rejects_bad_dates(client, caplog):
    tokens = login(client, caplog)
    r = client.post(
        "/v1/sync/push",
        headers=auth(tokens),
        json={
            "certificates": [
                {"id": str(uuid.uuid4()), "type": "coc", "issue_date": "2026-01-02", "expiry_date": "2025-01-01"}
            ]
        },
    )
    assert r.status_code == 422


def test_export_and_delete_account(client, caplog, db):
    tokens = login(client, caplog)
    client.post(
        "/v1/sync/push",
        headers=auth(tokens),
        json={"certificates": [{"id": str(uuid.uuid4()), "type": "passport", "number": "FAKE123", "version": 0}]},
    )
    r = client.get("/v1/me/export", headers=auth(tokens))
    z = zipfile.ZipFile(io.BytesIO(r.content))
    assert json.loads(z.read("certificates.json"))[0]["number"] == "FAKE123"
    assert "consents.json" in z.namelist()

    assert client.delete("/v1/me", headers=auth(tokens)).status_code == 202
    with db() as s:
        assert s.scalar(select(func.count()).select_from(User)) == 0
        assert s.scalar(select(func.count()).select_from(Certificate)) == 0
        assert s.scalar(select(func.count()).select_from(Alert)) == 0
    assert client.get("/v1/me", headers=auth(tokens)).status_code == 401


def test_meta_and_admin(client):
    meta = client.get("/v1/meta").json()
    assert "kolkata" in meta["mmds"] and "Not affiliated" in meta["unofficial_notice"]
    assert client.get("/v1/admin/status").status_code == 403
    assert client.get("/v1/admin/status", headers={"Authorization": "Bearer test-admin-token"}).status_code == 200
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/readyz").status_code == 200
