from datetime import date
from pathlib import Path

import pytest

from sa_scraper.classify import classify
from sa_scraper.extract import extract_text, text_quality
from sa_scraper.summarise import METADATA_ONLY_NOTE, find_dates, find_deadline, summarise

FIX = Path(__file__).parent / "fixtures"


@pytest.mark.parametrize(
    "text,expected",
    [
        ("dated 15.07.2026", date(2026, 7, 15)),
        ("on 05/08/2026", date(2026, 8, 5)),
        ("1st October 2026", date(2026, 10, 1)),
        ("October 14, 2026", date(2026, 10, 14)),
        ("29 Sept, 2026", date(2026, 9, 29)),
        ("29.02.2028", date(2028, 2, 29)),  # leap year
    ],
)
def test_find_dates_formats(text, expected):
    assert find_dates(text)[0][0] == expected


def test_invalid_dates_are_ignored():
    assert find_dates("31.02.2026 and 29.02.2027") == []


def test_deadline_needs_an_action_sentence():
    # Real wording from the October 2026 engineering exam notice: a DGMA promise, not a candidate deadline.
    s = [
        "Candidates may note that the address of the examination centre shall be informed at the latest by "
        "October 14, 2026."
    ]
    assert find_deadline(s) is None
    s = ["Candidates are required to submit the application on or before 20.10.2026 through the portal."]
    assert find_deadline(s) == date(2026, 10, 20)


def test_metadata_only_summary_never_uses_text():
    c = classify("RESULT OF DREDGE MATE GRADE-II WRITTEN EXAMINATION HELD IN THE MONTH OF AUGUST 2026")
    s = summarise("RESULT OF DREDGE MATE ...", "FAKE names Ravi Kumar ...", c, metadata_only=True)
    assert s.key_points == [METADATA_ONLY_NOTE]
    assert "Ravi" not in (s.summary_detailed or "") + s.summary_short


def test_real_circular_65_summary():
    ex = extract_text((FIX / "circular_65_of_2026.pdf").read_bytes())
    assert ex.method == "pdfplumber" and ex.pages == 3
    title = (
        "Clarification to existing provision within TEAP Manual Part A, Chapter III related to issuance of "
        "steam/motor endorsement to MEO Class I / Class II CoC holders, reg."
    )
    c = classify(title, body=ex.text, circular_number="65 of 2026")
    s = summarise(title, ex.text, c, text_quality=text_quality(ex.text, title))
    assert s.summary_short.startswith("Clarification to existing provision within TEAP Manual")
    assert 1 <= len(s.key_points) <= 5
    assert all(len(p) <= 280 for p in s.key_points)
    for p in s.key_points:  # extractive: every point comes from the PDF text
        assert p.rstrip("…")[:60] in " ".join(ex.text.split())
    assert "text_quality" not in s.uncertain_fields


def test_bad_scan_is_flagged_and_uses_the_typed_title():
    ex = extract_text((FIX / "circular_61_of_2026_scanned.pdf").read_bytes())
    title = "Clarification regarding endorsement of signatures in Continuous Discharge certificate (CDC)"
    c = classify(title, body=ex.text, circular_number="61 of 2026")
    s = summarise(title, ex.text, c, text_quality=text_quality(ex.text, title))
    assert "text_quality" in s.uncertain_fields
    assert s.summary_short == title


def test_summary_payload_is_small():
    ex = extract_text((FIX / "circular_65_of_2026.pdf").read_bytes())
    c = classify("x", body=ex.text)
    s = summarise("x", ex.text, c)
    size = len((s.summary_short + (s.summary_detailed or "") + "".join(s.key_points)).encode())
    assert size < 5000  # spec: < 5 KB per summary
