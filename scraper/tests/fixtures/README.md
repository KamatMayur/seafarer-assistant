# Test fixtures

All files here are **clearly labelled test fixtures**.

| File | What it is |
|---|---|
| `latest_news.html`, `year_list_page1.html`, `inner_table_*.html` | Trimmed copies of public dgma.gov.in listing pages saved on 06-Oct-2026. Real data; only the site chrome was removed. |
| `circular_65_of_2026.pdf` | Public DGMA EAC Branch Circular No. 65 of 2026 (text PDF). |
| `circular_61_of_2026_scanned.pdf` | Public DGMA Circular No. 61 of 2026 (a scan with a poor OCR text layer). Used to test text-quality detection. |

Synthetic inputs (broken layouts, fake HTTP responses) are built inside the tests and named `FAKE_...`.
