$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$source = Join-Path $repoRoot ".githooks\pre-commit"
$targetDir = Join-Path $repoRoot ".git\hooks"
$target = Join-Path $targetDir "pre-commit"

if (-not (Test-Path $source)) {
  throw "Hook template not found: $source"
}

if (-not (Test-Path $targetDir)) {
  throw "Git hooks directory not found: $targetDir"
}

Copy-Item -Path $source -Destination $target -Force
Write-Host "Installed pre-commit hook to: $target" -ForegroundColor Green
Write-Host "Hook will run scripts/precheck.ps1 before each commit." -ForegroundColor Green
