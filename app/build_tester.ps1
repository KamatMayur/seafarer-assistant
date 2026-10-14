# Build the tester installer (MSIX) with the server address built in.
#   cd app
#   .\build_tester.ps1 -ApiBase https://api.your-domain.in -Version 0.2.0
# Output: build\windows\x64\runner\Release\seafarer_assistant.msix  (+ a copy named with the version in ..\dist)
# Signed with the msix tool's self-signed test certificate: testers trust it once (docs/tester-install-guide.md).
param(
    [Parameter(Mandatory = $true)][string]$ApiBase,
    [string]$Version = '0.2.0'
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if ($ApiBase -notmatch '^https://') {
    Write-Warning "ApiBase is not https:// - fine for a local test, never for testers on other machines."
}
$msixVersion = "$Version.0"

Write-Host "Building Seafarer Assistant $Version for $ApiBase ..."
flutter build windows --release --dart-define=API_BASE=$ApiBase
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }

dart run msix:create --build-windows false --install-certificate false --version $msixVersion  # without the flag it prompts and leaves the package unsigned
if ($LASTEXITCODE -ne 0) { throw 'msix:create failed' }

$msix = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release\seafarer_assistant.msix'
$dist = Join-Path $PSScriptRoot '..\dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$out = Join-Path $dist "SeafarerAssistant-$Version-test.msix"
Copy-Item $msix $out -Force
Write-Host "Done: $out"
