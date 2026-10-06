"""Extractive summaries (no LLM): subject line, directive sentences, deadlines, all quoted from the document.

Nothing here is generated. Every sentence and date shown to users exists verbatim in the PDF, so the risk of
an invented rule or deadline is removed. The cost is that wording is the circular's own, not plain language.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import date

from sa_scraper.classify import Classification

MODEL_VERSION = "extractive-rules-v1"
MAX_SHORT = 300
MAX_POINT = 280
MAX_POINTS = 5

_MONTHS = {
    m: i + 1 for i, m in enumerate(["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"])
}
_MON = r"(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?"
_DATE_PATTERNS = [
    (re.compile(r"\b(\d{1,2})[./-](\d{1,2})[./-](\d{4})\b"), "dmy"),
    (re.compile(rf"\b(\d{{1,2}})(?:st|nd|rd|th)?\s+{_MON},?\s+(\d{{4}})\b", re.I), "d_mon_y"),
    (re.compile(rf"\b{_MON}\s+(\d{{1,2}})(?:st|nd|rd|th)?,?\s+(\d{{4}})\b", re.I), "mon_d_y"),
]
_DEADLINE_CUE = re.compile(
    r"\b(on or before|last date|not later than|no later than|latest by|deadline|till|until|up ?to|before)\b", re.I
)
_DIRECTIVE = re.compile(
    r"\b(shall|must|are required to|is required to|are directed|are hereby|is hereby|are requested to|"
    r"are advised to|mandatory|compulsory|with effect from|w\.?\s?e\.?\s?f|last date|on or before|not later than|"
    r"should (apply|submit|ensure|book|register)|apply|submit|book (their|the) seats?|register|extended|"
    r"valid (till|until|up ?to)|discontinued|no longer|will not be)\b",
    re.I,
)
_ACTION = re.compile(
    r"\b(are required to|must|shall (apply|submit|ensure|obtain|complete|register|undergo)|are requested to|"
    r"are advised to|should (apply|submit|ensure|book|register)|apply|submit|book (their|the) seats?|"
    r"last date|on or before|not later than)\b",
    re.I,
)
_NOISE = re.compile(
    r"(government of india|ministry of ports|directorate general|tel\b|fax\b|e-?mail|www\.|@|"
    r"^\s*(to|from|copy to|dated?|f\.?\s?no|file no|sd/-|encl)\b|9th floor|beta building|kanjurmarg|"
    r"i-think techno|signature|digitally signed|^\s*\(.*\)\s*$)",
    re.I,
)
# "Subiect" / "Sub" cover OCR errors and abbreviations. The subject ends at a blank line, a reference line,
# a numbered paragraph, or a line starting a new sentence ("Whereas", "The", ...).
_SUBJECT = re.compile(
    r"\bsub(?:[ij]ect)?\s*[:.\-–]+\s*(.{10,400}?)"
    r"(?:\n\s*\n|\n\s*(?:ref|reference)\b|\n\s*(?:[IVX]+|\d+)\.\s|\n(?=(?:Whereas|The|In|It|This|All|Attention)\b)|$)",
    re.I | re.S,
)
_LIST_TAIL = re.compile(r"\s+(?:[a-z]|[ivx]+|\d+)[.)]$")
LOW_QUALITY = 0.93  # below this share of well-formed words the text layer is probably bad OCR
_SENT_SPLIT = re.compile(r"(?<=[.;:])\s+(?=[A-Z(\d])|\n(?=\s*(?:\d+|[a-z]|[ivx]+)[.)]\s)")

METADATA_ONLY_NOTE = (
    "This is a list of individual candidates. It is not stored or summarised here. "
    "Open the official PDF to check your name."
)


@dataclass
class SummaryDraft:
    summary_short: str
    summary_detailed: str | None
    key_points: list[str]
    action_required: bool
    action_deadline: date | None
    affected_groups: dict[str, list[str]]
    uncertain_fields: list[str] = field(default_factory=list)
    method: str = "extractive"
    model_version: str = MODEL_VERSION


def _truncate(text: str, limit: int) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) <= limit:
        return text
    cut = text[: limit - 1].rsplit(" ", 1)[0]
    return cut + "…"


def find_dates(text: str) -> list[tuple[date, int]]:
    """All valid dates in text with their positions. Indian order (day first) for numeric dates."""
    found: list[tuple[date, int]] = []
    for pattern, kind in _DATE_PATTERNS:
        for m in pattern.finditer(text):
            try:
                if kind == "dmy":
                    d, mo, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
                elif kind == "d_mon_y":
                    d, mo, y = int(m.group(1)), _MONTHS[m.group(2).lower()[:3]], int(m.group(3))
                else:
                    mo, d, y = _MONTHS[m.group(1).lower()[:3]], int(m.group(2)), int(m.group(3))
                if 2000 <= y <= 2100:
                    found.append((date(y, mo, d), m.start()))
            except ValueError:
                continue
    return sorted(found, key=lambda x: x[1])


def find_deadline(sentences: list[str]) -> date | None:
    """First date that follows a deadline cue ('on or before', 'last date', 'till' ...) within 60 characters,
    in a sentence that asks the reader to act. ('The venue shall be informed latest by 14 Oct' is not a deadline.)"""
    for s in sentences:
        if not _ACTION.search(s):
            continue
        for cue in _DEADLINE_CUE.finditer(s):
            for d, pos in find_dates(s):
                if 0 <= pos - cue.end() <= 60:
                    return d
    return None


def _subject(text: str) -> str | None:
    m = _SUBJECT.search(text[:4000])
    if not m:
        return None
    subject = re.sub(r"\s+", " ", m.group(1)).strip(" -–:.")
    return subject if len(subject) >= 10 else None


def _title_recall(title: str, other: str) -> float:
    words = {w.lower() for w in re.findall(r"[A-Za-z]{5,}", title)}
    if len(words) < 3:
        return 1.0
    other_words = {w.lower() for w in re.findall(r"[A-Za-z]{5,}", other)}
    return sum(1 for w in words if w in other_words) / len(words)


def _sentences(text: str) -> list[str]:
    body = text.replace("\f", "\n")
    parts = []
    for para in re.split(r"\n\s*\n|\n(?=\s*\d+\.\s)", body):
        para = re.sub(r"\s*\n\s*", " ", para).strip()
        parts.extend(_LIST_TAIL.sub("", p.strip()) for p in _SENT_SPLIT.split(para) if p and p.strip())
    return [p for p in parts if 40 <= len(p) <= 600 and not _NOISE.search(p)]


def affected_groups(c: Classification) -> dict[str, list[str]]:
    keys = {
        "departments": "department",
        "levels": "level",
        "ship_types": "ship_type",
        "mmds": "mmd",
        "cert_types": "certificate_type",
        "exam_grades": "exam_grade",
    }
    return {k: sorted(c.values(kind)) for k, kind in keys.items() if c.values(kind)}


def summarise(
    title: str,
    text: str | None,
    c: Classification,
    *,
    metadata_only: bool = False,
    text_quality: float = 1.0,
) -> SummaryDraft:
    groups = affected_groups(c)
    if metadata_only or not text or len(text.strip()) < 80:
        return SummaryDraft(
            summary_short=_truncate(title, MAX_SHORT),
            summary_detailed=None,
            key_points=[METADATA_ONLY_NOTE] if metadata_only else [],
            action_required=False,
            action_deadline=None,
            affected_groups=groups,
            uncertain_fields=[] if metadata_only else ["text_unavailable"],
        )

    subject = _subject(text)
    if subject and _title_recall(title, subject) < 0.6:
        # The subject should repeat the typed listing title. If most title words are missing from it, the text
        # layer is a bad scan ("Clarification resardins endorsem t of sisnatures ...").
        text_quality = min(text_quality, _title_recall(title, subject))
    sentences = _sentences(text)
    scored = []
    for i, s in enumerate(sentences):
        score = 3 * len(_DIRECTIVE.findall(s)) + (1 if find_dates(s) else 0)
        if subject and s.lower().startswith(subject.lower()[:40]):
            score -= 5  # don't repeat the subject
        if score > 0:
            scored.append((score, i, s))
    top = sorted(scored, key=lambda x: (-x[0], x[1]))[:MAX_POINTS]
    key_points = [_truncate(s, MAX_POINT) for _, _, s in sorted(top, key=lambda x: x[1])]

    action_required = c.audience == "seafarers" and any(_ACTION.search(p) for p in key_points)
    deadline = find_deadline([s for _, _, s in top]) or (find_deadline(sentences) if action_required else None)

    detailed_src = [s for s in sentences if not (subject and s.lower().startswith(subject.lower()[:40]))][:4]
    uncertain = []
    if action_required and deadline is None:
        uncertain.append("deadline")
    if not key_points:
        uncertain.append("key_points")
    if text_quality < LOW_QUALITY:
        uncertain.append("text_quality")  # scanned PDF with OCR errors: UI warns and prefers the title

    return SummaryDraft(
        # The listing title is typed by DGMA staff, so prefer it over a subject line read from a bad scan.
        summary_short=_truncate(subject if subject and text_quality >= LOW_QUALITY else title, MAX_SHORT),
        summary_detailed=_truncate(" ".join(detailed_src), 1500) if detailed_src else None,
        key_points=key_points,
        action_required=action_required,
        action_deadline=deadline,
        affected_groups=groups,
        uncertain_fields=uncertain,
    )
