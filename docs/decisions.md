# Decisions, deviations and open questions (Phase 0 checkpoint)

## Resolved with the owner (06-Oct-2026) — binding, supersedes the items marked below
- **R1. No LLM / no Anthropic API key (supersedes D2 Anthropic row, D6 embeddings-for-now, D11, and the LLM parts of the hallucination guard).** Classification and tagging are rules-based (`scraper/sa_scraper/rules/taxonomy.yaml`). Summaries are *extractive*: they quote the PDF and never generate text, so there is nothing to hallucinate. An LLM can be plugged in later via `SA_ANTHROPIC_API_KEY` as an optional upgrade. Translation (Phase 3) uses IndicTrans2 run locally. Q&A (Phase 3) is cited passage search with no generated answer.
- **R2. No Redis/arq (supersedes D7).** The worker is a plain loop (`sa-scraper worker`) and Postgres row status is the queue. This keeps local dev Docker-free. Redis can be added later if needed.
- **R3. Name, login, hosting, money (answers open questions 1, 2, 3, 5; D1).** Placeholder `seafarer_assistant` ("DG Alerts" rejected). Email login only. Run locally. Monetisation off.
- **R4. Local Postgres without Docker (answers D0 for Phase 1).** `infra/dev/localpg.py` (pgserver: PostgreSQL 16 + pgvector). Docker compose is kept for deployment only.
- **R5. Classifier hold threshold** is 0.65 (not 0.7). Only *title*-strength tags restrict who is alerted. Body-text tags are "mentions". Critical advisories are never held.
- **R6. Privacy and backfill.** Exam results, CoC dispatch lists and other candidate lists are `metadata_only`: their PDFs are never downloaded because they contain names. Documents older than 183 days are `archived`. Alerts only go out for documents published in the last 30 days.

