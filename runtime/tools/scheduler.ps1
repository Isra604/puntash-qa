param(
    [ValidateSet('Status','Apply','Remove','MarkAgentManaged')]
    [string]$Operation = 'Status',
    [switch]$OwnerApproved,
    [string]$ExternalId
)

$ErrorActionPreference = 'Stop'
$installRoot = Split-Path -Parent $PSScriptRoot
$projectRoot = Split-Path -Parent $installRoot
$stateDir = Join-Path $installRoot 'state'
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$policyPath = Join-Path $stateDir 'OWNER_POLICY.json'
$registrationPath = Join-Path $stateDir 'SCHEDULER_REGISTRATION.json'

function Get-TaskName {
    $bytes = [Text.Encoding]::UTF8.GetBytes($projectRoot.ToLowerInvariant())
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').Substring(0, 12)
    } finally {
        $sha.Dispose()
    }
    return "ComprehensiveQA-$hash"
}

$taskName = Get-TaskName

function Save-Registration([string]$Status, [string]$Message, [hashtable]$Extra = @{}) {
    $record = [ordered]@{
        updated_at = (Get-Date).ToString('o')
        status = $Status
        message = $Message
        task_name = $taskName
        platform = 'windows'
    }
    foreach ($key in $Extra.Keys) { $record[$key] = $Extra[$key] }
    $record | ConvertTo-Json -Depth 8 | Set-Content $registrationPath -Encoding UTF8
}

if ($Operation -eq 'Status') {
    $exists = $false
    try {
        Get-ScheduledTask -TaskName $taskName -ErrorAction Stop | Out-Null
        $exists = $true
    } catch {}
    $registration = $null
    if (Test-Path $registrationPath) {
        $registration = Get-Content $registrationPath -Raw | ConvertFrom-Json
    }
    [ordered]@{ task_name = $taskName; registered = $exists; registration = $registration } | ConvertTo-Json -Depth 8
    return
}

if (-not $OwnerApproved) {
    throw 'Scheduler mutation requires explicit human owner approval.'
}

if ($Operation -eq 'Remove') {
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
    } catch {
        if ($_.Exception.Message -notmatch 'cannot find|No MSFT_ScheduledTask') { throw }
    }
    Save-Registration 'DISABLED' 'Local OS schedule removed by owner.'
    Write-Host "SCHEDULER_REMOVED=$taskName"
    return
}

if (-not (Test-Path $policyPath)) { throw 'OWNER_POLICY missing.' }
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json
if (-not $policy.configured -or -not $policy.approval.approved_by_human) {
    throw 'OWNER_POLICY is not human-approved/configured.'
}

if ($Operation -eq 'MarkAgentManaged') {
    if (-not $policy.schedule.enabled -or $policy.schedule.executor_mode -ne 'AGENT_MANAGED') {
        throw 'Policy is not enabled for AGENT_MANAGED scheduling.'
    }
    Save-Registration 'AGENT_MANAGED_ACTIVE' 'External AI/platform scheduler marked active.' @{
        external_id = $ExternalId
        frequency = $policy.schedule.frequency
        local_time = $policy.schedule.local_time
    }
    Write-Host 'SCHEDULER_AGENT_MANAGED=ACTIVE'
    return
}

if (-not $policy.schedule.enabled) { throw 'Schedule is disabled in OWNER_POLICY.' }
if ($policy.schedule.executor_mode -eq 'UNCONFIGURED') {
    Save-Registration 'NEEDS_EXECUTOR' 'Schedule intent exists but no executor is configured.'
    Write-Host 'SCHEDULER_NEEDS_EXECUTOR=1'
    return
}
if ($policy.schedule.executor_mode -eq 'AGENT_MANAGED') {
    Save-Registration 'NEEDS_PLATFORM_ACTIVATION' 'Schedule is owner-approved but must be activated by the AI platform scheduler.' @{
        frequency = $policy.schedule.frequency
        local_time = $policy.schedule.local_time
    }
    Write-Host 'SCHEDULER_NEEDS_PLATFORM_ACTIVATION=1'
    return
}
if ($policy.schedule.executor_mode -ne 'LOCAL_COMMAND') { throw 'Unsupported executor mode.' }

$time = [datetime]::ParseExact([string]$policy.schedule.local_time, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
switch ([string]$policy.schedule.frequency) {
    'DAILY' {
        $trigger = New-ScheduledTaskTrigger -Daily -At $time
    }
    'WEEKDAYS' {
        $trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At $time
    }
    'WEEKLY' {
        $days = @($policy.schedule.days_of_week)
        if (-not $days.Count) { $days = @('Sunday') }
        $validDays = @('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')
        foreach ($day in $days) {
            if ($validDays -notcontains [string]$day) { throw "Invalid weekly day: $day" }
        }
        $trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek $days -At $time
    }
    default { throw "Unsupported schedule frequency: $($policy.schedule.frequency)" }
}

$runner = Join-Path $installRoot 'tools\scheduled-run.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`""
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description 'Owner-approved Universal Comprehensive QA scheduled run.' -Force | Out-Null
Save-Registration 'ACTIVE' 'Local Windows scheduled QA registered.' @{
    frequency = $policy.schedule.frequency
    local_time = $policy.schedule.local_time
    executor_mode = 'LOCAL_COMMAND'
}
Write-Host "SCHEDULER_ACTIVE=$taskName TIME=$($policy.schedule.local_time) FREQUENCY=$($policy.schedule.frequency)"
