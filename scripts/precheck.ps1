$ErrorActionPreference = "Stop"

function Assert-CommandExists {
  param([Parameter(Mandatory = $true)][string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Command not found: $Name. Please install and configure it in PATH."
  }
}

Write-Host "==> Running local precheck (Windows)" -ForegroundColor Cyan

Assert-CommandExists "flutter"
Assert-CommandExists "dart"

Write-Host "==> flutter pub get" -ForegroundColor Yellow
flutter pub get

Write-Host "==> dart run build_runner build --delete-conflicting-outputs" -ForegroundColor Yellow
dart run build_runner build --delete-conflicting-outputs

Write-Host "==> flutter analyze" -ForegroundColor Yellow
flutter analyze

Write-Host "==> flutter build windows --release" -ForegroundColor Yellow
flutter build windows --release

Write-Host "Precheck passed." -ForegroundColor Green
