"""Login codes, JWT access tokens and rotating refresh tokens."""

from __future__ import annotations

import hashlib
import hmac
import secrets
import uuid
from datetime import UTC, datetime, timedelta

import jwt

from sa_backend.settings import get_settings

ALGORITHM = "HS256"


def _hmac(value: str) -> str:
    return hmac.new(get_settings().jwt_secret.encode(), value.encode(), hashlib.sha256).hexdigest()


def new_login_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_login_code(identifier: str, code: str) -> str:
    return _hmac(f"login:{identifier.lower()}:{code}")


def new_refresh_token() -> tuple[str, str]:
    token = secrets.token_urlsafe(48)
    return token, _hmac(f"refresh:{token}")


def hash_refresh_token(token: str) -> str:
    return _hmac(f"refresh:{token}")


def create_access_token(user_id: uuid.UUID) -> tuple[str, int]:
    minutes = get_settings().access_token_minutes
    now = datetime.now(UTC)
    payload = {"sub": str(user_id), "iat": now, "exp": now + timedelta(minutes=minutes), "typ": "access"}
    return jwt.encode(payload, get_settings().jwt_secret, algorithm=ALGORITHM), minutes * 60


def decode_access_token(token: str) -> uuid.UUID:
    payload = jwt.decode(token, get_settings().jwt_secret, algorithms=[ALGORITHM])
    if payload.get("typ") != "access":
        raise jwt.InvalidTokenError("wrong token type")
    return uuid.UUID(payload["sub"])
