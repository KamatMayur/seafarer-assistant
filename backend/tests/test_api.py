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

from sa_backend import reference
from sa_backend.db.models import Alert, Certificate, Document, DocumentSummary, DocumentTag, Source, User
from sa_backend.services.matching import GRADE_DEPARTMENT

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


def test_existing_user_signs_in_without_consents_and_keeps_them(client, caplog, db):
    from sa_backend.db.models import Consent

    email_ok = {"purpose": "email_alerts", "granted": True, "policy_version": "draft-0.1"}
    first = login(client, caplog, email="back@example.com", consents=[*CONSENT, email_ok])
    again = login(client, caplog, email="back@example.com", consents=[])  # "I already have an account"
    assert first["new_user"] is True and again["new_user"] is False
    with db() as s:
        rows = s.scalars(select(Consent).join(User).where(User.email == "back@example.com")).all()
    assert sorted((c.purpose, c.granted) for c in rows) == [("core_service", True), ("email_alerts", True)]


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


def test_prod_refuses_default_jwt_secret(monkeypatch):
    from sa_backend.settings import get_settings

    monkeypatch.setenv("SA_ENV", "prod")
    monkeypatch.setenv("SA_JWT_SECRET", "dev-only-change-me")
    get_settings.cache_clear()
    with pytest.raises(RuntimeError):
        get_settings()
    monkeypatch.setenv("SA_JWT_SECRET", "x" * 48)
    get_settings.cache_clear()
    assert get_settings().env == "prod"
    get_settings.cache_clear()


def test_new_user_feed_is_backfilled_from_recent_documents(client, caplog, db):
    _seed_document(db)  # processed yesterday, engine-only, about CoCs
    tokens = login(client, caplog)
    assert client.get("/v1/feed", headers=auth(tokens)).json()["items"] == []

    client.patch("/v1/me", headers=auth(tokens), json={"department": "deck", "level": "officer"})
    assert client.get("/v1/feed", headers=auth(tokens)).json()["items"] == []  # not for deck

    client.patch("/v1/me", headers=auth(tokens), json={"department": "engine"})
    items = client.get("/v1/feed", headers=auth(tokens)).json()["items"]
    assert [i["kind"] for i in items] == ["new_document"]

    # adding a CoC adds the "may affect your certificate" alert; repeating changes nothing (idempotent)
    cert = {"id": str(uuid.uuid4()), "type": "coc", "expiry_date": "2030-01-01", "version": 0}
    client.post("/v1/sync/push", headers=auth(tokens), json={"certificates": [cert]})
    client.patch("/v1/me", headers=auth(tokens), json={"department": "engine"})
    kinds = sorted(i["kind"] for i in client.get("/v1/feed", headers=auth(tokens)).json()["items"])
    assert kinds == ["cert_impact", "new_document"]
    with db() as s:
        assert s.scalar(select(func.count()).select_from(Alert).where(Alert.channel != "in_app")) == 0


def test_feedback_and_crash_reports(client, caplog, db):
    tokens = login(client, caplog)
    r = client.post(
        "/v1/feedback",
        headers=auth(tokens),
        json={
            "kind": "problem",
            "message": "FAKE: feed is empty after sign-in",
            "app_version": "0.2.0",
            "platform": "windows",
            "context": {"screen": "feed", "big": "x" * 2000},
        },
    )
    assert r.status_code == 201
    assert client.post("/v1/feedback", json={"kind": "problem", "message": "x"}).status_code == 401
    assert client.post("/v1/feedback", headers=auth(tokens), json={"kind": "spam", "message": "x"}).status_code == 422
    with db() as s:
        from sa_backend.db.models import UserFeedback

        f = s.scalar(select(UserFeedback))
        assert f.kind == "problem" and len(f.context["big"]) == 500  # bounded
    # deleted with the account
    client.delete("/v1/me", headers=auth(tokens))
    with db() as s:
        assert s.scalar(select(func.count()).select_from(UserFeedback)) == 0


