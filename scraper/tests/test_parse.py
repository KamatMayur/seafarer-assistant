from datetime import date
from pathlib import Path

import pytest

from sa_scraper.config import load_sources
from sa_scraper.parse import normalise_number, parse_listing, with_page

FIX = Path(__file__).parent / "fixtures"
SOURCES = load_sources()


def test_all_source_configs_load_and_have_unique_ids():
    assert len(SOURCES) >= 10
    assert all(cfg.url().startswith("https://dgma.gov.in/") for cfg in SOURCES.values())


def test_latest_news_wide_table():
    cfg = SOURCES["dgma_latest_news"]
    res = parse_listing((FIX / "latest_news.html").read_bytes(), cfg.layout, cfg.url())
    assert res.problems == []
    assert len(res.items) == 50
    first = res.items[0]
    assert first.title == "COC Dispatch List of Engineering Wing of Dated 06.10.2026"
    assert first.published_date == date(2026, 10, 6)
    assert first.circular_number == "10 of 2026"  # "10 of\n   2026" across lines
    assert first.branch == "Engineering Wing"
    assert first.site_type == "COC Dispatch List"
    assert first.pdf_url.startswith("https://dgma.gov.in/download/")
    # rows without a number ("---") have none
    assert res.items[1].circular_number is None


def test_year_list_skips_year_group_rows_and_finds_next_page():
    cfg = SOURCES["yl_dgs_circulars"]
    url = "https://dgma.gov.in/year-list?type=DGS+Circulars&year=2026&rows=100"
    res = parse_listing((FIX / "year_list_page1.html").read_bytes(), cfg.layout, url)
    assert res.problems == []
    assert len(res.items) == 10  # the "2026" colspan row is not an item
    assert res.items[0].circular_number == "65 of 2026"
    # next page keeps the year/rows filters
    assert res.next_page_url == "https://dgma.gov.in/year-list?type=DGS+Circulars&year=2026&rows=100&page=2"


def test_inner_table_layout():
    cfg = SOURCES["nw_isps_security"]
    res = parse_listing((FIX / "inner_table_isps.html").read_bytes(), cfg.layout, cfg.url())
    assert res.problems == []
    assert len(res.items) == 10
    assert res.items[0].circular_number == "47 of 2026"
    assert res.items[0].published_date == date(2026, 8, 5)


def test_replacement_char_in_title_is_cleaned():
    cfg = SOURCES["training_circulars"]
    res = parse_listing((FIX / "inner_table_ew_exam_notices.html").read_bytes(), cfg.layout, cfg.url())
    assert all("�" not in it.title for it in res.items)


def test_layout_drift_is_reported_not_ignored():
    cfg = SOURCES["dgma_latest_news"]
    fake = b"<table class='data-table'><tr><th>Name</th><th>When</th></tr><tr><td>x</td><td>y</td></tr></table>"
    res = parse_listing(fake, cfg.layout, cfg.url())
    assert res.items == []
    assert any("missing expected columns" in p for p in res.problems)


def test_missing_table_is_reported():
    cfg = SOURCES["dgma_latest_news"]
    res = parse_listing(b"<html><body>FAKE maintenance page</body></html>", cfg.layout, cfg.url())
    assert res.items == [] and "matched nothing" in res.problems[0]


def test_reordered_columns_still_parse():
    cfg = SOURCES["dgma_latest_news"]
    fake = (
        b"<table class='data-table'><tr><th>Publish Date</th><th>Download</th><th>Title</th><th>No of Year.</th></tr>"
        b"<tr><td>01-Oct-2026</td><td><a href='/download/x.pdf'>D</a></td><td>FAKE title</td><td>3 of 2026</td></tr>"
        b"</table>"
    )
    res = parse_listing(fake, cfg.layout, cfg.url())
    assert len(res.items) == 1
    assert res.items[0].pdf_url == "https://dgma.gov.in/download/x.pdf"
    assert res.items[0].circular_number == "3 of 2026"


@pytest.mark.parametrize(
    "raw,expected",
    [
        ("65 of 2026", "65 of 2026"),
        ("10 of\n   2026", "10 of 2026"),
        ("---", None),
        ("", None),
        ("007 OF 2025", "7 of 2025"),
    ],
)
def test_normalise_number(raw, expected):
    assert normalise_number(raw) == expected


def test_with_page_increments():
    assert with_page("https://x.in/a?type=A&page=2") == "https://x.in/a?type=A&page=3"
