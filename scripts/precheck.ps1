$ErrorActionPreference = "Stop"

function Assert-CommandExists {
  param([Parameter(Mandatory = $true)][string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Command not found: $Name. Please install and configure it in PATH."
  }
}

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )
  Write-Host "==> $Title" -ForegroundColor Yellow
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "Precheck failed at: $Title (exit code: $LASTEXITCODE)"
  }
}

Write-Host "==> Running local precheck (Windows)" -ForegroundColor Cyan

Assert-CommandExists "flutter"
Assert-CommandExists "dart"

Invoke-Checked "flutter pub get" { flutter pub get }
Invoke-Checked "dart run build_runner build --delete-conflicting-outputs" {
  dart run build_runner build --delete-conflicting-outputs
}
Invoke-Checked "flutter analyze --no-fatal-infos lib" {
  flutter analyze --no-fatal-infos lib
}

if ($env:PRECHECK_RUN_WINDOWS_BUILD -eq "1") {
  Invoke-Checked "flutter build windows --release" {
    flutter build windows --release
  }
} else {
  Write-Host "==> skip flutter build windows --release (set PRECHECK_RUN_WINDOWS_BUILD=1 to enable)" -ForegroundColor DarkYellow
}

Write-Host "Precheck passed." -ForegroundColor Green
