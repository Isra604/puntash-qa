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
$script:acceptanceReceiptIntegrity='UNVERIFIED'

function Get-Sha256([string]$Path) {
    $stream=[IO.File]::OpenRead($Path);$sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToUpperInvariant() }
    finally { $sha.Dispose();$stream.Dispose() }
}

function ConvertTo-WindowsArgument([string]$Value) {
    if ($null -eq $Value -or $Value.Length -eq 0) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append('"')
    $slashes = 0
    foreach ($ch in $Value.ToCharArray()) {
        if ($ch -eq '\') { $slashes++; continue }
        if ($ch -eq '"') {
            [void]$sb.Append(('\' * ($slashes * 2 + 1)))
            [void]$sb.Append('"')
            $slashes = 0
            continue
        }
        if ($slashes) { [void]$sb.Append(('\' * $slashes)); $slashes = 0 }
        [void]$sb.Append($ch)
    }
    if ($slashes) { [void]$sb.Append(('\' * ($slashes * 2))) }
    [void]$sb.Append('"')
    return $sb.ToString()
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

function Save-Status([string]$Result, [string]$Message, [hashtable]$Extra = @{}) {
    $record = [ordered]@{
        updated_at = (Get-Date).ToString('o')
        last_attempt = (Get-Date).ToString('o')
        last_result = $Result
        message = $Message
        acceptance_receipt_integrity = $script:acceptanceReceiptIntegrity
    }
    foreach ($key in $Extra.Keys) { $record[$key] = $Extra[$key] }
    Write-JsonAtomic -Path $statusPath -Value $record -Depth 8
}

if (-not (Test-Path $acceptancePath)) {
    Save-Status 'BLOCKED' 'Human acceptance receipt missing.'
    exit 5
}
try{$receipt=Get-Content $acceptancePath -Raw|ConvertFrom-Json}catch{Save-Status 'BLOCKED' 'Human acceptance receipt is invalid JSON.';exit 5}
$currentTerms=(Get-Content (Join-Path $installRoot 'TERMS_VERSION') -Raw).Trim()
if($receipt.accepted_by_human_attestation -ne $true -or [string]$receipt.terms_version -ne $currentTerms){Save-Status 'BLOCKED' 'Human acceptance receipt does not prove acceptance of the current Terms version.';exit 5}
$legalManifestPath=Join-Path $installRoot 'LEGAL_MANIFEST.json'
try{$legalManifest=Get-Content $legalManifestPath -Raw|ConvertFrom-Json}catch{Save-Status 'BLOCKED' 'LEGAL_MANIFEST is missing or invalid.';exit 5}
foreach($doc in $legalManifest.documents.PSObject.Properties){
    $docPath=Join-Path $installRoot $doc.Name
    if(-not(Test-Path $docPath -PathType Leaf)){Save-Status 'BLOCKED' ('Installed legal document is missing: '+$doc.Name);exit 5}
    $actualHash=Get-Sha256 $docPath
    if($actualHash -ne ([string]$doc.Value).ToUpperInvariant()){Save-Status 'BLOCKED' ('Installed legal document hash mismatch: '+$doc.Name);exit 5}
}
$legacyAcceptanceReceipt=$false
if($null -eq $receipt.legal_document_sha256){
    try{
        $installation=Get-Content (Join-Path $installRoot 'INSTALLATION.json') -Raw|ConvertFrom-Json
        $previous=[version]$installation.previous_version
        $legacyAcceptanceReceipt=([string]$receipt.acceptance_method -eq 'interactive_windows_gui_update_clickwrap' -and $previous -lt [version]'2.1.0' -and [string]$receipt.package_version -eq [string]$installation.version -and [string]$receipt.terms_version -eq $currentTerms)
    }catch{$legacyAcceptanceReceipt=$false}
    if(-not $legacyAcceptanceReceipt){Save-Status 'BLOCKED' 'Human acceptance receipt is missing legal document hashes and is not a recognized legacy updater receipt.';exit 5}
}else{
    foreach($doc in $legalManifest.documents.PSObject.Properties){
        $rp=$receipt.legal_document_sha256.PSObject.Properties[$doc.Name]
        if($null -eq $rp -or ([string]$rp.Value).ToUpperInvariant() -ne ([string]$doc.Value).ToUpperInvariant()){Save-Status 'BLOCKED' ('Human acceptance receipt legal hash mismatch: '+$doc.Name);exit 5}
    }
}
$script:acceptanceReceiptIntegrity=$(if($legacyAcceptanceReceipt){'LEGACY_UPDATE_RECEIPT'}else{'HASH_VERIFIED'})
if (-not (Test-Path $policyPath)) {
    Save-Status 'BLOCKED' 'OWNER_POLICY missing.'
    exit 6
}
try{$policy=Get-Content $policyPath -Raw|ConvertFrom-Json}catch{Save-Status 'BLOCKED' 'OWNER_POLICY is invalid JSON.';exit 6}
if($null -eq $policy.schedule -or $null -eq $policy.schedule.executor){Save-Status 'BLOCKED' 'OWNER_POLICY schedule structure is invalid.';exit 6}
$logRetentionDays=30
if($policy.schedule.executor.PSObject.Properties.Name -contains 'log_retention_days'){$logRetentionDays=[int]$policy.schedule.executor.log_retention_days}
if($logRetentionDays -lt 1 -or $logRetentionDays -gt 365){$logRetentionDays=30}
Get-ChildItem $logDir -File -ErrorAction SilentlyContinue | Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-$logRetentionDays)} | Remove-Item -Force -ErrorAction SilentlyContinue
if (-not $policy.configured -or $policy.approval.approved_by_human -ne $true) {
    Save-Status 'BLOCKED' 'OWNER_POLICY is not human-approved/configured.'
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
    $runId = 'SCHEDULED-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
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
    Save-Status 'RUNNING' 'Scheduled QA executor started.' @{ run_id = $runId; executor = $command; started_at = (Get-Date).ToString('o'); acceptance_receipt_integrity = $(if($legacyAcceptanceReceipt){'LEGACY_UPDATE_RECEIPT'}else{'HASH_VERIFIED'}) }
    $argumentLine = (@($arguments) | ForEach-Object { ConvertTo-WindowsArgument ([string]$_) }) -join ' '
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $filePath
    $startInfo.Arguments = $argumentLine
    $startInfo.WorkingDirectory = $ProjectPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'Executor process could not be started.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $finished = $process.WaitForExit($timeoutMinutes * 60 * 1000)
    if (-not $finished) {
        try {
            $taskKill = Join-Path $env:SystemRoot 'System32\taskkill.exe'
            if (Test-Path $taskKill) { & $taskKill /PID $process.Id /T /F *> $null }
        } catch {}
        if (-not $process.HasExited) { try { $process.Kill() } catch {} }
        try { [void]$process.WaitForExit(10000) } catch {}
        $stdout = if ($stdoutTask.IsCompleted) { $stdoutTask.GetAwaiter().GetResult() } else { '' }
        $stderr = if ($stderrTask.IsCompleted) { $stderrTask.GetAwaiter().GetResult() } else { '' }
        Set-Content $stdoutPath $stdout -Encoding UTF8
        Set-Content $stderrPath $stderr -Encoding UTF8
        Save-Status 'TIMEOUT' "Executor exceeded $timeoutMinutes minutes." @{ run_id = $runId; stdout = $stdoutPath; stderr = $stderrPath; completed_at = (Get-Date).ToString('o') }
        exit 9
    }
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    Set-Content $stdoutPath $stdout -Encoding UTF8
    Set-Content $stderrPath $stderr -Encoding UTF8
    $exitCode = [int]$process.ExitCode
    if ($exitCode -eq 0) {
        Save-Status 'SUCCESS' 'Scheduled QA executor completed.' @{ run_id = $runId; exit_code = $exitCode; stdout = $stdoutPath; stderr = $stderrPath; completed_at = (Get-Date).ToString('o') }
        exit 0
    }
    Save-Status 'FAILED' "Executor exited with code $exitCode." @{ run_id = $runId; exit_code = $exitCode; stdout = $stdoutPath; stderr = $stderrPath; completed_at = (Get-Date).ToString('o') }
    exit $exitCode
} catch {
    Save-Status 'FAILED' ('Scheduled runner internal error: ' + $_.Exception.Message) @{ completed_at = (Get-Date).ToString('o') }
    exit 10
} finally {
    if ($lock) { $lock.Dispose() }
}
