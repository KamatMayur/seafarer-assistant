"""Parse a listing page into items, using header text (not column positions) to find fields.

Also produces a structure fingerprint and a list of problems so layout drift is reported, not ignored.
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from datetime import date, datetime
from urllib.parse import parse_qsl, urlencode, urljoin, urlsplit, urlunsplit

from selectolax.lexbor import LexborHTMLParser, LexborNode

from sa_scraper.config import Layout

_WS = re.compile(r"\s+")
_NUMBER = re.compile(r"(\d+)\s*of\s*(\d{4})", re.I)


def clean(text: str | None) -> str:
    if not text:
        return ""
    # The site serves a few titles with U+FFFD where an en dash was intended ("October 2026 � MMD").
    return _WS.sub(" ", text.replace("�", "–")).strip()


def norm_header(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", text.lower())


def normalise_number(text: str) -> str | None:
    m = _NUMBER.search(text or "")
    return f"{int(m.group(1))} of {m.group(2)}" if m else None


@dataclass
class ListingItem:
    title: str
    pdf_url: str
    published_date: date | None
    circular_number: str | None = None
    branch: str | None = None
    site_type: str | None = None


@dataclass
class ParseResult:
    items: list[ListingItem] = field(default_factory=list)
    problems: list[str] = field(default_factory=list)
    structure_hash: str | None = None
    headers: list[str] = field(default_factory=list)
    next_page_url: str | None = None


def with_page(url: str, param: str = "page") -> str:
    """Return url with its page parameter incremented (keeps every other filter such as year and rows)."""
    parts = urlsplit(url)
    query = dict(parse_qsl(parts.query, keep_blank_values=True))
    query[param] = str(int(query.get(param, "1")) + 1)
    return urlunsplit(parts._replace(query=urlencode(query)))


def _map_columns(headers: list[str], layout: Layout) -> tuple[dict[str, int], list[str]]:
    mapping: dict[str, int] = {}
    normed = [norm_header(h) for h in headers]
    for fieldname, aliases in layout.columns.items():
        for alias in aliases:
            a = norm_header(alias)
            idx = next((i for i, h in enumerate(normed) if h and h.startswith(a)), None)
            if idx is not None:
                mapping[fieldname] = idx
                break
    missing = [f for f in layout.required if f not in mapping]
    return mapping, missing


def _first_link(cell: LexborNode, base_url: str) -> str | None:
    for a in cell.css("a"):
        href = (a.attributes.get("href") or "").strip()
        if href and not href.startswith(("#", "javascript:", "mailto:")):
            return urljoin(base_url, href)
    return None


def parse_listing(html: bytes | str, layout: Layout, page_url: str) -> ParseResult:
    tree = LexborHTMLParser(html)
    result = ParseResult()
    table = tree.css_first(layout.table)
    if table is None:
        result.problems.append(f"table selector {layout.table!r} matched nothing")
        return result

    header_row = table.css_first("thead tr") or table.css_first("tr")
    headers = [clean(c.text()) for c in header_row.css("th,td")] if header_row else []
    result.headers = headers
    result.structure_hash = hashlib.sha256("|".join(norm_header(h) for h in headers).encode()).hexdigest()[:16]
    mapping, missing = _map_columns(headers, layout)
    if missing:
        result.problems.append(f"missing expected columns {missing}; headers seen: {headers}")
        return result

    for row in table.css("tr"):
        if row is header_row:
            continue
        cells = row.css("td")
        if len(cells) < max(layout.skip_row_if_cells_lt, 1) or len(cells) <= max(mapping.values()):
            continue
        title = clean(cells[mapping["title"]].text())
        link = _first_link(cells[mapping["link"]], page_url)
        if not link and "title" in mapping:
            link = _first_link(cells[mapping["title"]], page_url)
        raw_date = clean(cells[mapping["date"]].text())
        try:
            published = datetime.strptime(raw_date, layout.date_format).date() if raw_date else None
        except ValueError:
            published = None
            result.problems.append(f"unparseable date {raw_date!r} for {title[:60]!r}")
        if not title or not link:
            result.problems.append(f"row without title/link skipped: {title[:60]!r}")
            continue
        number = normalise_number(clean(cells[mapping["number"]].text())) if "number" in mapping else None
        result.items.append(
            ListingItem(
                title=title,
                pdf_url=link,
                published_date=published,
                circular_number=number,
                branch=clean(cells[mapping["branch"]].text()) or None if "branch" in mapping else None,
                site_type=clean(cells[mapping["site_type"]].text()) or None if "site_type" in mapping else None,
            )
        )

    if layout.pagination:
        param = layout.pagination.get("param", "page")
        nxt = tree.css_first('a[rel="next"]') or next(
            (a for a in tree.css(".pagination a") if a.text(strip=True).lower().startswith("next")), None
        )
        if nxt is not None and f"{param}=" in (nxt.attributes.get("href") or ""):
            result.next_page_url = with_page(page_url, param)
    return result
