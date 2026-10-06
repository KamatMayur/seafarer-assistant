"""Test helpers shared by backend and scraper test suites."""

from __future__ import annotations

import os
from collections.abc import Iterator
from pathlib import Path

import psycopg
from alembic import command
from alembic.config import Config
from sqlalchemy import Engine, create_engine, text
from sqlalchemy.orm import Session, sessionmaker

from sa_backend.settings import REPO_ROOT, get_settings


def test_database_url() -> str:
    url = os.environ.get("SA_TEST_DATABASE_URL")
    if not url:
        env = REPO_ROOT / ".env"
        if env.exists():
            for line in env.read_text().splitlines():
                if line.startswith("SA_TEST_DATABASE_URL="):
                    url = line.split("=", 1)[1].strip()
    if not url:
        raise RuntimeError("Set SA_TEST_DATABASE_URL (run: python infra/dev/localpg.py seafarer_test)")
    if not url.rstrip("/").endswith("_test"):
        raise RuntimeError(f"Refusing to run tests against a non-test database: {url}")
    return url


def migrate_fresh(url: str) -> None:
    """Drop everything and apply all Alembic migrations (so the migrations themselves are tested)."""
    with psycopg.connect(url.replace("postgresql+psycopg://", "postgresql://"), autocommit=True) as conn:
        conn.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
    cfg = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
    cfg.set_main_option("script_location", str(Path(__file__).resolve().parents[1] / "migrations"))
    cfg.attributes["url"] = url
    command.upgrade(cfg, "head")


def truncate_all(engine: Engine) -> None:
    with engine.begin() as conn:
        tables = (
            conn.execute(
                text("SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename <> 'alembic_version'")
            )
            .scalars()
            .all()
        )
        conn.execute(text(f"TRUNCATE {', '.join(tables)} RESTART IDENTITY CASCADE"))


def engine_and_sessions(url: str) -> tuple[Engine, sessionmaker[Session]]:
    engine = create_engine(url)
    return engine, sessionmaker(bind=engine, expire_on_commit=False)


def use_test_db(monkeypatch, url: str, tmp_path: Path) -> Iterator[None]:
    monkeypatch.setenv("SA_DATABASE_URL", url)
    monkeypatch.setenv("SA_DATA_DIR", str(tmp_path))
    get_settings.cache_clear()
    from sa_backend.db import session as session_mod

    session_mod.get_engine.cache_clear()
    yield
    get_settings.cache_clear()
    session_mod.get_engine.cache_clear()
