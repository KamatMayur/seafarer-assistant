# Test checklist

Maintained across all phases. Column **Auto** gives the automated test that covers the item (filled in as tests are written). **Manual** items are run before each release candidate.

## Pipeline (Phase 1)
| # | Case | Expected | Auto | Manual |
|---|---|---|---|---|
| P1 | New circular appears on a listing page | Detected within one poll, alert delivered < 4 h after publication, correct tags | | ☐ |
| P2 | Same item seen on two listing pages (e.g. Latest News + All Circulars) | One `documents` row, one alert per user | | ☐ |
| P3 | Same URL, new PDF bytes | `document_versions` row added, users re-alerted as an "Updated" item | | ☐ |
| P4 | Addendum/corrigendum referencing "Circular NN of YYYY" | Linked via `related_document_id`; detail screen shows the relation | | ☐ |
| P5 | Listing page returns 0 items / 5xx / timeout | Admin alerted; no crash; next run retries | | ☐ |
| P6 | Listing page layout changed (selectors match nothing, structure hash differs) | Admin alerted with a diff; source marked degraded | | ☐ |
| P7 | Scanned (image-only) PDF | OCR fallback used; `extraction_method = ocr` | | ☐ |
| P8 | Summary mentions a number/date not in the source | Moved to `uncertain_fields`; document held in `needs_review` | | ☐ |
| P9 | Security advisory with summarisation failing | Title + link still sent as critical | | ☐ |
| P10 | Worker crash mid-pipeline, job retried | No duplicate alerts (dedupe key) | | ☐ |
| P11 | Rate limiting | ≥ 5 s between requests to dgma.gov.in, verified in logs | | ☐ |

## Admin UI (Phase 1)
| # | Case | Expected | Auto |
|---|---|---|---|
| A1 | Any /admin page without a session | Redirect to /admin/login; wrong token → 401, audit-logged | test_admin_ui::test_pages_need_login |
| A2 | Admin token rotated | All existing admin sessions invalid | test_rotating_admin_token_ends_sessions |
| A3 | POST without CSRF token | 403, nothing changed | test_review_save_then_approve_sends_alerts |
| A4 | Save edits on a held document | Stays held; summary `human`/verified; tags replaced; no alerts | test_review_save_then_approve_sends_alerts |
| A5 | Approve | Status processed; alerts only to matching users; audit row | test_review_save_then_approve_sends_alerts |
| A6 | Publish without alerts | Status processed; zero alerts | test_publish_without_alerts_and_unchecking_tags |
| A7 | `sa-scraper reprocess` after admin review | Reviewed documents skipped (tags/summary kept) | test_pipeline::test_reprocess_skips_admin_reviewed_documents |
| A8 | First admin account created | Shared token stops working; token sessions end | test_admin_accounts::test_token_login_stops_once_an_account_exists |
| A9 | Wrong password / code / unknown email | Same generic error; failed attempt audit-logged | test_any_wrong_factor_fails_with_same_message |
| A10 | 5 failed logins | Account locked 15 min, even with correct factors | test_lockout_after_repeated_failures |
| A11 | Password reset or account disabled | That admin's sessions end immediately | test_disable_and_password_reset_end_sessions |
| A12 | Same TOTP code used twice | Second use rejected (replay) | test_totp_rejects_replay_and_old_codes |
| A13 | Tester sends a report / the app crashes | Appears under Admin → Feedback; deleted with the account | test_api::test_feedback_and_crash_reports |
| A14 | Unexpected server error | 500 with a generic message; admin event recorded | test_api::test_unexpected_errors_are_reported |

## App (Phase 2)
| # | Case | Auto |
|---|---|---|
| W1 | Full journey: consent, email code, profile, backfilled feed, document, wallet, search, report, delete account | `app/integration_test/app_flow_test.dart` (real app + local API) |
| W2 | Close window → hides to tray; second launch brings it back; `--minimized` starts hidden | manual (verified 10-Oct-2026) |
| W3 | Install the MSIX on a clean PC with the test certificate | ☐ not yet done |

## Matching
| # | Case | Expected |
|---|---|---|
| M1 | Engine-only circular | Deck users and catering users get no alert |
| M2 | Ratings-only circular | Officers get no alert unless they follow the topic |
| M3 | MMD-specific exam notice (Kolkata) | Only users with home MMD Kolkata or exam grade + MMD match |
| M4 | Circular on a cert type the user holds | `cert_impact` alert with reason + "verify with DGMA/MMD" |
| M5 | Muted topic | No alert, but the document still appears in the archive |
| M6 | Quiet hours 22:00–07:00 IST | Normal alerts deferred; critical alerts delivered |

## Summary accuracy (ongoing)
- Weekly: an admin spot-checks 10 random summaries against the PDFs. Errors are logged in `docs/accuracy-log.md` with type (wrong date / wrong audience / missing action / other).

## Certificates & reminders
| # | Case | Expected |
|---|---|---|
| C1 | Expiry date in the past | Shown as Expired; no future reminders; one "expired" alert |
| C2 | No expiry date | No reminders; shown as "No expiry" |
| C3 | Expiry 29-Feb (leap year), reminder offsets crossing Feb | Correct calendar arithmetic; no crash |
| C4 | Device timezone not IST | Reminders fire on the IST date the user expects (documented choice) |
| C5 | Changing offsets after creating a certificate | Reminders rescheduled; no duplicates |

## OCR (Phase 3/5)
- Blurry · rotated 90/180° · multi-page · laminated glare · Hindi + English mixed · DD-MM vs MM-DD ambiguity. The user must confirm every field before saving.

## Offline & sync
| # | Case | Expected |
|---|---|---|
| O1 | Add/edit certificate offline, reconnect | Synced; no loss |
| O2 | Edit the same certificate on two devices offline | Conflict surfaced to the user; nothing silently overwritten |
| O3 | Delete offline | Tombstone syncs; does not reappear |
| O4 | 256 kbps throttled link | Feed loads text-only in < 10 s; summary payload < 5 KB |

## Languages & UI
- Every UI string exists in all 8 ARB files (CI check). Long Malayalam/Tamil words don't overflow at 200% text scale. Dark mode contrast ≥ 4.5:1.

## Security & privacy
- Data export ZIP contains all of the user's server-side data. Account deletion removes all user rows within 24 h. An encrypted certificate file copied off the device can't be opened. Admin actions appear in the audit log. No secrets in the repo (CI secret scan).
