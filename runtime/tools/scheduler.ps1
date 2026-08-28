param(
    [ValidateSet('Status','Apply','Remove','MarkAgentManaged','ConfirmAgentManagedDisabled')]
    [string]$Operation = 'Status',
    [switch]$OwnerApproved,
    [string]$ExternalId
)

$ErrorActionPreference = 'Stop'
$installRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $installRoot
$stateDir = Join-Path $installRoot 'state'
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$registrationPath = Join-Path $stateDir 'SCHEDULER_REGISTRATION.json'
$policyTool = Join-Path $PSScriptRoot 'policy-manager.ps1'

function Get-TaskName {
    $bytes = [Text.Encoding]::UTF8.GetBytes($projectRoot.ToLowerInvariant())
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').Substring(0, 12) }
    finally { $sha.Dispose() }
    return "ComprehensiveQA-$hash"
}
function Hash-Text([string]$text) {
    $bytes=[Text.Encoding]::UTF8.GetBytes($text);$sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Get-ScheduleSignature($schedule) {
    $material=[ordered]@{enabled=[bool]$schedule.enabled;frequency=[string]$schedule.frequency;local_time=[string]$schedule.local_time;days_of_week=@($schedule.days_of_week);timezone_mode=[string]$schedule.timezone_mode;executor_mode=[string]$schedule.executor_mode}
    return (Hash-Text ($material|ConvertTo-Json -Depth 6 -Compress)).Substring(0,20)
}
function Write-JsonAtomic([string]$Path,$Value,[int]$Depth=10) {
    $dir=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $dir -PathType Container)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
    $token=[guid]::NewGuid().ToString('N')
    $tmp=Join-Path $dir ((Split-Path -Leaf $Path)+'.tmp.'+$token)
    $backup=Join-Path $dir ((Split-Path -Leaf $Path)+'.bak.'+$token)
    $json=($Value|ConvertTo-Json -Depth $Depth).Replace("`r`n","`n").Replace("`r","`n")+"`n"
    [IO.File]::WriteAllText($tmp,$json,(New-Object Text.UTF8Encoding($false)))
    try {
        if(Test-Path -LiteralPath $Path){[IO.File]::Replace($tmp,$Path,$backup,$true);Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue}
        else {
            try{[IO.File]::Move($tmp,$Path)}catch{if(Test-Path -LiteralPath $Path){[IO.File]::Replace($tmp,$Path,$backup,$true);Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue}else{throw}}
        }
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
    }
}

function Save-Registration([string]$Status,[string]$Message,[hashtable]$Extra=@{}) {
    $platform=if($Extra.ContainsKey('platform')){[string]$Extra['platform']}else{'windows'}
    $record=[ordered]@{updated_at=(Get-Date).ToString('o');status=$Status;message=$Message;task_name=$taskName;platform=$platform}
    foreach($key in $Extra.Keys){if($key-ne'platform'){$record[$key]=$Extra[$key]}}
    Write-JsonAtomic -Path $registrationPath -Value $record -Depth 10
    return [pscustomobject]$record
}
function Load-Registration {
    if(-not(Test-Path $registrationPath -PathType Leaf)){return $null}
    try{return (Get-Content $registrationPath -Raw|ConvertFrom-Json)}catch{return [pscustomobject]@{status='REGISTRATION_STATE_INVALID';message='Scheduler registration state is invalid JSON.'}}
}
function Get-ValidatedPolicy {
    $raw=& $policyTool -Operation Get | Out-String
    if(-not$raw){throw 'OWNER_POLICY validation returned no data.'}
    return ($raw|ConvertFrom-Json)
}
function Ensure-TaskSchedulerAvailable {
    if(-not(Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)){throw 'Windows Task Scheduler cmdlets are unavailable.'}
}
function Get-LocalTaskState {
    Ensure-TaskSchedulerAvailable
    try{$task=Get-ScheduledTask -TaskName $taskName -ErrorAction Stop;return [pscustomobject]@{exists=$true;error=$null;task=$task}}
    catch{
        if($_.FullyQualifiedErrorId -match 'NoMatchingMSFTScheduledTask|ObjectNotFound' -or $_.Exception.Message -match 'No MSFT_ScheduledTask objects found'){return [pscustomobject]@{exists=$false;error=$null;task=$null}}
        return [pscustomobject]@{exists=$false;error=$_.Exception.Message;task=$null}
    }
}
function Remove-LocalTask {
    Ensure-TaskSchedulerAvailable
    $state=Get-LocalTaskState
    if($state.error){throw $state.error}
    if($state.exists){Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop;return $true}
    return $false
}
function Resolve-Executor([string]$command) {
    if([string]::IsNullOrWhiteSpace($command)){return $null}
    $resolved=Get-Command $command -CommandType Application -ErrorAction SilentlyContinue
    if($resolved){return $resolved.Source}
    $candidate=$command
    if(-not[IO.Path]::IsPathRooted($candidate)){$candidate=Join-Path $projectRoot $candidate}
    if(Test-Path $candidate -PathType Leaf){return [IO.Path]::GetFullPath($candidate)}
    return $null
}
function Validate-ExternalId([string]$id) {
    if([string]::IsNullOrWhiteSpace($id)-or$id.Length-gt512){throw 'A bounded external-id is required for AGENT_MANAGED activation.'}
    if($id-match'[\r\n]' -or $id-match'gh[op]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'){throw 'external-id contains disallowed control/secret-like content.'}
}

