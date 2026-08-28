param(
  [switch]$NoPrompt
)
$ErrorActionPreference = 'Stop'
$installRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $installRoot 'config\update.json'
$installPath = Join-Path $installRoot 'INSTALLATION.json'
if (-not (Test-Path $configPath)) { throw "Update configuration missing: $configPath" }
if (-not (Test-Path $installPath)) { throw "Installation metadata missing: $installPath" }
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$installed = Get-Content $installPath -Raw | ConvertFrom-Json
$current = [version]$installed.version
$repo = [string]$config.repository

function Get-GhPath {
  $cmd = Get-Command gh -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $known = 'C:\Program Files\GitHub CLI\gh.exe'
  if (Test-Path $known) { return $known }
  return $null
}

function Get-LatestRelease {
  $gh = Get-GhPath
  if ($gh) {
    try {
      $raw = & $gh api "repos/$repo/releases/latest" 2>$null
      if ($LASTEXITCODE -eq 0 -and $raw) { return ($raw | ConvertFrom-Json) }
    } catch {}
  }
  try {
    return Invoke-RestMethod -Headers @{ 'User-Agent'='PUNTASH-QA-Updater' } -Uri "https://api.github.com/repos/$repo/releases/latest"
  } catch {
    if ($config.current_visibility -eq 'private') {
      throw "Could not check the private update channel. Authenticate GitHub CLI for repository $repo. When the repository becomes public, anonymous update checks will work automatically."
    }
    throw
  }
}

$release = Get-LatestRelease
$tag = [string]$release.tag_name
if (-not $tag) { throw 'Latest release did not contain a tag name.' }
$latestText = $tag.TrimStart('v','V')
$latest = [version]$latestText
$statePath = Join-Path $installRoot 'state\LAST_UPDATE_CHECK.json'
[ordered]@{
  checked_at = (Get-Date).ToString('o')
  current_version = $current.ToString()
  latest_version = $latest.ToString()
  latest_tag = $tag
  update_available = ($latest -gt $current)
  repository = $repo
} | ConvertTo-Json | Set-Content $statePath -Encoding UTF8

if ($latest -le $current) {
  Write-Host "No update available. Installed: $current | Latest: $latest"
  exit 0
}

Write-Host "Update available: $current -> $latest"
if ($NoPrompt) { exit 10 }

Add-Type -AssemblyName System.Windows.Forms
if (-not [System.Windows.Forms.SystemInformation]::UserInteractive) {
  Write-Host "Update available: $latest. Interactive user approval is required to install it."
  exit 10
}
$notes = [string]$release.body
if ($notes.Length -gt 1800) { $notes = $notes.Substring(0,1800) + "`r`n..." }
$message = "PUNTASH QA`r`nUniversal Comprehensive QA Gate System`r`n`r`nA new version is available.`r`n$current -> $latest`r`n`r`n$notes`r`n`r`nInstall this update now? A backup will be created first."
$result = [System.Windows.Forms.MessageBox]::Show($message,'PUNTASH QA Update Available',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Information)
if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
  Write-Host 'Update deferred by user.'
  exit 0
}
& (Join-Path $PSScriptRoot 'update.ps1') -ReleaseTag $tag
exit $LASTEXITCODE
