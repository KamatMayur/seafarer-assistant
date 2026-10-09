"""Per-admin accounts: password + TOTP, lockout, session invalidation, audit identity, manage CLI."""

import re
import time

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from sa_backend.admin import auth, manage
from sa_backend.db.models import AdminAccount, AdminAuditLog

PASSWORD = "correct horse battery"


@pytest.fixture
def client(db, monkeypatch):
    monkeypatch.setenv("SA_ADMIN_TOKEN", "bootstrap-token")
    from sa_backend.settings import get_settings

    get_settings.cache_clear()
    from sa_backend.api.app import create_app

    return TestClient(create_app())


def make_admin(db, email="owner@example.com", role="owner") -> str:
    with db() as s:
        _, secret = manage.create(s, email, PASSWORD, role)
        s.commit()
    return secret


def code_for(secret: str, offset_steps: int = 0) -> str:
    return auth.totp_code(secret, auth.current_step() + offset_steps)


def test_totp_matches_rfc6238_vector():
    # RFC 6238 Appendix B, SHA-1 secret "12345678901234567890", T=59 -> 94287082 (8 digits); last 6 = 287082
    secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    assert auth.totp_code(secret, 59 // 30) == "287082"


def test_totp_rejects_replay_and_old_codes():
    secret = auth.new_totp_secret()
    now = time.time()
    step = auth.verify_totp(secret, auth.totp_code(secret, auth.current_step(now)), 0, now)
    assert step is not None
    assert auth.verify_totp(secret, auth.totp_code(secret, step), step, now) is None  # replay
    assert auth.verify_totp(secret, auth.totp_code(secret, auth.current_step(now) - 5), 0, now) is None


def test_password_hashing():
    h = auth.hash_password(PASSWORD)
    assert h.startswith("scrypt$") and PASSWORD not in h
    assert auth.verify_password(PASSWORD, h) and not auth.verify_password("wrong", h)


def test_secret_is_stored_encrypted(db):
    secret = make_admin(db)
    with db() as s:
        acct = s.scalar(select(AdminAccount))
        assert secret not in acct.totp_secret_enc
        assert auth.decrypt_secret(acct.totp_secret_enc) == secret


def test_token_login_stops_once_an_account_exists(client, db):
    assert client.post("/admin/login", data={"token": "bootstrap-token"}, follow_redirects=False).status_code == 303
    assert client.get("/admin", follow_redirects=False).status_code == 200
    make_admin(db)
    # the existing token session ends and the token no longer logs in
    assert client.get("/admin", follow_redirects=False).status_code == 303
    assert client.post("/admin/login", data={"token": "bootstrap-token"}).status_code == 401
    assert 'name="code"' in client.get("/admin/login").text


def test_account_login_and_audit_identity(client, db):
    secret = make_admin(db, "editor@example.com", "editor")
    r = client.post(
        "/admin/login",
        data={"email": "Editor@Example.com", "password": PASSWORD, "code": code_for(secret)},
        follow_redirects=False,
    )
    assert r.status_code == 303
    page = client.get("/admin")
    assert "editor@example.com" in page.text
    csrf = re.search(r'name="csrf" value="([^"]+)"', page.text).group(1)
    client.post("/admin/logout", data={"csrf": csrf})
    with db() as s:
        logins = s.scalars(select(AdminAuditLog.admin).where(AdminAuditLog.action == "login")).all()
        assert logins == ["editor@example.com"]


@pytest.mark.parametrize("field", ["password", "code", "email"])
def test_any_wrong_factor_fails_with_same_message(client, db, field):
    secret = make_admin(db)
    data = {"email": "owner@example.com", "password": PASSWORD, "code": code_for(secret)}
    data[field] = {"password": "wrong password!!", "code": "000000", "email": "nobody@example.com"}[field]
    r = client.post("/admin/login", data=data)
    assert r.status_code == 401 and "Wrong email, password or code." in r.text


def test_lockout_after_repeated_failures(client, db):
    secret = make_admin(db)
    for _ in range(auth.MAX_FAILED):
        client.post("/admin/login", data={"email": "owner@example.com", "password": "nope-nope-nope", "code": "1"})
    r = client.post("/admin/login", data={"email": "owner@example.com", "password": PASSWORD, "code": code_for(secret)})
    assert r.status_code == 401 and "Too many failed attempts" in r.text
    with db() as s:
        assert s.scalar(select(AdminAccount.locked_until)) is not None


def test_disable_and_password_reset_end_sessions(client, db, monkeypatch):
    secret = make_admin(db)
    client.post("/admin/login", data={"email": "owner@example.com", "password": PASSWORD, "code": code_for(secret)})
    assert client.get("/admin", follow_redirects=False).status_code == 200

    monkeypatch.setenv("SA_NEW_ADMIN_PASSWORD", "another long password")
    assert manage.main(["reset-password", "owner@example.com"]) == 0
    assert client.get("/admin", follow_redirects=False).status_code == 303

    # log in again with the new password (next TOTP step: the previous one was used)
    client.post(
        "/admin/login",
        data={"email": "owner@example.com", "password": "another long password", "code": code_for(secret, 1)},
    )
    assert client.get("/admin", follow_redirects=False).status_code == 200
    assert manage.main(["disable", "owner@example.com"]) == 0
    assert client.get("/admin", follow_redirects=False).status_code == 303


def test_manage_cli_validation(db, monkeypatch, capsys):
    monkeypatch.setenv("SA_NEW_ADMIN_PASSWORD", "short")
    assert manage.main(["create", "x@example.com"]) == 2
    monkeypatch.setenv("SA_NEW_ADMIN_PASSWORD", PASSWORD)
    assert manage.main(["create", "x@example.com", "--role", "owner"]) == 0
    assert "otpauth://totp/" in capsys.readouterr().out
    assert manage.main(["create", "X@example.com"]) == 2  # duplicate, case-insensitive
    assert manage.main(["list"]) == 0
    assert "x@example.com" in capsys.readouterr().out
    assert manage.main(["disable", "ghost@example.com"]) == 2
