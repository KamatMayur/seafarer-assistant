"""Phase 1 checkpoint demo: create sample seafarer profiles and show which recent documents alert each of them.

Usage:  python infra/dev/demo_profiles.py            -> create/refresh demo users, match, print their feeds
        python infra/dev/demo_profiles.py --remove   -> delete the demo users (and their alerts)
Demo users have @demo.invalid emails. Matching is idempotent, so re-running creates no duplicate alerts.
"""

from __future__ import annotations

import sys
import uuid
from datetime import date, timedelta

from sqlalchemy import delete, select

from sa_backend.db.models import Alert, Certificate, Document, User, UserTopicPref
from sa_backend.db.session import session_scope
from sa_backend.services.alerts import ALERT_WINDOW_DAYS, create_document_alerts

PROFILES = [
    dict(
        email="deck.officer.mumbai@demo.invalid",
        name="DEMO Deck officer (Mumbai)",
        rank="Second Officer",
        department="deck",
        level="officer",
        ship_types=["tanker"],
        home_mmd="mumbai",
        exam_grades=["chief_mate"],
        follow=["exams", "revalidation"],
        certs=[("coc", 400), ("medical", 25)],
    ),
    dict(
        email="engine.officer@demo.invalid",
        name="DEMO Engine officer (Kolkata)",
        rank="Second Engineer",
        department="engine",
        level="officer",
        ship_types=["bulk"],
        home_mmd="kolkata",
        exam_grades=["meo_class_1"],
        follow=["e_portal"],
        certs=[("coc", 900), ("stcw_advanced", 120)],
    ),
    dict(
        email="rating@demo.invalid",
        name="DEMO Rating (AB, Chennai)",
        rank="AB",
        department="deck",
        level="rating",
        ship_types=["container"],
        home_mmd="chennai",
        exam_grades=[],
        follow=["welfare", "rpsl"],
        certs=[("cdc", 700), ("stcw_basic", 60)],
    ),
    dict(
        email="eto.cadet@demo.invalid",
        name="DEMO ETO cadet (Kochi)",
        rank="Electrical Cadet",
        department="electrical",
        level="cadet",
        ship_types=[],
        home_mmd="kochi",
        exam_grades=["eto"],
        follow=["training", "exams"],
        certs=[],
    ),
]


def remove() -> None:
    with session_scope() as s:
        n = s.execute(delete(User).where(User.email.like("%@demo.invalid"))).rowcount
    print(f"removed {n} demo users")


def upsert_profiles() -> None:
    today = date.today()
    with session_scope() as s:
        for p in PROFILES:
            user = s.scalar(select(User).where(User.email == p["email"]))
            if user is None:
                user = User(email=p["email"])
                s.add(user)
            for k in ("name", "rank", "department", "level", "ship_types", "home_mmd", "exam_grades"):
                setattr(user, k, p[k])
            user.alert_channels = ["in_app"]
            s.flush()
            s.execute(delete(UserTopicPref).where(UserTopicPref.user_id == user.id))
            s.add_all(UserTopicPref(user_id=user.id, topic=t, mode="follow") for t in p["follow"])
            s.execute(delete(Certificate).where(Certificate.user_id == user.id))
            s.add_all(
                Certificate(id=uuid.uuid4(), user_id=user.id, type=t, expiry_date=today + timedelta(days=d))
                for t, d in p["certs"]
            )


def match_recent() -> int:
    since = date.today() - timedelta(days=ALERT_WINDOW_DAYS)
    with session_scope() as s:
        docs = s.scalars(select(Document).where(Document.status == "processed", Document.published_date >= since))
        return sum(create_document_alerts(s, d) for d in docs)


def print_feeds() -> None:
    with session_scope() as s:
        recent = s.scalar(
            select(Document.id)
            .where(Document.status == "processed")
            .where(Document.published_date >= date.today() - timedelta(days=ALERT_WINDOW_DAYS))
            .limit(1)
        )
        if recent is None:
            print("No processed documents from the last 30 days: run the scraper first.")
        for p in PROFILES:
            user = s.scalar(select(User).where(User.email == p["email"]))
            rows = s.execute(
                select(Alert, Document)
                .join(Document, Alert.document_id == Document.id)
                .where(Alert.user_id == user.id, Alert.channel == "in_app")
                .order_by(Document.published_date.desc())
            ).all()
            print(f"\n=== {p['name']}  ({len(rows)} alerts)")
            for alert, doc in rows:
                when = doc.published_date.strftime("%d %b") if doc.published_date else "  —   "
                flag = "!" if alert.priority == "critical" else ("C" if alert.kind == "cert_impact" else " ")
                print(f" {flag} {when}  [{doc.doc_type}] {doc.title[:90]}")
                print(f"           why: {alert.reason}")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # Windows consoles default to cp1252
    if "--remove" in sys.argv:
        remove()
    else:
        upsert_profiles()
        print(f"{match_recent()} new alert rows")
        print_feeds()
