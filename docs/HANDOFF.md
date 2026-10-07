# Handoff — state of the project (07-Oct-2026)

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

## Session 2 (07-Oct-2026): DONE
- Binding decisions above recorded in `docs/decisions.md` (R1–R6; D7/D11 marked superseded).
- **Admin web UI** at `/admin` (`backend/sa_backend/admin/`, Jinja + vendored HTMX, no CDN). Log in with `SA_ADMIN_TOKEN` → 12 h signed cookie (HttpOnly, SameSite=Strict, invalidated when the token rotates) + CSRF token on every POST. Pages: dashboard (doc counts, source health, admin events with Acknowledge), review queue, document search/list, document editor (doc type, priority, audience, title-strength tags as checkboxes, summary/key points/deadline) with **Save**, **Save & approve (send alerts)**, **Publish without alerts**; audit log. Every action is written to `admin_audit_log`. Saving marks the English summary `method=human, verified_by_human`.
- `sa-scraper reprocess` now **skips admin-reviewed documents** so rule changes never undo human edits.
- **Bug fixed:** with SQLAlchemy 2.1 (what pip installs now), `rowcount` of `INSERT … ON CONFLICT` is -1, so alert and expiry-reminder counts were wrong (reminders even returned negative counts). Inserts now use `RETURNING`. Regression test added.
- `infra/`: `Dockerfile`, `docker-compose.yml` (pgvector/pg16, one-shot `migrate`, `api`, `worker`, Caddy auto-HTTPS with admin CSP), `Caddyfile`, `.env.prod.example`, `backup.sh` (nightly gpg-encrypted pg_dump). **Not yet built/run: Docker is not installed on the dev machine.** The settings now refuse to start outside `SA_ENV=dev` without a long `SA_JWT_SECRET`.
- `infra/dev/demo_profiles.py`: Phase 1 checkpoint demo (4 sample profiles, matched alerts with reasons; `--remove` deletes them).
- Taxonomy: nautical CoC dispatch lists are now deck-only (`dispatch list of nautical`); before, they reached every officer.
- Re-seeded on 07-Oct-2026: 13/13 sources ok; 367 processed, 15 needs_review, 567 archived, 3 retry (one is a 45 MB PDF over the 25 MB cap).
- Tests: 108 passing, coverage 88%, ruff clean.

## Phase 1 checkpoint demo — findings for the owner (07-Oct-2026)
`infra/dev/demo_profiles.py` result (last 30 days): deck officer Mumbai 28 alerts, engine officer Kolkata 23, AB rating Chennai 12, ETO cadet Kochi 5. Every alert carries a "why". Points to decide:
1. **CoC dispatch lists are noisy.** Each one gives a CoC holder two items (new_document + cert_impact), and there are about 3 a week per wing. Suggestion: treat dispatch lists as a followable topic (`coc_dispatch`, off by default) and skip cert_impact for them.
2. **Issuing branch counts as title text** (`classify(head = title + branch)`). The engine rule `engineering (wing|…)` therefore tags all 123 "Engineering Wing" documents engine-only, including general safety circulars. I deliberately did not add a matching "Nautical Wing" rule (it made the FFLB lifeboat circular deck-only). Decide whether the branch should restrict audience at all.
3. Ratings receive nautical CoC-exam seat-booking notices (department deck, no level tag). A `level: officer` rule for "competency examination"/"CoC exam" would fix it.
4. Feed UI should group the new_document + cert_impact pair for the same document into one card.


## Remaining
- **Phase 1 checkpoint review** by the owner: run `demo_profiles.py`, look through `/admin/review`.
- Build and smoke-test `infra/docker-compose.yml` on a machine with Docker.
- Per-admin accounts + TOTP for the admin UI (architecture §5); today it is one shared admin token.
- **Phase 2 (Windows Flutter app): not started.** It needs the Flutter SDK and Visual Studio 2022 Build Tools ("Desktop development with C++"). Screens: `docs/screens.md`. API: `/v1/*` (the generated OpenAPI is at `/docs` when the API runs).
- Phases 3–6 as in the spec. Phase 3 adds IndicTrans2 translation, RPSL/vessel lists, sea time/NRI, PDF export, OCR scan and cited search.

## Setup on a new machine (Windows)
Use **Python 3.12** (`pgserver` has no wheels for 3.13/3.14): `winget install Python.Python.3.12 --scope user`.
```powershell
git clone <repo> ; cd <repo>
py -3.12 -m venv .venv
.venv\Scripts\pip install -e backend[dev] -e scraper[dev]
.venv\Scripts\python infra\dev\localpg.py            # prints SA_DATABASE_URL
.venv\Scripts\python infra\dev\localpg.py seafarer_test
copy .env.example .env   # paste both URLs, set SA_JWT_SECRET and SA_ADMIN_TOKEN (SA_SCRAPER_CONTACT optional)
cd backend ; ..\.venv\Scripts\python -m alembic upgrade head ; cd ..
.venv\Scripts\python -m pytest
# Re-seed real data (~30–60 min, 5 s between requests):
.venv\Scripts\python -c "from sa_scraper.cli import main; main()" scrape
.venv\Scripts\python -c "from sa_scraper.cli import main; main()" process --limit 500 --since <today minus 6 months>
.venv\Scripts\python -c "from sa_scraper.cli import main; main()" status
.venv\Scripts\python infra\dev\demo_profiles.py
# API + admin UI (http://127.0.0.1:8000/admin):
.venv\Scripts\python -m uvicorn sa_backend.api.app:app --http h11 --loop asyncio --ws none
```
Notes:
- The `pgserver` Postgres picks a port when it starts. If the port changes after a reboot, re-run `localpg.py` and update `.env`.
- **Windows Smart App Control** (Windows 11) blocks unsigned compiled files downloaded by pip: psycopg's binary `pq`, SQLAlchemy's Cython speedups, uvicorn's `httptools`/`watchfiles`, and pip's `.exe` launchers (`sa-scraper.exe`, `uvicorn.exe`, `alembic.exe`). Symptom: "An Application Control policy has blocked this file". Do not turn SAC off; instead:
  - run tools as `python -m …` (or `python -c "from sa_scraper.cli import main; main()" …` for the CLI), uvicorn with `--http h11 --loop asyncio --ws none` and no `--reload`;
  - force pure-Python DB drivers with a venv-local hook (not committed) — create `.venv\Lib\site-packages\_sa_sac_workaround.pth` containing one line:
    `import os, sys; os.environ.setdefault("DISABLE_SQLALCHEMY_CEXT_RUNTIME", "1"); os.environ.setdefault("PSYCOPG_IMPL", "python"); os.environ["PATH"] = os.path.join(sys.prefix, "Lib", "site-packages", "pgserver", "pginstall", "bin") + os.pathsep + os.environ.get("PATH", "")`
    (psycopg's pure-Python mode then uses the signed-OK `libpq.dll` bundled with pgserver).
