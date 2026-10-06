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
UNOFFICIAL = "Independent app. Not affiliated with DGMA, DG Shipping or the Government of India."
