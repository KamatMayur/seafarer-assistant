# Handoff – state of the project (10-Oct-2026, updated after the tester-readiness work)

For whoever continues this project (and their Claude Code). Start here, then `CLAUDE.md` (standing rules and
commands) and `docs/decisions.md` (why things are the way they are). Repository:
https://github.com/KamatMayur/seafarer-assistant, branch `main`.

## In one paragraph
A Windows app (Flutter) plus a Python backend for Indian merchant navy seafarers. The backend scrapes 13 public
dgma.gov.in listing pages, extracts and classifies each circular/notice with **rules (no LLM)**, writes an
extractive summary (quotes only), and creates alerts for users whose profile matches (department, level, MMD,
exam grades, ship types, followed topics, certificates held). The app shows those alerts, the documents, an
archive search and a certificate wallet with expiry reminders, and works offline. **Phase 1 (backend) is
complete. Phase 2 (Windows app) is complete and ready for testers except hosting** (see "Next steps").
Phase 3 has started: certificate scan reading (R12), cited search (R14), sea time + NRI days (R15), PDF export (R16). Phases 4–6 not started.

## Status by phase
| Phase | State |
|---|---|
| 0 Plan | Done: `docs/architecture.md`, `schema.sql`, `openapi.yaml`, `screens.md`, `decisions.md` |
| 1 Backend pipeline + admin | **Done.** 13 sources healthy; 129 tests pass; ruff clean. Admin UI at `/admin` with per-admin accounts (password + TOTP). Not done: Docker compose smoke test (no Docker on the dev machine). |
| 2 Windows app | **Done, waiting for a server.** All app tests pass, incl. a full UI journey on the real app (`integration_test/`). Tray + start with Windows, single instance, report a problem, crash reports, privacy notice, tester tips, MSIX installer script. Certificate scan reading (on-device Windows OCR, R12). |
| 3 | **Started.** Done: OCR scan (R12, listed under Phase 2 above); cited search – `GET /v1/search/passages` + "Quotes" mode in Archive (verbatim passages with page numbers and a link to the official PDF at that page; R14); sea time + NRI days – "Sea time" tab, synced log, totals by rank/ship type, NRI days per financial year from `app/assets/nri_rules.json` (R15; **owner must check the tax citations**). PDF export – sea service summary + certificates pack, built on the device (R16). To do (order by tester feedback): exam countdown cards and RPSL/vessel checks (both need real scraped data to build safely), regional languages (IndicTrans2, multi-GB model), premium gating (needs Razorpay + business entity). |
| 4–6 | Not started (premium, mobile, launch). |

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
- **R12** Certificate OCR on the device. **R13** Profile fields must agree.
- **R14** Cited search replaces "Ask about the rules": verbatim passages with page numbers, no generated answer.
- **R15** Sea time + NRI days computed on the device; tax thresholds and citations in `app/assets/nri_rules.json`, unverified until the owner checks them.
- **R16** PDF export on the device; Latin-1 font only for now.
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
1. **Owner: hosting decisions** – `docs/hosting-options.md` (recommended: DigitalOcean Bangalore 2 vCPU/4 GB,
   a `.in` domain, Brevo free email; or the $0 option: Oracle Always Free in Mumbai/Hyderabad + DuckDNS +
   a dedicated Gmail account). Also needed: operator name + privacy contact email for the notice.
2. **Deploy** with `docs/deployment.md` (never run before: expect small fixes; update the runbook).
3. **Build the tester installer** pointing at the server: `cd app; .\build_tester.ps1 -ApiBase https://api.<domain>`.
   Install it once on a clean PC following `docs/tester-install-guide.md` (not yet tried end to end).
4. **Invite 5–10 testers** with the guide and `docs/tester-checklist.md`; watch Admin → Feedback and the dashboard.
5. Then Phase 3, ordered by tester feedback (candidates: exam countdown cards, RPSL/fake-agency check, regional
   languages, sea time/NRI, PDF export, plain-language summaries if testers ask).

## Known issues / limits
- Windows notifications need the app running; it now lives in the tray and starts with Windows (no FCM on Windows).
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
- 10-Oct-2026 (later): tester readiness – widget tests fixed, tray/startup/single instance, feedback + crash
  reports, privacy notice, tips, MSIX script, full-UI integration test (found and fixed a crash on leaving Archive
  during a search), hosting options and deployment runbook.
- 12-Oct-2026: "I already have an account" sign-in (re-sign-in no longer overwrites consents); certificate scan
  reading with Windows' built-in OCR (R12), checked on a FAKE certificate image and PDF.
- 12-Oct-2026: profile fields depend on each other (department -> level -> rank -> exams, R13), checked by the API.
- 13-Oct-2026 (session on a second dev machine: Flutter in `C:	oolslutter`, VS Build Tools on C:): Phase 3
  cited search (backend + Quotes mode + tests, R14); `build_tester.ps1` now passes `--install-certificate false`
  (without it, in a non-interactive shell msix:create stops at a prompt and leaves the package unsigned). No real
  data was scraped on that machine (no scraper contact email given), so Quotes is tested on FAKE data only:
  checklist Q2/Q5/Q6 and the integration journey still need a run against real circulars.
- 14-Oct-2026: Phase 3 sea time + NRI days (R15): Drift table `sea_services` (app schema v2, migration adds the
  table), `SeaServiceRepository` sync, Sea time tab + form, `domain/sea_time.dart`, rules file with citations;
  backend tests for sea-service sync. Owner to do: check the citations in `app/assets/nri_rules.json` (especially
  the Income-tax Act, 2025) and set `verified_by_owner` to true per regime.
- 14-Oct-2026: PDF export (R16): `features/export/` (pure builders + save actions), Export PDF buttons on Sea time
  and Wallet, tests incl. a FAKE PNG scan page.
