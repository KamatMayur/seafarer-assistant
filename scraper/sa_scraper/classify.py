"""Rule-based classification and tagging (no LLM). Rules live in rules/taxonomy.yaml."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml

RULES_PATH = Path(__file__).parent / "rules" / "taxonomy.yaml"

_ROMAN = {"I": 1, "II": 2, "III": 3, "IV": 4, "1": 1, "2": 2, "3": 3, "4": 4}
_MEO_CONTEXT = re.compile(r"\bMEO\b|marine engineer officer|engineer officer|\bclass\b.{0,20}\b(engine|CoC)", re.I)
_CLASS_TOKEN = re.compile(r"\bclass[- ]?(IV|III|II|I|[1-4])(?![\w])", re.I)


@dataclass(frozen=True)
class Tag:
    kind: str
    value: str
    strength: str  # 'title' | 'body'
    evidence: str


@dataclass
class Classification:
    doc_type: str
    audience: str  # 'seafarers' | 'industry' | 'internal' | 'general'
    priority: str
    confidence: float
    tags: list[Tag] = field(default_factory=list)
    reasons: list[str] = field(default_factory=list)
    related_reference: str | None = None  # "N of YYYY" this document amends/clarifies
    relation: str | None = None

    def values(self, kind: str, strength: str | None = "title") -> set[str]:
        return {t.value for t in self.tags if t.kind == kind and (strength is None or t.strength == strength)}


@dataclass(frozen=True)
class _Matcher:
    title: tuple[re.Pattern[str], ...]
    body: tuple[re.Pattern[str], ...]


def _compile(patterns: list[str] | str | None) -> tuple[re.Pattern[str], ...]:
    if not patterns:
        return ()
    if isinstance(patterns, str):
        patterns = [patterns]
    return tuple(re.compile(p, re.I) for p in patterns)


@dataclass(frozen=True)
class Rules:
    raw: dict[str, Any]
    min_body_hits: int
    review_threshold: float
    site_types: dict[str, str]
    doc_type_title_rules: tuple[tuple[str, re.Pattern[str]], ...]
    internal_site_types: frozenset[str]
    internal: tuple[re.Pattern[str], ...]
    industry: tuple[re.Pattern[str], ...]
    seafarer: tuple[re.Pattern[str], ...]
    seafarer_doc_types: frozenset[str]
    seafarer_site_types: frozenset[str]
    critical: tuple[re.Pattern[str], ...]
    relation_title: re.Pattern[str]
    relation_body: re.Pattern[str]
    relation_ref: re.Pattern[str]
    tags: dict[str, dict[str, _Matcher]]


@lru_cache
def load_rules(path: Path = RULES_PATH) -> Rules:
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    tags: dict[str, dict[str, _Matcher]] = {}
    for kind, values in raw["tags"].items():
        tags[kind] = {}
        for value, spec in values.items():
            title = _compile(spec.get("title"))
            tags[kind][value] = _Matcher(title=title, body=_compile(spec.get("body")) or title)
    return Rules(
        raw=raw,
        min_body_hits=int(raw.get("min_body_hits", 2)),
        review_threshold=float(raw.get("review_threshold", 0.6)),
        site_types={k.lower(): v for k, v in raw["site_types"].items()},
        doc_type_title_rules=tuple((r["type"], re.compile(r["pattern"], re.I)) for r in raw["doc_type_title_rules"]),
        internal_site_types=frozenset(s.lower() for s in raw["internal"]["site_types"]),
        internal=_compile(raw["internal"]["title"]),
        industry=_compile(raw["industry"]["title"]),
        seafarer=_compile(raw["seafarer_indicators"]["title"]),
        seafarer_doc_types=frozenset(raw.get("seafarer_doc_types", [])),
        seafarer_site_types=frozenset(s.lower() for s in raw.get("seafarer_site_types", [])),
        critical=_compile(raw["critical"]["title"]),
        relation_title=re.compile(raw["relations"]["title"], re.I),
        relation_body=re.compile(raw["relations"]["body"], re.I),
        relation_ref=re.compile(raw["relations"]["reference"], re.I),
        tags=tags,
    )


def _first(patterns: tuple[re.Pattern[str], ...], text: str) -> str | None:
    for p in patterns:
        if m := p.search(text):
            return m.group(0)
    return None


def _count(patterns: tuple[re.Pattern[str], ...], text: str) -> tuple[int, str | None]:
    total, sample = 0, None
    for p in patterns:
        found = p.findall(text)
        if found:
            total += len(found)
            if sample is None:
                m = p.search(text)
                sample = m.group(0) if m else None
    return total, sample


def _meo_classes(title: str) -> list[Tag]:
    if not _MEO_CONTEXT.search(title):
        return []
    tags, seen = [], set()
    for m in _CLASS_TOKEN.finditer(title):
        n = _ROMAN[m.group(1).upper()]
        if n not in seen:
            seen.add(n)
            tags.append(Tag("exam_grade", f"meo_class_{n}", "title", m.group(0)))
    return tags


def classify(
    title: str,
    *,
    site_type: str | None = None,
    branch: str | None = None,
    body: str | None = None,
    circular_number: str | None = None,
    hints: dict[str, Any] | None = None,
    rules: Rules | None = None,
) -> Classification:
    rules = rules or load_rules()
    hints = hints or {}
    reasons: list[str] = []
    confidence = 0.4
    head = f"{title} {branch or ''}".strip()

    # --- doc type ---------------------------------------------------------------------------------
    doc_type = None
    for dtype, pattern in rules.doc_type_title_rules:
        if m := pattern.search(title):
            doc_type = dtype
            reasons.append(f"doc_type={dtype} from title '{m.group(0)}'")
            break
    if doc_type is None and site_type and (mapped := rules.site_types.get(site_type.lower())):
        doc_type = mapped
        reasons.append(f"doc_type={mapped} from site type '{site_type}'")
    if doc_type is None and hints.get("doc_type"):
        doc_type = hints["doc_type"]
        reasons.append(f"doc_type={doc_type} from source hint")
    if doc_type is None and circular_number:
        doc_type = "circular"
        reasons.append("doc_type=circular because it has a circular number")
    if doc_type is None:
        doc_type = "unknown"
    else:
        confidence += 0.3

    # --- tags -------------------------------------------------------------------------------------
    tags: list[Tag] = []
    for kind, values in rules.tags.items():
        for value, matcher in values.items():
            if hit := _first(matcher.title, head):
                tags.append(Tag(kind, value, "title", hit))
            elif body:
                n, sample = _count(matcher.body, body)
                if n >= rules.min_body_hits and sample:
                    tags.append(Tag(kind, value, "body", f"{sample} (x{n})"))
    tags.extend(_meo_classes(title))
    if any(t.kind == "exam_grade" and t.value.startswith("meo_class") for t in tags) and not any(
        t.kind == "department" and t.value == "engine" and t.strength == "title" for t in tags
    ):
        tags.append(Tag("department", "engine", "title", "MEO class"))
    for topic in hints.get("topics", []):
        if not any(t.kind == "topic" and t.value == topic for t in tags):
            tags.append(Tag("topic", topic, "title", "source hint"))

    # --- audience ---------------------------------------------------------------------------------
    if (site_type and site_type.lower() in rules.internal_site_types) or (hit := _first(rules.internal, title)):
        audience = "internal"
        reasons.append(
            f"internal: {site_type if site_type and site_type.lower() in rules.internal_site_types else hit}"
        )
        confidence += 0.2
    elif doc_type in rules.seafarer_doc_types or (site_type or "").lower() in rules.seafarer_site_types:
        audience = "seafarers"
        reasons.append(f"seafarer document type '{site_type or doc_type}'")
        confidence += 0.2
    elif hit := _first(rules.seafarer, head):
        audience = "seafarers"
        reasons.append(f"seafarer indicator '{hit}'")
        confidence += 0.2
    elif body and _count(rules.seafarer, body)[0] >= 3:
        audience = "seafarers"
        reasons.append("seafarer indicators in body")
        confidence += 0.1
    elif hit := _first(rules.industry, head):
        audience = "industry"
        reasons.append(f"industry indicator '{hit}'")
        confidence += 0.2
    else:
        audience = "general"
        reasons.append("no audience indicator")

    if audience == "internal":
        tags = []  # internal documents never alert; their tags are noise

    # --- priority ---------------------------------------------------------------------------------
    critical_hit = _first(rules.critical, title)
    if hints.get("priority") == "critical" or (doc_type == "advisory" and critical_hit):
        priority = "critical"
        reasons.append(f"critical: {critical_hit or 'source hint'}")
    elif audience in ("internal", "industry", "general"):
        priority = "low"
    else:
        priority = "normal"
    if audience == "internal":
        priority = "low"

    # --- relation to an earlier document ----------------------------------------------------------
    related_reference = relation = None
    head_text = (body or "")[:2000]
    if m := (rules.relation_title.search(title) or rules.relation_body.search(head_text)):
        own = (circular_number or "").lower()
        # A reference in the title counts even if it equals the document's own number (the site lists
        # "Addendum 01 To DGS Circular No. 57" as number 57). In the body, the own number is just the header.
        refs = [(r, True) for r in rules.relation_ref.finditer(title)]
        refs += [(r, False) for r in rules.relation_ref.finditer(head_text)]
        for ref, in_title in refs:
            candidate = f"{int(ref.group(1))} of {ref.group(2)}"
            if in_title or candidate.lower() != own:
                related_reference, relation = candidate, m.group(1).lower()
                reasons.append(f"{relation} of {candidate}")
                break

    return Classification(
        doc_type=doc_type,
        audience=audience,
        priority=priority,
        confidence=round(min(confidence, 1.0), 2),
        tags=tags,
        reasons=reasons,
        related_reference=related_reference,
        relation=relation,
    )
