"""Tag values produced by the scraper must be values the app can show and users can pick."""

from sa_backend import reference
from sa_scraper.classify import load_rules


def test_taxonomy_values_exist_in_reference_lists():
    tags = load_rules().tags
    assert set(tags["department"]) <= set(reference.DEPARTMENTS)
    assert set(tags["level"]) <= set(reference.LEVELS)
    assert set(tags["ship_type"]) <= set(reference.SHIP_TYPES)
    assert set(tags["mmd"]) <= set(reference.MMDS)
    assert set(tags["certificate_type"]) <= set(reference.CERT_TYPES)
    assert set(tags["exam_grade"]) | {"meo_class_1", "meo_class_2", "meo_class_3", "meo_class_4"} <= set(
        reference.EXAM_GRADES
    )
    assert set(tags["topic"]) <= set(reference.TOPICS)


def test_source_hint_topics_exist():
    from sa_scraper.config import load_sources

    for cfg in load_sources().values():
        assert set(cfg.hints.get("topics", [])) <= set(reference.TOPICS), cfg.id