def test_privacy_notice_fills_settings(client, monkeypatch):
    from sa_backend.settings import get_settings

    page = client.get("/privacy").text
    assert "[contact email not set]" in page and "not affiliated with DGMA" in page
    monkeypatch.setenv("SA_PRIVACY_CONTACT", "privacy@example.com")
    monkeypatch.setenv("SA_OPERATOR_NAME", "FAKE Operator")
    get_settings.cache_clear()
    page = client.get("/privacy").text
    assert "privacy@example.com" in page and "FAKE Operator" in page and "<script" not in page
    md = client.get("/v1/legal/privacy").json()
    assert md["version"] and "Delete my account" in md["markdown"]


def test_unexpected_errors_are_reported(db, monkeypatch):
    from sa_backend.api.app import create_app
    from sa_backend.db.models import AdminEvent

    app = create_app()

    @app.get("/boom")
    def boom():
        raise RuntimeError("FAKE failure")

    c = TestClient(app, raise_server_exceptions=False)
    r = c.get("/boom")
    assert r.status_code == 500 and "reported" in r.json()["detail"]
    with db() as s:
        assert "RuntimeError" in s.scalar(select(AdminEvent.message))


# Department, level, rank and exam grades must agree with each other (reference.py + PATCH /v1/me).
def test_reference_tables_are_complete_and_consistent():
    for dept, ranks in reference.RANKS.items():
        for rank in ranks:
            if rank != "Other":
                assert rank in reference.RANK_LEVEL, rank
                assert reference.RANK_LEVEL[rank] in reference.DEPARTMENT_LEVELS[dept], rank
    for dept, grades in reference.DEPARTMENT_EXAM_GRADES.items():
        assert set(grades) <= set(reference.EXAM_GRADES), dept
        for g in grades:  # matching's grade -> department map agrees (NCV fits deck and engine)
            assert GRADE_DEPARTMENT.get(g, dept) == dept or dept == "other" or g == "dredge", (dept, g)
    for rank, held in reference.RANK_HELD_GRADES.items():
        dept = next(d for d, ranks in reference.RANKS.items() if rank in ranks)
        assert set(held) <= set(reference.DEPARTMENT_EXAM_GRADES[dept]), rank
    assert reference.DEPARTMENT_LEVELS["catering"] == ["rating"]
    assert reference.DEPARTMENT_LEVELS["other"] == list(reference.LEVELS)


@pytest.mark.parametrize(
    ("profile", "problem"),
    [
        ({"department": "engine", "level": "cadet", "rank": "Chief Engineer"}, "not a cadet / trainee rank"),
        ({"department": "engine", "level": "officer", "rank": "Master"}, "not a rank in Engine"),
        ({"department": "catering", "level": "officer"}, "not a level in Catering"),
        ({"department": "deck", "level": "officer", "exam_grades": ["meo_class_2"]}, "not an exam for Deck"),
    ],
)
def test_contradictions_are_rejected(client, caplog, profile, problem):
    tokens = login(client, caplog)
    r = client.patch("/v1/me", headers=auth(tokens), json=profile)
    assert r.status_code == 422 and problem in r.text, r.text


def test_changing_department_with_the_old_rank_is_rejected_but_consistent_changes_work(client, caplog):
    tokens = login(client, caplog)
    ok = {"department": "engine", "level": "cadet", "rank": "Engine Cadet", "exam_grades": ["meo_class_4"]}
    assert client.patch("/v1/me", headers=auth(tokens), json=ok).status_code == 200
    r = client.patch("/v1/me", headers=auth(tokens), json={"department": "deck"})
    assert r.status_code == 422 and "Engine Cadet is not a rank in Deck" in r.text
    moved = {"department": "deck", "level": "cadet", "rank": "Deck Cadet", "exam_grades": ["second_mate"]}
    assert client.patch("/v1/me", headers=auth(tokens), json=moved).status_code == 200
    # Fields unrelated to the profile rules still save without re-sending everything.
    assert client.patch("/v1/me", headers=auth(tokens), json={"name": "FAKE"}).status_code == 200
