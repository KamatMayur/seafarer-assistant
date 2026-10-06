"""Decide whether a document concerns a user. Pure functions, no database access, fully unit-tested.

Only 'title'-strength tags restrict the audience. Tags found only in the PDF body are weaker evidence, and using
them to exclude people causes missed alerts (e.g. "Masters are advised..." in a circular for all seafarers).
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field

# Exam grades belong to departments, so a user who picked exam grades but no department still matches sensibly.
GRADE_DEPARTMENT = {
    "second_mate": "deck",
    "chief_mate": "deck",
    "master": "deck",
    "signal": "deck",
    "gmdss": "deck",
    "dredge": "deck",
    "meo_class_1": "engine",
    "meo_class_2": "engine",
    "meo_class_3": "engine",
    "meo_class_4": "engine",
    "eto": "electrical",
}
CERT_LABELS = {
    "coc": "Certificate of Competency (CoC)",
    "cop": "Certificate of Proficiency (CoP)",
    "stcw_basic": "STCW basic safety course",
    "stcw_advanced": "STCW advanced course",
    "medical": "medical fitness certificate",
    "cdc": "CDC",
    "passport": "passport",
    "bsid": "BSID",
    "visa": "visa",
    "other": "document",
}


@dataclass(frozen=True)
class DocFacts:
    id: uuid.UUID
    doc_type: str
    audience: str  # seafarers | industry | internal | general
    priority: str
    departments: frozenset[str] = frozenset()
    levels: frozenset[str] = frozenset()
    ship_types: frozenset[str] = frozenset()
    mmds: frozenset[str] = frozenset()
    exam_grades: frozenset[str] = frozenset()
    cert_types: frozenset[str] = frozenset()
    topics: frozenset[str] = frozenset()  # title and body strength


@dataclass(frozen=True)
class UserFacts:
    id: uuid.UUID
    department: str | None = None
    level: str | None = None
    ship_types: frozenset[str] = frozenset()
    home_mmd: str | None = None
    exam_grades: frozenset[str] = frozenset()
    followed_topics: frozenset[str] = frozenset()
    muted_topics: frozenset[str] = frozenset()
    certificates: tuple[tuple[uuid.UUID, str], ...] = ()  # (certificate id, cert type)


@dataclass
class Match:
    kind: str  # 'new_document' | 'exam'
    priority: str
    reasons: list[str]
    cert_impacts: list[tuple[uuid.UUID, str]] = field(default_factory=list)  # (certificate id, reason)

    @property
    def reason(self) -> str:
        return "; ".join(self.reasons)


def _label(value: str) -> str:
    return value.replace("_", " ").title().replace("Meo", "MEO").replace("Eto", "ETO").replace("Ncv", "NCV")


def match(doc: DocFacts, user: UserFacts) -> Match | None:
    # Internal administration (vacancies, tenders) never alerts anyone.
    if doc.audience == "internal":
        return None

    followed = doc.topics & user.followed_topics
    muted = doc.topics & user.muted_topics
    user_cert_types = {t for _, t in user.certificates}
    cert_hits = doc.cert_types & user_cert_types

    # Critical safety/security advisories go to every seafarer, whatever their filters or mutes.
    if doc.priority == "critical":
        return Match("new_document", "critical", ["Safety/security advisory for all seafarers"])

    if muted and not followed:
        return None

    if doc.audience in ("industry", "general") and not followed and not cert_hits:
        return None  # in the archive, not pushed; users can follow these topics

    reasons: list[str] = []
    if followed:
        reasons.append("You follow: " + ", ".join(sorted(_label(t) for t in followed)))
    elif doc.audience in ("industry", "general"):
        reasons.append("Mentions a certificate you hold")

    # Profile filters apply to everything below critical, including followed topics.
    user_depts = {user.department} if user.department else set()
    user_depts |= {GRADE_DEPARTMENT[g] for g in user.exam_grades if g in GRADE_DEPARTMENT}
    if doc.departments:
        if user_depts and not (doc.departments & user_depts):
            return None
        if user_depts & doc.departments:
            reasons.append(_label(sorted(user_depts & doc.departments)[0]))
    if doc.levels and user.level:
        if user.level not in doc.levels:
            return None
        reasons.append(_label(user.level))
    # MMD only restricts exam-type notices; circulars mention MMDs in passing.
    if doc.mmds and doc.doc_type in ("exam_schedule", "result", "notice"):
        if user.home_mmd and user.home_mmd in doc.mmds:
            reasons.append(f"MMD {_label(user.home_mmd)}")
        elif not (doc.exam_grades & user.exam_grades):
            # Users preparing for a grade the notice names still get it (they may book at any MMD).
            return None
    if doc.exam_grades and user.exam_grades and doc.doc_type in ("exam_schedule", "result"):
        overlap = doc.exam_grades & user.exam_grades
        if not overlap and not (doc.departments & user_depts):
            return None
        if overlap:
            reasons.append("Exam: " + ", ".join(sorted(_label(g) for g in overlap)))
    if doc.ship_types and user.ship_types and not (doc.ship_types & user.ship_types):
        return None
    if doc.ship_types & user.ship_types:
        reasons.append(", ".join(sorted(_label(s) for s in doc.ship_types & user.ship_types)))
    if not reasons:
        reasons.append("For all seafarers")

    impacts = [
        (
            cert_id,
            f"This {doc.doc_type.replace('_', ' ')} concerns your {CERT_LABELS.get(ctype, ctype)}. "
            "Check whether it changes anything for you, and verify with DGMA or your MMD.",
        )
        for cert_id, ctype in user.certificates
        if ctype in cert_hits
    ]
    kind = "exam" if doc.doc_type in ("exam_schedule", "result") else "new_document"
    priority = "low" if doc.priority == "low" else "normal"
    return Match(kind, priority, reasons, impacts)
