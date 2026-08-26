param(
  [Parameter(Mandatory=$true)]
  [string]$ProjectPath,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $packageRoot 'runtime'

if (-not (Test-Path $ProjectPath -PathType Container)) {
  throw "Project path does not exist or is not a directory: $ProjectPath"
}

$project = (Resolve-Path $ProjectPath).Path
$dest = Join-Path $project '.comprehensive-qa'

if (Test-Path $dest) {
  if (-not $Force) { throw "QA runtime already exists: $dest. Use -Force only if you intentionally want to replace the installed runtime files." }
  $backup = "$dest.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $dest $backup -Recurse
}

New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item (Join-Path $runtime '*') $dest -Recurse -Force

foreach ($d in @('profile','reports','evidence','artifacts','remediation','dispositions','state')) {
  New-Item -ItemType Directory -Path (Join-Path $dest $d) -Force | Out-Null
}

$profile = Join-Path $dest 'profile\PROJECT_QA_PROFILE.md'
if (-not (Test-Path $profile)) {
  Copy-Item (Join-Path $dest 'templates\PROJECT_QA_PROFILE.md') $profile
}

$ledger = Join-Path $dest 'state\FINDING_LEDGER.jsonl'
if (-not (Test-Path $ledger)) { New-Item -ItemType File -Path $ledger | Out-Null }

$installed = @{
  system = 'Universal Comprehensive QA Gate System'
  version = (Get-Content (Join-Path $packageRoot 'VERSION') -Raw).Trim()
  installed_at = (Get-Date).ToString('o')
  project_path = $project
  runtime_path = $dest
} | ConvertTo-Json -Depth 4
$installed | Set-Content -Path (Join-Path $dest 'INSTALLATION.json') -Encoding UTF8

Write-Host "Installed Comprehensive QA runtime at: $dest"
Write-Host "Next instruction for your QA agent:"
Write-Host "Read .comprehensive-qa/AGENT_INSTRUCTIONS.md in full, perform Discovery, build the Project QA Profile, then map and run all 25 gates."
