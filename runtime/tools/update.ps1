param(
  [string]$ReleaseTag
)
$ErrorActionPreference = 'Stop'
$installRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $installRoot
$config = Get-Content (Join-Path $installRoot 'config\update.json') -Raw | ConvertFrom-Json
$installed = Get-Content (Join-Path $installRoot 'INSTALLATION.json') -Raw | ConvertFrom-Json
$currentVersion = [version]$installed.version
$repo = [string]$config.repository

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if (-not [System.Windows.Forms.SystemInformation]::UserInteractive) {
  throw 'Interactive human approval is required for updates.'
}

function Get-GhPath {
  $cmd = Get-Command gh -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $known='C:\Program Files\GitHub CLI\gh.exe'
  if (Test-Path $known) { return $known }
  return $null
}
function Get-Release([string]$tag) {
  $gh=Get-GhPath
  if ($gh) {
    try {
      $endpoint = if ($tag) { "repos/$repo/releases/tags/$tag" } else { "repos/$repo/releases/latest" }
      $raw=& $gh api $endpoint 2>$null
      if ($LASTEXITCODE -eq 0 -and $raw) { return ($raw | ConvertFrom-Json) }
    } catch {}
  }
  try {
    $uri=if ($tag) { "https://api.github.com/repos/$repo/releases/tags/$tag" } else { "https://api.github.com/repos/$repo/releases/latest" }
    return Invoke-RestMethod -Headers @{ 'User-Agent'='Universal-Comprehensive-QA-Updater' } -Uri $uri
  } catch {
    if ($config.current_visibility -eq 'private') { throw "Private update channel requires authenticated GitHub CLI access to $repo." }
    throw
  }
}
function Download-Asset($release,[string]$name,[string]$dest) {
  $gh=Get-GhPath
  if ($gh) {
    & $gh release download ([string]$release.tag_name) -R $repo -p $name -D (Split-Path -Parent $dest) --clobber | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Test-Path $dest)) { return }
  }
  $asset=$release.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
  if (-not $asset) { throw "Release asset not found: $name" }
  Invoke-WebRequest -Headers @{ 'User-Agent'='Universal-Comprehensive-QA-Updater' } -Uri $asset.browser_download_url -OutFile $dest
}
function Show-TermsAcceptance([string]$pkgRoot,[string]$newVersion,[string]$termsVersion) {
  $legal=@('LICENSE','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','NOTICE','CREDITS.md')
  $combined=New-Object System.Text.StringBuilder
  [void]$combined.AppendLine("Universal Comprehensive QA Gate System v$newVersion")
  [void]$combined.AppendLine("Updated Terms version: $termsVersion")
  [void]$combined.AppendLine(('='*80))
  foreach($f in $legal){
    [void]$combined.AppendLine("`r`n===== $f =====")
    [void]$combined.AppendLine((Get-Content (Join-Path $pkgRoot $f) -Raw))
  }
  $form=New-Object System.Windows.Forms.Form
  $form.Text="QA System Update - Updated Terms Require Human Acceptance"
  $form.Size=New-Object System.Drawing.Size(980,820); $form.StartPosition='CenterScreen'; $form.TopMost=$true
  $title=New-Object System.Windows.Forms.Label; $title.Location=New-Object System.Drawing.Point(20,15); $title.Size=New-Object System.Drawing.Size(930,50); $title.Font=New-Object System.Drawing.Font('Segoe UI',11,[System.Drawing.FontStyle]::Bold); $title.Text='UPDATED TERMS - HUMAN ACCEPTANCE REQUIRED'; $form.Controls.Add($title)
  $box=New-Object System.Windows.Forms.RichTextBox; $box.Location=New-Object System.Drawing.Point(20,70); $box.Size=New-Object System.Drawing.Size(930,485); $box.ReadOnly=$true; $box.Text=$combined.ToString(); $form.Controls.Add($box)
  $c1=New-Object System.Windows.Forms.CheckBox; $c1.Location=New-Object System.Drawing.Point(22,565); $c1.Size=New-Object System.Drawing.Size(920,28); $c1.Text='I am a natural person authorized to accept these updated terms.'; $form.Controls.Add($c1)
  $c2=New-Object System.Windows.Forms.CheckBox; $c2.Location=New-Object System.Drawing.Point(22,595); $c2.Size=New-Object System.Drawing.Size(920,38); $c2.Text='I have read and accept the updated License, Terms, Disclaimer, Data Responsibility Notice and Human Acceptance Requirement.'; $form.Controls.Add($c2)
  $lab=New-Object System.Windows.Forms.Label; $lab.Location=New-Object System.Drawing.Point(22,648); $lab.Size=New-Object System.Drawing.Size(390,24); $lab.Text='Type exactly I ACCEPT to continue:'; $form.Controls.Add($lab)
  $phrase=New-Object System.Windows.Forms.TextBox; $phrase.Location=New-Object System.Drawing.Point(415,645); $phrase.Size=New-Object System.Drawing.Size(220,26); $form.Controls.Add($phrase)
  $ok=New-Object System.Windows.Forms.Button; $ok.Location=New-Object System.Drawing.Point(650,700); $ok.Size=New-Object System.Drawing.Size(145,40); $ok.Text='Accept & Update'; $ok.Enabled=$false; $form.Controls.Add($ok)
  $cancel=New-Object System.Windows.Forms.Button; $cancel.Location=New-Object System.Drawing.Point(805,700); $cancel.Size=New-Object System.Drawing.Size(145,40); $cancel.Text='Decline / Cancel'; $form.Controls.Add($cancel)
  $script:legalAccepted=$false
  $refresh={ $ok.Enabled=($c1.Checked -and $c2.Checked -and $phrase.Text -ceq 'I ACCEPT') }
  $c1.Add_CheckedChanged($refresh); $c2.Add_CheckedChanged($refresh); $phrase.Add_TextChanged($refresh)
  $ok.Add_Click({$script:legalAccepted=$true;$form.Close()}); $cancel.Add_Click({$script:legalAccepted=$false;$form.Close()})
  [void]$form.ShowDialog(); $form.Dispose()
  return $script:legalAccepted
}
function Restore-Managed([string]$backup) {
  foreach($d in @('gates','templates','agent-guides','dashboard','prompts')){
    $target=Join-Path $installRoot $d
    if(Test-Path $target){Remove-Item $target -Recurse -Force}
    $source=Join-Path $backup $d
    if(Test-Path $source){Copy-Item $source $target -Recurse -Force}
  }
  foreach($d in @('tools')){
    $target=Join-Path $installRoot $d
    if(Test-Path $target){Remove-Item $target -Recurse -Force}
    $source=Join-Path $backup $d
    if(Test-Path $source){Copy-Item $source $target -Recurse -Force}
  }
  $files=@('AGENT_INSTRUCTIONS.md','START_HERE.md','OPEN_DASHBOARD.cmd','LICENSE','NOTICE','CREDITS.md','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','TERMS_VERSION','LEGAL_MANIFEST.json','INSTALLATION.json')
  foreach($f in $files){$src=Join-Path $backup $f;$dst=Join-Path $installRoot $f;if(Test-Path $src){Copy-Item $src $dst -Force}elseif($f -in @('START_HERE.md','OPEN_DASHBOARD.cmd') -and (Test-Path $dst)){Remove-Item $dst -Force}}
  $uc=Join-Path $backup 'config\update.json'; if(Test-Path $uc){Copy-Item $uc (Join-Path $installRoot 'config\update.json') -Force}
  $pc=Join-Path $backup 'config\permission-policy.json';$pct=Join-Path $installRoot 'config\permission-policy.json';if(Test-Path $pc){Copy-Item $pc $pct -Force}elseif(Test-Path $pct){Remove-Item $pct -Force}
  $r=Join-Path $backup 'state\HUMAN_ACCEPTANCE_RECEIPT.json'; if(Test-Path $r){Copy-Item $r (Join-Path $installRoot 'state\HUMAN_ACCEPTANCE_RECEIPT.json') -Force}
}

