$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$currentVersion=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$temp=Join-Path ([IO.Path]::GetTempPath()) ('qa-v2-upgrade-redteam-'+[guid]::NewGuid().ToString('N'))
function Assert([bool]$ok,[string]$name){if(-not$ok){throw "UPGRADE_REDTEAM_FAIL=$name"};Write-Host "UPGRADE_REDTEAM_PASS=$name"}
try{
  New-Item -ItemType Directory $temp|Out-Null
  $oldZip=Join-Path $temp 'v1.4.0.zip';git -C $root archive --format=zip --output=$oldZip v1.4.0
  if($LASTEXITCODE-ne0){throw 'Cannot archive v1.4.0 tag'}
  $oldPkg=Join-Path $temp 'oldpkg';Expand-Archive $oldZip $oldPkg -Force
  $distRel='.v2-upgrade-redteam-dist';$dist=Join-Path $root $distRel;if(Test-Path $dist){Remove-Item $dist -Recurse -Force};& (Join-Path $root 'scripts\build-release.ps1') -OutputDirectory $distRel|Out-Null
  $v2Zip=Join-Path $dist ("COMPREHENSIVE-QA-GATE-SYSTEM-v$currentVersion.zip");Assert (Test-Path $v2Zip) 'v2 tracked package builds'
  $v2Pkg=Join-Path $temp 'v2pkg';Expand-Archive $v2Zip $v2Pkg -Force
  $project=Join-Path $temp 'project';$install=Join-Path $project '.comprehensive-qa';New-Item -ItemType Directory $install -Force|Out-Null
  Copy-Item (Join-Path $oldPkg 'runtime\*') $install -Recurse -Force
  foreach($d in @('profile','reports','reports\dashboard','evidence','artifacts','remediation','dispositions','state')){New-Item -ItemType Directory (Join-Path $install $d) -Force|Out-Null}
  Set-Content (Join-Path $install 'reports\dashboard\PRESERVE_HISTORY.marker') 'history-v14' -Encoding UTF8
  Set-Content (Join-Path $install 'evidence\PRESERVE_EVIDENCE.marker') 'evidence-v14' -Encoding UTF8
  Set-Content (Join-Path $install 'state\PRESERVE_STATE.marker') 'state-v14' -Encoding UTF8
  Set-Content (Join-Path $install 'profile\PRESERVE_PROFILE.marker') 'profile-v14' -Encoding UTF8
  [ordered]@{version='1.4.0';terms_version='1.0.0';synthetic_layout_test=$true}|ConvertTo-Json|Set-Content (Join-Path $install 'INSTALLATION.json') -Encoding UTF8
  $configHash=(Get-FileHash (Join-Path $install 'config\default.yaml') -Algorithm SHA256).Hash
  $backup=Join-Path $temp 'backup-v1.4.0';Copy-Item $install $backup -Recurse -Force

  # Prove the released v1.4 updater's managed-directory behavior before simulating it.
  $oldUpdater=Get-Content (Join-Path $oldPkg 'runtime\tools\update.ps1') -Raw
  Assert ($oldUpdater.Contains("foreach(`$d in @('gates','templates','agent-guides','dashboard'))")) 'released v1.4 updater replaces managed runtime directories'
  Assert ($oldUpdater.Contains('Copy-Item (Join-Path $pkgRoot "runtime\$d") $target -Recurse -Force')) 'released v1.4 updater recursively copies gates tree'

  # Filesystem-only simulation of the already-released v1.4 updater after human confirmation.
  Copy-Item (Join-Path $v2Pkg 'runtime\AGENT_INSTRUCTIONS.md') (Join-Path $install 'AGENT_INSTRUCTIONS.md') -Force
  Copy-Item (Join-Path $v2Pkg 'runtime\START_HERE.md') (Join-Path $install 'START_HERE.md') -Force
  Copy-Item (Join-Path $v2Pkg 'runtime\OPEN_DASHBOARD.cmd') (Join-Path $install 'OPEN_DASHBOARD.cmd') -Force
  foreach($d in @('gates','templates','agent-guides','dashboard')){$target=Join-Path $install $d;if(Test-Path $target){Remove-Item $target -Recurse -Force};Copy-Item (Join-Path $v2Pkg "runtime\$d") $target -Recurse -Force}
  New-Item -ItemType Directory (Join-Path $install 'tools') -Force|Out-Null;Copy-Item (Join-Path $v2Pkg 'runtime\tools\*') (Join-Path $install 'tools') -Recurse -Force
  Copy-Item (Join-Path $v2Pkg 'runtime\config\update.json') (Join-Path $install 'config\update.json') -Force
  foreach($f in @('LICENSE','NOTICE','CREDITS.md','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','TERMS_VERSION','LEGAL_MANIFEST.json')){Copy-Item (Join-Path $v2Pkg $f) (Join-Path $install $f) -Force}
  $meta=Get-Content (Join-Path $install 'INSTALLATION.json') -Raw|ConvertFrom-Json;$meta.version=$currentVersion;$meta|ConvertTo-Json|Set-Content (Join-Path $install 'INSTALLATION.json') -Encoding UTF8

  Assert ((Get-ChildItem (Join-Path $install 'gates') -Filter 'GATE-*.md').Count-eq25) 'v1.4 to v2 retains exactly 25 gates'
  Assert ((Get-ChildItem (Join-Path $install 'gates\lenses') -Filter 'LENS-*.md').Count-eq9) 'v1.4 updater receives all 9 nested lenses'
  Assert (Test-Path (Join-Path $install 'gates\reliability.yaml')) 'v1.4 updater receives reliability policy'
  Assert (Test-Path (Join-Path $install 'gates\reliability-map.json')) 'v1.4 updater receives reliability map'
  Assert (Test-Path (Join-Path $install 'tools\validate-run.ps1')) 'v1.4 updater receives v2 validator'
  Assert ((Get-Content (Join-Path $install 'reports\dashboard\PRESERVE_HISTORY.marker') -Raw).Trim()-eq'history-v14') 'history preserved during upgrade'
  Assert ((Get-Content (Join-Path $install 'evidence\PRESERVE_EVIDENCE.marker') -Raw).Trim()-eq'evidence-v14') 'evidence preserved during upgrade'
  Assert ((Get-Content (Join-Path $install 'state\PRESERVE_STATE.marker') -Raw).Trim()-eq'state-v14') 'state preserved during upgrade'
  Assert ((Get-FileHash (Join-Path $install 'config\default.yaml') -Algorithm SHA256).Hash-eq$configHash) 'owner config/default preserved by v1.4 updater'
  Assert ((Get-Content (Join-Path $install 'TERMS_VERSION') -Raw).Trim()-eq'1.0.0') 'terms version unchanged across v1.4 to v2'

  # Filesystem-only simulation of current rollback managed restore. No GUI/acceptance bypass is used.
  foreach($d in @('gates','templates','agent-guides','dashboard')){$target=Join-Path $install $d;if(Test-Path $target){Remove-Item $target -Recurse -Force};$source=Join-Path $backup $d;if(Test-Path $source){Copy-Item $source $target -Recurse -Force}}
  $toolsTarget=Join-Path $install 'tools';if(Test-Path $toolsTarget){Remove-Item $toolsTarget -Recurse -Force};$toolsSource=Join-Path $backup 'tools';if(Test-Path $toolsSource){Copy-Item $toolsSource $toolsTarget -Recurse -Force}
  foreach($f in @('AGENT_INSTRUCTIONS.md','START_HERE.md','OPEN_DASHBOARD.cmd','INSTALLATION.json')){$src=Join-Path $backup $f;$dst=Join-Path $install $f;if(Test-Path $src){Copy-Item $src $dst -Force}elseif($f-in@('START_HERE.md','OPEN_DASHBOARD.cmd')-and(Test-Path $dst)){Remove-Item $dst -Force}}
  $uc=Join-Path $backup 'config\update.json';if(Test-Path $uc){Copy-Item $uc (Join-Path $install 'config\update.json') -Force}

  Assert (-not(Test-Path (Join-Path $install 'gates\lenses'))) 'rollback removes v2 lens tree'
  Assert (-not(Test-Path (Join-Path $install 'tools\validate-run.ps1'))) 'rollback removes v2-only validator residue'
  Assert ((Get-Content (Join-Path $install 'INSTALLATION.json') -Raw|ConvertFrom-Json).version-eq'1.4.0') 'rollback restores v1.4 metadata'
  Assert ((Get-Content (Join-Path $install 'reports\dashboard\PRESERVE_HISTORY.marker') -Raw).Trim()-eq'history-v14') 'history survives rollback'
  Assert ((Get-Content (Join-Path $install 'evidence\PRESERVE_EVIDENCE.marker') -Raw).Trim()-eq'evidence-v14') 'evidence survives rollback'
  Assert ((Get-Content (Join-Path $install 'state\PRESERVE_STATE.marker') -Raw).Trim()-eq'state-v14') 'state survives rollback'
  Write-Host 'V2_UPGRADE_REDTEAM_RESULT=PASS'
}finally{if(Test-Path $temp){Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue};$localDist=Join-Path $root '.v2-upgrade-redteam-dist';if(Test-Path $localDist){Remove-Item $localDist -Recurse -Force -ErrorAction SilentlyContinue}}
