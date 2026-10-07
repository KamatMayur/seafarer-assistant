"""Classifier tests on real DGMA titles (seen 06-Oct-2026)."""

import pytest

from sa_scraper.classify import classify


def tags(c, kind):
    return c.values(kind)


@pytest.mark.parametrize(
    "title,site_type,doc_type,audience,priority",
    [
        (
            "Advisory for the Safety and Security of Indian Seafarers in view of the Heightened Security situation",
            None,
            "advisory",
            "seafarers",
            "critical",
        ),
        (
            "Vacancy Notice - The post of Administrative cum Accounts Officer (A.A.O) in the pay scale",
            "Vacancy",
            "unknown",
            "internal",
            "low",
        ),
        ("Procurement of Kitchen Equipment through LPC mode", None, "unknown", "internal", "low"),
        (
            "COC Dispatch List of Engineering Wing of Dated 06.10.2026",
            "COC Dispatch List",
            "notice",
            "seafarers",
            "normal",
        ),
        ("DATE – 23.09.2026 DGMA MUMBAI - SPEED POST", None, "notice", "seafarers", "normal"),
        (
            "Notice to Engineering candidates for CoC Written examination - October,2026",
            None,
            "exam_schedule",
            "seafarers",
            "normal",
        ),
        (
            "Intimation of Declaring the Written result for the month of July 2026",
            None,
            "result",
            "seafarers",
            "normal",
        ),
        (
            "Maritime Cyber Security Risk Management for Port Facilities under the International Ship and Port",
            "DGS Circulars",
            "circular",
            "industry",
            "low",
        ),
        ("Accidental Release of Free-fall Lifeboat (FFLB) at Sea", "DGS Circulars", "circular", "seafarers", "normal"),
        (
            "Nautical EAC Advisory- Reiteration of Advisory regarding Fraudulent SMS/WhatsApp Messages",
            None,
            "advisory",
            "seafarers",
            "normal",
        ),
    ],
)
def test_doc_type_audience_priority(title, site_type, doc_type, audience, priority):
    c = classify(title, site_type=site_type)
    assert (c.doc_type, c.audience, c.priority) == (doc_type, audience, priority), c.reasons


def test_meo_classes_from_title_listing_several():
    c = classify(
        "Clarification to existing provision within TEAP Manual Part A, Chapter III related to issuance "
        "of steam/motor endorsement to MEO Class I / Class II CoC holders, reg."
    )
    assert {"meo_class_1", "meo_class_2"} <= tags(c, "exam_grade")
    assert "meo_class_3" not in tags(c, "exam_grade")
    assert tags(c, "department") == {"engine"}
    assert "coc" in tags(c, "certificate_type")


def test_signal_exam_mmd():
    c = classify("Notice for Signal Examination for the month of October, 2026 - MMD Kolkata")
    assert c.doc_type == "exam_schedule"
    assert tags(c, "mmd") == {"kolkata"}
    assert "signal" in tags(c, "exam_grade") and "deck" in tags(c, "department")


def test_dgma_mumbai_head_office_is_not_an_mmd_tag():
    c = classify("DATE – 23.09.2026 DGMA MUMBAI - SPEED POST")
    assert tags(c, "mmd") == set()


def test_navi_mumbai_is_not_mmd_mumbai():
    c = classify("Show Cause Notice dated 29.09.2026 - M/s. IMU NAVI MUMBAI CAMPUS (MTI No.208053)")
    assert "mumbai" not in tags(c, "mmd")


def test_internal_documents_have_no_tags():
    c = classify("Filling of 01 post of Shipping Master and Director through Transfer on Deputation in Govt.")
    assert c.audience == "internal" and c.tags == []


def test_rating_vs_officer_levels():
    c = classify("DGMA CIRCULAR 53 OF 2026 Alternative/Dual Certification for Seafarers (Ratings and Able Seafarer)")
    assert "rating" in tags(c, "level") and "officer" not in tags(c, "level")


def test_addendum_links_to_same_number_listed_on_site():
    c = classify(
        "Addendum 01 To DGS Circular No. 57 Of 2026 -Extension of Transition Period for Issuance of",
        circular_number="57 of 2026",
    )
    assert c.relation == "addendum" and c.related_reference == "57 of 2026"


def test_supersession_found_in_body_only():
    body = (
        "DGMA CIRCULAR 47 OF 2026\nDGMA Advisory on Precautionary Measures\n"
        "(Issued in supersession of DGMA Circular No. 36 of 2026 dated 15.07.2026)\n1. The safety ..."
    )
    c = classify("Advisory for the Safety and Security of Indian Seafarers", body=body, circular_number="47 of 2026")
    assert (c.relation, c.related_reference) == ("supersession", "36 of 2026")


def test_body_tags_are_weaker_than_title_tags():
    body = "Masters of ships shall ensure ... Masters are advised ... the Master shall report ..."
    c = classify("Launch of Seafarer Tracking Module on e-NAVIK DGMA Portal", body=body)
    assert "deck" not in c.values("department")  # title strength only
    assert "deck" in c.values("department", strength="body")


def test_source_hint_makes_piracy_page_critical():
    c = classify("Piracy and Armed Robbery on Vessels.", hints={"priority": "critical", "topics": ["piracy"]})
    assert c.priority == "critical"
    assert "piracy" in tags(c, "topic")


def test_unknown_doc_types_are_held_for_review():
    from sa_scraper.classify import load_rules

    threshold = load_rules().review_threshold
    assert classify("FAKE Something entirely new").confidence < threshold
    # unknown type even with a seafarer indicator still goes to review
    c = classify("82nd STCW Compliance Board Decision")
    assert c.doc_type == "unknown" and c.confidence < threshold
    # a known type with a clear audience is released
    assert classify("Guidelines for ETO Preparatory Course", site_type="DGS Circulars").confidence >= threshold


@pytest.mark.parametrize(
    "title",
    ["COC Dispatch List of Nautical Wing of Dated 05.10.2026", "COC Dispatch List of Nautical of Dated 21.09.2026"],
)
def test_nautical_dispatch_lists_are_deck_only(title):
    assert tags(classify(title, site_type="COC Dispatch List"), "department") == {"deck"}


def test_nautical_wing_as_issuer_does_not_make_a_circular_deck_only():
    c = classify("Accidental Release of Free-fall Lifeboat (FFLB) at Sea", branch="Nautical Wing")
    assert "deck" not in tags(c, "department")
