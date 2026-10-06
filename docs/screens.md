# Screens and wireframes (Phase 0)

The Windows layout is shown. On phones, the left rail becomes a bottom navigation bar (5 tabs) and the two-pane views become push navigation.

## Screen list

| # | Screen | Phase | Free/Premium |
|---|---|---|---|
| S1 | Welcome + "unofficial app" notice + consent | 2 | Free |
| S2 | Sign in (email magic link / phone OTP) | 2 | Free |
| S3 | Onboarding profile: language → department → level → rank → ship types → home MMD → exam grades | 2 | Free |
| S4 | **For You** feed (alerts that match the profile, newest first, critical items pinned) | 2 | Free |
| S5 | Document detail (summary, who is affected, what to do, deadline, original PDF, disclaimer) | 2 | Free (EN) / Premium (other languages) |
| S6 | Archive search (filters: type, branch, date, department) | 2 | Free |
| S7 | Certificate wallet (list grouped by status: expired / expiring / valid) | 2 | Free |
| S8 | Certificate add/edit (manual, or from a scan in Phase 3) | 2 / 3 | Free |
| S9 | Reminder settings (offsets, channels, quiet hours) | 2 | Free |
| S10 | Settings: profile, topics follow/mute, language, data saver, export data, delete account, privacy | 2 | Free |
| S11 | Scan certificate → OCR review ("confirm each field") | 3 | Free |
| S12 | Exams: countdown cards + exam notices filtered by grade/MMD | 3 | Free |
| S13 | Safety checks: vessel name/IMO check, RPSL agency check | 3 | Free |
| S14 | Ask about the rules (chat with citations) | 3 | Premium |
| S15 | Sea time + NRI days calculator | 3 | Free (view) / Premium (export) |
| S16 | Export PDF (certificates pack, sea service summary) | 3 | Premium |
| S17 | Premium paywall / manage subscription | 3 | — |
| A1–A6 | Admin web: scraper health, document queue, summary editor, broadcast, users/stats, audit log | 1 / 3 | — |

## Key wireframes

> Circulars 53 and 65 of 2026 below are real titles taken from dgma.gov.in/all-circulars (seen 06-Oct-2026). The security advisory, certificate numbers and dates are placeholders made up for the layout.

### S4 — For You feed (Windows, two-pane)

```
┌──────┬──────────────────────────────────────┬───────────────────────────────────────────┐
│ ☰    │ For You            [Data saver ○]  ⟳ │  DGMA Circular 53 of 2026      31-Aug-2026│
│      │──────────────────────────────────────│  Alternative/Dual Certification for       │
│ 🔔For│ ⚠ CRITICAL · Security advisory       │  Seafarers (Ratings and Able Seafarer)    │
│  You │   Piracy advisory – Gulf of Guinea    │───────────────────────────────────────────│
│      │   2 h ago                             │  AI summary — always verify with the      │
│ 📄Arc│──────────────────────────────────────│  official circular.                       │
│  hive│ ● Circular 65 of 2026 · Engine        │                                           │
│      │   Steam/motor endorsement for MEO     │  In short                                 │
│ 🗂Wal│   Class I/II CoC holders              │  …≤3 lines…                               │
│  let │   ⚑ Affects your CoC (MEO Cl. II)     │                                           │
│      │   29-Sep                              │  Who is affected   Deck ratings, AB       │
│ 🎓Exa│──────────────────────────────────────│  What you must do  …                      │
│  ms  │ ○ Circular 53 of 2026 · Ratings       │  Deadline          Not stated in circular │
│      │   Dual certification for ratings      │                                           │
│ 🛡Che│   31-Aug                              │  Key points  • … • …                      │
│  cks │                                       │                                           │
│      │                                       │  [Open original PDF ↗]  [Share] [EN ▾]    │
│ ⚙    │                                       │  Model: … · Not yet human-verified        │
└──────┴──────────────────────────────────────┴───────────────────────────────────────────┘
```

### S7 — Certificate wallet

```
┌──────────────────────────────────────────────────────────────────┐
│ Wallet                                   [+ Add]  [📷 Scan]       │
│──────────────────────────────────────────────────────────────────│
│ EXPIRED (1)                                                       │
│  ■ Medical fitness        exp 12-Jul-2026     expired 86 days ago │
│ EXPIRING SOON (2)                                                 │
│  ■ CoC MEO Class II       exp 02-Jan-2027     88 days             │
│     ⚑ 1 circular may affect this certificate →                     │
│  ■ Passport               exp 30-Mar-2027     175 days            │
│ VALID (5)                                                         │
│  ■ CDC                    exp 14-Feb-2031                         │
│  ■ STCW Basic – PSSR      no expiry                               │
│  …                                                                │
└──────────────────────────────────────────────────────────────────┘
```

### S11 — OCR review (user confirms before saving)

```
┌─────────────────────────────┬─────────────────────────────────────┐
│ [scanned image, zoomable]   │ Type        [CoC ▾]                  │
│                             │ Number      [MUM/MEO2/12345 ] ✓ found│
│   highlighted boxes show    │ Issued      [14-03-2022   ] ? check  │
│   where each value was read │ Expires     [13-03-2027   ] ✓ found  │
│                             │ Authority   [MMD Mumbai   ]          │
│                             │  ⚠ Dates read as DD-MM-YYYY. Check.   │
│                             │        [Rescan]   [Save]              │
└─────────────────────────────┴─────────────────────────────────────┘
```

### S14 — Ask about the rules

```
┌──────────────────────────────────────────────────────────────────┐
│ Ask about the rules                                     Premium  │
│──────────────────────────────────────────────────────────────────│
│ You: Can I revalidate my CoC with sea service on a foreign flag? │
│                                                                  │
│ Answer (from 3 circulars):                                       │
│  … answer text … [1] … [2]                                       │
│  [1] DGS Circular NN of YYYY, p.2 ↗   [2] … ↗                     │
│  AI answer — verify with the official circular or your MMD.      │
│                                                                  │
│ If the sources don't cover it: "I couldn't find this in the      │
│ circulars I have. Please check with your MMD."                   │
│ [ Type a question…                                        Send ] │
└──────────────────────────────────────────────────────────────────┘
```

## Cross-cutting UI rules

- Every summary shows: the disclaimer, a link to the original PDF, the model version, and the human-verified status.
- The persistent footer in About says: *"Independent app. Not affiliated with DGMA, DG Shipping or the Government of India."*
- Text scaling up to 200% without clipping; light/dark/system themes; tap targets of at least 44 px.
- Values the AI could not determine show "Not stated in circular", never a guess.
