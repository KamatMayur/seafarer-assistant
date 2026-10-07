# Seafarer Compliance Assistant (working name)

An independent assistant for Indian merchant navy seafarers. It watches public DGMA pages for new circulars and notices, summarises them in plain language, alerts only the people they affect, and keeps a certificate wallet with expiry reminders.

> **Not affiliated with DGMA, DG Shipping or the Government of India.** Always verify with the official circular.

## Status
**Phase 1 — backend pipeline + admin UI done; checkpoint review pending.** See [docs/HANDOFF.md](docs/HANDOFF.md) for current state. [docs/decisions.md](docs/decisions.md) lists the binding decisions (R1–R6) and remaining open questions.

| Document | Contents |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Repo layout, system diagram, pipeline, client architecture, security |
| [docs/schema.sql](docs/schema.sql) | Final PostgreSQL schema (reference for Alembic migrations) |
| [docs/openapi.yaml](docs/openapi.yaml) | API contract |
| [docs/screens.md](docs/screens.md) | Screen list and wireframes |
| [docs/test-checklist.md](docs/test-checklist.md) | Living test checklist |

## Layout (created as each phase starts)
`backend/` FastAPI · `scraper/` sources + pipeline workers · `app/` Flutter · `admin/` admin web templates · `infra/` Docker + deploy · `docs/`

One-command setup (`docker compose up`), `.env.example` and the guide for adding a new scraper source arrive in Phase 1.
