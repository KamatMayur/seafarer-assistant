# Handoff — state of the project (06-Oct-2026)

Read this first when continuing on a new machine. Spec: the original build prompt (phases 0–6). Plan docs: `docs/`.

## Decisions taken with the owner (binding)
1. **No Anthropic API key.** Classification and tagging are rules-based (`scraper/sa_scraper/rules/taxonomy.yaml`). Summaries are *extractive*: they quote the PDF and never generate text. An LLM can be plugged in later via `SA_ANTHROPIC_API_KEY` as an optional upgrade, but nothing uses it yet.
   - Translation (later): IndicTrans2 run locally. Q&A (later): cited passage search, with no generated answer.
2. Placeholder product name `seafarer_assistant`. "DG Alerts" was rejected because it implies government affiliation (decisions.md D1). Email login only. Run locally. Monetisation off.
3. **Deviation from decisions.md D7:** there is no Redis/arq. The worker is a plain loop (`sa-scraper worker`) and Postgres row status acts as the queue. This keeps local dev Docker-free. Redis can be added later if needed.
4. Privacy: exam results, CoC dispatch lists and other candidate lists are `metadata_only`. Their PDFs are never downloaded or stored because they contain names.
5. Documents older than 183 days are `archived` (metadata only). Alerts only go out for documents published in the last 30 days, so a backfill never floods users.
6. Only *title*-strength tags restrict who is alerted. Body-text tags are "mentions". Unknown doc types (confidence < 0.65) are held in `needs_review`. Critical advisories are never held.

## Phase 1 — backend pipeline: DONE (checkpoint not yet reviewed)
- `scraper/sources/dgma.yaml`: 13 live sources, all verified healthy. These are the year-list pages by type plus latest news, piracy, ISPS and training. Columns are mapped by header text, so drift is reported.
- `sa_scraper`: polite HTTP client (robots, UA, ≥5 s spacing, retries, size cap), parser, classifier, extractive summariser, OCR-quality detection, pipeline, CLI.
- `sa_backend`: models plus an Alembic migration (`0001`), matching (pure, tested), alerts (idempotent, quiet hours IST), email provider, admin events (Slack/email/log, 12 h de-duplication) and expiry reminders (180/90/30/7/0 days, then expired).
- FastAPI API (`/v1`): email-code auth with JWT and rotating refresh tokens, profile, topics, devices, feed, document search (Postgres full-text search) and detail, offline sync with version conflicts, data export ZIP, account deletion, `/v1/meta`, `/v1/admin/status`, health checks.
- Tests: 94 passing (`pytest` from the repo root). Coverage 85%. `ruff check` is clean.
- Seed: real DGMA data was being processed on the old machine. It is **not** carried over (see re-seed below).

## Remaining
- **Phase 1 checkpoint demo:** after re-seeding, create 3–4 sample profiles (deck officer Mumbai, engine officer, rating, ETO cadet) and show matched alerts. `docs/test-checklist.md` already exists. Update `decisions.md` with items 1 and 3 above.
- Admin web UI (Jinja + HTMX) for the review queue and summary edits. Only the JSON `/v1/admin/status` exists today.
- `infra/`: docker-compose (postgres+pgvector, api, worker, caddy) for deployment.
- **Phase 2 (Windows Flutter app): not started.** It needs the Flutter SDK and Visual Studio 2022 Build Tools ("Desktop development with C++"). Screens: `docs/screens.md`. API: `/v1/*` (the generated OpenAPI is at `/docs` when the API runs).
- Phases 3–6 as in the spec. Phase 3 adds IndicTrans2 translation, RPSL/vessel lists, sea time/NRI, PDF export, OCR scan and cited search.

## Setup on a new machine (Windows)
```powershell
git clone <repo> ; cd <repo>
py -3.12 -m venv .venv
.venv\Scripts\pip install -e backend[dev] -e scraper[dev]
.venv\Scripts\python infra\dev\localpg.py            # prints SA_DATABASE_URL
.venv\Scripts\python infra\dev\localpg.py seafarer_test
copy .env.example .env   # paste both URLs, set SA_JWT_SECRET and SA_SCRAPER_CONTACT
cd backend ; ..\.venv\Scripts\alembic upgrade head ; cd ..
.venv\Scripts\python -m pytest
# Re-seed real data (~30–40 min, 5 s between requests):
.venv\Scripts\sa-scraper scrape
.venv\Scripts\sa-scraper process --limit 500 --since <today minus 6 months>
.venv\Scripts\sa-scraper status
# API:
.venv\Scripts\uvicorn sa_backend.api.app:app --reload
```
Note: the `pgserver` Postgres picks a port when it starts. If the port changes after a reboot, re-run `localpg.py` and update `.env`.
