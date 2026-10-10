# Seafarer Assistant – Windows app (Phase 2)

Flutter app (Windows first; Android/iOS in Phase 5). Offline-first: the UI reads a local SQLite database (Drift);
the network only updates it.

## What it does
- Sign in with an email code; consent screen (DPDP); profile (department, level, rank, MMD, ship types, exam grades).
- **For you** feed: alerts that match the profile, with the reason. A document and its "may affect your
  certificate" alert are one card. Critical advisories are pinned. Two panes on wide windows.
- Document view: short summary, who is affected, what to do, deadline ("Not stated in circular" if none),
  quoted key points, related circulars, official PDF, disclaimer. Works offline once opened.
- Archive search (server full-text search; saved documents when offline).
- Certificate wallet: add/edit/delete offline, sync with conflict handling, scans stored only on this device
  (AES-256-GCM, key in Windows Credential Manager).
- Expiry reminders 180/90/30/7/0 days and expired, as Windows notifications (computed locally, so they work offline).
- Polls for new alerts every 30 min while open (2 h in data-saver mode) and shows a notification for each.
- Settings: topics follow/mute, quiet hours, data saver, server address, download my data, delete account, sign out.

## Requirements (installed on D: for this project)
- Flutter SDK: `D:\tools\flutter` (add `D:\tools\flutter\bin` to PATH; `PUB_CACHE=D:\tools\pub-cache`).
- Visual Studio 2022 Build Tools with "Desktop development with C++": `D:\tools\VS2022BuildTools`.

## Run against the local API
```powershell
# terminal 1 (repo root): API
.venv\Scripts\uvicorn sa_backend.api.app:app --port 8000
# terminal 2
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift code generation
flutter run -d windows                                      # or --dart-define=API_BASE=https://...
```
In dev mode the sign-in code is printed in the API terminal (`DEV LOGIN CODE ...`) when SMTP is not configured.

## Test
```powershell
flutter test
```

## Build the installer for testers (MSIX)
```powershell
flutter build windows --release
dart run msix:create
```
Output: `build\windows\x64\runner\Release\seafarer_assistant.msix`. It is signed with a self-signed test
certificate, so testers must trust it once: right-click the .msix → Properties → Digital Signatures → Details →
View Certificate → Install Certificate → Local Machine → "Trusted People". A real code-signing certificate
(paid) removes this step; see docs/decisions.md D2.
