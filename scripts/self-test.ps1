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
$terms=(Get-Content (Join-Path $root 'TERMS_VERSION') -Raw).Trim();Check ([string]$manifest.terms_version -eq $terms) 'Terms version consistency'
$legalManifest=Get-Content (Join-Path $root 'LEGAL_MANIFEST.json')-Raw|ConvertFrom-Json
Check ([string]$legalManifest.package_version -eq $version) 'LEGAL_MANIFEST package version consistency'
Check ([string]$legalManifest.terms_version -eq $terms) 'LEGAL_MANIFEST terms version consistency'
Check ([string]$legalManifest.line_endings -eq 'LF') 'LEGAL_MANIFEST deterministic LF contract'
$legalOk=$true
foreach($p in $legalManifest.documents.PSObject.Properties){$path=Join-Path $root $p.Name;if(-not(Test-Path $path)){$legalOk=$false;continue};$actual=(Get-FileHash -Algorithm SHA256 $path).Hash.ToUpperInvariant();if($actual -ne ([string]$p.Value).ToUpperInvariant()){$legalOk=$false}}
Check $legalOk 'legal document SHA-256 manifest integrity'
$psFiles=Get-ChildItem $root -Recurse -Filter '*.ps1' -File|Where-Object{$_.FullName -notmatch '\\.git\\|\\dist\\'}
foreach($p in $psFiles){$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile($p.FullName,[ref]$tokens,[ref]$errors)|Out-Null;Check ($errors.Count -eq 0) ("PowerShell parse: "+(Resolve-Path $p.FullName -Relative))}
$required=@('START_HERE_WINDOWS.cmd','scripts\install-gui.ps1','runtime\START_HERE.md','runtime\tools\qa-doctor.ps1','runtime\tools\qa-doctor.sh','docs\PRODUCT_ROADMAP.md','.github\workflows\qa.yml','scripts\generate-legal-manifest.ps1','.gitattributes')
foreach($r in $required){Check (Test-Path (Join-Path $root $r)) "$r present"}
if([version]$version -ge [version]'2.1.0'){
  $v21=@('runtime\templates\OWNER_POLICY.json','runtime\templates\PERMISSION_POLICY.json','runtime\templates\SCHEDULED_QA.md','runtime\tools\policy-manager.ps1','runtime\tools\policy-manager.py','runtime\tools\policy-manager.sh','runtime\tools\authorize-change.ps1','runtime\tools\authorize-change.py','runtime\tools\authorize-change.sh','runtime\tools\scheduler.ps1','runtime\tools\scheduler.py','runtime\tools\scheduler.sh','runtime\tools\scheduled-run.ps1','runtime\tools\scheduled-run.py','runtime\tools\scheduled-run.sh','runtime\tools\dashboard-control.ps1','runtime\tools\dashboard-control.py','runtime\tools\open-dashboard.sh','scripts\v2.1-control-red-team.py','scripts\v2.1-upgrade-red-team.ps1')
  foreach($r in $v21){Check (Test-Path (Join-Path $root $r)) "v2.1 asset: $r"}
  $permA=(Get-FileHash (Join-Path $root 'runtime\config\permission-policy.json') -Algorithm SHA256).Hash;$permB=(Get-FileHash (Join-Path $root 'runtime\templates\PERMISSION_POLICY.json') -Algorithm SHA256).Hash;Check ($permA-eq$permB) 'v2.1 permission policy compatibility copy matches canonical config'
  $agent=Get-Content (Join-Path $root 'runtime\AGENT_INSTRUCTIONS.md') -Raw;Check ($agent.Contains('authorize-change')) 'agent contract requires mechanical change authorization'
  $dash=Get-Content (Join-Path $root 'runtime\dashboard\index.html') -Raw;Check ($dash.Contains('Agent permissions') -and $dash.Contains('Scheduled QA') -and $dash.Contains('QA Control Center')) 'dashboard v2.1 control UI present'
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
$runTemp=Join-Path ([IO.Path]::GetTempPath()) ('qa-v2-run-validator-'+[guid]::NewGuid().ToString('N'))
try{
 New-Item $runTemp -ItemType Directory|Out-Null
 $gates=@();foreach($i in 1..25){$gates+=[ordered]@{gate=$i;status='PASS';assurance='STRONG';summary='self-test';evidence_freshness='CURRENT';evidence_refs=@(('evidence/GATE-{0:D2}.txt'-f$i));lens_impact_reviewed=$false;lens_exception_lenses=@();lens_exception_rationale=''}}
 $lenses=@();foreach($i in 1..9){$lenses+=[ordered]@{lens=$i;status='PASS';assurance='STRONG';applicability_rationale='self-test applicable';applicability_evidence=@('profile/PROJECT_QA_PROFILE.md');evidence_freshness='CURRENT';evidence_refs=@(('evidence/LENS-{0:D2}.txt'-f$i))}}
 $base=[ordered]@{schema_version=2;run_id='SELFTEST';project=[ordered]@{name='self';branch='main';head='abc'};completed_at=(Get-Date).ToString('o');summary=[ordered]@{pass=25;fail=0;blocked=0;not_run=0;not_applicable=0};evidence_assurance=[ordered]@{overall='STRONG'};findings_summary=[ordered]@{open=0};gates=$gates;lenses=$lenses;test_trustworthiness=[ordered]@{applicable=$true;status='PASS';assurance='STRONG';evidence_freshness='CURRENT';evidence_refs=@('evidence/LENS-01/test-trust.txt');decisive_suites=@('critical')};findings=@();changes=[ordered]@{lens_changes=@()}}
 $valid=Join-Path $runTemp 'valid.json';$base|ConvertTo-Json -Depth 12|Set-Content $valid -Encoding UTF8
 & pwsh -NoProfile -File (Join-Path $root 'runtime\tools\validate-run.ps1') -RunPath $valid|Out-Null;Check ($LASTEXITCODE -eq 0) 'run validator accepts valid 25+9 STRONG run'
 $bad=Get-Content $valid -Raw|ConvertFrom-Json;$bad.gates[0].assurance='WEAK';$badPath=Join-Path $runTemp 'bad-weak.json';$bad|ConvertTo-Json -Depth 12|Set-Content $badPath -Encoding UTF8;& pwsh -NoProfile -File (Join-Path $root 'runtime\tools\validate-run.ps1') -RunPath $badPath|Out-Null;Check ($LASTEXITCODE -ne 0) 'run validator rejects PASS with WEAK evidence'
 $bad=Get-Content $valid -Raw|ConvertFrom-Json;$bad.gates[0].assurance='MODERATE';$badPath=Join-Path $runTemp 'bad-moderate.json';$bad|ConvertTo-Json -Depth 12|Set-Content $badPath -Encoding UTF8;& pwsh -NoProfile -File (Join-Path $root 'runtime\tools\validate-run.ps1') -RunPath $badPath|Out-Null;Check ($LASTEXITCODE -ne 0) 'run validator rejects MODERATE PASS without non-material gap attestation'
 $bad=Get-Content $valid -Raw|ConvertFrom-Json;$bad.lenses[1].status='BLOCKED';$bad.lenses[1]|Add-Member -NotePropertyName reason -NotePropertyValue 'tool missing' -Force;$badPath=Join-Path $runTemp 'bad-g25.json';$bad|ConvertTo-Json -Depth 12|Set-Content $badPath -Encoding UTF8;& pwsh -NoProfile -File (Join-Path $root 'runtime\tools\validate-run.ps1') -RunPath $badPath|Out-Null;Check ($LASTEXITCODE -ne 0) 'run validator rejects GATE-25 PASS with unresolved lens'
}finally{if(Test-Path $runTemp){Remove-Item $runTemp -Recurse -Force}}

if([version]$version -ge [version]'2.1.0'){
  $pyCmd=Get-Command python -ErrorAction SilentlyContinue
  if($pyCmd){& $pyCmd.Source (Join-Path $root 'scripts\v2.1-control-red-team.py')|Out-Host;Check ($LASTEXITCODE-eq0) 'v2.1 control/permission red-team'}else{Check $false 'Python required by CI for v2.1 cross-platform red-team'}
}

$dashRequired=@('runtime\dashboard\index.html','runtime\dashboard\data.js','runtime\templates\DASHBOARD_RUN.json','runtime\OPEN_DASHBOARD.cmd','runtime\tools\dashboard-refresh.ps1','runtime\tools\dashboard-refresh.sh','runtime\tools\open-dashboard.ps1','docs\DASHBOARD.md')
foreach($r in $dashRequired){Check (Test-Path (Join-Path $root $r)) "$r present"}
$dashHtml=Get-Content (Join-Path $root 'runtime\dashboard\index.html') -Raw
foreach($token in @('Needs attention','Health trend','25 gate map','What changed','Run history','Local only · no telemetry','Reliability assurance','9 cross-cutting lenses','function renderLenses','function showLens')){Check ($dashHtml.Contains($token)) ("dashboard UI token: $token")}
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

if($BuildPackage){& (Join-Path $root 'scripts\build-release.ps1') -OutputDirectory '.selftest-dist'|Out-Host;$zip=Join-Path $root ".selftest-dist\COMPREHENSIVE-QA-GATE-SYSTEM-v$version.zip";Check (Test-Path $zip) 'release ZIP builds';if(Test-Path $zip){Add-Type -AssemblyName System.IO.Compression.FileSystem;$z=[IO.Compression.ZipFile]::OpenRead($zip);try{$names=@($z.Entries.FullName);Check (@($names|Where-Object{$_ -match '^runtime/gates/GATE-\d\d\.md$'}).Count -eq 25) 'release ZIP contains 25 gates';Check ($names -contains 'runtime/tools/qa-doctor.ps1') 'release ZIP contains QA Doctor';Check ($names -contains 'START_HERE_WINDOWS.cmd') 'release ZIP contains Easy Start launcher';Check ($names -contains 'runtime/dashboard/index.html') 'release ZIP contains Dashboard';Check ($names -contains 'runtime/tools/dashboard-refresh.ps1') 'release ZIP contains Dashboard refresh tool';Check (@($names|Where-Object{$_ -match '^runtime/gates/lenses/LENS-\d\d\.md$'}).Count -eq 9) 'release ZIP contains 9 reliability lenses';Check ($names -contains 'runtime/gates/reliability.yaml') 'release ZIP contains reliability policy';Check ($names -contains 'runtime/tools/validate-run.ps1') 'release ZIP contains run validator';if([version]$version-ge[version]'2.1.0'){Check ($names -contains 'runtime/tools/dashboard-control.ps1') 'release ZIP contains Windows Control Center';Check ($names -contains 'runtime/tools/dashboard-control.py') 'release ZIP contains portable Control Center';Check ($names -contains 'runtime/tools/authorize-change.py') 'release ZIP contains change authorization engine';Check ($names -contains 'runtime/templates/PERMISSION_POLICY.json') 'release ZIP contains v2.0-updater compatible permission policy';Check ($names -contains 'runtime/templates/SCHEDULED_QA.md') 'release ZIP contains v2.0-updater compatible scheduled prompt'}}finally{$z.Dispose()}};Remove-Item (Join-Path $root '.selftest-dist') -Recurse -Force -ErrorAction SilentlyContinue}
if($failures.Count){Write-Host "SELF_TEST_RESULT=FAIL COUNT=$($failures.Count)";foreach($f in $failures){Write-Host "FAILED=$f"};exit 1}
Write-Host 'SELF_TEST_RESULT=PASS'
