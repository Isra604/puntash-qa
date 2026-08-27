param([string]$ProjectPath)

$ErrorActionPreference = 'Stop'
$installRoot = Split-Path -Parent $PSScriptRoot
if (-not $ProjectPath) { $ProjectPath = Split-Path -Parent $installRoot }
$stateDir = Join-Path $installRoot 'state'
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$statusPath = Join-Path $stateDir 'SCHEDULER_STATUS.json'
$policyPath = Join-Path $stateDir 'OWNER_POLICY.json'
$acceptancePath = Join-Path $stateDir 'HUMAN_ACCEPTANCE_RECEIPT.json'
$lockPath = Join-Path $stateDir 'SCHEDULED_RUN.lock'
$logDir = Join-Path $stateDir 'scheduler\logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

function Save-Status([string]$Result, [string]$Message, [hashtable]$Extra = @{}) {
    $record = [ordered]@{
        updated_at = (Get-Date).ToString('o')
        last_attempt = (Get-Date).ToString('o')
        last_result = $Result
        message = $Message
    }
    foreach ($key in $Extra.Keys) { $record[$key] = $Extra[$key] }
    $record | ConvertTo-Json -Depth 8 | Set-Content $statusPath -Encoding UTF8
}

if (-not (Test-Path $acceptancePath)) {
    Save-Status 'BLOCKED' 'Human acceptance receipt missing.'
    exit 5
}
if (-not (Test-Path $policyPath)) {
    Save-Status 'BLOCKED' 'OWNER_POLICY missing.'
    exit 6
}
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json
if (-not $policy.configured) {
    Save-Status 'BLOCKED' 'OWNER_POLICY is not configured.'
    exit 6
}
if (-not $policy.schedule.enabled) {
    Save-Status 'DISABLED' 'Schedule disabled by owner.'
    exit 0
}
if ($policy.schedule.executor_mode -ne 'LOCAL_COMMAND') {
    Save-Status 'NEEDS_EXECUTOR' "Local scheduled runner cannot execute mode $($policy.schedule.executor_mode)."
    exit 7
}

$command = [string]$policy.schedule.executor.command
if ([string]::IsNullOrWhiteSpace($command)) {
    Save-Status 'NEEDS_EXECUTOR' 'LOCAL_COMMAND executable is empty.'
    exit 7
}
$resolved = Get-Command $command -ErrorAction SilentlyContinue
$filePath = if ($resolved) { $resolved.Source } else { $command }
if (-not $resolved -and -not (Test-Path $filePath -PathType Leaf)) {
    Save-Status 'NEEDS_EXECUTOR' "Executor not found: $command"
    exit 7
}

$lock = $null
try {
    try {
        $lock = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch {
        Save-Status 'SKIPPED_OVERLAP' 'Another scheduled QA run is already active.'
        exit 8
    }
    $runId = 'SCHEDULED-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    $stdoutPath = Join-Path $logDir "$runId.stdout.log"
    $stderrPath = Join-Path $logDir "$runId.stderr.log"
    $promptPath = Join-Path $installRoot 'prompts\SCHEDULED_QA.md'
if(-not(Test-Path $promptPath)){$promptPath=Join-Path $installRoot 'templates\SCHEDULED_QA.md'}
    $arguments = @()
    foreach ($argument in @($policy.schedule.executor.arguments)) {
        $expanded = [string]$argument
        $expanded = $expanded.Replace('{project}', $ProjectPath).Replace('{install}', $installRoot).Replace('{prompt_file}', $promptPath)
        $arguments += $expanded
    }
    $timeoutMinutes = 240
    if ($policy.schedule.executor.PSObject.Properties.Name -contains 'timeout_minutes') {
        $timeoutMinutes = [int]$policy.schedule.executor.timeout_minutes
    }
    if ($timeoutMinutes -lt 1 -or $timeoutMinutes -gt 1440) { $timeoutMinutes = 240 }
    Save-Status 'RUNNING' 'Scheduled QA executor started.' @{ run_id = $runId; executor = $command; started_at = (Get-Date).ToString('o') }
    $process = Start-Process -FilePath $filePath -ArgumentList $arguments -WorkingDirectory $ProjectPath -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    $finished = $process.WaitForExit($timeoutMinutes * 60 * 1000)
    if (-not $finished) {
        try { $process.Kill() } catch {}
        Save-Status 'TIMEOUT' "Executor exceeded $timeoutMinutes minutes." @{ run_id = $runId; stdout = $stdoutPath; stderr = $stderrPath }
        exit 9
    }
    $exitCode = $process.ExitCode
    if ($exitCode -eq 0) {
        Save-Status 'SUCCESS' 'Scheduled QA executor completed.' @{ run_id = $runId; exit_code = $exitCode; stdout = $stdoutPath; stderr = $stderrPath; completed_at = (Get-Date).ToString('o') }
        exit 0
    }
    Save-Status 'FAILED' "Executor exited with code $exitCode." @{ run_id = $runId; exit_code = $exitCode; stdout = $stdoutPath; stderr = $stderrPath; completed_at = (Get-Date).ToString('o') }
    exit $exitCode
} finally {
    if ($lock) { $lock.Dispose() }
    Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
}
