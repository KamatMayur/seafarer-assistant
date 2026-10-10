# One-click local demo: database + API + Windows app.
#   Right-click > "Run with PowerShell", or in a terminal:  powershell -ExecutionPolicy Bypass -File demo.ps1
# Sign in with any email address. Email is not configured in dev, so the 6-digit code appears in the
# "Seafarer API" window as:  DEV LOGIN CODE for you@example.com: 123456
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$py = Join-Path $root '.venv\Scripts\python.exe'
$exe = Join-Path $root 'app\build\windows\x64\runner\Release\seafarer_assistant.exe'

if (-not (Test-Path $py)) { throw "Python environment missing. See docs/HANDOFF.md 'Setup on a new machine'." }
if (-not (Test-Path $exe)) { throw "App not built yet. Run: cd app; flutter build windows --release" }

Write-Host 'Starting the local database...'
$dbUrl = (& $py (Join-Path $root 'infra\dev\localpg.py')).Trim()
Write-Host "  $dbUrl"

# Apply any new migrations.
Push-Location (Join-Path $root 'backend')
$env:SA_DATABASE_URL = $dbUrl
& (Join-Path $root '.venv\Scripts\alembic.exe') upgrade head | Out-Null
Pop-Location

$apiUp = $false
try { $apiUp = (Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/healthz -TimeoutSec 2).StatusCode -eq 200 } catch {}
if (-not $apiUp) {
    Write-Host 'Starting the API (a new window; leave it open)...'
    $cmd = "`$env:SA_ENV='dev'; `$env:SA_DATABASE_URL='$dbUrl'; `$host.UI.RawUI.WindowTitle='Seafarer API'; " +
           "Write-Host 'Sign-in codes appear here as: DEV LOGIN CODE ...' -ForegroundColor Yellow; " +
           "& '$root\.venv\Scripts\uvicorn.exe' sa_backend.api.app:app --host 127.0.0.1 --port 8000"
    Start-Process powershell -ArgumentList '-NoExit', '-Command', $cmd -WorkingDirectory $root
    for ($i = 0; $i -lt 30 -and -not $apiUp; $i++) {
        Start-Sleep -Seconds 1
        try { $apiUp = (Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8000/healthz -TimeoutSec 2).StatusCode -eq 200 } catch {}
    }
    if (-not $apiUp) { throw 'The API did not start; check the Seafarer API window.' }
}

Write-Host 'Starting the app...'
Start-Process $exe
Write-Host 'Done. Admin pages: http://127.0.0.1:8000/admin   API docs: http://127.0.0.1:8000/docs'
