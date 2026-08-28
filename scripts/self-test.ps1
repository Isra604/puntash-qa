param([switch]$BuildPackage)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$failures=New-Object System.Collections.Generic.List[string]
function Check([bool]$ok,[string]$name){if($ok){Write-Host "PASS: $name"}else{$failures.Add($name);Write-Host "FAIL: $name"}}
$version=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$manifest=Get-Content (Join-Path $root 'manifest.json') -Raw|ConvertFrom-Json
Check ([string]$manifest.version -eq $version) 'VERSION matches manifest.json'
Check ((Get-ChildItem (Join-Path $root 'runtime\gates') -Filter 'GATE-*.md').Count -eq 25) 'exactly 25 gate files'
foreach($i in 1..25){Check (Test-Path (Join-Path $root ('runtime\gates\GATE-{0:D2}.md' -f $i))) ("gate {0:D2} exists" -f $i)}
$lensDir=Join-Path $root 'runtime\gates\lenses'
Check ((Get-ChildItem $lensDir -Filter 'LENS-*.md').Count -eq 9) 'exactly 9 reliability lens files'
foreach($i in 1..9){Check (Test-Path (Join-Path $lensDir ('LENS-{0:D2}.md' -f $i))) ("lens {0:D2} exists" -f $i)}
$relPolicyPath=Join-Path $root 'runtime\gates\reliability.yaml';Check (Test-Path $relPolicyPath) 'reliability policy present'
$relPolicy=if(Test-Path $relPolicyPath){Get-Content $relPolicyPath -Raw}else{''}
foreach($token in @('required_gate_count: 25','required_lens_count: 9','MATERIAL_PASS_FORBIDDEN','PASS_FORBIDDEN','coverage_percentage_is_never_behavioral_proof: true','decisive_automated_test_pass_requires_test_trustworthiness_evaluation: true')){Check ($relPolicy.Contains($token)) ("reliability policy token: $token")}
$gateV2Ok=$true;foreach($i in 1..25){$gt=Get-Content (Join-Path $root ('runtime\gates\GATE-{0:D2}.md' -f $i))-Raw;if($gt -notmatch 'v2 cross-cutting reliability obligations' -or $gt -notmatch 'Evidence-assurance rule'){$gateV2Ok=$false}}
Check $gateV2Ok 'all 25 gates contain v2 reliability obligations'
$lensContractOk=$true;foreach($i in 1..9){$lt=Get-Content (Join-Path $lensDir ('LENS-{0:D2}.md' -f $i))-Raw;if($lt -notmatch 'Applicability decision' -or $lt -notmatch 'Evidence assurance' -or $lt -notmatch 'PASS / FAIL / BLOCKED / NOT_RUN / NOT_APPLICABLE'){$lensContractOk=$false}}
Check $lensContractOk 'all 9 lenses contain applicability/status/assurance contract'
foreach($j in @('manifest.json','LEGAL_MANIFEST.json','runtime\config\update.json')){try{Get-Content (Join-Path $root $j)-Raw|ConvertFrom-Json|Out-Null;Check $true "$j valid JSON"}catch{Check $false "$j valid JSON"}}
$terms=(Get-Content (Join-Path $root 'TERMS_VERSION') -Raw).Trim();Check ([string]$manifest.terms_version -eq $terms) 'Terms version consistency';$defaultCfg=Get-Content (Join-Path $root 'runtime\config\default.yaml') -Raw;Check ($defaultCfg.Contains(('terms_version: '+$terms))) 'default.yaml Terms version consistency';if([version]$version -ge [version]'2.1.0'){Check ($defaultCfg.Contains('authority_source: state/OWNER_POLICY.json') -and $defaultCfg.Contains('legacy_allowed_modes_are_not_authority: true')) 'v2.1 OWNER_POLICY is canonical remediation authority'}
$legalManifest=Get-Content (Join-Path $root 'LEGAL_MANIFEST.json')-Raw|ConvertFrom-Json
Check ([string]$legalManifest.package_version -eq $version) 'LEGAL_MANIFEST package version consistency'
Check ([string]$legalManifest.terms_version -eq $terms) 'LEGAL_MANIFEST terms version consistency'
Check ([string]$legalManifest.line_endings -eq 'LF') 'LEGAL_MANIFEST deterministic LF contract'
$legalOk=$true
foreach($p in $legalManifest.documents.PSObject.Properties){$path=Join-Path $root $p.Name;if(-not(Test-Path $path)){$legalOk=$false;continue};$actual=(Get-FileHash -Algorithm SHA256 $path).Hash.ToUpperInvariant();if($actual -ne ([string]$p.Value).ToUpperInvariant()){$legalOk=$false}}
Check $legalOk 'legal document SHA-256 manifest integrity'
$legalLfOnly=$true;foreach($p in $legalManifest.documents.PSObject.Properties){$bytes=[IO.File]::ReadAllBytes((Join-Path $root $p.Name));for($i=0;$i-lt($bytes.Length-1);$i++){if($bytes[$i]-eq13-and$bytes[$i+1]-eq10){$legalLfOnly=$false;break}}};Check $legalLfOnly 'legal documents contain LF only (no CRLF)'
$psFiles=Get-ChildItem $root -Recurse -Filter '*.ps1' -File|Where-Object{$_.FullName -notmatch '\\.git\\|\\dist\\'}
foreach($p in $psFiles){$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile($p.FullName,[ref]$tokens,[ref]$errors)|Out-Null;Check ($errors.Count -eq 0) ("PowerShell parse: "+(Resolve-Path $p.FullName -Relative))}
$required=@('START_HERE_WINDOWS.cmd','scripts\install-gui.ps1','runtime\START_HERE.md','runtime\tools\qa-doctor.ps1','runtime\tools\qa-doctor.sh','docs\PRODUCT_ROADMAP.md','.github\workflows\qa.yml','scripts\generate-legal-manifest.ps1','.gitattributes')
foreach($r in $required){Check (Test-Path (Join-Path $root $r)) "$r present"}
if([version]$version -ge [version]'2.1.0'){
  $v21=@('runtime\templates\OWNER_POLICY.json','runtime\templates\PERMISSION_POLICY.json','runtime\templates\SCHEDULED_QA.md','runtime\tools\policy-manager.ps1','runtime\tools\policy-manager.py','runtime\tools\policy-manager.sh','runtime\tools\authorize-change.ps1','runtime\tools\path-safety.ps1','runtime\templates\UNTRUSTED_PROJECT_CONTENT.md','scripts\v2.1-final-adversarial-red-team.py','scripts\v2.1-windows-path-safety-red-team.ps1','scripts\v2.1-reproducible-package-red-team.ps1','runtime\tools\authorize-change.py','runtime\tools\authorize-change.sh','runtime\tools\prepare-scheduler-for-rollback.ps1','runtime\tools\scheduler.ps1','runtime\tools\scheduler.py','runtime\tools\scheduler.sh','runtime\tools\scheduled-run.ps1','runtime\tools\scheduled-run.py','runtime\tools\scheduled-run.sh','runtime\tools\dashboard-control.ps1','runtime\tools\dashboard-control.py','runtime\tools\open-dashboard.sh','scripts\v2.1-control-red-team.py','scripts\v2.1-policy-fuzz-red-team.py','scripts\v2.1-runtime-red-team.py','scripts\v2.1-concurrency-red-team.py','scripts\v2.1-upgrade-red-team.ps1','scripts\v2.1-windows-control-red-team.ps1','scripts\v2.1-windows-authorization-red-team.ps1','scripts\v2.1-windows-scheduler-red-team.ps1','scripts\v2.1-rollback-scheduler-red-team.ps1','scripts\v2.1-windows-timeout-red-team.ps1','scripts\v2.1-unix-scheduler-red-team.py','scripts\v2.1-overlap-red-team.py','scripts\v2.1-target-scope-red-team.py','scripts\v2.1-portable-timeout-red-team.py','docs\AUTOMATION_AND_PERMISSIONS.md')
  foreach($r in $v21){Check (Test-Path (Join-Path $root $r)) "v2.1 asset: $r"}
  $permA=(Get-FileHash (Join-Path $root 'runtime\config\permission-policy.json') -Algorithm SHA256).Hash;$permB=(Get-FileHash (Join-Path $root 'runtime\templates\PERMISSION_POLICY.json') -Algorithm SHA256).Hash;Check ($permA-eq$permB) 'v2.1 permission policy compatibility copy matches canonical config';$promptA=(Get-FileHash (Join-Path $root 'runtime\prompts\SCHEDULED_QA.md') -Algorithm SHA256).Hash;$promptB=(Get-FileHash (Join-Path $root 'runtime\templates\SCHEDULED_QA.md') -Algorithm SHA256).Hash;Check ($promptA-eq$promptB) 'v2.1 scheduled prompt compatibility copy matches canonical prompt'
  $agent=Get-Content (Join-Path $root 'runtime\AGENT_INSTRUCTIONS.md') -Raw;Check ($agent.Contains('authorize-change')) 'agent contract requires mechanical change authorization'
Check ($agent.Contains('Instruction firewall for untrusted project content') -and $agent.Contains('UNTRUSTED_PROJECT_CONTENT.md')) 'agent instruction firewall contract'
$runTemplate=Get-Content (Join-Path $root 'runtime\templates\DASHBOARD_RUN.json') -Raw|ConvertFrom-Json;Check ([int]$runTemplate.schema_version -ge 3 -and $null-ne$runTemplate.automatic_remediation) 'schema-v3 remediation accounting contract'
  $dash=Get-Content (Join-Path $root 'runtime\dashboard\index.html') -Raw;if([version]$version -lt [version]'2.2.0'){Check ($dash.Contains('Agent permissions') -and $dash.Contains('Scheduled QA') -and $dash.Contains('QA Control Center')) 'dashboard v2.1 control UI present';Check ($dash.Contains('openAuthenticatedReport') -and $dash.Contains('X-QA-Control-Token')) 'dashboard authenticated report control present'}else{Check ($dash.Contains('SCAN NOW') -and $dash.Contains('Permissions') -and $dash.Contains('Automatic scans') -and $dash.Contains('Recovery Center') -and $dash.Contains('Ask PUNTASH')) 'dashboard v2.2 human control UI present';Check ($dash.Contains('/api/evidence') -and $dash.Contains('/api/approval') -and $dash.Contains('X-QA-Control-Token')) 'dashboard v2.2 authenticated control surface present'}
}
if([version]$version -ge [version]'2.2.0'){
  $v22=@('runtime\templates\MANUAL_QA.md','runtime\prompts\MANUAL_QA.md','runtime\tools\manual-run.ps1','runtime\tools\manual-run.py','runtime\tools\manual-run.sh','scripts\v2.2-dashboard-red-team.py','scripts\v2.2-windows-dashboard-red-team.ps1','scripts\v2.2-upgrade-red-team.ps1','docs\V2_2_DASHBOARD_CAPABILITY_MATRIX.md','docs\V2_2_DASHBOARD_CHECKPOINT.json','docs\PUNTASH_QA_DASHBOARD_RELEASE_MASTER_PLAN.md')
  foreach($r in $v22){Check (Test-Path (Join-Path $root $r)) "v2.2 dashboard asset: $r"}
  $manualA=(Get-FileHash (Join-Path $root 'runtime\prompts\MANUAL_QA.md') -Algorithm SHA256).Hash;$manualB=(Get-FileHash (Join-Path $root 'runtime\templates\MANUAL_QA.md') -Algorithm SHA256).Hash;Check ($manualA-eq$manualB) 'v2.2 manual prompt compatibility copy matches canonical prompt'
}
$guideCount=(Get-ChildItem (Join-Path $root 'runtime\agent-guides') -Filter '*.md' -File).Count;Check ($guideCount -ge 5) 'agent quick guides present'
$update=Get-Content (Join-Path $root 'runtime\config\update.json')-Raw|ConvertFrom-Json;Check ($update.current_visibility -eq 'public') 'public update channel retained'
$tracked=git -C $root ls-files
$secretRegex='gh[op]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
$secretHit=$false
foreach($rel in $tracked){$p=Join-Path $root $rel;if(Test-Path $p -PathType Leaf){try{$txt=Get-Content $p -Raw -ErrorAction Stop;if($txt -match $secretRegex){$secretHit=$true;Write-Host "SECRET_SIGNATURE_HIT=$rel"}}catch{}}}
Check (-not $secretHit) 'no common secret signatures in tracked text files'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('qa-doctor-selftest-'+[guid]::NewGuid().ToString('N'))
try{New-Item -ItemType Directory $temp|Out-Null;& (Join-Path $root 'runtime\tools\qa-doctor.ps1') -ProjectPath $root -OutputDirectory $temp|Out-Host;Check (Test-Path (Join-Path $temp 'QA_DOCTOR.json')) 'QA Doctor produces JSON';$d=Get-Content (Join-Path $temp 'QA_DOCTOR.json')-Raw|ConvertFrom-Json;Check ($d.status -eq 'READY_FOR_AGENT_DISCOVERY') 'QA Doctor status contract';Check ($d.schema_version -eq 2 -and $d.doctor_version -eq '2.0') 'QA Doctor v2 contract';Check (@($d.reliability_lens_hints.PSObject.Properties).Count -eq 9) 'QA Doctor emits 9 reliability hints'}finally{if(Test-Path $temp){Remove-Item $temp -Recurse -Force}}