$release=Get-Release $ReleaseTag
$tag=[string]$release.tag_name
$newVersion=[version]($tag.TrimStart('v','V'))
if($newVersion -le $currentVersion){Write-Host "No newer version to install. Current: $currentVersion | Requested: $newVersion";exit 0}
$temp=Join-Path ([IO.Path]::GetTempPath()) ("comprehensive-qa-update-"+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
$backup=$null
try {
  $manifestName='release-manifest.json'
  $manifestPath=Join-Path $temp $manifestName
  Download-Asset $release $manifestName $manifestPath
  $manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json
  if([string]$manifest.version -ne $newVersion.ToString()){throw 'Release manifest version does not match release tag.'}
  $zipName=[string]$manifest.asset_name
  $zipPath=Join-Path $temp $zipName
  Download-Asset $release $zipName $zipPath
  $actual=(Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToUpperInvariant()
  $expected=([string]$manifest.sha256).ToUpperInvariant()
  if($actual -ne $expected){throw "SHA-256 verification failed. Expected $expected, got $actual"}
  $extract=Join-Path $temp 'package'; Expand-Archive $zipPath $extract -Force
  $pkgRoot=$extract
  if(-not (Test-Path (Join-Path $pkgRoot 'VERSION'))){
    $dirs=Get-ChildItem $extract -Directory
    if($dirs.Count -eq 1 -and (Test-Path (Join-Path $dirs[0].FullName 'VERSION'))){$pkgRoot=$dirs[0].FullName}
  }
  if(-not (Test-Path (Join-Path $pkgRoot 'runtime\AGENT_INSTRUCTIONS.md'))){throw 'Downloaded package is missing runtime/AGENT_INSTRUCTIONS.md'}
  $gateCount=(Get-ChildItem (Join-Path $pkgRoot 'runtime\gates') -Filter 'GATE-*.md').Count
  if($gateCount -ne 25){throw "Downloaded package gate validation failed: $gateCount/25"}
  if($newVersion -ge [version]'2.0.0'){
    $lensDir=Join-Path $pkgRoot 'runtime\gates\lenses'
    $lensCount=if(Test-Path $lensDir){(Get-ChildItem $lensDir -Filter 'LENS-*.md').Count}else{0}
    if($lensCount -ne 9){throw "Downloaded package reliability-lens validation failed: $lensCount/9"}
    if(-not(Test-Path (Join-Path $pkgRoot 'runtime\gates\reliability.yaml'))){throw 'Downloaded v2 package is missing gates/reliability.yaml'}
  }
  if($newVersion -ge [version]'2.1.0'){
    foreach($required21 in @('runtime\templates\PERMISSION_POLICY.json','runtime\templates\OWNER_POLICY.json','runtime\tools\policy-manager.ps1','runtime\tools\scheduler.ps1','runtime\tools\scheduled-run.ps1','runtime\tools\dashboard-control.ps1','runtime\tools\dashboard-control.py','runtime\templates\SCHEDULED_QA.md')){if(-not(Test-Path (Join-Path $pkgRoot $required21))){throw "Downloaded v2.1 package missing: $required21"}}
  }
  $newTerms=(Get-Content (Join-Path $pkgRoot 'TERMS_VERSION') -Raw).Trim()
  $oldTerms=if(Test-Path (Join-Path $installRoot 'TERMS_VERSION')){(Get-Content (Join-Path $installRoot 'TERMS_VERSION') -Raw).Trim()}else{[string]$installed.terms_version}
  if($newTerms -ne $oldTerms){
    if(-not (Show-TermsAcceptance $pkgRoot $newVersion.ToString() $newTerms)){Write-Host 'Update cancelled because updated terms were not accepted.';exit 4}
  } else {
    $confirm=[System.Windows.Forms.MessageBox]::Show("Update Universal Comprehensive QA Gate System from $currentVersion to $newVersion?`r`n`r`nA backup will be created first. Project QA reports, evidence, profile and state will be preserved.",'Confirm QA System Update',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Question)
    if($confirm -ne [System.Windows.Forms.DialogResult]::Yes){Write-Host 'Update cancelled by user.';exit 4}
  }
  $backupRoot=Join-Path $projectRoot '.comprehensive-qa-backups'; New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
  $backup=Join-Path $backupRoot ((Get-Date -Format 'yyyyMMdd_HHmmss')+"-v$currentVersion")
  Copy-Item $installRoot $backup -Recurse -Force

  Copy-Item (Join-Path $pkgRoot 'runtime\AGENT_INSTRUCTIONS.md') (Join-Path $installRoot 'AGENT_INSTRUCTIONS.md') -Force
  Copy-Item (Join-Path $pkgRoot 'runtime\START_HERE.md') (Join-Path $installRoot 'START_HERE.md') -Force
  Copy-Item (Join-Path $pkgRoot 'runtime\OPEN_DASHBOARD.cmd') (Join-Path $installRoot 'OPEN_DASHBOARD.cmd') -Force
  foreach($d in @('gates','templates','agent-guides','dashboard','prompts')){
    $target=Join-Path $installRoot $d
    if(Test-Path $target){Remove-Item $target -Recurse -Force}
    Copy-Item (Join-Path $pkgRoot "runtime\$d") $target -Recurse -Force
  }
  $toolsTarget=Join-Path $installRoot 'tools'
  if(Test-Path $toolsTarget){Remove-Item $toolsTarget -Recurse -Force}
  Copy-Item (Join-Path $pkgRoot 'runtime\tools') $toolsTarget -Recurse -Force
  Copy-Item (Join-Path $pkgRoot 'runtime\config\update.json') (Join-Path $installRoot 'config\update.json') -Force
  $permPolicy=Join-Path $pkgRoot 'runtime\templates\PERMISSION_POLICY.json'
  if(Test-Path $permPolicy){Copy-Item $permPolicy (Join-Path $installRoot 'config\permission-policy.json') -Force}
  foreach($f in @('LICENSE','NOTICE','CREDITS.md','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','TERMS_VERSION','LEGAL_MANIFEST.json')){Copy-Item (Join-Path $pkgRoot $f) (Join-Path $installRoot $f) -Force}

  if($newTerms -ne $oldTerms){
    [ordered]@{
      system='Universal Comprehensive QA Gate System'; package_version=$newVersion.ToString(); terms_version=$newTerms; accepted_at=(Get-Date).ToString('o'); acceptance_method='interactive_windows_gui_update_clickwrap'; accepted_by_human_attestation=$true; acceptance_phrase='I ACCEPT'; creator='Ofir Israeli'; license='MIT'; transmitted_by_updater=$false
    } | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $installRoot 'state\HUMAN_ACCEPTANCE_RECEIPT.json') -Encoding UTF8
  }
  $meta=Get-Content (Join-Path $installRoot 'INSTALLATION.json') -Raw | ConvertFrom-Json
  $meta | Add-Member -NotePropertyName previous_version -NotePropertyValue $currentVersion.ToString() -Force
  $meta.version=$newVersion.ToString()
  $meta.terms_version=$newTerms
  $meta | Add-Member -NotePropertyName updated_at -NotePropertyValue (Get-Date).ToString('o') -Force
  $meta | Add-Member -NotePropertyName last_update_backup -NotePropertyValue $backup -Force
  $meta | Add-Member -NotePropertyName update_repository -NotePropertyValue $repo -Force
  $meta | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $installRoot 'INSTALLATION.json') -Encoding UTF8

  if((Get-ChildItem (Join-Path $installRoot 'gates') -Filter 'GATE-*.md').Count -ne 25){throw 'Post-update validation failed: gate count is not 25.'}
  if($newVersion -ge [version]'2.0.0'){if((Get-ChildItem (Join-Path $installRoot 'gates\lenses') -Filter 'LENS-*.md').Count -ne 9){throw 'Post-update validation failed: reliability lens count is not 9.'};if(-not(Test-Path (Join-Path $installRoot 'gates\reliability.yaml'))){throw 'Post-update validation failed: reliability policy missing.'}}
  if($newVersion -ge [version]'2.1.0'){foreach($r21 in @('templates\PERMISSION_POLICY.json','templates\OWNER_POLICY.json','tools\policy-manager.ps1','tools\scheduler.ps1','tools\scheduled-run.ps1','tools\dashboard-control.ps1','tools\dashboard-control.py','templates\SCHEDULED_QA.md')){if(-not(Test-Path (Join-Path $installRoot $r21))){throw "Post-update validation failed: missing v2.1 control asset: $r21"}};$pm=Join-Path $installRoot 'tools\policy-manager.ps1';if(-not(Test-Path (Join-Path $installRoot 'state\OWNER_POLICY.json'))){& $pm -Operation Get -ProjectPath $projectRoot|Out-Null}}
  foreach($p in @('profile','reports','evidence','artifacts','remediation','dispositions','state')){if(-not(Test-Path (Join-Path $installRoot $p))){throw "Post-update validation failed: preserved directory missing: $p"}}
  $dashRefresh=Join-Path $installRoot 'tools\dashboard-refresh.ps1'; if(Test-Path $dashRefresh){try{& $dashRefresh -ProjectPath $projectRoot|Out-Null;Write-Host 'DASHBOARD_REFRESH_AFTER_UPDATE=PASS'}catch{Write-Host 'DASHBOARD_REFRESH_AFTER_UPDATE=WARNING'}}
  [ordered]@{updated_at=(Get-Date).ToString('o');from=$currentVersion.ToString();to=$newVersion.ToString();release_tag=$tag;backup=$backup;sha256=$actual;status='SUCCESS'} | ConvertTo-Json -Compress | Add-Content (Join-Path $installRoot 'state\UPDATE_HISTORY.jsonl') -Encoding UTF8
  [System.Windows.Forms.MessageBox]::Show("Update completed successfully.`r`n$currentVersion -> $newVersion`r`n`r`nBackup: $backup",'QA System Updated',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
  Write-Host "UPDATE_SUCCESS=$currentVersion->$newVersion"
  Write-Host "BACKUP=$backup"
} catch {
  $msg=$_.Exception.Message
  if($backup -and (Test-Path $backup)){
    try { Restore-Managed $backup; Write-Host 'ROLLBACK_AFTER_FAILURE=PASS' } catch { Write-Host "ROLLBACK_AFTER_FAILURE=FAILED: $($_.Exception.Message)" }
  }
  throw "Update failed: $msg"
} finally {
  if(Test-Path $temp){Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}
}
