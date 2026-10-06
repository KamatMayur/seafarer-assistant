from __future__ import annotations

import hmac
from collections.abc import Iterator
from typing import Annotated

import jwt
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from sa_backend.api.security import decode_access_token
from sa_backend.db.models import User
from sa_backend.db.session import make_sessionmaker
from sa_backend.settings import get_settings


def get_db() -> Iterator[Session]:
    session = make_sessionmaker()()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


DB = Annotated[Session, Depends(get_db)]


def current_user(db: DB, authorization: Annotated[str | None, Header()] = None) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "missing bearer token")
    try:
        user_id = decode_access_token(authorization.split(" ", 1)[1])
    except jwt.PyJWTError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid or expired token") from e
    user = db.get(User, user_id)
    if user is None or user.deleted_at is not None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "account not found")
    return user


CurrentUser = Annotated[User, Depends(current_user)]


def require_admin(authorization: Annotated[str | None, Header()] = None) -> None:
    token = get_settings().admin_token
    supplied = (authorization or "").removeprefix("Bearer ").strip()
    if not token or not hmac.compare_digest(supplied, token):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "admin only")