$validatorRequired=@('runtime\tools\validate-run.ps1','runtime\tools\validate-run.py','runtime\tools\validate-run.sh','runtime\gates\reliability-map.json','scripts\v2-red-team.py')
foreach($r in $validatorRequired){Check (Test-Path (Join-Path $root $r)) "$r present"}
$runTemp=Join-Path ([IO.Path]::GetTempPath()) ('qa-v3-run-validator-'+[guid]::NewGuid().ToString('N'))
try{
 New-Item $runTemp -ItemType Directory|Out-Null;$vi=Join-Path $runTemp '.comprehensive-qa';New-Item (Join-Path $vi 'tools'),(Join-Path $vi 'gates'),(Join-Path $vi 'state'),(Join-Path $vi 'evidence'),(Join-Path $vi 'profile') -ItemType Directory -Force|Out-Null
 Copy-Item (Join-Path $root 'runtime\tools\validate-run.ps1') (Join-Path $vi 'tools\validate-run.ps1');Copy-Item (Join-Path $root 'runtime\gates\reliability-map.json') (Join-Path $vi 'gates\reliability-map.json')
 'profile'|Set-Content (Join-Path $vi 'profile\PROJECT_QA_PROFILE.md') -Encoding UTF8
 $gates=@();foreach($i in 1..25){$ep=('evidence/GATE-{0:D2}.txt'-f$i);'gate'|Set-Content (Join-Path $vi ($ep-replace'/','\')) -Encoding UTF8;$gates+=[ordered]@{gate=$i;status='PASS';assurance='STRONG';summary='self-test';evidence_freshness='CURRENT';evidence_refs=@($ep);lens_impact_reviewed=$false;lens_exception_lenses=@();lens_exception_rationale=''}}
 $lenses=@();foreach($i in 1..9){$ep=('evidence/LENS-{0:D2}.txt'-f$i);'lens'|Set-Content (Join-Path $vi ($ep-replace'/','\')) -Encoding UTF8;$lenses+=[ordered]@{lens=$i;status='PASS';assurance='STRONG';applicability_rationale='self-test applicable';applicability_evidence=@('profile/PROJECT_QA_PROFILE.md');evidence_freshness='CURRENT';evidence_refs=@($ep)}}
 'trust'|Set-Content (Join-Path $vi 'evidence\test-trust.txt') -Encoding UTF8
 $base=[ordered]@{schema_version=3;run_id='SELFTEST';project=[ordered]@{name='self';branch='main';head='abc'};started_at='2026-08-28T10:00:00+00:00';completed_at='2026-08-28T10:30:00+00:00';summary=[ordered]@{pass=25;fail=0;blocked=0;not_run=0;not_applicable=0};evidence_assurance=[ordered]@{overall='STRONG'};findings_summary=[ordered]@{open=0};gates=$gates;lenses=$lenses;test_trustworthiness=[ordered]@{applicable=$true;status='PASS';assurance='STRONG';evidence_freshness='CURRENT';evidence_refs=@('evidence/test-trust.txt');decisive_suites=@('critical')};findings=@();changes=[ordered]@{};automatic_remediation=[ordered]@{performed=$false;entries=@()}}
 $valid=Join-Path $runTemp 'valid.json';$base|ConvertTo-Json -Depth 14|Set-Content $valid -Encoding UTF8;$validator=Join-Path $vi 'tools\validate-run.ps1'
 & pwsh -NoProfile -File $validator -RunPath $valid|Out-Null;Check ($LASTEXITCODE -eq 0) 'run validator accepts valid schema-v3 25+9 STRONG run with real evidence'
 $bad=Get-Content $valid -Raw|ConvertFrom-Json;$bad.gates[0].assurance='WEAK';$badPath=Join-Path $runTemp 'bad-weak.json';$bad|ConvertTo-Json -Depth 14|Set-Content $badPath -Encoding UTF8;& pwsh -NoProfile -File $validator -RunPath $badPath|Out-Null;Check ($LASTEXITCODE -ne 0) 'run validator rejects PASS with WEAK evidence'
 $bad=Get-Content $valid -Raw|ConvertFrom-Json;$bad.gates[0].assurance='MODERATE';$badPath=Join-Path $runTemp 'bad-moderate.json';$bad|ConvertTo-Json -Depth 14|Set-Content $badPath -Encoding UTF8;& pwsh -NoProfile -File $validator -RunPath $badPath|Out-Null;Check ($LASTEXITCODE -ne 0) 'run validator rejects MODERATE PASS without non-material gap attestation'
 $bad=Get-Content $valid -Raw|ConvertFrom-Json;$bad.lenses[1].status='BLOCKED';$bad.lenses[1]|Add-Member -NotePropertyName reason -NotePropertyValue 'tool missing' -Force;$badPath=Join-Path $runTemp 'bad-g25.json';$bad|ConvertTo-Json -Depth 14|Set-Content $badPath -Encoding UTF8;& pwsh -NoProfile -File $validator -RunPath $badPath|Out-Null;Check ($LASTEXITCODE -ne 0) 'run validator rejects GATE-25 PASS with unresolved lens'
 $bad=Get-Content $valid -Raw|ConvertFrom-Json;$bad.gates[0].evidence_refs=@('evidence/missing.txt');$badPath=Join-Path $runTemp 'bad-missing-evidence.json';$bad|ConvertTo-Json -Depth 14|Set-Content $badPath -Encoding UTF8;& pwsh -NoProfile -File $validator -RunPath $badPath|Out-Null;Check ($LASTEXITCODE -ne 0) 'run validator rejects named-only missing evidence'
}finally{if(Test-Path $runTemp){Remove-Item $runTemp -Recurse -Force}}

if([version]$version -ge [version]'2.1.0'){
  $pyCmd=Get-Command python -ErrorAction SilentlyContinue
  if($pyCmd){
    foreach($rt in @('v2.1-control-red-team.py','v2.1-policy-fuzz-red-team.py','v2.1-runtime-red-team.py','v2.1-concurrency-red-team.py','v2.1-final-adversarial-red-team.py','v2.1-target-scope-red-team.py','v2.1-overlap-red-team.py')){
      & $pyCmd.Source (Join-Path $root ('scripts\'+$rt))|Out-Host;Check ($LASTEXITCODE-eq0) ("v2.1 red-team: $rt")
    }
  }else{Check $false 'Python required by CI for v2.1 cross-platform red-team'}
}
if([version]$version -ge [version]'2.2.0'){
  $pyCmd=Get-Command python -ErrorAction SilentlyContinue
  if($pyCmd){& $pyCmd.Source (Join-Path $root 'scripts\v2.2-dashboard-red-team.py')|Out-Host;Check ($LASTEXITCODE-eq0) 'v2.2 portable Dashboard red-team'}else{Check $false 'Python required by v2.2 Dashboard red-team'}
}

$dashRequired=@('runtime\dashboard\index.html','runtime\dashboard\data.js','runtime\templates\DASHBOARD_RUN.json','runtime\OPEN_DASHBOARD.cmd','runtime\tools\dashboard-refresh.ps1','runtime\tools\dashboard-refresh.sh','runtime\tools\open-dashboard.ps1','docs\DASHBOARD.md')
foreach($r in $dashRequired){Check (Test-Path (Join-Path $root $r)) "$r present"}
$dashHtml=Get-Content (Join-Path $root 'runtime\dashboard\index.html') -Raw
if([version]$version -lt [version]'2.2.0'){$uiTokens=@('Needs attention','Health trend','25 gate map','What changed','Run history','Local only · no telemetry','Reliability assurance','9 cross-cutting lenses','function renderLenses','function showLens')}else{$uiTokens=@('SCAN NOW','What changed','Activity timeline','Observe only','Fix safe things','More active protection','Automatic scans','Approval requests','Project health over time','Ready to release?','Recovery Center','Ask PUNTASH','Settings & about','Overview','Details','Local only · no telemetry')};foreach($token in $uiTokens){Check ($dashHtml.Contains($token)) ("dashboard UI token: $token")}
if(Get-Command node -ErrorAction SilentlyContinue){
  $matches=[regex]::Matches($dashHtml,'(?s)<script>(.*?)</script>')
  $js=if($matches.Count){$matches[$matches.Count-1].Groups[1].Value}else{''}
  $jsTemp=Join-Path ([IO.Path]::GetTempPath()) ('qa-dashboard-js-'+[guid]::NewGuid().ToString('N')+'.js')
  try{Set-Content $jsTemp $js -Encoding UTF8;& node --check $jsTemp 2>$null|Out-Null;Check ($LASTEXITCODE -eq 0) 'dashboard JavaScript syntax'}finally{Remove-Item $jsTemp -Force -ErrorAction SilentlyContinue}
}
$dashTemp=Join-Path ([IO.Path]::GetTempPath()) ('qa-dashboard-selftest-'+[guid]::NewGuid().ToString('N'))
try{
  $installed=Join-Path $dashTemp '.comprehensive-qa';New-Item -ItemType Directory $installed -Force|Out-Null;Copy-Item (Join-Path $root 'runtime\*') $installed -Recurse -Force
  [ordered]@{version=$version}|ConvertTo-Json|Set-Content (Join-Path $installed 'INSTALLATION.json') -Encoding UTF8
  $runDir=Join-Path $installed 'reports\dashboard';New-Item -ItemType Directory $runDir -Force|Out-Null
  $r1=[ordered]@{schema_version=1;run_id='RUN-1';project=[ordered]@{name='Demo';branch='main';head='11111111'};completed_at='2026-08-25T10:00:00Z';summary=[ordered]@{pass=18;fail=3;blocked=2;not_run=1;not_applicable=1};findings_summary=[ordered]@{open=5;critical=0;high=1;medium=2;low=2;resolved_this_run=0;new_this_run=5};gates=@();findings=@();changes=[ordered]@{new_findings=@();resolved_findings=@();gate_changes=@();notes=@()}}
  $r2=[ordered]@{schema_version=1;run_id='RUN-2';project=[ordered]@{name='Demo';branch='main';head='22222222'};completed_at='2026-08-26T10:00:00Z';summary=[ordered]@{pass=21;fail=1;blocked=1;not_run=1;not_applicable=1};findings_summary=[ordered]@{open=2;critical=0;high=0;medium=1;low=1;resolved_this_run=3;new_this_run=0};gates=@();findings=@();changes=[ordered]@{new_findings=@();resolved_findings=@('UQ-1','UQ-2','UQ-3');gate_changes=@();notes=@()}}
  $r1|ConvertTo-Json -Depth 10|Set-Content (Join-Path $runDir 'RUN-1.json') -Encoding UTF8;$r2|ConvertTo-Json -Depth 10|Set-Content (Join-Path $runDir 'RUN-2.json') -Encoding UTF8
  & (Join-Path $installed 'tools\dashboard-refresh.ps1') -ProjectPath $dashTemp|Out-Null
  $data=Get-Content (Join-Path $installed 'dashboard\data.js') -Raw
  Check ($data -match 'RUN-1' -and $data -match 'RUN-2') 'Dashboard renders structured history'
  Check ($data.IndexOf('RUN-2') -lt $data.IndexOf('RUN-1')) 'Dashboard history sorted newest first'
}finally{if(Test-Path $dashTemp){Remove-Item $dashTemp -Recurse -Force}}


$brandManifest=Get-Content (Join-Path $root 'manifest.json') -Raw|ConvertFrom-Json
Check ($brandManifest.name -eq 'puntash-qa' -and $brandManifest.display_name -eq 'PUNTASH QA' -and $brandManifest.subtitle -eq 'Universal Comprehensive QA Gate System') 'PUNTASH QA branding identity'
Check ($brandManifest.project_install_dir -eq '.comprehensive-qa') 'stable internal install path remains .comprehensive-qa'
Check ($brandManifest.updates.repository -eq 'Isra604/puntash-qa') 'PUNTASH QA update repository identity'
$dashBrand=Get-Content (Join-Path $root 'runtime/dashboard/index.html') -Raw
Check ($dashBrand -match '<title>PUNTASH QA Dashboard</title>' -and $dashBrand -match '>PUNTASH<' -and $dashBrand -match '>QA</span>') 'PUNTASH QA dashboard branding'
$buildScript=Get-Content (Join-Path $root 'scripts/build-release.ps1') -Raw
Check ($buildScript -match 'PUNTASH-QA-v\$version\.zip') 'PUNTASH QA release artifact naming'
$legacyRepo='Isra604/'+'comprehensive'+'-qa-gate-system'
Check (-not (git -C $root grep -I -F $legacyRepo -- . 2>$null)) 'legacy repository slug absent from tracked content'
if($BuildPackage){& (Join-Path $root 'scripts\build-release.ps1') -OutputDirectory '.selftest-dist'|Out-Host;$zip=Join-Path $root ".selftest-dist\PUNTASH-QA-v$version.zip";Check (Test-Path $zip) 'release ZIP builds';if(Test-Path $zip){Add-Type -AssemblyName System.IO.Compression.FileSystem;$z=[IO.Compression.ZipFile]::OpenRead($zip);try{$names=@($z.Entries.FullName);Check (@($names|Where-Object{$_ -match '^runtime/gates/GATE-\d\d\.md$'}).Count -eq 25) 'release ZIP contains 25 gates';Check ($names -contains 'runtime/tools/qa-doctor.ps1') 'release ZIP contains QA Doctor';Check ($names -contains 'START_HERE_WINDOWS.cmd') 'release ZIP contains Easy Start launcher';Check ($names -contains 'runtime/dashboard/index.html') 'release ZIP contains Dashboard';Check ($names -contains 'runtime/tools/dashboard-refresh.ps1') 'release ZIP contains Dashboard refresh tool';Check (@($names|Where-Object{$_ -match '^runtime/gates/lenses/LENS-\d\d\.md$'}).Count -eq 9) 'release ZIP contains 9 reliability lenses';Check ($names -contains 'runtime/gates/reliability.yaml') 'release ZIP contains reliability policy';Check ($names -contains 'runtime/tools/validate-run.ps1') 'release ZIP contains run validator';if([version]$version-ge[version]'2.1.0'){Check ($names -contains 'runtime/tools/dashboard-control.ps1') 'release ZIP contains Windows Control Center';Check ($names -contains 'runtime/tools/dashboard-control.py') 'release ZIP contains portable Control Center';Check ($names -contains 'runtime/tools/authorize-change.py') 'release ZIP contains change authorization engine';Check ($names -contains 'runtime/tools/prepare-scheduler-for-rollback.ps1') 'release ZIP contains rollback scheduler preflight';Check ($names -contains 'runtime/templates/PERMISSION_POLICY.json') 'release ZIP contains v2.0-updater compatible permission policy';Check ($names -contains 'runtime/templates/SCHEDULED_QA.md') 'release ZIP contains v2.0-updater compatible scheduled prompt'};if([version]$version-ge[version]'2.2.0'){Check ($names -contains 'runtime/tools/manual-run.ps1') 'release ZIP contains Windows manual scan runner';Check ($names -contains 'runtime/tools/manual-run.py') 'release ZIP contains portable manual scan runner';Check ($names -contains 'runtime/templates/MANUAL_QA.md') 'release ZIP contains manual QA prompt'}}finally{$z.Dispose()}};Remove-Item (Join-Path $root '.selftest-dist') -Recurse -Force -ErrorAction SilentlyContinue}
if($failures.Count){Write-Host "SELF_TEST_RESULT=FAIL COUNT=$($failures.Count)";foreach($f in $failures){Write-Host "FAILED=$f"};exit 1}
Write-Host 'SELF_TEST_RESULT=PASS'