$taskName=Get-TaskName

if($Operation-eq'Status'){
    $registration=Load-Registration
    $effective=if($registration){$registration.PSObject.Copy()}else{[pscustomobject]@{}}
    $taskState=$null
    try{$taskState=Get-LocalTaskState}catch{$taskState=[pscustomobject]@{exists=$false;error=$_.Exception.Message;task=$null}}
    try{
        $policy=Get-ValidatedPolicy;$schedule=$policy.schedule;$signature=Get-ScheduleSignature $schedule;$externalId=[string]$registration.external_id
        if($externalId){
            if(-not$schedule.enabled -or $schedule.executor_mode-ne'AGENT_MANAGED'){$effective|Add-Member status 'NEEDS_PLATFORM_DEACTIVATION' -Force;$effective|Add-Member message 'External AI/platform schedule must be disabled.' -Force;$effective|Add-Member external_id $externalId -Force}
            elseif($registration.status-eq'AGENT_MANAGED_ACTIVE'-and[string]$registration.schedule_signature-ne$signature){$effective|Add-Member status 'NEEDS_PLATFORM_UPDATE' -Force;$effective|Add-Member message 'External AI/platform schedule no longer matches owner policy.' -Force;$effective|Add-Member schedule_signature $signature -Force}
        }
        if($taskState.exists-and(-not$schedule.enabled -or $schedule.executor_mode-ne'LOCAL_COMMAND')){$effective|Add-Member status 'STALE_LOCAL_REGISTRATION' -Force;$effective|Add-Member message 'A Windows scheduled task exists but current owner policy does not authorize LOCAL_COMMAND scheduling.' -Force}
        elseif($schedule.enabled-and$schedule.executor_mode-eq'LOCAL_COMMAND'-and-not$taskState.exists-and-not$taskState.error-and$registration.status-eq'ACTIVE'){$effective|Add-Member status 'MISSING_LOCAL_REGISTRATION' -Force;$effective|Add-Member message 'Owner policy expects local scheduling but the Windows task is missing.' -Force}
    }catch{$effective|Add-Member status 'POLICY_INVALID' -Force;$effective|Add-Member message $_.Exception.Message -Force}
    if($taskState.error){$effective|Add-Member status 'SCHEDULER_STATUS_ERROR' -Force;$effective|Add-Member message $taskState.error -Force}
    [ordered]@{task_name=$taskName;registered=[bool]$taskState.exists;registration=$(if($effective.PSObject.Properties.Count){$effective}else{$null})}|ConvertTo-Json -Depth 10
    return
}

if(-not$OwnerApproved){throw 'Scheduler mutation requires explicit human owner approval.'}
$previous=Load-Registration
$previousExternal=if($previous){[string]$previous.external_id}else{''}

if($Operation-eq'ConfirmAgentManagedDisabled'){
    if(-not$previousExternal){Save-Registration 'DISABLED' 'No external AI/platform schedule is recorded as active.'|Out-Null;Write-Host 'SCHEDULER_AGENT_MANAGED=DISABLED';return}
    Validate-ExternalId $ExternalId
    if($ExternalId-ne$previousExternal){throw 'ExternalId does not match the recorded external schedule.'}
    Save-Registration 'DISABLED' 'External AI/platform schedule deactivation confirmed by the agent.' @{platform='agent-managed';deactivated_external_id=$previousExternal}|Out-Null
    Write-Host 'SCHEDULER_AGENT_MANAGED=DISABLED';return
}

if($Operation-eq'Remove'){
    try{[void](Remove-LocalTask)}catch{Save-Registration 'BLOCKED' 'Could not remove local Windows scheduled task.' @{error=$_.Exception.Message}|Out-Null;throw}
    if($previousExternal){Save-Registration 'NEEDS_PLATFORM_DEACTIVATION' 'Local schedule is disabled; external AI/platform schedule still requires deactivation.' @{platform='agent-managed';external_id=$previousExternal}|Out-Null;Write-Host 'SCHEDULER_NEEDS_PLATFORM_DEACTIVATION=1';return}
    Save-Registration 'DISABLED' 'Local OS schedule removed by owner.'|Out-Null;Write-Host "SCHEDULER_REMOVED=$taskName";return
}

$policy=Get-ValidatedPolicy
if(-not$policy.configured -or -not$policy.approval.approved_by_human){throw 'OWNER_POLICY is not human-approved/configured.'}
$schedule=$policy.schedule;$signature=Get-ScheduleSignature $schedule