## Phase 1 checkpoint findings — resolved 09-Oct-2026 (owner asked to complete Phase 1 with sensible defaults; change any of these if you disagree)
- **R7. CoC dispatch lists are opt-in.** Topic `coc_dispatch` must be followed to get them (profile filters still apply), and they never create a `cert_impact` alert. Reason: about 3 a week per wing, useful only to someone waiting for a CoC.
- **R8. The issuing branch never restricts the audience.** Tags matched only in the branch ("Engineering Wing") are stored as mentions (`strength=body`, evidence `branch: …`). Reason: the Engineering Wing also issues general safety circulars, which were reaching engineers only.
- **R9. Competency-exam notices are for officers** (`competency examination`, `grade competency` → level officer), so ratings stop receiving nautical CoC seat-booking notices.
- **R10. The feed groups a document's `new_document` and `cert_impact` alerts into one card.** Implemented in the app (Phase 2), not the API.
- **R11. Per-admin accounts** (email + scrypt password + TOTP authenticator code, lockout after 5 failures for 15 min) replace the shared token. `SA_ADMIN_TOKEN` only works until the first account exists (bootstrap/dev). Manage with `python -m sa_backend.admin.manage`. TOTP secrets are encrypted with a key derived from `SA_JWT_SECRET`; rotating that secret means re-enrolling admins (`manage reset-totp`).
- **R12. Certificate scan reading happens on the device** (brought forward from Phase 3 at the owner's request, 12-Oct-2026). Windows uses its built-in offline OCR (`Windows.Media.Ocr`, PDFs rendered with `Windows.Data.Pdf`, first 2 pages) via `app/windows/runner/ocr_channel.cpp`; mobile will use Google ML Kit on-device text recognition behind the same `CertificateOcr` interface. Fields come from rules in `app/lib/domain/certificate_scan.dart` (no LLM, R1), only empty fields are filled, the user checks them, and the OCR text is not stored. Rejected: a Python OCR model (PaddleOCR/EasyOCR) on the server, because it would upload scans and break the "scans never leave the device" promise; and bundling Python in the app (not possible on iOS, very large on Windows).
- **R13. Profile fields must agree** (12-Oct-2026, from tester feedback: an engine cadet could pick Chief Engineer). `backend/sa_backend/reference.py` holds the tables: `RANK_LEVEL` (rank -> officer/rating/cadet; Junior Engineer counts as cadet/trainee), `DEPARTMENT_LEVELS` (catering = rating only), `DEPARTMENT_EXAM_GRADES` (NCV and dredge for deck and engine; none for catering) and `RANK_HELD_GRADES` (exams a rank normally already holds are not offered, e.g. a Fourth Engineer is not offered MEO Class IV). `/v1/meta` sends them; the app filters level -> rank -> exams and picking a rank sets the level; `PATCH /v1/me` rejects contradictions with 422. The owner can correct any table entry.

Status key: **NEEDS YOU** = blocked on your answer · **PROPOSED** = I will proceed this way unless you object · **FYI** = constraint, no choice needed.

## Blocking issues

### D0. Local toolchain — RESOLVED (09-Oct-2026): Flutter SDK in `D:\tools\flutter`, VS 2022 Build Tools in `D:\tools\VS2022BuildTools` (owner: install on D only)
On 06-Oct-2026 this machine has Python 3.12, Git and Node. It does **not** have:
- **Flutter SDK**, plus **Visual Studio 2022 with "Desktop development with C++"**, which a Flutter Windows build needs. Required for Phase 2.
- **Docker Desktop** (needs WSL2). Required for Phase 1 Postgres + pgvector + Redis. The alternative is a native PostgreSQL 16 + pgvector and Memurai/Redis install. Docker is strongly preferred.

Phase 1 cannot run end to end until Docker (or native Postgres) is installed. I can write and unit-test the scraper and parsers without it.

### D1. Product name — placeholder chosen (R3); final name still open
§10 of the spec says the branding must not imply a DGMA/DG Shipping product. **"DG Alerts" conflicts with that**: "DG" is how seafarers refer to the Directorate itself. App stores also reject names that suggest a government affiliation. Proposed alternatives (no trademark search done): **Shipshape Alerts**, **SeaBrief**, **CircularWatch**, **BerthNote**. Until you choose, the code uses the placeholder package id `seafarer_assistant`.

### D2. Paid services to approve — NEEDS YOU (Anthropic row: superseded by R1)
| Service | Needed for | When | Cost driver |
|---|---|---|---|
| Anthropic API | summaries, tagging, translation, Q&A | Phase 1 | Roughly 30–60 documents a month × 8 languages, which is low. Q&A scales with users. |
| Cloud VM (+ domain) | backend | Phase 1 demo, or local only until Phase 4 | ~2 vCPU / 4 GB |
| Email sender (e.g. AWS SES / Resend) | magic-link login, admin alerts | Phase 2 | free tier is likely enough |
| SMS OTP provider (e.g. MSG91) | phone login, SMS fallback | optional (D4) | per SMS; needs DLT registration in India |
| WhatsApp Business Cloud API | premium delivery | Phase 3 | per conversation; needs Meta business verification **and pre-approved message templates** |
| Razorpay | Windows/web payments | Phase 3 | % per transaction; needs a business entity/KYC |
| Apple Developer ($99/yr) + Google Play ($25 once) | mobile | Phase 5 | — |
| Firebase (FCM) | mobile push | Phase 5 | free |

### D3. iOS builds need macOS — FYI
iOS apps can't be built or signed on Windows. Phase 5 needs a Mac, or a cloud macOS CI (GitHub Actions macOS runners or Codemagic) **and** an Apple Developer account.

## Proposed deviations from the spec's tech stack

### D4. Auth: backend-issued JWT instead of Firebase Auth — PROPOSED
FlutterFire's Windows desktop support is not production-grade. Instead, the backend sends email codes and magic links (and SMS OTP once a provider is approved) and issues short-lived JWT access tokens and rotating refresh tokens. This works the same on all 3 platforms and avoids a hard dependency on Google. **Default: email login only until you approve an SMS provider.**

### D5. Certificate files stay on the device by default — PROPOSED
This follows DPDP minimisation and reduces breach impact. Only certificate **metadata** (type, subtype, number, dates) syncs to the server, which is enough for circular↔certificate matching and push reminders. Images are encrypted on the device with AES-256-GCM, and the key is held in the OS secure store. An optional *encrypted cloud backup* (zero-knowledge: the key is derived from a user passphrase) can be added later as a premium feature. **Trade-off:** if users lose the device without a backup, they lose the images. The metadata survives.

### D6. Embeddings: local multilingual model instead of a paid API — DEFERRED to Phase 3 (R1)
Anthropic has no embeddings endpoint. Instead of adding another paid vendor, the worker runs **BAAI/bge-m3** (multilingual, 1024-dim) on the VM. It covers English and the Indic scripts, so a question in Hindi can retrieve English circulars. Cost: ~2 GB RAM and slower indexing. With ~1–2k documents, that is fine.

### D7. Job queue: arq (async, Redis) instead of Celery — SUPERSEDED by R2
The scraper and API are async (httpx, FastAPI). arq gives cron scheduling, retries and job-ID dedupe with much less setup than Celery, and Celery does not officially support Windows dev hosts. Redis stays, as the spec requires.

### D8. Windows notifications: tray poller + local toasts — PROPOSED
FCM has no Windows desktop client. The Windows app can run from the system tray at login (opt-in), poll `/feed` every 30 min and raise local toasts. Expiry reminders are scheduled locally and work offline. **Limitation:** if the app isn't running, there are no toasts. Users see the backlog on next launch. Windows Push Notification Service would need a Microsoft Store identity and can be added later.

### D9. Desktop OCR: Windows.Media.Ocr instead of bundled Tesseract — PROPOSED
It is built into Windows 10/11 and needs no 30+ MB of bundled language data. Server-side Tesseract stays for scanned **circular** PDFs.

### D10. Admin UI: server-rendered (Jinja2 + HTMX) inside the backend — PROPOSED
It is one deployable, Python only, and needs no separate SPA build. `/admin` in the monorepo holds the templates and static files.

### D11. Model choice — SUPERSEDED by R1
The model is set by env var (`CLAUDE_MODEL_SUMMARY`, `CLAUDE_MODEL_CLASSIFY`). The default is a Sonnet-class model for summaries and Q&A and Haiku for classification and translation. All calls use JSON-schema structured output, and `model_version` is stored on every summary.

## Accuracy and safety rules (decided)

- **Hallucination guard:** after summarising, every circular number, date and section reference in the output is searched for in `raw_text`. Any that are missing are moved to `uncertain_fields`, and the document goes to `needs_review`.
- Low classifier confidence (< 0.7) holds the document from broadcast until an admin approves it. **Exception:** items from security-advisory sources go out immediately as title + link.
- The vessel and RPSL checks always show the list's `last_updated` date and the note *"Not found ≠ safe"*.
- **NRI days** are informational only. Thresholds (e.g. 182 days, and the special counting rules for crew) live in a config file with source citations and are not hard-coded. The app shows a "consult a tax professional" note. These rules change through Finance Acts.

## Open questions — NEEDS YOU (answer any time before the phase noted)

1. **Name** (D1). Before Phase 2 UI strings.
2. **Approve the Anthropic API key + local Docker** for the Phase 1 demo. Do you want the backend deployed to a VM for the Phase 1 demo, or is local enough?
3. **Login method at launch:** email only (free), or email + phone OTP (needs an SMS provider and DLT registration)?
4. **Translation review:** will a native speaker review the UI strings for the 7 Indian languages? Machine-translated UI strings will be marked as *draft* until then.
5. **Business entity:** Razorpay, WhatsApp Business and store listings all need one. Is there a company or sole proprietorship, or should monetisation stay switched off until Phase 6?
6. **Admin alert channel** for scraper failures: email address and/or Slack webhook?

## Source discovery (verified 06-Oct-2026)

- `https://dgma.gov.in/robots.txt` is `Disallow:` (empty), so all paths are allowed. We still rate-limit (≥ 5 s) and send a clear User-Agent with a contact address.
- `/all-circulars` is a server-rendered HTML table (No. of Year · Title · Issue Date · PDF link), with an archive at `?archive=true`. No JS rendering is needed, so plain httpx + selectolax is enough.
- The engineering-wing, MMD and banned-vessel/RPSL list pages are still to be discovered and configured in Phase 1.
