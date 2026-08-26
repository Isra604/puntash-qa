param(
  [Parameter(Mandatory=$true)]
  [string]$ProjectPath
)
$ErrorActionPreference = 'Stop'
$dest = Join-Path (Resolve-Path $ProjectPath).Path '.comprehensive-qa'
$required = @(
  'AGENT_INSTRUCTIONS.md',
  'config\default.yaml',
  'profile\PROJECT_QA_PROFILE.md',
  'state\FINDING_LEDGER.jsonl',
  'INSTALLATION.json',
  'LICENSE',
  'TERMS_OF_USE.md',
  'DISCLAIMER.md',
  'DATA_RESPONSIBILITY_NOTICE.md',
  'HUMAN_ACCEPTANCE.md',
  'TERMS_VERSION',
  'LEGAL_MANIFEST.json',
  'NOTICE',
  'CREDITS.md',
  'state\HUMAN_ACCEPTANCE_RECEIPT.json',
  'tools\check-update.ps1',
  'tools\update.ps1',
  'tools\rollback.ps1',
  'config\update.json',
  'state\FIRST_RUN_ATTRIBUTION_PENDING.txt'
)
foreach ($i in 1..25) { $required += ('gates\GATE-{0:D2}.md' -f $i) }
$missing = @()
foreach ($r in $required) { if (-not (Test-Path (Join-Path $dest $r))) { $missing += $r } }
if ($missing.Count -gt 0) {
  Write-Error ("Installation verification failed. Missing: " + ($missing -join ', '))
  exit 1
}
Write-Host "PASS: Comprehensive QA runtime verified at $dest"
Write-Host "PASS: 25 gate definitions present"
