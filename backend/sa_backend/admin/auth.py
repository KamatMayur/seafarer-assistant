"""Admin browser session: the admin token is exchanged once for a signed, short-lived cookie.

The cookie is bound to the current SA_ADMIN_TOKEN (rotating the token logs every session out). POSTs also need a
CSRF token derived from the session, sent as a form field or the X-CSRF-Token header (HTMX).
"""

from __future__ import annotations

import hashlib
import hmac
import secrets
from datetime import UTC, datetime, timedelta

import jwt
from fastapi import HTTPException, Request, status

from sa_backend.settings import get_settings

COOKIE = "sa_admin"
SESSION_HOURS = 12
ALGORITHM = "HS256"


def _mac(value: str) -> str:
    return hmac.new(get_settings().jwt_secret.encode(), value.encode(), hashlib.sha256).hexdigest()


def token_matches(supplied: str) -> bool:
    token = get_settings().admin_token
    return bool(token) and hmac.compare_digest(supplied.strip().encode(), token.encode())


def new_session() -> str:
    now = datetime.now(UTC)
    payload = {
        "typ": "admin",
        "sid": secrets.token_urlsafe(16),
        "tk": _mac(f"admin-token:{get_settings().admin_token}")[:32],
        "iat": now,
        "exp": now + timedelta(hours=SESSION_HOURS),
    }
    return jwt.encode(payload, get_settings().jwt_secret, algorithm=ALGORITHM)


def session_id(request: Request) -> str | None:
    """The session id if the request carries a valid admin cookie, else None."""
    raw = request.cookies.get(COOKIE)
    if not raw or not get_settings().admin_token:
        return None
    try:
        payload = jwt.decode(raw, get_settings().jwt_secret, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None
    expected = _mac(f"admin-token:{get_settings().admin_token}")[:32]
    if payload.get("typ") != "admin" or not hmac.compare_digest(payload.get("tk", ""), expected):
        return None
    return payload["sid"]


def csrf_for(sid: str) -> str:
    return _mac(f"csrf:{sid}")[:40]


class LoginRequired(Exception):
    """Raised by the dependency below; turned into a redirect to the login page."""


def require_session(request: Request) -> str:
    sid = session_id(request)
    if sid is None:
        raise LoginRequired
    return sid


async def require_csrf(request: Request) -> None:
    sid = require_session(request)
    supplied = request.headers.get("x-csrf-token")
    if supplied is None:
        form = await request.form()
        supplied = str(form.get("csrf", ""))
    if not hmac.compare_digest(supplied, csrf_for(sid)):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "bad CSRF token; reload the page")
