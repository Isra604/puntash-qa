$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$temp=Join-Path ([IO.Path]::GetTempPath()) ('qa-v21-upgrade-redteam-'+[guid]::NewGuid().ToString('N'))
function Assert([bool]$ok,[string]$name){if(-not $ok){throw "V21_UPGRADE_REDTEAM_FAIL=$name"};Write-Host "V21_UPGRADE_REDTEAM_PASS=$name"}
try {
 New-Item -ItemType Directory $temp|Out-Null
 $oldZip=Join-Path $temp 'v2.0.0.zip';git -C $root archive --format=zip --output=$oldZip v2.0.0;if($LASTEXITCODE-ne0){throw 'Cannot archive v2.0.0'}
 $oldPkg=Join-Path $temp 'oldpkg';Expand-Archive $oldZip $oldPkg -Force
 $oldUpdater=Get-Content (Join-Path $oldPkg 'runtime\tools\update.ps1') -Raw
 Assert ($oldUpdater.Contains("foreach(`$d in @('gates','templates','agent-guides','dashboard'))")) 'released v2.0 updater managed tree contract detected'
 Assert ($oldUpdater -match "runtime\\tools.*toolsTarget.*Recurse.*Force") 'released v2.0 updater replaces tools recursively'
 $project=Join-Path $temp 'project';$install=Join-Path $project '.comprehensive-qa';New-Item -ItemType Directory $install -Force|Out-Null
 Copy-Item (Join-Path $oldPkg 'runtime\*') $install -Recurse -Force
 foreach($d in @('profile','reports','reports\dashboard','evidence','artifacts','remediation','dispositions','state')){New-Item -ItemType Directory (Join-Path $install $d) -Force|Out-Null}
 [ordered]@{version='2.0.0';terms_version='1.0.0';project_path=$project}|ConvertTo-Json|Set-Content (Join-Path $install 'INSTALLATION.json') -Encoding UTF8
 Set-Content (Join-Path $install 'state\HUMAN_ACCEPTANCE_RECEIPT.json') '{"accepted_by_human_attestation":true}' -Encoding UTF8
 Set-Content (Join-Path $install 'reports\PRESERVE_REPORT.marker') 'report' -Encoding UTF8
 Set-Content (Join-Path $install 'evidence\PRESERVE_EVIDENCE.marker') 'evidence' -Encoding UTF8
 $defaultHash=(Get-FileHash (Join-Path $install 'config\default.yaml') -Algorithm SHA256).Hash
 $backup=Join-Path $temp 'backup-v2.0.0';Copy-Item $install $backup -Recurse -Force
 # Simulate only paths the released v2.0 updater knows how to copy.
 foreach($f in @('AGENT_INSTRUCTIONS.md','START_HERE.md','OPEN_DASHBOARD.cmd')){Copy-Item (Join-Path $root "runtime\$f") (Join-Path $install $f) -Force}
 foreach($d in @('gates','templates','agent-guides','dashboard')){$target=Join-Path $install $d;if(Test-Path $target){Remove-Item $target -Recurse -Force};Copy-Item (Join-Path $root "runtime\$d") $target -Recurse -Force}
 $tools=Join-Path $install 'tools';if(Test-Path $tools){Remove-Item $tools -Recurse -Force};Copy-Item (Join-Path $root 'runtime\tools') $tools -Recurse -Force
 Copy-Item (Join-Path $root 'runtime\config\update.json') (Join-Path $install 'config\update.json') -Force
 Assert (-not(Test-Path (Join-Path $install 'config\permission-policy.json'))) 'test proves released v2.0 updater does not copy new config file'
 Assert (-not(Test-Path (Join-Path $install 'prompts'))) 'test proves released v2.0 updater does not copy new prompts tree'
 Assert (Test-Path (Join-Path $install 'templates\PERMISSION_POLICY.json')) 'permission policy compatibility copy arrives via templates'
 Assert (Test-Path (Join-Path $install 'templates\SCHEDULED_QA.md')) 'scheduled prompt compatibility copy arrives via templates'
 Assert (Test-Path (Join-Path $install 'tools\dashboard-control.ps1')) 'control center arrives via tools'
 Assert (Test-Path (Join-Path $install 'tools\scheduler.ps1')) 'scheduler arrives via tools'
 & (Join-Path $install 'tools\dashboard-refresh.ps1') -ProjectPath $project|Out-Null
 $owner=Get-Content (Join-Path $install 'state\OWNER_POLICY.json') -Raw|ConvertFrom-Json
 Assert (-not $owner.configured -and $owner.permissions.preset-eq'REPORT_ONLY' -and -not $owner.schedule.enabled) 'direct upgrade initializes safe owner policy without inventing choice'
 & (Join-Path $install 'tools\policy-manager.ps1') -Operation Get -ProjectPath $project|Out-Null
 Assert ($true) 'policy manager works through compatibility permission policy fallback'
 Assert ((Get-FileHash (Join-Path $install 'config\default.yaml') -Algorithm SHA256).Hash-eq$defaultHash) 'owner default config preserved'
 Assert ((Get-Content (Join-Path $install 'reports\PRESERVE_REPORT.marker') -Raw).Trim()-eq'report') 'reports preserved'
 Assert ((Get-Content (Join-Path $install 'evidence\PRESERVE_EVIDENCE.marker') -Raw).Trim()-eq'evidence') 'evidence preserved'
 # Configure an owner policy, then prove rollback filesystem leaves owner choice/history but removes v2.1 managed assets.
 $candidate=Get-Content (Join-Path $install 'state\OWNER_POLICY.json') -Raw|ConvertFrom-Json;$candidate.permissions.preset='SAFE_FIXES';$cand=Join-Path $temp 'candidate.json';$candidate|ConvertTo-Json -Depth 12|Set-Content $cand -Encoding UTF8
 & (Join-Path $install 'tools\policy-manager.ps1') -Operation Apply -PolicyJsonPath $cand -OwnerApproved -ApprovalSource manual_cli -ProjectPath $project|Out-Null
 Assert ((Get-Content (Join-Path $install 'state\OWNER_POLICY.json') -Raw|ConvertFrom-Json).permissions.preset-eq'SAFE_FIXES') 'owner choice persisted before rollback'
 Assert (Test-Path (Join-Path $install 'state\OWNER_POLICY_HISTORY.jsonl')) 'owner policy audit history exists'
 # Current rollback's managed restore model. State is intentionally not replaced except legal receipt.
 foreach($d in @('gates','templates','agent-guides','dashboard','prompts')){$target=Join-Path $install $d;if(Test-Path $target){Remove-Item $target -Recurse -Force};$source=Join-Path $backup $d;if(Test-Path $source){Copy-Item $source $target -Recurse -Force}}
 $toolsTarget=Join-Path $install 'tools';if(Test-Path $toolsTarget){Remove-Item $toolsTarget -Recurse -Force};Copy-Item (Join-Path $backup 'tools') $toolsTarget -Recurse -Force
 $pc=Join-Path $backup 'config\permission-policy.json';$pct=Join-Path $install 'config\permission-policy.json';if(Test-Path $pc){Copy-Item $pc $pct -Force}elseif(Test-Path $pct){Remove-Item $pct -Force}
 Assert ((Get-Content (Join-Path $install 'state\OWNER_POLICY.json') -Raw|ConvertFrom-Json).permissions.preset-eq'SAFE_FIXES') 'owner policy survives rollback'
 Assert (Test-Path (Join-Path $install 'state\OWNER_POLICY_HISTORY.jsonl')) 'owner policy history survives rollback'
 Assert (-not(Test-Path (Join-Path $install 'tools\scheduler.ps1'))) 'v2.1 scheduler tool removed when rolling back to v2.0'
 Assert (-not(Test-Path (Join-Path $install 'templates\PERMISSION_POLICY.json'))) 'v2.1 compatibility policy removed with managed templates rollback'
 Write-Host 'V21_UPGRADE_REDTEAM_RESULT=PASS'
} finally {if(Test-Path $temp){Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}}
