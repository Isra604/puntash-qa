$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$temp=Join-Path ([IO.Path]::GetTempPath()) ('qa v21 win control '+[guid]::NewGuid().ToString('N'))
function Assert([bool]$ok,[string]$name){if(-not $ok){throw "V21_WIN_CONTROL_REDTEAM_FAIL=$name"};Write-Host "V21_WIN_CONTROL_REDTEAM_PASS=$name"}
$proc=$null
try{
  $project=Join-Path $temp 'project';$install=Join-Path $project '.comprehensive-qa';New-Item -ItemType Directory $project -Force|Out-Null;Copy-Item (Join-Path $root 'runtime') $install -Recurse -Force
  $state=Join-Path $install 'state';$reports=Join-Path $install 'reports';New-Item -ItemType Directory $state,$reports -Force|Out-Null
  Copy-Item (Join-Path $root 'TERMS_VERSION') (Join-Path $install 'TERMS_VERSION') -Force
  Copy-Item (Join-Path $root 'LEGAL_MANIFEST.json') (Join-Path $install 'LEGAL_MANIFEST.json') -Force
  $fixtureLegal=(Get-Content (Join-Path $root 'LEGAL_MANIFEST.json') -Raw|ConvertFrom-Json).documents;foreach($prop in $fixtureLegal.PSObject.Properties){Copy-Item (Join-Path $root $prop.Name) (Join-Path $install $prop.Name) -Force}
  Set-Content (Join-Path $reports 'redteam-report.md') '# report' -Encoding UTF8;Set-Content (Join-Path $state 'sensitive.txt') 'local-sensitive-state' -Encoding UTF8
  $probe=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$probe.Start();$port=([Net.IPEndPoint]$probe.LocalEndpoint).Port;$probe.Stop()
  $token='windows-redteam-token';$out=Join-Path $temp 'server.out';$err=Join-Path $temp 'server.err';$server=Join-Path $install 'tools\dashboard-control.ps1'
  $args="-NoProfile -ExecutionPolicy Bypass -File `"$server`" -ProjectPath `"$project`" -Port $port -IdleMinutes 2 -NoBrowser -ControlToken `"$token`""
  $proc=Start-Process powershell.exe -ArgumentList $args -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
  $base="http://127.0.0.1:$port/";$ready=$false
  foreach($i in 1..40){Start-Sleep -Milliseconds 250;try{$r=Invoke-WebRequest -Uri $base -UseBasicParsing -TimeoutSec 1;if($r.StatusCode-eq200){$ready=$true;break}}catch{}}
  Assert $ready 'server_loopback_ready'
  try{Invoke-RestMethod -Uri ($base+'api/policy') -Method Get -TimeoutSec 2|Out-Null;throw 'unauthorized API allowed'}catch{Assert ($_.Exception.Response.StatusCode.value__ -eq 403) 'missing_token_denied'}
  try{Invoke-WebRequest -Uri ($base+'state/sensitive.txt') -UseBasicParsing -TimeoutSec 2|Out-Null;throw 'state file served'}catch{Assert ($_.Exception.Response.StatusCode.value__ -eq 404) 'static_state_denied'}
  try{Invoke-WebRequest -Uri ($base+'data.js') -UseBasicParsing -TimeoutSec 2|Out-Null;throw 'dashboard data served publicly'}catch{Assert ($_.Exception.Response.StatusCode.value__ -eq 404) 'static_dashboard_data_denied'}
  try{Invoke-RestMethod -Uri ($base+'api/dashboard-data') -TimeoutSec 2|Out-Null;throw 'dashboard data API unauthenticated'}catch{Assert ($_.Exception.Response.StatusCode.value__ -eq 403) 'dashboard_data_requires_token'}
  $headers=@{'X-QA-Control-Token'=$token}
  $dashboardData=Invoke-RestMethod -Uri ($base+'api/dashboard-data') -Headers $headers -TimeoutSec 2;Assert ($dashboardData.ok-eq$true -and $null-ne$dashboardData.data) 'authenticated_dashboard_data_allowed'
  $policy=Invoke-RestMethod -Uri ($base+'api/policy') -Headers $headers -TimeoutSec 2;Assert ($policy.ok-eq$true) 'valid_token_policy_read'
  $candidate=$policy.policy;$candidate.permissions.preset='SAFE_FIXES';$candidate.schedule.enabled=$false;$body=$candidate|ConvertTo-Json -Depth 20
  $saved=Invoke-RestMethod -Uri ($base+'api/policy') -Method Post -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 20;Assert ($saved.ok-eq$true -and $saved.policy.permissions.preset-eq'SAFE_FIXES') 'owner_policy_mutation_through_control_api'
  Assert (Test-Path (Join-Path $state 'OWNER_POLICY_HISTORY.jsonl')) 'control_api_policy_audit_history'
  try{Invoke-WebRequest -Uri ($base+'api/report?path=redteam-report.md') -UseBasicParsing -TimeoutSec 2|Out-Null;throw 'report API unauthenticated'}catch{Assert ($_.Exception.Response.StatusCode.value__ -eq 403) 'report_requires_token'}
  $rep=Invoke-WebRequest -Uri ($base+'api/report?path=redteam-report.md') -Headers $headers -UseBasicParsing -TimeoutSec 2;Assert ($rep.Content -match 'report') 'authenticated_report_allowed'
  foreach($bad in @('../state/sensitive.txt','reports/../state/sensitive.txt','%2e%2e/state/sensitive.txt')){try{Invoke-WebRequest -Uri ($base+'api/report?path='+$bad) -Headers $headers -UseBasicParsing -TimeoutSec 2|Out-Null;throw 'report traversal allowed'}catch{Assert ($_.Exception.Response.StatusCode.value__ -eq 404) ('report_traversal_denied_'+($bad-replace'[^A-Za-z0-9]','_'))}}
  # Native scheduled runner validates current human acceptance and prunes old logs.
  $terms=(Get-Content (Join-Path $install 'TERMS_VERSION') -Raw).Trim();$legalDocs=(Get-Content (Join-Path $install 'LEGAL_MANIFEST.json') -Raw|ConvertFrom-Json).documents
  $receiptPath=Join-Path $state 'HUMAN_ACCEPTANCE_RECEIPT.json'
  $badHashes=[ordered]@{};foreach($prop in $legalDocs.PSObject.Properties){$badHashes[$prop.Name]=$prop.Value};$badHashes['TERMS_OF_USE.md']='0'*64
  [ordered]@{terms_version=$terms;accepted_by_human_attestation=$true;legal_document_sha256=$badHashes}|ConvertTo-Json -Depth 8|Set-Content $receiptPath -Encoding UTF8
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $install 'tools\scheduled-run.ps1') -ProjectPath $project|Out-Null;Assert ($LASTEXITCODE-eq5) 'windows_scheduled_runner_rejects_legal_hash_mismatch'
  [ordered]@{terms_version=$terms;accepted_by_human_attestation=$true;acceptance_method='interactive_windows_gui_update_clickwrap';package_version='2.1.0'}|ConvertTo-Json -Depth 8|Set-Content $receiptPath -Encoding UTF8
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $install 'tools\scheduled-run.ps1') -ProjectPath $project|Out-Null;Assert ($LASTEXITCODE-eq5) 'windows_scheduled_runner_rejects_hashless_nonlegacy_receipt'
  [ordered]@{version='2.1.0';previous_version='2.0.0';terms_version=$terms}|ConvertTo-Json|Set-Content (Join-Path $install 'INSTALLATION.json') -Encoding UTF8
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $install 'tools\scheduled-run.ps1') -ProjectPath $project|Out-Null;Assert ($LASTEXITCODE-eq0) 'windows_scheduled_runner_accepts_recognized_legacy_updater_receipt'
  [ordered]@{terms_version=$terms;accepted_by_human_attestation=$true;legal_document_sha256=$legalDocs}|ConvertTo-Json -Depth 8|Set-Content $receiptPath -Encoding UTF8
  Set-Content (Join-Path $state 'OWNER_POLICY.json') '{bad-json' -Encoding UTF8;& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $install 'tools\scheduled-run.ps1') -ProjectPath $project|Out-Null;Assert ($LASTEXITCODE-eq6) 'windows_scheduled_runner_rejects_malformed_policy'
  $recovered=Invoke-RestMethod -Uri ($base+'api/policy') -Method Post -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 20;Assert ($recovered.ok-eq$true -and $recovered.policy.permissions.preset-eq'SAFE_FIXES') 'windows_owner_policy_recovery_via_control_api'
  $helper=Join-Path $project 'scheduled helper.py';Set-Content $helper 'import sys;print("ARG="+sys.argv[1]);print("Q="+sys.argv[2]);print("B="+sys.argv[3])' -Encoding UTF8;$python=(Get-Command python.exe -ErrorAction Stop).Source;$pol=$recovered.policy;$pol.schedule.enabled=$true;$pol.schedule.executor_mode='LOCAL_COMMAND';$pol.schedule.executor.command=$python;$pol.schedule.executor.arguments=@($helper,'{project}','contains"quote','ends-with-backslash\');$pol.schedule.executor.timeout_minutes=5;$pol.schedule.executor.log_retention_days=30;$schedBody=$pol|ConvertTo-Json -Depth 20;$scheduledPolicy=Invoke-RestMethod -Uri ($base+'api/policy') -Method Post -Headers $headers -ContentType 'application/json' -Body $schedBody -TimeoutSec 20;Assert ($scheduledPolicy.ok-eq$true) 'windows_owner_policy_schedule_apply_after_recovery'
  $logDir=Join-Path $state 'scheduler\logs';New-Item -ItemType Directory $logDir -Force|Out-Null;$oldLog=Join-Path $logDir 'SCHEDULED-old.stdout.log';Set-Content $oldLog old;$x=Get-Item $oldLog;$x.LastWriteTime=(Get-Date).AddDays(-40)
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $install 'tools\scheduled-run.ps1') -ProjectPath $project|Out-Null;Assert ($LASTEXITCODE-eq0) 'windows_scheduled_runner_success';$status=Get-Content (Join-Path $state 'SCHEDULER_STATUS.json') -Raw|ConvertFrom-Json;$outText=(Get-Content $status.stdout -Raw).Trim();Assert ($outText -match [regex]::Escape('ARG='+$project)) 'windows_executor_arguments_preserve_spaces';Assert ($outText -match [regex]::Escape('Q=contains"quote')) 'windows_executor_arguments_preserve_quotes';Assert ($outText -match [regex]::Escape('B=ends-with-backslash\')) 'windows_executor_arguments_preserve_trailing_backslash';Assert (-not(Test-Path $oldLog)) 'windows_scheduled_log_retention'
  Invoke-RestMethod -Uri ($base+'api/shutdown') -Method Post -Headers $headers -TimeoutSec 10|Out-Null;$proc.WaitForExit(10000)|Out-Null;Assert $proc.HasExited 'clean_shutdown'
  Write-Host 'V21_WIN_CONTROL_REDTEAM_RESULT=PASS'
}finally{if($proc -and -not $proc.HasExited){try{$proc.Kill()}catch{}};if(Test-Path $temp){Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}}
