"""Profile filter tests (test checklist M1–M6)."""

import uuid

from sa_backend.services.matching import DocFacts, UserFacts, match


def doc(**kw):
    base = dict(id=uuid.uuid4(), doc_type="circular", audience="seafarers", priority="normal")
    base.update({k: frozenset(v) if isinstance(v, set) else v for k, v in kw.items()})
    return DocFacts(**base)


def user(**kw):
    base = dict(id=uuid.uuid4())
    base.update({k: frozenset(v) if isinstance(v, set) else v for k, v in kw.items()})
    return UserFacts(**base)


DECK_OFFICER = user(department="deck", level="officer", home_mmd="mumbai")
ENGINE_OFFICER = user(department="engine", level="officer", home_mmd="kolkata")
RATING = user(department="deck", level="rating", home_mmd="chennai")
CATERING = user(department="catering", level="rating")


def test_m1_engine_only_circular():
    d = doc(departments={"engine"})
    assert match(d, ENGINE_OFFICER) is not None
    assert match(d, DECK_OFFICER) is None
    assert match(d, CATERING) is None


def test_m2_ratings_only_circular():
    d = doc(levels={"rating"})
    assert match(d, RATING) is not None
    assert match(d, DECK_OFFICER) is None


def test_m3_mmd_specific_exam_notice():
    d = doc(doc_type="exam_schedule", departments={"deck"}, mmds={"kolkata"}, exam_grades={"signal"})
    assert match(d, DECK_OFFICER) is None  # home MMD Mumbai
    kolkata_deck = user(department="deck", level="officer", home_mmd="kolkata")
    assert "MMD Kolkata" in match(d, kolkata_deck).reason
    # preparing for the grade the notice names: still alerted, any MMD
    candidate = user(department="deck", home_mmd="goa", exam_grades={"signal"})
    assert match(d, candidate) is not None


def test_mmd_does_not_restrict_circulars():
    d = doc(doc_type="circular", mmds={"kolkata"})
    assert match(d, DECK_OFFICER) is not None


def test_m4_certificate_impact():
    cert_id = uuid.uuid4()
    u = user(department="engine", level="officer", certificates=((cert_id, "coc"),))
    m = match(doc(departments={"engine"}, cert_types={"coc"}), u)
    assert m.cert_impacts and m.cert_impacts[0][0] == cert_id
    assert "verify with DGMA" in m.cert_impacts[0][1]


def test_m5_muted_topic():
    d = doc(topics={"training"})
    assert match(d, user(muted_topics={"training"})) is None
    assert match(d, user()) is not None


def test_critical_reaches_everyone_even_if_muted():
    d = doc(doc_type="advisory", priority="critical", departments={"deck"}, topics={"security"})
    for u in (ENGINE_OFFICER, CATERING, user(muted_topics={"security"})):
        m = match(d, u)
        assert m is not None and m.priority == "critical"


def test_internal_never_alerts():
    assert match(doc(audience="internal", priority="low"), user(followed_topics={"training"})) is None


def test_industry_only_when_followed_and_profile_filters_still_apply():
    d = doc(audience="industry", priority="low", topics={"training"}, departments={"deck"})
    assert match(d, DECK_OFFICER) is None
    assert match(d, user(department="deck", followed_topics={"training"})) is not None
    assert match(d, user(department="engine", followed_topics={"training"})) is None


def test_exam_grade_overlap():
    d = doc(doc_type="exam_schedule", departments={"engine"}, exam_grades={"meo_class_4"})
    assert "MEO Class 4" in match(d, user(department="engine", exam_grades={"meo_class_4"})).reason
    # grade picked without department still maps to engine
    assert match(d, user(exam_grades={"meo_class_4"})) is not None
    assert match(d, user(exam_grades={"second_mate"})) is None


def test_ship_type_filter():
    d = doc(ship_types={"tanker"})
    assert match(d, user(ship_types={"container"})) is None
    assert match(d, user(ship_types={"tanker", "bulk"})) is not None
    assert match(d, user()) is not None  # no ship types chosen: not excluded


def test_empty_profile_gets_general_seafarer_circulars():
    m = match(doc(), user())
    assert m is not None and m.reason == "For all seafarers"
