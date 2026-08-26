param(
  [Parameter(Mandatory=$true)]
  [string]$ProjectPath,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$runtime = Join-Path $packageRoot 'runtime'
$version = (Get-Content (Join-Path $packageRoot 'VERSION') -Raw).Trim()
$termsVersion = (Get-Content (Join-Path $packageRoot 'TERMS_VERSION') -Raw).Trim()

if (-not (Test-Path $ProjectPath -PathType Container)) {
  throw "Project path does not exist or is not a directory: $ProjectPath"
}
$project = (Resolve-Path $ProjectPath).Path
$dest = Join-Path $project '.comprehensive-qa'
if ((Test-Path $dest) -and (-not $Force)) { throw "QA runtime already exists: $dest. No files were changed. Use -Force only if you intentionally want to reinstall; fresh human acceptance will still be required." }

$legalNames = @(
  'LICENSE',
  'TERMS_OF_USE.md',
  'DISCLAIMER.md',
  'DATA_RESPONSIBILITY_NOTICE.md',
  'HUMAN_ACCEPTANCE.md',
  'NOTICE',
  'CREDITS.md'
)
foreach ($name in $legalNames) {
  $p = Join-Path $packageRoot $name
  if (-not (Test-Path $p -PathType Leaf)) { throw "Required legal document missing: $p" }
}

$hashes = [ordered]@{}
foreach ($name in $legalNames) {
  $hashes[$name] = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $packageRoot $name)).Hash
}

# HUMAN ACCEPTANCE GATE. No target-project write occurs before this block succeeds.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if (-not [System.Windows.Forms.SystemInformation]::UserInteractive) {
  throw 'Human acceptance required. The Windows installer must run in an interactive desktop session; unattended/CI acceptance is not supported.'
}

$combined = New-Object System.Text.StringBuilder
[void]$combined.AppendLine("Universal Comprehensive QA Gate System v$version")
[void]$combined.AppendLine("Original creator and project architect: Ofir Israeli")
[void]$combined.AppendLine("Terms version: $termsVersion")
[void]$combined.AppendLine(('=' * 80))
foreach ($name in $legalNames) {
  [void]$combined.AppendLine("")
  [void]$combined.AppendLine("===== $name =====")
  [void]$combined.AppendLine((Get-Content -LiteralPath (Join-Path $packageRoot $name) -Raw))
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Universal Comprehensive QA Gate System v$version - Human Acceptance Required"
$form.Size = New-Object System.Drawing.Size(980,820)
$form.StartPosition = 'CenterScreen'
$form.MinimizeBox = $false
$form.MaximizeBox = $false
$form.TopMost = $true

$title = New-Object System.Windows.Forms.Label
$title.Location = New-Object System.Drawing.Point(20,15)
$title.Size = New-Object System.Drawing.Size(930,52)
$title.Font = New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold)
$title.Text = "HUMAN ACCEPTANCE REQUIRED`r`nReview the documents below. An AI agent or automation is not authorized to accept on your behalf."
$form.Controls.Add($title)

$termsBox = New-Object System.Windows.Forms.RichTextBox
$termsBox.Location = New-Object System.Drawing.Point(20,72)
$termsBox.Size = New-Object System.Drawing.Size(930,470)
$termsBox.ReadOnly = $true
$termsBox.WordWrap = $true
$termsBox.Font = New-Object System.Drawing.Font('Consolas',9)
$termsBox.Text = $combined.ToString()
$form.Controls.Add($termsBox)

$checkHuman = New-Object System.Windows.Forms.CheckBox
$checkHuman.Location = New-Object System.Drawing.Point(22,552)
$checkHuman.Size = New-Object System.Drawing.Size(920,28)
$checkHuman.Text = 'I am a natural person authorized to accept these terms for myself or the relevant organization/project owner.'
$form.Controls.Add($checkHuman)

$checkTerms = New-Object System.Windows.Forms.CheckBox
$checkTerms.Location = New-Object System.Drawing.Point(22,582)
$checkTerms.Size = New-Object System.Drawing.Size(920,28)
$checkTerms.Text = 'I have read and accept the License, Terms of Use, Disclaimer, Data Responsibility Notice, and Human Acceptance Requirement.'
$form.Controls.Add($checkTerms)

$checkRisk = New-Object System.Windows.Forms.CheckBox
$checkRisk.Location = New-Object System.Drawing.Point(22,612)
$checkRisk.Size = New-Object System.Drawing.Size(920,40)
$checkRisk.Text = 'I understand that suitability, permissions, backups, change review, legal/compliance obligations, and consequences of use remain my responsibility.'
$form.Controls.Add($checkRisk)

$phraseLabel = New-Object System.Windows.Forms.Label
$phraseLabel.Location = New-Object System.Drawing.Point(22,660)
$phraseLabel.Size = New-Object System.Drawing.Size(400,23)
$phraseLabel.Text = 'Type exactly I ACCEPT to enable installation:'
$form.Controls.Add($phraseLabel)

$phrase = New-Object System.Windows.Forms.TextBox
$phrase.Location = New-Object System.Drawing.Point(425,657)
$phrase.Size = New-Object System.Drawing.Size(220,26)
$form.Controls.Add($phrase)

$acceptButton = New-Object System.Windows.Forms.Button
$acceptButton.Location = New-Object System.Drawing.Point(655,700)
$acceptButton.Size = New-Object System.Drawing.Size(145,40)
$acceptButton.Text = 'Accept & Install'
$acceptButton.Enabled = $false
$form.Controls.Add($acceptButton)

