$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$temp=Join-Path ([IO.Path]::GetTempPath()) ('puntash-v22-win-final-'+[guid]::NewGuid().ToString('N'))
$proc1=$null;$proc2=$null
function Assert([bool]$Ok,[string]$Name){if(-not$Ok){throw "V22_WIN_FINAL_ADVERSARIAL_FAIL=$Name"};Write-Host "V22_WIN_FINAL_ADVERSARIAL_PASS=$Name"}
function Free-Port {$l=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$l.Start();$p=([Net.IPEndPoint]$l.LocalEndpoint).Port;$l.Stop();return $p}
function Start-Control([string]$Server,[string]$Project,[int]$Port,[string]$Token,[string]$Out,[string]$Err){
  $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName=(Get-Command pwsh).Source;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true
  foreach($a in @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$Server,'-ProjectPath',$Project,'-Port',[string]$Port,'-IdleMinutes','10','-NoBrowser','-ControlToken',$Token)){[void]$psi.ArgumentList.Add($a)}
  $psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$p=[Diagnostics.Process]::Start($psi)
  $base="http://127.0.0.1:$Port/";$ready=$false
  foreach($i in 1..80){Start-Sleep -Milliseconds 150;if($p.HasExited){break};try{$x=Invoke-WebRequest -Uri $base -UseBasicParsing -TimeoutSec 1;if($x.StatusCode-eq200){$ready=$true;break}}catch{}}
  if(-not$ready){$stdout=$p.StandardOutput.ReadToEnd();$stderr=$p.StandardError.ReadToEnd();throw "Control Center failed to start: $stdout $stderr"}
  return [pscustomobject]@{Process=$p;Base=$base;Token=$Token}
}
function Api([string]$Base,[string]$Token,[string]$Path,[string]$Method='GET',$Body=$null,[int]$Expected=200){
  $h=@{'X-QA-Control-Token'=$Token};$args=@{Uri=($Base+$Path);Headers=$h;Method=$Method;TimeoutSec=30}
  if($null-ne$Body){$args.ContentType='application/json';$args.Body=($Body|ConvertTo-Json -Depth 40 -Compress)}
  try{$r=Invoke-WebRequest @args -UseBasicParsing;$code=[int]$r.StatusCode;$content=$r.Content}catch{$code=[int]$_.Exception.Response.StatusCode.value__;$content=[string]$_.ErrorDetails.Message;if([string]::IsNullOrWhiteSpace($content)){try{$content=$_.Exception.Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()}catch{$content=''}}}
  if($code-ne$Expected){throw "API $Method $Path expected $Expected got $code body=$content"}
  if([string]::IsNullOrWhiteSpace($content)){return $null};try{return $content|ConvertFrom-Json}catch{return $content}
}
function Async-Post([string]$Base,[string]$Token,[string]$Path,$Body){
  $json=$Body|ConvertTo-Json -Depth 40 -Compress
  return Start-Job -ArgumentList $Base,$Token,$Path,$json -ScriptBlock {param($b,$t,$p,$j);$h=@{'X-QA-Control-Token'=$t};try{$r=Invoke-WebRequest -Uri ($b+$p) -Headers $h -Method Post -ContentType 'application/json' -Body $j -UseBasicParsing -TimeoutSec 40;[pscustomobject]@{code=[int]$r.StatusCode;body=$r.Content}}catch{[pscustomobject]@{code=[int]$_.Exception.Response.StatusCode.value__;body=''}}}
}
try{
  $project=Join-Path $temp 'project';New-Item -ItemType Directory $project -Force|Out-Null
  git -C $project init -q;git -C $project config user.email 'redteam@example.invalid';git -C $project config user.name 'PUNTASH QA Red Team'
  Set-Content (Join-Path $project 'app.txt') 'baseline' -Encoding UTF8;git -C $project add app.txt;git -C $project commit -q -m baseline;$head=(git -C $project rev-parse HEAD).Trim()
  $install=Join-Path $project '.comprehensive-qa';Copy-Item (Join-Path $root 'runtime') $install -Recurse -Force
  $state=Join-Path $install 'state';$evidence=Join-Path $install 'evidence';$profile=Join-Path $install 'profile';$reports=Join-Path $install 'reports\dashboard';New-Item -ItemType Directory $state,$evidence,$profile,$reports,(Join-Path $project 'docs') -Force|Out-Null
  Copy-Item (Join-Path $root 'TERMS_VERSION') (Join-Path $install 'TERMS_VERSION') -Force;Copy-Item (Join-Path $root 'LEGAL_MANIFEST.json') (Join-Path $install 'LEGAL_MANIFEST.json') -Force
  $legal=(Get-Content (Join-Path $root 'LEGAL_MANIFEST.json') -Raw|ConvertFrom-Json).documents;foreach($x in $legal.PSObject.Properties){Copy-Item (Join-Path $root $x.Name) (Join-Path $install $x.Name) -Force}
  [ordered]@{version='2.2.0';previous_version='2.1.0'}|ConvertTo-Json|Set-Content (Join-Path $install 'INSTALLATION.json') -Encoding UTF8
  [ordered]@{terms_version=(Get-Content (Join-Path $root 'TERMS_VERSION') -Raw).Trim();accepted_by_human_attestation=$true;legal_document_sha256=$legal}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $state 'HUMAN_ACCEPTANCE_RECEIPT.json') -Encoding UTF8
  Set-Content (Join-Path $profile 'PROJECT_QA_PROFILE.md') 'profile' -Encoding UTF8
  $pyExe=(Get-Command python -ErrorAction Stop).Source;$pyFp=(& $pyExe (Join-Path $install 'tools\project-fingerprint.py') $project|Out-String|ConvertFrom-Json);$psFp=(& (Join-Path $install 'tools\project-fingerprint.ps1') -ProjectPath $project|Out-String|ConvertFrom-Json);Assert ($pyFp.ok-eq$true -and $psFp.ok-eq$true -and [string]$pyFp.sha256-eq[string]$psFp.sha256 -and [int64]$pyFp.file_count-eq[int64]$psFp.file_count -and [int64]$pyFp.byte_count-eq[int64]$psFp.byte_count) 'native_python_powershell_project_fingerprint_parity'
  $gates=@();foreach($i in 1..25){$rel=('evidence/GATE-WIN-{0:D2}.txt'-f$i);Set-Content (Join-Path $install ($rel-replace'/','\')) 'gate';$gates+=[ordered]@{gate=$i;status='PASS';assurance='STRONG';summary='Verified';evidence_freshness='CURRENT';evidence_refs=@($rel);lens_impact_reviewed=$false;lens_exception_lenses=@();lens_exception_rationale=''}}
  $lenses=@();foreach($i in 1..9){$rel=('evidence/LENS-WIN-{0:D2}.txt'-f$i);Set-Content (Join-Path $install ($rel-replace'/','\')) 'lens';$lenses+=[ordered]@{lens=$i;status='PASS';assurance='STRONG';applicability_rationale='Applicable';applicability_evidence=@('profile/PROJECT_QA_PROFILE.md');evidence_freshness='CURRENT';evidence_refs=@($rel)}}
  Set-Content (Join-Path $evidence 'TRUST-WIN.txt') 'trust';$completed=(Get-Date).ToString('o');$started=(Get-Date).AddMinutes(-1).ToString('o')
  $run=[ordered]@{schema_version=3;run_id='RUN-WIN-VALID';project=[ordered]@{name='win-redteam';branch='main';head=$head};started_at=$started;completed_at=$completed;summary=[ordered]@{pass=25;fail=0;blocked=0;not_run=0;not_applicable=0};evidence_assurance=[ordered]@{overall='STRONG'};findings_summary=[ordered]@{open=0};gates=$gates;lenses=$lenses;test_trustworthiness=[ordered]@{applicable=$true;status='PASS';assurance='STRONG';evidence_freshness='CURRENT';evidence_refs=@('evidence/TRUST-WIN.txt');decisive_suites=@('critical')};findings=@();changes=[ordered]@{};automatic_remediation=[ordered]@{performed=$false;entries=@()}}
  $run|ConvertTo-Json -Depth 20|Set-Content (Join-Path $reports 'RUN-WIN-VALID.json') -Encoding UTF8
  $policyTool=Join-Path $install 'tools\policy-manager.ps1';$p=(& $policyTool -Operation Get|Out-String)|ConvertFrom-Json;$p.permissions.preset='SAFE_FIXES';$cand=Join-Path $temp 'baseline-policy.json';$p|ConvertTo-Json -Depth 20|Set-Content $cand -Encoding UTF8;& $policyTool -Operation Apply -PolicyJsonPath $cand -OwnerApproved -ApprovalSource manual_cli|Out-Null
  $server=Join-Path $install 'tools\dashboard-control.ps1';$c1=Start-Control $server $project (Free-Port) 'win-final-token-1' (Join-Path $temp 'c1.out') (Join-Path $temp 'c1.err');$proc1=$c1.Process;$c2=Start-Control $server $project (Free-Port) 'win-final-token-2' (Join-Path $temp 'c2.out') (Join-Path $temp 'c2.err');$proc2=$c2.Process
  $ov=Api $c1.Base $c1.Token 'api/overview';Assert ($ov.overview.release_readiness.ready-eq$true -and $ov.overview.project_health.label-eq'Good') 'current_clean_git_run_is_ready_and_good'
  Set-Content (Join-Path $project 'app.txt') 'dirty change' -Encoding UTF8;$ov=Api $c1.Base $c1.Token 'api/overview';Assert ($ov.overview.release_readiness.state-eq'STALE' -and $ov.overview.project_health.label-ne'Good') 'native_dirty_git_state_invalidates_ready_and_good';git -C $project checkout -- app.txt
  $ov=Api $c1.Base $c1.Token 'api/overview';Assert ($ov.overview.release_readiness.ready-eq$true) 'native_clean_restore_restores_readiness'
  Set-Content (Join-Path $evidence 'approval-proof.txt') 'proof';$current=(Api $c1.Base $c1.Token 'api/policy').policy;$req=[ordered]@{request_id='REQ-WIN-RACE';created_at=(Get-Date).ToString('o');policy_revision=$current.policy_revision;finding_id='F-WIN-RACE';risk='LOW';category='documentation';change_summary='Approve this exact documentation request';evidence_refs=@('evidence/approval-proof.txt');target_paths=@('docs/approved.md');expected_behavior_proven=$true;reversible=$true};($req|ConvertTo-Json -Compress)|Set-Content (Join-Path $state 'APPROVAL_REQUESTS.jsonl') -Encoding UTF8
  $q=Api $c1.Base $c1.Token 'api/approvals';$item=@($q.approvals|Where-Object{$_.request_id-eq'REQ-WIN-RACE'})[0];Assert (-not[string]::IsNullOrWhiteSpace([string]$item.request_hash)) 'native_approval_hash_visible'
  $body=[ordered]@{request_id='REQ-WIN-RACE';request_hash=[string]$item.request_hash;decision='APPROVE'};$j1=Async-Post $c1.Base $c1.Token 'api/approval' $body;$j2=Async-Post $c2.Base $c2.Token 'api/approval' $body;Wait-Job $j1,$j2 -Timeout 45|Out-Null;$res=@(Receive-Job $j1;Receive-Job $j2);Remove-Job $j1,$j2 -Force
  $codes=@($res.code|Sort-Object);Assert ($codes.Count-eq2 -and $codes[0]-eq200 -and $codes[1]-eq409) 'native_cross_process_double_approval_exactly_one_wins';$decisions=@(Get-Content (Join-Path $state 'OWNER_APPROVAL_DECISIONS.jsonl')|ForEach-Object{try{$_|ConvertFrom-Json}catch{}}|Where-Object{$_.request_id-eq'REQ-WIN-RACE'});Assert ($decisions.Count-eq1) 'native_cross_process_approval_decision_single_record'
  [ordered]@{status='AGENT_MANAGED_ACTIVE';platform='agent-managed';external_id='external-native-redteam'}|ConvertTo-Json|Set-Content (Join-Path $state 'SCHEDULER_REGISTRATION.json') -Encoding UTF8;Set-Content (Join-Path $state 'OWNER_POLICY.json') '{broken' -Encoding UTF8
  $r=Api $c1.Base $c1.Token 'api/recovery' 'POST' ([ordered]@{action='reset_policy_to_observe_only'}) 409;Assert ($r.policy_safe-eq$true -and $r.error-eq'recovery_scheduler_cleanup_failed') 'native_recovery_does_not_false_claim_external_schedule_removed';$safe=(Api $c1.Base $c1.Token 'api/policy').policy;Assert ($safe.permissions.preset-eq'REPORT_ONLY' -and $safe.schedule.enabled-eq$false) 'native_recovery_partial_failure_leaves_safe_policy'
  [ordered]@{status='DISABLED'}|ConvertTo-Json|Set-Content (Join-Path $state 'SCHEDULER_REGISTRATION.json') -Encoding UTF8
  $sched=Join-Path $install 'tools\scheduler.ps1';$schedBackup=Get-Content (Join-Path $root 'runtime\tools\scheduler.ps1') -Raw
  @'
param([string]$Operation,[switch]$OwnerApproved)
$state=Join-Path (Split-Path -Parent $PSScriptRoot) 'state';$reg=Join-Path $state 'SCHEDULER_REGISTRATION.json';$marker=Join-Path $state 'STUB_APPLY_STARTED'
if($Operation-eq'Apply'){Set-Content $marker '1';Start-Sleep -Milliseconds 900;[ordered]@{status='ACTIVE'}|ConvertTo-Json|Set-Content $reg -Encoding UTF8;Write-Host 'APPLY';return}
if($Operation-eq'Remove'){[ordered]@{status='DISABLED'}|ConvertTo-Json|Set-Content $reg -Encoding UTF8;Write-Host 'REMOVE';return}
if($Operation-eq'Status'){if(Test-Path $reg){Get-Content $reg -Raw}else{'{"status":"DISABLED"}'};return}
throw 'bad operation'
'@|Set-Content $sched -Encoding UTF8
  $p=(Api $c1.Base $c1.Token 'api/policy').policy;$p.schedule.executor_mode='LOCAL_COMMAND';$p.schedule.executor.command=(Get-Command pwsh).Source;$p.schedule.executor.arguments=@('-NoProfile','-Command','exit 0');$p.schedule.enabled=$false
  $cand2=Join-Path $temp 'race-base.json';$p|ConvertTo-Json -Depth 30|Set-Content $cand2 -Encoding UTF8;& $policyTool -Operation Apply -PolicyJsonPath $cand2 -OwnerApproved -ApprovalSource manual_cli|Out-Null;$p=(Api $c1.Base $c1.Token 'api/policy').policy
  $pa=$p|ConvertTo-Json -Depth 30|ConvertFrom-Json;$pa.schedule.enabled=$true;$pb=$p|ConvertTo-Json -Depth 30|ConvertFrom-Json;$pb.schedule.enabled=$false
  $jobA=Async-Post $c1.Base $c1.Token 'api/policy' $pa;foreach($i in 1..100){if(Test-Path (Join-Path $state 'STUB_APPLY_STARTED')){break};Start-Sleep -Milliseconds 30};Assert (Test-Path (Join-Path $state 'STUB_APPLY_STARTED')) 'native_cross_process_policy_race_reaches_apply';$jobB=Async-Post $c2.Base $c2.Token 'api/policy' $pb;Wait-Job $jobA,$jobB -Timeout 45|Out-Null;$ra=@(Receive-Job $jobA;Receive-Job $jobB);Remove-Job $jobA,$jobB -Force
  $final=(Api $c1.Base $c1.Token 'api/policy').policy;$reg=Get-Content (Join-Path $state 'SCHEDULER_REGISTRATION.json') -Raw|ConvertFrom-Json;Assert ($final.schedule.enabled-eq$false -and $reg.status-eq'DISABLED') 'native_cross_process_policy_scheduler_state_consistent'
  [IO.File]::WriteAllText($sched,$schedBackup,(New-Object Text.UTF8Encoding($false)))
  $helper=Join-Path $project 'manual-helper.ps1';Set-Content $helper 'Start-Sleep -Seconds 3; Write-Output scan-ok' -Encoding UTF8;$p=(Api $c1.Base $c1.Token 'api/policy').policy;$p.schedule.enabled=$false;$p.schedule.executor_mode='LOCAL_COMMAND';$p.schedule.executor.command=(Get-Command pwsh).Source;$p.schedule.executor.arguments=@('-NoProfile','-NonInteractive','-File',$helper);$save=Api $c1.Base $c1.Token 'api/policy' 'POST' $p
  $s1=Api $c1.Base $c1.Token 'api/scan-now' 'POST' @{} 202;foreach($i in 1..80){Start-Sleep -Milliseconds 75;$st=Api $c1.Base $c1.Token 'api/scan-status';if([string]$st.scan.last_result-eq'RUNNING'){break}};Assert ([string]$st.scan.last_result-eq'RUNNING') 'native_first_scan_running'
  $blocked=Api $c2.Base $c2.Token 'api/scan-now' 'POST' @{} 409;Assert ($blocked.error-eq'scan_already_running') 'native_second_control_rejects_shared_active_scan';$st2=Api $c2.Base $c2.Token 'api/scan-status';Assert ($st2.active-eq$true -and [string]$st2.scan.last_result-eq'RUNNING') 'native_second_control_sees_shared_active_scan'
  foreach($i in 1..100){Start-Sleep -Milliseconds 75;$st=Api $c1.Base $c1.Token 'api/scan-status';if(-not$st.active){break}};Assert ([string]$st.scan.last_result-eq'SUCCESS') 'native_winning_scan_status_survives_overlap'
  Api $c2.Base $c2.Token 'api/shutdown' 'POST' @{}|Out-Null;$proc2.WaitForExit(10000)|Out-Null;Api $c1.Base $c1.Token 'api/shutdown' 'POST' @{}|Out-Null;$proc1.WaitForExit(10000)|Out-Null
  Write-Host 'V22_WIN_FINAL_ADVERSARIAL_RESULT=PASS'
}finally{
  if($proc2-and-not$proc2.HasExited){try{$proc2.Kill($true)}catch{}};if($proc1-and-not$proc1.HasExited){try{$proc1.Kill($true)}catch{}}
  Get-Job -ErrorAction SilentlyContinue|Remove-Job -Force -ErrorAction SilentlyContinue
  if(Test-Path $temp){Start-Sleep -Milliseconds 300;Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}
}
exit 0
