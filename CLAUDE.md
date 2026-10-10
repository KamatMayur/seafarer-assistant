# CLAUDE.md – Seafarer Compliance Assistant

Read `docs/HANDOFF.md` first: current state, what is done, what to do next, setup. This file is the standing
rules and the commands.

## What this is
An **independent** assistant for Indian merchant navy seafarers. It watches public dgma.gov.in pages for circulars,
exam notices and advisories, extracts and tags them, alerts only the seafarers they concern, and keeps a
certificate wallet with expiry reminders. Windows app first (Phase 2), mobile later (Phase 5). The full spec
(phases 0–6) is summarised in `docs/architecture.md`; binding decisions are in `docs/decisions.md` (R1–R11).

## Rules that must not be broken
- **No LLM / no Anthropic API key (R1).** Classification and tags are rules (`scraper/sa_scraper/rules/taxonomy.yaml`).
  Summaries are *extractive*: every sentence, date and number shown to users is quoted from the PDF. Never add
  generated text without the owner's approval.
- **Never invent DGMA data.** Test data that is not real is labelled `FAKE` or uses `example.com`. Real fixtures
  are in `scraper/tests/fixtures/` with a README.
- **Unofficial.** Name, copy and branding must never imply a DGMA / DG Shipping / Government product.
- **Scrape public pages only**, ≥5 s between requests, clear User-Agent with contact (`SA_SCRAPER_CONTACT`).
  Never touch logged-in portals (e-Samudra, e-NAVIK) or ask users for portal passwords.
- **Privacy (DPDP Act).** Exam results, CoC dispatch lists and other candidate lists are `metadata_only`: never
  download or store their text (they contain names). Certificate scans never leave the device (AES-256-GCM).
- **Alerts:** only *title*-strength tags restrict who is alerted; body tags are "mentions". Unknown doc types are
  held for admin review (confidence < 0.65). Critical advisories are never held and reach everyone.
- Only documents from the last 30 days alert; older than 183 days are `archived` (metadata only).
- Admin edits are never overwritten: `reprocess` skips human-verified documents.
- Owner preference for *their* machine: install tools on **D:** only (C: is full). Ask before any install.

## Layout
```
backend/   sa_backend: SQLAlchemy models + Alembic (migrations/), FastAPI API (/v1), admin UI (/admin, Jinja+HTMX),
           services: matching (pure), alerts, notify, reminders, admin_events
scraper/   sa_scraper: sources/*.yaml, polite HTTP, parser, classifier, extractive summariser, pipeline, CLI (sa-scraper)
app/       Flutter app: lib/core (api, tokens, toasts, background sync), lib/data (Drift DB, repositories),
           lib/domain (pure logic), lib/features/* (screens), test/
infra/     docker-compose (deploy, untested), dev/localpg.py (Postgres without Docker), dev/demo_profiles.py
docs/      HANDOFF, decisions, architecture, schema, openapi, screens, test-checklist
demo.ps1   one-click local demo (database + API window + app)
```

## Commands (Windows, from the repo root)
```powershell
# Python (3.12) – backend + scraper
.venv\Scripts\python infra\dev\localpg.py              # start local Postgres; prints SA_DATABASE_URL (port can change after reboot -> update .env)
cd backend; ..\.venv\Scripts\alembic upgrade head; cd ..
.venv\Scripts\python -m pytest -o addopts=""           # all backend+scraper tests (needs SA_TEST_DATABASE_URL, db name ending _test)
.venv\Scripts\ruff check backend scraper; .venv\Scripts\ruff format backend scraper
.venv\Scripts\sa-scraper status | scrape | process --since YYYY-MM-DD | reprocess | run-once | worker
.venv\Scripts\uvicorn sa_backend.api.app:app --port 8000   # API (SA_ENV=dev prints login codes to the console)
python -m sa_backend.admin.manage create you@example.com --role owner   # admin account (password + TOTP)

# Flutter app (cd app)
dart run build_runner build          # regenerate lib/data/db.g.dart after changing Drift tables
flutter analyze --no-pub
flutter test --no-pub --timeout 90s
flutter build windows --release      # build\windows\x64\runner\Release\seafarer_assistant.exe
dart run msix:create                 # installer (not built yet)
```

## Gotchas already hit (save yourself the time)
- `.gitignore` `data/` once hid `app/lib/data/`; it is now `/data/`. Check `git status` shows new folders.
- Windows Flutter builds need **Developer Mode** on and the VS component **C++ ATL** (`atlbase.h`) for the
  notification and secure-storage plugins.
- A hung `flutter_tester.exe` (or the running app) locks `app/build/native_assets/windows/sqlite3.dll` and every
  later `flutter test`/`build` fails with "failed to delete file". Close the app / kill `flutter_tester` first.
- Package APIs moved: `flutter_local_notifications` 22 uses named args (`initialize(settings:)`, `show(id:, …)`);
  `file_picker` 13 uses static `FilePicker.pickFiles()` returning a list and `saveFile(bytes:)` returning a Uri;
  Riverpod 3 `Override` comes from `package:flutter_riverpod/misc.dart`; `StateProvider` is legacy (use Notifier).
  Check the package source in `PUB_CACHE` before guessing a signature.
- SQLAlchemy 2.1: `rowcount` of `INSERT … ON CONFLICT` is -1; use `RETURNING` to count inserts.
- Tests share one Postgres test DB and truncate between tests; never point `SA_TEST_DATABASE_URL` at real data
  (the helper refuses names not ending in `_test`).
- `pytest.ini` already passes `-q`; adding another `-q` hides the summary line (use `-o addopts=""`).

## Working style the owner expects
Phases with checkpoints (see HANDOFF). Commit with clear messages ending with the Co-Authored-By line; push only
when asked. Keep `docs/HANDOFF.md`, `docs/decisions.md` and `docs/test-checklist.md` current when you finish work.
