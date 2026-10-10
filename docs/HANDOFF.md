# Handoff – state of the project (10-Oct-2026)

For whoever continues this project (and their Claude Code). Start here, then `CLAUDE.md` (standing rules and
commands) and `docs/decisions.md` (why things are the way they are). Repository:
https://github.com/KamatMayur/seafarer-assistant, branch `main`.

## In one paragraph
A Windows app (Flutter) plus a Python backend for Indian merchant navy seafarers. The backend scrapes 13 public
dgma.gov.in listing pages, extracts and classifies each circular/notice with **rules (no LLM)**, writes an
extractive summary (quotes only), and creates alerts for users whose profile matches (department, level, MMD,
exam grades, ship types, followed topics, certificates held). The app shows those alerts, the documents, an
archive search and a certificate wallet with expiry reminders, and works offline. **Phase 1 (backend) is
complete. Phase 2 (Windows app) is built and runs; a few items remain (below).** Phases 3–6 not started.

## Status by phase
| Phase | State |
|---|---|
| 0 Plan | Done: `docs/architecture.md`, `schema.sql`, `openapi.yaml`, `screens.md`, `decisions.md` |
| 1 Backend pipeline + admin | **Done.** 13 sources healthy; 129 tests pass; ruff clean. Admin UI at `/admin` with per-admin accounts (password + TOTP). Not done: Docker compose smoke test (no Docker on the dev machine). |
| 2 Windows app | **Built and running** (`demo.ps1`). Remaining: 3 widget tests failing, window title rebuild, MSIX installer, tester checkpoint. See "Next steps". |
| 3–6 | Not started (translations via IndicTrans2, OCR scan, RPSL/vessel checks, sea time/NRI, PDF export, cited search, premium, mobile, launch). |

## Binding decisions (details in docs/decisions.md)
- **R1 No LLM / no API key.** Rules-based tags; extractive summaries. Translation later with IndicTrans2 (local).
- **R2 No Redis.** Worker is a loop (`sa-scraper worker`); Postgres row status is the queue.
- **R3** Placeholder name `seafarer_assistant` ("DG Alerts" rejected: implies government). Email login only. Local
  hosting for now. Monetisation off.
- **R4** Local Postgres without Docker: `infra/dev/localpg.py` (pip `pgserver`, PostgreSQL 16 + pgvector).
- **R5** Review threshold 0.65; only title tags restrict alerts; critical advisories never held.
- **R6** Candidate lists are metadata-only (privacy); >183 days archived; alerts only for the last 30 days.
- **R7** CoC dispatch lists are opt-in (follow topic `coc_dispatch`), never a certificate-impact alert.
- **R8** The issuing branch never restricts the audience. **R9** Competency/GMDSS/signal exam notices are officer-only.
- **R10** The app groups a document's alerts into one feed card. **R11** Per-admin accounts with TOTP.
- Owner applied defaults for R7–R11 to finish Phase 1; they can still change them.

## What exists (where to look)
- `scraper/sources/dgma.yaml` – the 13 sources (mostly `/year-list?type=…&year={year}&rows=100`), header-mapped
  tables, so layout drift raises an admin event instead of failing silently.
- `scraper/sa_scraper/rules/taxonomy.yaml` – all classification rules. `classify.py` applies them;
  `summarise.py` extracts subject, directive sentences and deadlines (a deadline must sit in a sentence that asks
  the reader to act); `extract.py` detects bad OCR text layers (title-vs-subject check).
- `backend/sa_backend/services/matching.py` – who gets what (pure function, fully tested).
  `alerts.py` – creates alerts when a document is processed, and `backfill_user_alerts` gives a new or edited
  profile the matching alerts of the last 30 days (in-app only).
- `backend/sa_backend/api/` – `/v1` API used by the app; `admin/` – review queue, editor, audit log.
- `app/lib/` – Flutter app. `data/repositories.dart` holds all network→local-DB logic (feed incremental sync with
  offline read marks; certificate sync with version conflicts; offline document cache). `core/background.dart`
  polls every 30 min (2 h data saver), shows Windows toasts for new alerts and local expiry reminders.
- Real-data demo (last 30 days, `infra/dev/demo_profiles.py`): deck officer Mumbai 15 alerts, engine officer
  Kolkata 12, AB rating Chennai 9, ETO cadet Kochi 5; every alert says why.

