"""Command line entry point: `sa-scraper <command>`. Run `sa-scraper --help` for the list."""

from __future__ import annotations

import argparse
import logging
import sys
import time
from datetime import date, datetime, timedelta

from sqlalchemy import func, select

from sa_backend.db.models import AdminEvent, Document, DocumentSummary, Source
from sa_backend.db.session import make_sessionmaker, session_scope
from sa_backend.services.notify import deliver_due
from sa_backend.services.reminders import create_expiry_alerts
from sa_backend.settings import get_settings
from sa_scraper.config import IST, load_sources
from sa_scraper.http import PoliteClient
from sa_scraper.parse import parse_listing
from sa_scraper.pipeline import due_sources, process_pending, recheck_recent, scrape_source, sync_sources

log = logging.getLogger("sa_scraper")


def _client() -> PoliteClient:
    s = get_settings()
    if not s.scraper_contact:
        log.warning("SA_SCRAPER_CONTACT is not set; the bot's User-Agent has no contact address")
    return PoliteClient(
        s.user_agent,
        min_interval_s=s.scraper_min_interval_s,
        timeout_s=s.scraper_timeout_s,
        max_bytes=int(s.scraper_max_pdf_mb * 1024 * 1024),
    )


def cmd_scrape(args: argparse.Namespace) -> None:
    configs = load_sources()
    wanted = args.source or list(configs)
    this_year = datetime.now(IST).year
    years = list(range(this_year - args.backfill_years, this_year + 1))
    with _client() as client:
        with session_scope() as s:
            sync_sources(s, configs)
        for sid in wanted:
            with session_scope() as s:
                out = scrape_source(s, client, configs[sid], years=years)
            print(
                f"{sid:22} items={out.items:4} new={out.new:4} changed={out.changed:3} "
                f"problems={len(out.problems)}{' ERROR ' + out.error if out.error else ''}"
            )


def cmd_process(args: argparse.Namespace) -> None:
    since = date.fromisoformat(args.since) if args.since else None
    with _client() as client:
        counts = process_pending(make_sessionmaker(), client, load_sources(), limit=args.limit, published_since=since)
    print(counts)


def cmd_reprocess(args: argparse.Namespace) -> None:
    """Re-run classification/summaries (no download) after rule changes. Alerts stay idempotent.
    Documents an admin has reviewed (human-verified summary) are skipped so their edits are not undone."""
    statuses = args.status.split(",")
    reviewed = select(DocumentSummary.document_id).where(DocumentSummary.verified_by_human)
    with session_scope() as s:
        n = s.execute(
            Document.__table__.update()
            .where(
                # Re-classifying an extracted document never downloads, so documents whose PDF had no text
                # layer (scans) are included too; they are classified from the title.
                Document.status.in_(statuses),
                Document.id.not_in(reviewed),
            )
            .values(status="extracted", attempts=0)
        ).rowcount
    print(f"{n} documents queued for re-classification")
    cmd_process(argparse.Namespace(limit=args.limit, since=None))


def run_once() -> None:
    configs = load_sources()
    now = datetime.now(IST)
    with _client() as client:
        with session_scope() as s:
            sync_sources(s, configs)
            due = due_sources(s, configs, now)
        for cfg in due:
            with session_scope() as s:
                scrape_source(s, client, cfg)
        process_pending(make_sessionmaker(), client, configs, limit=100)
        recheck_recent(make_sessionmaker(), client)
    with session_scope() as s:
        create_expiry_alerts(s)
        deliver_due(s)


def cmd_run_once(_: argparse.Namespace) -> None:
    run_once()
    print("ok")


def cmd_worker(args: argparse.Namespace) -> None:
    log.info("worker started; cycle every %d min", args.interval_min)
    while True:
        started = time.monotonic()
        try:
            run_once()
        except Exception:  # keep the worker alive; the error is logged and the next cycle retries
            log.exception("cycle failed")
        time.sleep(max(30.0, args.interval_min * 60 - (time.monotonic() - started)))


def cmd_status(_: argparse.Namespace) -> None:
    with session_scope() as s:
        print("SOURCES")
        for src in s.scalars(select(Source).order_by(Source.id)):
            last = src.last_success_at.astimezone(IST).strftime("%d-%b %H:%M") if src.last_success_at else "never"
            print(f"  {src.id:22} {src.health:9} items={src.last_item_count or 0:4} last_ok={last}")
        print("DOCUMENTS")
        for status, n in s.execute(select(Document.status, func.count()).group_by(Document.status)):
            print(f"  {status:13} {n}")
        print("RECENT ADMIN EVENTS")
        since = datetime.now(IST) - timedelta(days=2)
        for e in s.scalars(
            select(AdminEvent).where(AdminEvent.created_at > since).order_by(AdminEvent.id.desc()).limit(10)
        ):
            print(
                f"  {e.created_at.astimezone(IST):%d-%b %H:%M} {e.severity:7} {e.source_id or '-':20} {e.message[:100]}"
            )


def cmd_check_source(args: argparse.Namespace) -> None:
    cfg = load_sources()[args.source]
    with _client() as client:
        res = client.get(cfg.url())
    parsed = parse_listing(res.content, cfg.layout, cfg.url())
    print(f"HTTP {res.status}  items={len(parsed.items)}  headers={parsed.headers}  next={parsed.next_page_url}")
    for p in parsed.problems:
        print("  problem:", p)
    for it in parsed.items[:10]:
        print(f"  {it.published_date}  {it.circular_number or '-':12} {it.title[:80]}")


def main(argv: list[str] | None = None) -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(prog="sa-scraper")
    sub = p.add_subparsers(required=True)

    sp = sub.add_parser("scrape", help="scrape listing pages (all sources by default)")
    sp.add_argument("--source", action="append", help="source id (repeatable)")
    sp.add_argument("--backfill-years", type=int, default=0, help="also fetch N previous years of yearly sources")
    sp.set_defaults(fn=cmd_scrape)

    sp = sub.add_parser("process", help="download, extract, classify, summarise and alert pending documents")
    sp.add_argument("--limit", type=int, default=200)
    sp.add_argument("--since", help="only documents published on/after YYYY-MM-DD")
    sp.set_defaults(fn=cmd_process)

    sp = sub.add_parser("reprocess", help="re-classify and re-summarise without downloading (after rule changes)")
    sp.add_argument("--status", default="processed,needs_review")
    sp.add_argument("--limit", type=int, default=2000)
    sp.set_defaults(fn=cmd_reprocess)

    sub.add_parser(
        "run-once", help="one full cycle: due sources, processing, rechecks, reminders, delivery"
    ).set_defaults(fn=cmd_run_once)
    sp = sub.add_parser("worker", help="run cycles forever")
    sp.add_argument("--interval-min", type=int, default=10)
    sp.set_defaults(fn=cmd_worker)
    sub.add_parser("status", help="source health, document counts, admin events").set_defaults(fn=cmd_status)
    sp = sub.add_parser("check-source", help="fetch and parse one source without saving")
    sp.add_argument("source")
    sp.set_defaults(fn=cmd_check_source)

    args = p.parse_args(argv)
    args.fn(args)


if __name__ == "__main__":
    main()
