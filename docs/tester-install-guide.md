# Seafarer Assistant – install guide for testers (Windows 10/11)

Thank you for testing. This takes about 3 minutes. You need the file **SeafarerAssistant-x.y.z-test.msix**.

> This is a test version of an **independent** app. It is not from DGMA, DG Shipping or the Government of India.
> Always check the official circular before acting.

## 1. Trust the test certificate (once)
The test version is signed with a test certificate, so Windows needs your permission once.
1. Right-click the `.msix` file → **Properties** → **Digital Signatures** tab.
2. Select the signature in the list → **Details** → **View Certificate** → **Install Certificate…**
3. Choose **Local Machine** → Next (click **Yes** if Windows asks).
4. Choose **Place all certificates in the following store** → **Browse** → **Trusted People** → OK → Next → Finish.

## 2. Install
Double-click the `.msix` file → **Install**. The app opens when it is done.
If Windows says the publisher is not trusted, step 1 was not completed – repeat it and choose *Local Machine* and
*Trusted People*.

## 3. Sign in and set up
1. Tick the privacy checkbox (read the privacy notice first if you like) → **Continue**.
2. Enter your email → **Send code** → type the 6-digit code from the email (check spam).
3. Fill in your profile: department, level, rank, home MMD, ship types, and the exams you are preparing for.
   This decides what you see.
4. Add a few certificates in **Wallet** (CoC, CDC, passport, medical, STCW courses) with their expiry dates.
   You can attach a scan; it stays on your computer, encrypted.

## How it works
- **For you** shows DGMA circulars, exam notices and advisories from the last 30 days that match your profile.
  Each card says why you got it. Critical safety advisories are always at the top.
- Closing the window keeps the app in the **system tray** (bottom-right, near the clock) so alerts and expiry
  reminders keep arriving as Windows notifications. Quit from the tray icon's right-click menu.
- It starts with Windows into the tray. Change this in Windows **Settings → Apps → Startup**.
- It works offline with the data it already has; changes are sent when you reconnect.

## What we would like from you
See the tester checklist you were sent. Report anything odd from **Settings → Report a problem** – the app version
is attached automatically. Please do not include passwords or certificate numbers in reports.

## Uninstall
Windows **Settings → Apps → Installed apps → Seafarer Assistant → Uninstall**. To also delete your account and data
on the server first: in the app, **Settings → Delete my account**.