if($Operation-eq'MarkAgentManaged'){
    if(-not$schedule.enabled -or $schedule.executor_mode-ne'AGENT_MANAGED'){throw 'Policy is not enabled for AGENT_MANAGED scheduling.'}
    Validate-ExternalId $ExternalId
    [void](Remove-LocalTask)
    Save-Registration 'AGENT_MANAGED_ACTIVE' 'External AI/platform scheduler marked active.' @{platform='agent-managed';external_id=$ExternalId;frequency=$schedule.frequency;local_time=$schedule.local_time;days_of_week=@($schedule.days_of_week);schedule_signature=$signature;policy_revision=$policy.policy_revision}|Out-Null
    Write-Host 'SCHEDULER_AGENT_MANAGED=ACTIVE';return
}

if(-not$schedule.enabled){throw 'Schedule is disabled in OWNER_POLICY.'}
$mode=[string]$schedule.executor_mode
if($previousExternal-and$mode-ne'AGENT_MANAGED'){
    [void](Remove-LocalTask)
    Save-Registration 'NEEDS_PLATFORM_DEACTIVATION' 'External AI/platform schedule must be disabled before another scheduler mode can become active.' @{platform='agent-managed';external_id=$previousExternal;pending_executor_mode=$mode}|Out-Null
    Write-Host 'SCHEDULER_NEEDS_PLATFORM_DEACTIVATION=1';return
}
if($mode-eq'UNCONFIGURED'){
    [void](Remove-LocalTask);Save-Registration 'NEEDS_EXECUTOR' 'Schedule intent exists but no executor is configured.'|Out-Null;Write-Host 'SCHEDULER_NEEDS_EXECUTOR=1';return
}
if($mode-eq'AGENT_MANAGED'){
    [void](Remove-LocalTask)
    if($previousExternal){
        if($previous.status-eq'AGENT_MANAGED_ACTIVE'-and[string]$previous.schedule_signature-eq$signature){Save-Registration 'AGENT_MANAGED_ACTIVE' 'External AI/platform scheduler remains aligned with owner policy.' @{platform='agent-managed';external_id=$previousExternal;frequency=$schedule.frequency;local_time=$schedule.local_time;days_of_week=@($schedule.days_of_week);schedule_signature=$signature;policy_revision=$policy.policy_revision}|Out-Null;Write-Host 'SCHEDULER_AGENT_MANAGED=ACTIVE'}
        else{Save-Registration 'NEEDS_PLATFORM_UPDATE' 'External AI/platform scheduler must be updated to match the owner policy.' @{platform='agent-managed';external_id=$previousExternal;frequency=$schedule.frequency;local_time=$schedule.local_time;days_of_week=@($schedule.days_of_week);schedule_signature=$signature;policy_revision=$policy.policy_revision}|Out-Null;Write-Host 'SCHEDULER_NEEDS_PLATFORM_UPDATE=1'}
    }else{Save-Registration 'NEEDS_PLATFORM_ACTIVATION' 'Schedule must be activated by the AI platform scheduler.' @{platform='agent-managed';frequency=$schedule.frequency;local_time=$schedule.local_time;days_of_week=@($schedule.days_of_week);schedule_signature=$signature;policy_revision=$policy.policy_revision}|Out-Null;Write-Host 'SCHEDULER_NEEDS_PLATFORM_ACTIVATION=1'}
    return
}
if($mode-ne'LOCAL_COMMAND'){throw 'Unsupported executor mode.'}

$resolvedExecutor=Resolve-Executor ([string]$schedule.executor.command)
if(-not$resolvedExecutor){[void](Remove-LocalTask);Save-Registration 'NEEDS_EXECUTOR' 'Configured local executor cannot be resolved.'|Out-Null;Write-Host 'SCHEDULER_NEEDS_EXECUTOR=1';return}
Ensure-TaskSchedulerAvailable
$runner=Join-Path $installRoot 'tools\scheduled-run.ps1'
if(-not(Test-Path $runner -PathType Leaf)){throw 'Scheduled runner is missing.'}
$windowsPowerShell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if(-not(Test-Path $windowsPowerShell -PathType Leaf)){throw 'Windows PowerShell executable is unavailable.'}
$time=[datetime]::ParseExact([string]$schedule.local_time,'HH:mm',[Globalization.CultureInfo]::InvariantCulture)
switch([string]$schedule.frequency){
    'DAILY'{$trigger=New-ScheduledTaskTrigger -Daily -At $time}
    'WEEKDAYS'{$trigger=New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At $time}
    'WEEKLY'{$days=@($schedule.days_of_week);$trigger=New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek $days -At $time}
    default{throw "Unsupported schedule frequency: $($schedule.frequency)"}
}
$action=New-ScheduledTaskAction -Execute $windowsPowerShell -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""
$settings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description 'Owner-approved Universal Comprehensive QA scheduled run.' -Force|Out-Null
Save-Registration 'ACTIVE' 'Local Windows scheduled QA registered.' @{platform='agent-managed';frequency=$schedule.frequency;local_time=$schedule.local_time;days_of_week=@($schedule.days_of_week);executor_mode='LOCAL_COMMAND';resolved_executor=$resolvedExecutor;schedule_signature=$signature;policy_revision=$policy.policy_revision}|Out-Null
Write-Host "SCHEDULER_ACTIVE=$taskName TIME=$($schedule.local_time) FREQUENCY=$($schedule.frequency)"
