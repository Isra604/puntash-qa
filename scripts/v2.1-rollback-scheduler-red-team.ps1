$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$temp=Join-Path ([IO.Path]::GetTempPath()) ('qa-v21-rollback-sched-'+[guid]::NewGuid().ToString('N'))
function Assert([bool]$ok,[string]$name){if(-not$ok){throw "V21_ROLLBACK_SCHED_REDTEAM_FAIL=$name"};Write-Host "V21_ROLLBACK_SCHED_REDTEAM_PASS=$name"}
try{
  $project=Join-Path $temp 'project with spaces';$install=Join-Path $project '.comprehensive-qa';New-Item -ItemType Directory $project -Force|Out-Null;Copy-Item (Join-Path $root 'runtime') $install -Recurse -Force
  $state=Join-Path $install 'state';New-Item -ItemType Directory $state -Force|Out-Null
  $policyTool=Join-Path $install 'tools\policy-manager.ps1';$scheduler=Join-Path $install 'tools\scheduler.ps1';$preflight=Join-Path $install 'tools\prepare-scheduler-for-rollback.ps1'
  $base=(& $policyTool -Operation Get|Out-String)|ConvertFrom-Json
  # AGENT_MANAGED active must block rollback without mutating managed runtime.
  $base.schedule.enabled=$true;$base.schedule.executor_mode='AGENT_MANAGED';$base.schedule.local_time='03:00';$cand=Join-Path $temp 'agent.json';$base|ConvertTo-Json -Depth 20|Set-Content $cand -Encoding UTF8
  & $policyTool -Operation Apply -PolicyJsonPath $cand -OwnerApproved -ApprovalSource manual_cli|Out-Null
  & $scheduler -Operation Apply -OwnerApproved|Out-Null
  & $scheduler -Operation MarkAgentManaged -OwnerApproved -ExternalId 'automation-ext-123'|Out-Null
  $sentinel=Join-Path $install 'AGENT_INSTRUCTIONS.md';$hashBefore=(Get-FileHash $sentinel -Algorithm SHA256).Hash
  $out=(& $preflight -ProjectPath $project 2>&1|Out-String);$rc=$LASTEXITCODE
  Assert ($rc-eq13) 'active_external_schedule_blocks_rollback'
  $blockedReg=Get-Content (Join-Path $state 'SCHEDULER_REGISTRATION.json') -Raw|ConvertFrom-Json
  Assert ([string]$blockedReg.status-eq'NEEDS_PLATFORM_DEACTIVATION' -and [string]$blockedReg.external_id-eq'automation-ext-123') 'external_schedule_block_state_explicit'
  Assert ((Get-FileHash $sentinel -Algorithm SHA256).Hash-eq$hashBefore) 'blocked_preflight_does_not_mutate_managed_runtime'
  # Wrong ID cannot clear external reference.
  $wrong=$false;try{& $scheduler -Operation ConfirmAgentManagedDisabled -OwnerApproved -ExternalId 'wrong-id'|Out-Null}catch{$wrong=$true}
  Assert $wrong 'wrong_external_id_cannot_confirm_deactivation'
  $st=(& $scheduler -Operation Status|Out-String)|ConvertFrom-Json;Assert ([string]$st.registration.status-eq'NEEDS_PLATFORM_DEACTIVATION') 'external_reference_remains_after_wrong_confirmation'
  # Exact ID closes it, then preflight passes.
  & $scheduler -Operation ConfirmAgentManagedDisabled -OwnerApproved -ExternalId 'automation-ext-123'|Out-Null
  $out=(& $preflight -ProjectPath $project 2>&1|Out-String);$rc=$LASTEXITCODE
  Assert ($rc-eq0) 'preflight_passes_after_exact_external_deactivation'
  $afterDeactivate=Get-Content (Join-Path $state 'SCHEDULER_REGISTRATION.json') -Raw|ConvertFrom-Json
  Assert ([string]$afterDeactivate.status-eq'DISABLED') 'preflight_pass_state_is_disabled'
  # Local Task Scheduler registration must be removed by preflight and proven absent.
  $cur=(& $policyTool -Operation Get|Out-String)|ConvertFrom-Json;$cur.schedule.enabled=$true;$cur.schedule.executor_mode='LOCAL_COMMAND';$cur.schedule.executor.command=(Get-Command powershell.exe).Source;$cur.schedule.executor.arguments=@('-NoProfile','-Command','exit 0');$local=Join-Path $temp 'local.json';$cur|ConvertTo-Json -Depth 20|Set-Content $local -Encoding UTF8
  & $policyTool -Operation Apply -PolicyJsonPath $local -OwnerApproved -ApprovalSource manual_cli|Out-Null
  & $scheduler -Operation Apply -OwnerApproved|Out-Null
  $s1=(& $scheduler -Operation Status|Out-String)|ConvertFrom-Json;Assert ($s1.registered-eq$true) 'local_windows_schedule_registered_before_preflight'
  $out=(& $preflight -ProjectPath $project 2>&1|Out-String);$rc=$LASTEXITCODE
  Assert ($rc-eq0) 'local_schedule_removed_and_preflight_passes'
  $s2=(& $scheduler -Operation Status|Out-String)|ConvertFrom-Json;Assert ($s2.registered-eq$false) 'local_windows_schedule_absent_after_preflight'
  # Corrupt registration must not create a false safe result when policy expects local scheduling.
  Set-Content (Join-Path $state 'SCHEDULER_REGISTRATION.json') '{bad-json' -Encoding UTF8
  $out=(& $preflight -ProjectPath $project 2>&1|Out-String);$rc=$LASTEXITCODE
  Assert ($rc-ne0) 'invalid_scheduler_state_fails_closed'
  Write-Host 'V21_ROLLBACK_SCHED_REDTEAM_RESULT=PASS'
  $global:LASTEXITCODE=0
}finally{
  try{
    if(Test-Path $install){$sched=Join-Path $install 'tools\scheduler.ps1';if(Test-Path $sched){& $sched -Operation Remove -OwnerApproved|Out-Null}}
  }catch{}
  if(Test-Path $temp){Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}
}
if($?){exit 0}
