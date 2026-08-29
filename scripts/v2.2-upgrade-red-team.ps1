$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$currentVersion=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
if([version]$currentVersion -lt [version]'2.2.0'){throw 'v2.2 upgrade red-team requires VERSION >= 2.2.0'}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('qa-v22-upgrade-redteam-'+[guid]::NewGuid().ToString('N'))
function Assert([bool]$ok,[string]$name){if(-not$ok){throw "V22_UPGRADE_REDTEAM_FAIL=$name"};Write-Host "V22_UPGRADE_REDTEAM_PASS=$name"}
try{
  New-Item -ItemType Directory $temp|Out-Null
  $oldZip=Join-Path $temp 'v2.1.0.zip';git -C $root archive --format=zip --output=$oldZip v2.1.0;if($LASTEXITCODE-ne0){throw 'Cannot archive v2.1.0'}
  $oldPkg=Join-Path $temp 'oldpkg';Expand-Archive $oldZip $oldPkg -Force
  $project=Join-Path $temp 'project';$install=Join-Path $project '.comprehensive-qa';New-Item -ItemType Directory $install -Force|Out-Null
  Copy-Item (Join-Path $oldPkg 'runtime\*') $install -Recurse -Force
  foreach($f in @('LICENSE','NOTICE','CREDITS.md','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','TERMS_VERSION','LEGAL_MANIFEST.json')){Copy-Item (Join-Path $oldPkg $f) (Join-Path $install $f) -Force}
  foreach($d in @('profile','reports','reports\dashboard','evidence','artifacts','remediation','dispositions','state')){New-Item -ItemType Directory (Join-Path $install $d) -Force|Out-Null}
  Copy-Item (Join-Path $install 'templates\OWNER_POLICY.json') (Join-Path $install 'state\OWNER_POLICY.json') -Force
  [ordered]@{version='2.1.0';terms_version='1.1.0';project_path=$project}|ConvertTo-Json|Set-Content (Join-Path $install 'INSTALLATION.json') -Encoding UTF8
  Set-Content (Join-Path $install 'reports\PRESERVE_REPORT.marker') 'report-v21' -Encoding UTF8
  Set-Content (Join-Path $install 'evidence\PRESERVE_EVIDENCE.marker') 'evidence-v21' -Encoding UTF8
  Set-Content (Join-Path $install 'state\PRESERVE_STATE.marker') 'state-v21' -Encoding UTF8
  $backup=Join-Path $temp 'backup-v2.1.0';Copy-Item $install $backup -Recurse -Force

  # Simulate the released v2.1 updater managed-path contract after human approval.
  foreach($f in @('AGENT_INSTRUCTIONS.md','START_HERE.md','OPEN_DASHBOARD.cmd')){Copy-Item (Join-Path $root "runtime\$f") (Join-Path $install $f) -Force}
  foreach($d in @('gates','templates','agent-guides','dashboard','prompts')){$target=Join-Path $install $d;if(Test-Path $target){Remove-Item $target -Recurse -Force};Copy-Item (Join-Path $root "runtime\$d") $target -Recurse -Force}
  $tools=Join-Path $install 'tools';if(Test-Path $tools){Remove-Item $tools -Recurse -Force};Copy-Item (Join-Path $root 'runtime\tools') $tools -Recurse -Force
  Copy-Item (Join-Path $root 'runtime\config\update.json') (Join-Path $install 'config\update.json') -Force
  Copy-Item (Join-Path $root 'runtime\templates\PERMISSION_POLICY.json') (Join-Path $install 'config\permission-policy.json') -Force
  foreach($f in @('LICENSE','NOTICE','CREDITS.md','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','TERMS_VERSION','LEGAL_MANIFEST.json')){Copy-Item (Join-Path $root $f) (Join-Path $install $f) -Force}
  $meta=Get-Content (Join-Path $install 'INSTALLATION.json') -Raw|ConvertFrom-Json;$meta|Add-Member previous_version '2.1.0' -Force;$meta.version=$currentVersion;$meta|ConvertTo-Json -Depth 8|Set-Content (Join-Path $install 'INSTALLATION.json') -Encoding UTF8

  Assert (Test-Path (Join-Path $install 'tools\manual-run.ps1')) 'v21 updater receives Windows manual runner'
  Assert (Test-Path (Join-Path $install 'tools\manual-run.py')) 'v21 updater receives portable manual runner'
  Assert (Test-Path (Join-Path $install 'tools\project-fingerprint.ps1')) 'v21 updater receives Windows project fingerprint helper'
  Assert (Test-Path (Join-Path $install 'tools\project-fingerprint.py')) 'v21 updater receives portable project fingerprint helper'
  Assert (Test-Path (Join-Path $install 'tools\project-fingerprint.sh')) 'v21 updater receives shell project fingerprint wrapper'
  Assert (Test-Path (Join-Path $install 'templates\MANUAL_QA.md')) 'v21 updater receives manual prompt compatibility copy'
  Assert (Test-Path (Join-Path $install 'prompts\MANUAL_QA.md')) 'v21 updater receives canonical manual prompt'
  Assert ((Get-Content (Join-Path $install 'reports\PRESERVE_REPORT.marker') -Raw).Trim()-eq'report-v21') 'reports preserved across v21 to v22'
  Assert ((Get-Content (Join-Path $install 'evidence\PRESERVE_EVIDENCE.marker') -Raw).Trim()-eq'evidence-v21') 'evidence preserved across v21 to v22'
  Assert ((Get-Content (Join-Path $install 'state\PRESERVE_STATE.marker') -Raw).Trim()-eq'state-v21') 'state preserved across v21 to v22'
  Assert (((Get-Content (Join-Path $install 'TERMS_VERSION') -Raw).Trim()) -eq '1.1.0') 'v22 keeps Terms 1.1.0 so no synthetic renewed acceptance is required'
  & (Join-Path $install 'tools\policy-manager.ps1') -Operation Get -ProjectPath $project|Out-Null;Assert $true 'v21 owner policy remains readable after v22 upgrade'

  # Roll back managed paths to v2.1 and prove v2.2-only assets leave no residue.
  foreach($d in @('gates','templates','agent-guides','dashboard','prompts')){$target=Join-Path $install $d;if(Test-Path $target){Remove-Item $target -Recurse -Force};$source=Join-Path $backup $d;if(Test-Path $source){Copy-Item $source $target -Recurse -Force}}
  $toolsTarget=Join-Path $install 'tools';if(Test-Path $toolsTarget){Remove-Item $toolsTarget -Recurse -Force};Copy-Item (Join-Path $backup 'tools') $toolsTarget -Recurse -Force
  foreach($f in @('AGENT_INSTRUCTIONS.md','START_HERE.md','OPEN_DASHBOARD.cmd','INSTALLATION.json','LEGAL_MANIFEST.json')){$src=Join-Path $backup $f;$dst=Join-Path $install $f;if(Test-Path $src){Copy-Item $src $dst -Force}}
  Assert (-not(Test-Path (Join-Path $install 'tools\manual-run.ps1'))) 'rollback removes v22 Windows manual runner'
  Assert (-not(Test-Path (Join-Path $install 'tools\manual-run.py'))) 'rollback removes v22 portable manual runner'
  Assert (-not(Test-Path (Join-Path $install 'tools\project-fingerprint.ps1'))) 'rollback removes v22 Windows project fingerprint helper'
  Assert (-not(Test-Path (Join-Path $install 'tools\project-fingerprint.py'))) 'rollback removes v22 portable project fingerprint helper'
  Assert (-not(Test-Path (Join-Path $install 'tools\project-fingerprint.sh'))) 'rollback removes v22 shell project fingerprint wrapper'
  Assert (-not(Test-Path (Join-Path $install 'templates\MANUAL_QA.md'))) 'rollback removes v22 manual prompt template'
  Assert ((Get-Content (Join-Path $install 'reports\PRESERVE_REPORT.marker') -Raw).Trim()-eq'report-v21') 'reports survive v22 rollback'
  Assert ((Get-Content (Join-Path $install 'state\PRESERVE_STATE.marker') -Raw).Trim()-eq'state-v21') 'state survives v22 rollback'
  Write-Host 'V22_UPGRADE_REDTEAM_RESULT=PASS'
} finally {if(Test-Path $temp){Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}}
