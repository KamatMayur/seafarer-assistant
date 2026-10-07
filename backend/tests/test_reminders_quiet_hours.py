import uuid
from datetime import date, datetime
from types import SimpleNamespace
from zoneinfo import ZoneInfo

import pytest

from sa_backend.services.alerts import quiet_until
from sa_backend.services.reminders import EXPIRED, due_bucket

IST = ZoneInfo("Asia/Kolkata")


@pytest.mark.parametrize(
    "expiry,today,bucket",
    [
        (date(2027, 6, 1), date(2026, 10, 6), None),  # > 180 days
        (date(2027, 4, 4), date(2026, 10, 6), 180),
        (date(2026, 12, 1), date(2026, 10, 6), 90),
        (date(2026, 10, 26), date(2026, 10, 6), 30),  # added with 20 days left -> 30-day reminder
        (date(2026, 10, 13), date(2026, 10, 6), 7),
        (date(2026, 10, 6), date(2026, 10, 6), 0),
        (date(2026, 10, 5), date(2026, 10, 6), EXPIRED),
        (date(2028, 2, 29), date(2028, 2, 22), 7),  # leap day
        (date(2028, 3, 1), date(2028, 2, 1), 30),  # 29 days across a leap February
    ],
)
def test_due_bucket(expiry, today, bucket):
    assert due_bucket(expiry, today) == bucket


def _user(start, end):
    return SimpleNamespace(id=uuid.uuid4(), quiet_start_min=start, quiet_end_min=end)


def test_quiet_hours_overnight():
    u = _user(22 * 60, 7 * 60)
    assert quiet_until(u, datetime(2026, 10, 6, 23, 0, tzinfo=IST)) == datetime(2026, 10, 7, 7, 0, tzinfo=IST)
    assert quiet_until(u, datetime(2026, 10, 6, 6, 59, tzinfo=IST)) == datetime(2026, 10, 6, 7, 0, tzinfo=IST)
    assert quiet_until(u, datetime(2026, 10, 6, 12, 0, tzinfo=IST)) is None


def test_quiet_hours_use_ist_even_for_utc_input():
    u = _user(22 * 60, 7 * 60)
    utc = datetime(2026, 10, 6, 17, 0, tzinfo=ZoneInfo("UTC"))  # 22:30 IST
    assert quiet_until(u, utc) is not None


def test_no_quiet_hours():
    assert quiet_until(_user(None, None), datetime(2026, 10, 6, 23, 0, tzinfo=IST)) is None


def test_create_expiry_alerts_counts_and_is_idempotent(db):
    from sa_backend.db.models import Certificate, User
    from sa_backend.services.reminders import create_expiry_alerts

    today = date(2026, 10, 7)
    with db() as s:
        user = User(email="cert@example.com")
        s.add(user)
        s.flush()
        s.add(Certificate(id=uuid.uuid4(), user_id=user.id, type="medical", expiry_date=date(2026, 11, 6)))  # 30 days
        s.commit()
        assert create_expiry_alerts(s, today=today) == 1
        assert create_expiry_alerts(s, today=today) == 0
