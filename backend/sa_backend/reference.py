"""Reference values shown in onboarding and used as tag values. Keys must match scraper/rules/taxonomy.yaml
(a test checks this)."""

DEPARTMENTS = {
    "deck": "Deck",
    "engine": "Engine",
    "electrical": "Electrical (ETO)",
    "catering": "Catering",
    "other": "Other",
}
LEVELS = {"officer": "Officer", "rating": "Rating", "cadet": "Cadet / Trainee"}
RANKS = {
    "deck": ["Master", "Chief Officer", "Second Officer", "Third Officer", "Deck Cadet", "Bosun", "AB", "OS"],
    "engine": [
        "Chief Engineer",
        "Second Engineer",
        "Third Engineer",
        "Fourth Engineer",
        "Junior Engineer",
        "Engine Cadet",
        "Fitter",
        "Motorman",
        "Oiler",
        "Wiper",
    ],
    "electrical": ["ETO", "Electrical Cadet", "Electrician"],
    "catering": ["Chief Cook", "Cook", "Steward", "Messman"],
    "other": ["Other"],
}
# Which level each rank belongs to. Picking a rank sets the level; a level only offers its own ranks.
RANK_LEVEL = {
    "Master": "officer",
    "Chief Officer": "officer",
    "Second Officer": "officer",
    "Third Officer": "officer",
    "Deck Cadet": "cadet",
    "Bosun": "rating",
    "AB": "rating",
    "OS": "rating",
    "Chief Engineer": "officer",
    "Second Engineer": "officer",
    "Third Engineer": "officer",
    "Fourth Engineer": "officer",
    "Junior Engineer": "cadet",
    "Engine Cadet": "cadet",
    "Fitter": "rating",
    "Motorman": "rating",
    "Oiler": "rating",
    "Wiper": "rating",
    "ETO": "officer",
    "Electrical Cadet": "cadet",
    "Electrician": "rating",
    "Chief Cook": "rating",
    "Cook": "rating",
    "Steward": "rating",
    "Messman": "rating",
}
# Levels each department offers (derived from its ranks; "other" allows every level).
DEPARTMENT_LEVELS = {
    dept: [lvl for lvl in LEVELS if dept == "other" or any(RANK_LEVEL.get(r) == lvl for r in ranks)]
    for dept, ranks in RANKS.items()
}
SHIP_TYPES = {
    "tanker": "Tanker (oil / chemical / gas)",
    "bulk": "Bulk carrier",
    "container": "Container",
    "offshore": "Offshore / DP",
    "passenger": "Passenger / cruise / ferry",
    "fishing": "Fishing",
    "dredger": "Dredger",
    "ncv": "Near-coastal (NCV) / inland",
}
MMDS = {
    "mumbai": "Mumbai",
    "kolkata": "Kolkata",
    "chennai": "Chennai",
    "kochi": "Kochi",
    "kandla": "Kandla",
    "noida": "Noida",
    "goa": "Goa",
    "tuticorin": "Tuticorin",
    "visakhapatnam": "Visakhapatnam",
    "port_blair": "Port Blair",
    "jamnagar": "Jamnagar",
    "haldia": "Haldia",
    "paradip": "Paradip",
    "mangalore": "Mangalore",
}
EXAM_GRADES = {
    "second_mate": "2nd Mate (FG)",
    "chief_mate": "Chief Mate / 1st Mate (FG)",
    "master": "Master (FG)",
    "meo_class_4": "MEO Class IV",
    "meo_class_3": "MEO Class III",
    "meo_class_2": "MEO Class II",
    "meo_class_1": "MEO Class I",
    "eto": "ETO",
    "gmdss": "GMDSS (GOC)",
    "ncv": "NCV grades",
    "signal": "Signal exam",
    "dredge": "Dredge grades",
}
# Exams a department can prepare for ("other": all of them).
DEPARTMENT_EXAM_GRADES = {
    "deck": ["second_mate", "chief_mate", "master", "gmdss", "signal", "ncv", "dredge"],
    "engine": ["meo_class_4", "meo_class_3", "meo_class_2", "meo_class_1", "ncv", "dredge"],
    "electrical": ["eto"],
    "catering": [],
    "other": list(EXAM_GRADES),
}
# Certificates a rank normally already holds, so those exams are not offered again.
RANK_HELD_GRADES = {
    "Master": ["second_mate", "chief_mate", "master", "gmdss", "signal"],
    "Chief Officer": ["second_mate", "chief_mate", "gmdss", "signal"],
    "Second Officer": ["second_mate", "gmdss", "signal"],
    "Third Officer": ["second_mate", "gmdss", "signal"],
    "Chief Engineer": ["meo_class_4", "meo_class_3", "meo_class_2", "meo_class_1"],
    "Second Engineer": ["meo_class_4", "meo_class_3", "meo_class_2"],
    "Third Engineer": ["meo_class_4"],
    "Fourth Engineer": ["meo_class_4"],
    "ETO": ["eto"],
}


def profile_problems(department: str | None, level: str | None, rank: str | None, grades: list[str]) -> list[str]:
    """Contradictions between profile fields (empty list = consistent). Shared by the API and its tests."""
    problems = []
    if department and level and level not in DEPARTMENT_LEVELS[department]:
        problems.append(f"{LEVELS[level]} is not a level in {DEPARTMENTS[department]}")
    if rank:
        if department and rank not in RANKS[department]:
            problems.append(f"{rank} is not a rank in {DEPARTMENTS[department]}")
        if level and RANK_LEVEL.get(rank, level) != level:
            problems.append(f"{rank} is not a {LEVELS[level].lower()} rank")
    if department:
        wrong = sorted(set(grades) - set(DEPARTMENT_EXAM_GRADES[department]))
        if wrong:
            names = ", ".join(EXAM_GRADES[g] for g in wrong)
            problems.append(f"{names} is not an exam for {DEPARTMENTS[department]}")
    return problems


TOPICS = {
    "exams": "Exams",
    "training": "Training & courses",
    "revalidation": "Revalidation & validity",
    "sea_service": "Sea service",
    "e_portal": "e-Samudra / e-NAVIK",
    "security": "Security advisories",
    "piracy": "Piracy",
    "welfare": "Welfare & wages",
    "rpsl": "RPSL / manning agencies",
    "medical": "Medical",
    "coc_dispatch": "CoC dispatch lists",
    "immigration": "Sign-on / immigration",
    "fraud": "Fraud warnings",
    "mmd": "MMD notices",
}
CERT_TYPES = {
    "coc": "Certificate of Competency (CoC)",
    "cop": "Certificate of Proficiency (CoP)",
    "stcw_basic": "STCW basic safety",
    "stcw_advanced": "STCW advanced course",
    "medical": "Medical fitness",
    "cdc": "CDC",
    "passport": "Passport",
    "bsid": "BSID",
    "visa": "Visa",
    "other": "Other",
}
LANGUAGES = {
    "en": "English",
    "hi": "हिन्दी",
    "mr": "मराठी",
    "ta": "தமிழ்",
    "ml": "മലയാളം",
    "bn": "বাংলা",
    "te": "తెలుగు",
    "gu": "ગુજરાતી",
}
DISCLAIMER = "Automatic extract from the official document. Always verify with the official circular."
SEARCH_DISCLAIMER = (
    "Quoted passages that contain your search words, not an answer. A newer circular may have changed the rule: "
    "open the official PDF and check with your MMD."
)
UNOFFICIAL = "Independent app. Not affiliated with DGMA, DG Shipping or the Government of India."