## Try it (after setup below)
Right-click `demo.ps1` → Run with PowerShell. It starts the database, an "Seafarer API" window and the app. Sign in
with any email; the 6-digit code appears in the API window (`DEV LOGIN CODE …`) because SMTP is not configured.
Fill the profile; the feed fills with matching real circulars. Admin: http://127.0.0.1:8000/admin (create an
account first with `python -m sa_backend.admin.manage create you@example.com --role owner`).

## Next steps (in order)
1. **Fix the 3 failing widget tests** in `app/test/widgets_test.dart` (domain, certificate-sync and live-API tests
   pass). Seen so far: "welcome…consent" → `Bad state: No element`; "wallet groups…" → an assertion; "feed card…"
   failed in the first run. Likely causes to check: the test router/`GoRouterState.of` use in the welcome flow,
   the wallet test's Drift stream needing `pumpAndSettle`/disposal, and `FeedCardTile` needing a `Card` ancestor
   theme. Run: `cd app; flutter test --no-pub --timeout 90s test/widgets_test.dart`.
2. **Rebuild** (`flutter build windows --release`) – window title is already changed to "Seafarer Assistant" in
   `app/windows/runner/main.cpp` / `Runner.rc` but not yet rebuilt.
3. **Try every screen by hand** against the local API (checklist in `docs/test-checklist.md`, sections Offline,
   Certificates, Languages/UI) and fix what you find. Not yet hand-tested: certificate file attach/view, data
   export, delete account, quiet hours, toast click-through.
4. **Build the MSIX installer** (`dart run msix:create`) – self-signed for testers; instructions in `app/README.md`.
   That is the Phase 2 checkpoint ("installable Windows build for testers").
5. Then Phase 3 (see `docs/architecture.md` and the spec): regional languages (IndicTrans2), OCR scan
   (Windows.Media.Ocr), RPSL/vessel lists, sea time/NRI calculator, PDF export, cited search, premium gating.

## Known issues / limits
- Windows notifications only appear while the app is running (no FCM on Windows; tray/run-at-login not built yet).
- Summaries are quotes, not plain language (R1). Indian-language summaries fall back to English (banner shown).
- 3 PDFs failed processing (one is 45 MB, over the 25 MB cap) – visible in `sa-scraper status`.
- The Docker deployment files in `infra/` have never been built or run.
- `pgserver`'s Postgres port changes after a reboot: re-run `infra/dev/localpg.py` and update `.env`
  (`demo.ps1` does this automatically).

## Setup on a new Windows machine
Python 3.12, Git. For the app: Flutter SDK (stable 3.47+) and Visual Studio 2022 Build Tools with "Desktop
development with C++" **plus the "C++ ATL" component**; turn on Windows **Developer Mode**.
(Owner's machine: everything under `D:\tools`, `PUB_CACHE=D:\tools\pub-cache`.)
```powershell
git clone https://github.com/KamatMayur/seafarer-assistant.git; cd seafarer-assistant
py -3.12 -m venv .venv
.venv\Scripts\pip install -e backend[dev] -e scraper[dev]
.venv\Scripts\python infra\dev\localpg.py                 # prints SA_DATABASE_URL
.venv\Scripts\python infra\dev\localpg.py seafarer_test   # prints SA_TEST_DATABASE_URL
copy .env.example .env    # paste both URLs; set SA_JWT_SECRET (long random) and SA_SCRAPER_CONTACT (your email)
cd backend; ..\.venv\Scripts\alembic upgrade head; cd ..
.venv\Scripts\python -m pytest -o addopts=""              # expect 129 passed
# Real data (~30–40 min at 5 s/request). Use today's date minus 6 months:
.venv\Scripts\sa-scraper scrape
.venv\Scripts\sa-scraper process --limit 500 --since 2026-04-10
.venv\Scripts\python infra\dev\demo_profiles.py          # optional: sample profiles and their alerts
# App
cd app; flutter pub get; dart run build_runner build; flutter test --no-pub; flutter build windows --release; cd ..
.\demo.ps1
```

## History
- 06-Oct-2026: Phase 0 plan; Phase 1 pipeline, API, 94 tests (session 1).
- 07-Oct-2026: admin UI, deployment files, alert-count bug fix, checkpoint demo (session 2, another machine).
- 09–10-Oct-2026: Phase 1 completed (R7–R11, reprocess bug, admin TOTP); Phase 2 app written, built and run;
  new-user feed backfill; `demo.ps1`; this handoff (session 3).
