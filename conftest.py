"""Shared pytest fixtures. Database tests use SA_TEST_DATABASE_URL (a database whose name ends in _test)."""

import pytest

from sa_backend.testing import engine_and_sessions, migrate_fresh, test_database_url, truncate_all, use_test_db


@pytest.fixture(scope="session")
def db_url():
    url = test_database_url()
    migrate_fresh(url)
    return url


@pytest.fixture
def db(db_url, monkeypatch, tmp_path):
    """A clean database per test. Yields a sessionmaker; get_settings()/get_engine() point at the test DB."""
    engine, sessions = engine_and_sessions(db_url)
    truncate_all(engine)
    gen = use_test_db(monkeypatch, db_url, tmp_path)
    next(gen)
    yield sessions
    engine.dispose()
    next(gen, None)