$declineButton = New-Object System.Windows.Forms.Button
$declineButton.Location = New-Object System.Drawing.Point(810,700)
$declineButton.Size = New-Object System.Drawing.Size(140,40)
$declineButton.Text = 'Decline / Cancel'
$form.Controls.Add($declineButton)

$projectLabel = New-Object System.Windows.Forms.Label
$projectLabel.Location = New-Object System.Drawing.Point(22,708)
$projectLabel.Size = New-Object System.Drawing.Size(620,38)
$projectLabel.Text = "Target project: $project`r`nNo project files have been written yet."
$form.Controls.Add($projectLabel)

$script:accepted = $false
$updateButton = {
  $acceptButton.Enabled = ($checkHuman.Checked -and $checkTerms.Checked -and $checkRisk.Checked -and $phrase.Text -ceq 'I ACCEPT')
}
$checkHuman.Add_CheckedChanged($updateButton)
$checkTerms.Add_CheckedChanged($updateButton)
$checkRisk.Add_CheckedChanged($updateButton)
$phrase.Add_TextChanged($updateButton)
$acceptButton.Add_Click({ $script:accepted = $true; $form.Close() })
$declineButton.Add_Click({ $script:accepted = $false; $form.Close() })
$form.Add_FormClosing({ if (-not $script:accepted) { $script:accepted = $false } })

[void]$form.ShowDialog()
$form.Dispose()
if (-not $script:accepted) {
  Write-Host 'Installation declined or cancelled. No QA runtime was written to the target project.'
  exit 4
}

$acceptedAt = (Get-Date).ToString('o')
$installationId = [guid]::NewGuid().ToString()

Write-Host "Installing Universal Comprehensive QA Gate System v$version"
Write-Host 'Original creator and project architect: Ofir Israeli'
Write-Host 'Copyright (c) 2026 Ofir Israeli | MIT License'
Write-Host "Human acceptance recorded for Terms v$termsVersion"

if (Test-Path $dest) {
  $backup = "$dest.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
  Copy-Item $dest $backup -Recurse
}

New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item (Join-Path $runtime '*') $dest -Recurse -Force
foreach ($name in $legalNames) { Copy-Item (Join-Path $packageRoot $name) (Join-Path $dest $name) -Force }
Copy-Item (Join-Path $packageRoot 'LEGAL_MANIFEST.json') (Join-Path $dest 'LEGAL_MANIFEST.json') -Force
Copy-Item (Join-Path $packageRoot 'TERMS_VERSION') (Join-Path $dest 'TERMS_VERSION') -Force
foreach ($d in @('profile','reports','evidence','artifacts','remediation','dispositions','state')) {
  New-Item -ItemType Directory -Path (Join-Path $dest $d) -Force | Out-Null
}
$profile = Join-Path $dest 'profile\PROJECT_QA_PROFILE.md'
if (-not (Test-Path $profile)) { Copy-Item (Join-Path $dest 'templates\PROJECT_QA_PROFILE.md') $profile }
$ledger = Join-Path $dest 'state\FINDING_LEDGER.jsonl'
if (-not (Test-Path $ledger)) { New-Item -ItemType File -Path $ledger | Out-Null }

@"
Universal Comprehensive QA Gate System v$version
Original creator and project architect: Ofir Israeli
Copyright (c) 2026 Ofir Israeli
Licensed under the MIT License.
"@ | Set-Content -Path (Join-Path $dest 'state\FIRST_RUN_ATTRIBUTION_PENDING.txt') -Encoding UTF8

$receipt = [ordered]@{
  system = 'Universal Comprehensive QA Gate System'
  package_version = $version
  terms_version = $termsVersion
  installation_id = $installationId
  accepted_at = $acceptedAt
  project_path = $project
  acceptance_method = 'interactive_windows_gui_clickwrap'
  accepted_by_human_attestation = $true
  human_authority_attestation = 'I am a natural person authorized to accept these terms for myself or the relevant organization/project owner.'
  acceptance_phrase = 'I ACCEPT'
  local_os_user = [Environment]::UserName
  local_machine_name = [Environment]::MachineName
  creator = 'Ofir Israeli'
  creator_role = 'Original creator and project architect'
  license = 'MIT'
  legal_document_sha256 = $hashes
  transmitted_by_installer = $false
}
$receipt | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $dest 'state\HUMAN_ACCEPTANCE_RECEIPT.json') -Encoding UTF8

$installed = [ordered]@{
  system = 'Universal Comprehensive QA Gate System'
  version = $version
  terms_version = $termsVersion
  installed_at = (Get-Date).ToString('o')
  project_path = $project
  runtime_path = $dest
  installation_id = $installationId
  human_acceptance_receipt = 'state/HUMAN_ACCEPTANCE_RECEIPT.json'
  author = 'Ofir Israeli'
  creator_role = 'Original creator and project architect'
  license = 'MIT'
  copyright = 'Copyright (c) 2026 Ofir Israeli'
} 
$installed | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $dest 'INSTALLATION.json') -Encoding UTF8

Write-Host 'Comprehensive QA Gate System installed successfully.'
Write-Host 'Created by Ofir Israeli.'
Write-Host "Installed runtime: $dest"
Write-Host "Acceptance receipt: $dest\state\HUMAN_ACCEPTANCE_RECEIPT.json"
Write-Host 'Next: ask your QA agent to read .comprehensive-qa/AGENT_INSTRUCTIONS.md in full and perform Discovery.'
