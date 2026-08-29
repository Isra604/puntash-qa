param(
    [string]$ProjectPath,
    [int]$Port = 0,
    [int]$IdleMinutes = 30,
    [switch]$NoBrowser,
    [string]$ControlToken
)

$ErrorActionPreference = 'Stop'
$installRoot = Split-Path -Parent $PSScriptRoot
if (-not $ProjectPath) { $ProjectPath = Split-Path -Parent $installRoot }
$ProjectPath = (Resolve-Path $ProjectPath).Path
$stateDir = Join-Path $installRoot 'state'
New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
$ownerPolicyPath = Join-Path $stateDir 'OWNER_POLICY.json'
$ownerTemplate = Join-Path $installRoot 'templates\OWNER_POLICY.json'
if (-not (Test-Path $ownerPolicyPath) -and (Test-Path $ownerTemplate)) { Copy-Item $ownerTemplate $ownerPolicyPath -Force }
$refreshTool = Join-Path $PSScriptRoot 'dashboard-refresh.ps1'
$policyTool = Join-Path $PSScriptRoot 'policy-manager.ps1'
$schedulerTool = Join-Path $PSScriptRoot 'scheduler.ps1'
$manualRunner = Join-Path $PSScriptRoot 'manual-run.ps1'
$authTool = Join-Path $PSScriptRoot 'authorize-change.ps1'
$fingerprintTool = Join-Path $PSScriptRoot 'project-fingerprint.ps1'
$hostExe = (Get-Process -Id $PID).Path
$script:scanProcess = $null

if (Test-Path $refreshTool) { & $refreshTool -ProjectPath $ProjectPath | Out-Null }

if ($Port -eq 0) {
    $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $probe.Start(); $Port = ([Net.IPEndPoint]$probe.LocalEndpoint).Port; $probe.Stop()
}
if (-not $ControlToken) {
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $ControlToken = ([BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
}
$baseUrl = "http://127.0.0.1:$Port/"
$listener = [Net.HttpListener]::new(); $listener.Prefixes.Add($baseUrl); $listener.Start()
$lastActivity = Get-Date
$mutexSha=[Security.Cryptography.SHA256]::Create()
try{$mutexHash=([BitConverter]::ToString($mutexSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($installRoot.ToLowerInvariant())))).Replace('-','').Substring(0,24)}finally{$mutexSha.Dispose()}
$script:dashboardMutationMutex=[Threading.Mutex]::new($false,('Local\PuntashQA-DashboardMutation-'+$mutexHash))
function Enter-DashboardMutationLock {
    try{return $script:dashboardMutationMutex.WaitOne(30000)}catch [Threading.AbandonedMutexException]{return $true}
}
function Exit-DashboardMutationLock {try{$script:dashboardMutationMutex.ReleaseMutex()}catch{}}

function Set-CommonHeaders($response) {
    $response.Headers['Cache-Control'] = 'no-store'
    $response.Headers['X-Content-Type-Options'] = 'nosniff'
    $response.Headers['Referrer-Policy'] = 'no-referrer'
    $response.Headers['Cross-Origin-Resource-Policy'] = 'same-origin'
    $response.Headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'"
}
function Send-Bytes($context, [byte[]]$bytes, [string]$contentType, [int]$statusCode = 200) {
    $context.Response.StatusCode = $statusCode; $context.Response.ContentType = $contentType
    Set-CommonHeaders $context.Response; $context.Response.ContentLength64 = $bytes.Length
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length); $context.Response.OutputStream.Close()
}
function Send-Text($context, [string]$text, [string]$contentType = 'text/plain; charset=utf-8', [int]$statusCode = 200) {
    Send-Bytes $context ([Text.Encoding]::UTF8.GetBytes($text)) $contentType $statusCode
}
function Send-Json($context, $object, [int]$statusCode = 200) {
    Send-Text $context ($object | ConvertTo-Json -Depth 30 -Compress) 'application/json; charset=utf-8' $statusCode
}
function Authorized($request) {
    if ([string]$request.Headers['X-QA-Control-Token'] -ne $ControlToken) { return $false }
    $origin = [string]$request.Headers['Origin']; if ($origin -and $origin -ne $baseUrl.TrimEnd('/')) { return $false }
    return $true
}
function Read-JsonFile([string]$Path) { try { if(Test-Path -LiteralPath $Path -PathType Leaf){return Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json} } catch {}; return $null }
function Write-JsonAtomic([string]$Path,$Value){$dir=Split-Path -Parent $Path;New-Item -ItemType Directory -Path $dir -Force|Out-Null;$tmp=Join-Path $dir ((Split-Path -Leaf $Path)+'.tmp.'+[guid]::NewGuid().ToString('N'));try{[IO.File]::WriteAllText($tmp,(($Value|ConvertTo-Json -Depth 20 -Compress)+"`n"),(New-Object Text.UTF8Encoding($false)));Move-Item -LiteralPath $tmp -Destination $Path -Force}finally{Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}}
function Read-JsonLines([string]$Path,[int]$Limit=500) {
    $out=@(); if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return @()}
    $lines=@(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue); if($lines.Count -gt $Limit){$lines=$lines[($lines.Count-$Limit)..($lines.Count-1)]}
    foreach($line in $lines){if([string]::IsNullOrWhiteSpace($line)){continue};try{$o=$line|ConvertFrom-Json;if($null-ne$o){$out+=$o}}catch{}}
    return @($out)
}
function Read-BodyJson($request,[int]$MaxBytes=65536) {
    if($request.ContentLength64 -lt 0 -or $request.ContentLength64 -gt $MaxBytes){throw 'invalid_body_size'}
    if($request.ContentLength64 -eq 0){return [pscustomobject]@{}}
    $reader=New-Object IO.StreamReader($request.InputStream,$request.ContentEncoding);try{$body=$reader.ReadToEnd()}finally{$reader.Dispose()}
    try{return $body|ConvertFrom-Json}catch{throw 'invalid_json'}
}
function Append-JsonLine([string]$Path,$Object){$line=$Object|ConvertTo-Json -Depth 20 -Compress;Add-Content -LiteralPath $Path -Value $line -Encoding UTF8}
function Content-Type([string]$path) {
    switch ([IO.Path]::GetExtension($path).ToLowerInvariant()) {
        '.html' {'text/html; charset=utf-8'} '.js' {'application/javascript; charset=utf-8'} '.json' {'application/json; charset=utf-8'}
        '.md' {'text/plain; charset=utf-8'} '.txt' {'text/plain; charset=utf-8'} '.log' {'text/plain; charset=utf-8'} '.csv' {'text/plain; charset=utf-8'}
        '.xml' {'text/plain; charset=utf-8'} '.yaml' {'text/plain; charset=utf-8'} '.yml' {'text/plain; charset=utf-8'}
        '.png' {'image/png'} '.jpg' {'image/jpeg'} '.jpeg' {'image/jpeg'} '.webp' {'image/webp'} default {'application/octet-stream'}
    }
}
function Test-Reparse([string]$Path){try{$i=Get-Item -LiteralPath $Path -Force -ErrorAction Stop;return (($i.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0)}catch{return $false}}
function Test-NoReparseParts([string]$Root,[string[]]$Parts){$cur=$Root;if(Test-Reparse $cur){return $false};foreach($part in $Parts){$cur=Join-Path $cur $part;if((Test-Path -LiteralPath $cur) -and (Test-Reparse $cur)){return $false}};return $true}
function Safe-ViewPath([string]$Relative,[switch]$ReportsOnly) {
    if([string]::IsNullOrWhiteSpace($Relative)-or$Relative.Length-gt2048){return $null}
    $decoded=[Uri]::UnescapeDataString($Relative).Replace('\','/').TrimStart('/')
    $parts=@($decoded.Split('/'));if($parts.Count-eq0-or@($parts|Where-Object{$_-eq''-or$_-eq'..'-or$_-eq'.'}).Count){return $null}
    if($ReportsOnly -and $parts[0].ToLowerInvariant()-eq'reports'){$parts=@($parts|Select-Object -Skip 1)}
    if($parts.Count-eq0){return $null}
    $allowedRoots=@('evidence','artifacts','profile','reports','remediation','dispositions')
    $root=if($ReportsOnly){Join-Path $installRoot 'reports'}else{$installRoot}
    if(-not$ReportsOnly -and $allowedRoots -notcontains $parts[0].ToLowerInvariant()){return $null}
    if(-not(Test-NoReparseParts $root $parts)){return $null}
    $candidate=[IO.Path]::GetFullPath((Join-Path $root ($parts-join[IO.Path]::DirectorySeparatorChar)))
    $rootFull=[IO.Path]::GetFullPath($root).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(-not$candidate.StartsWith($rootFull,[StringComparison]::OrdinalIgnoreCase)){return $null}
    if(-not(Test-Path -LiteralPath $candidate -PathType Leaf)){return $null}
    $ext=[IO.Path]::GetExtension($candidate).ToLowerInvariant();$text=@('.md','.txt','.json','.log','.csv','.xml','.yaml','.yml');$images=@('.png','.jpg','.jpeg','.webp')
    if($text-notcontains$ext -and $images-notcontains$ext){return $null}
    $size=(Get-Item -LiteralPath $candidate).Length;if(($images-contains$ext -and $size-gt8388608)-or($text-contains$ext -and $size-gt2097152)){return $null}
    return $candidate
}
function Get-DashboardData {
    $dataPath=Join-Path $installRoot 'dashboard\data.js';if(-not(Test-Path $dataPath -PathType Leaf)){return [pscustomobject]@{schema_version=3;runs=@();run_count=0;project_path=$ProjectPath}}
    $raw=Get-Content $dataPath -Raw;$json=$raw-replace'^\s*window\.QA_DASHBOARD_DATA\s*=\s*',''-replace';\s*$',''
    try{return $json|ConvertFrom-Json}catch{return [pscustomobject]@{schema_version=3;runs=@();run_count=0;project_path=$ProjectPath}}
}
function Get-PolicyProjection { try {$raw=& $policyTool -Operation Get|Out-String;return [pscustomobject]@{ok=$true;data=($raw|ConvertFrom-Json)}}catch{return [pscustomobject]@{ok=$false;error='owner_policy_invalid';message=$_.Exception.Message}} }
function Get-SchedulerProjection { try {$raw=& $schedulerTool -Operation Status|Out-String;return [pscustomobject]@{ok=$true;data=($raw|ConvertFrom-Json)}}catch{return [pscustomobject]@{ok=$false;error='scheduler_status_error';message=$_.Exception.Message}} }
function Get-SchedulerSnapshot { $reg=Read-JsonFile (Join-Path $stateDir 'SCHEDULER_REGISTRATION.json');return [pscustomobject]@{ok=$true;data=[pscustomobject]@{registered=($null-ne$reg-and[string]$reg.status-in@('ACTIVE','AGENT_MANAGED_ACTIVE'));registration=$reg}} }
function Get-AcceptanceProjection {
    $terms='';try{$terms=(Get-Content (Join-Path $installRoot 'TERMS_VERSION') -Raw).Trim()}catch{}
    $receipt=Read-JsonFile (Join-Path $stateDir 'HUMAN_ACCEPTANCE_RECEIPT.json');$r=[ordered]@{present=($null-ne$receipt);valid=$false;terms_version=$terms;accepted_terms_version=$null;reason='Human acceptance has not been recorded.'}
    if($null-eq$receipt){return [pscustomobject]$r};$r.accepted_terms_version=[string]$receipt.terms_version
    if($receipt.accepted_by_human_attestation-ne$true){$r.reason='The acceptance record does not contain a human attestation.';return [pscustomobject]$r}
    if([string]$receipt.terms_version-ne$terms){$r.reason='The Terms have changed since acceptance.';return [pscustomobject]$r}
    $manifest=Read-JsonFile (Join-Path $installRoot 'LEGAL_MANIFEST.json');if($null-eq$manifest){$r.reason='The legal integrity manifest could not be verified.';return [pscustomobject]$r}
    foreach($doc in $manifest.documents.PSObject.Properties){$dp=Join-Path $installRoot $doc.Name;if(-not(Test-Path $dp -PathType Leaf)){$r.reason="A required legal document is missing: $($doc.Name)";return [pscustomobject]$r};$actual=(Get-FileHash $dp -Algorithm SHA256).Hash;if($actual-ne([string]$doc.Value).ToUpperInvariant()){$r.reason='The installed legal documents failed their integrity check.';return [pscustomobject]$r}}
    if($null-ne$receipt.legal_document_sha256){
        foreach($doc in $manifest.documents.PSObject.Properties){$rp=$receipt.legal_document_sha256.PSObject.Properties[$doc.Name];if($null-eq$rp-or([string]$rp.Value).ToUpperInvariant()-ne([string]$doc.Value).ToUpperInvariant()){$r.reason='The legal acceptance record no longer matches the installed legal documents.';return [pscustomobject]$r}}
    } else {
        $legacy=$false;$installation=Read-JsonFile (Join-Path $installRoot 'INSTALLATION.json')
        try{$legacy=([string]$receipt.acceptance_method-eq'interactive_windows_gui_update_clickwrap' -and [version]$installation.previous_version-lt[version]'2.1.0' -and [string]$receipt.package_version-eq[string]$installation.version -and [string]$receipt.terms_version-eq$terms)}catch{$legacy=$false}
        if(-not$legacy){$r.reason='The acceptance record cannot be integrity-verified.';return [pscustomobject]$r}
    }
    $r.valid=$true;$r.reason='Current Terms were accepted by a human and the local legal record is valid.';return [pscustomobject]$r
}
function Get-LegalProjection {$manifest=Read-JsonFile (Join-Path $installRoot 'LEGAL_MANIFEST.json');if($null-eq$manifest){return [pscustomobject]@{valid=$false;reason='Legal integrity manifest is missing or invalid.'}};foreach($doc in $manifest.documents.PSObject.Properties){$dp=Join-Path $installRoot $doc.Name;if(-not(Test-Path $dp -PathType Leaf)){return [pscustomobject]@{valid=$false;reason="Required legal document is missing: $($doc.Name)"}};$actual=(Get-FileHash $dp -Algorithm SHA256).Hash;if($actual-ne([string]$doc.Value).ToUpperInvariant()){return [pscustomobject]@{valid=$false;reason="Legal document integrity check failed: $($doc.Name)"}}};return [pscustomobject]@{valid=$true;reason='Installed legal documents match the integrity manifest.'}}
function Get-SchedulerHumanMessage([string]$State){
    $m=@{
      POLICY_INVALID='PUNTASH QA cannot verify the automatic-scan settings. Repair permissions before relying on automatic scans.'
      REGISTRATION_STATE_INVALID='The saved automatic-scan setup is damaged and needs repair.'
      SCHEDULER_STATUS_ERROR='PUNTASH QA could not verify the automatic-scan service on this computer.'
      STALE_LOCAL_REGISTRATION='An old automatic-scan entry needs cleanup.'
      MISSING_LOCAL_REGISTRATION='Automatic scans are enabled, but the expected local scan entry is missing.'
      BLOCKED='Automatic scans are blocked by a setup problem.'
      NEEDS_PLATFORM_ACTIVATION='Your AI platform still needs to turn this automatic schedule on.'
      NEEDS_PLATFORM_UPDATE='Your AI platform schedule needs to be updated to match these settings.'
      NEEDS_PLATFORM_DEACTIVATION='Automatic scans are off here, but your AI platform still needs to remove its schedule.'
    }
    if($m.ContainsKey($State)){return [string]$m[$State]};return 'Automatic scan setup needs attention.'
}
function Get-PermissionName([string]$Preset){$m=@{REPORT_ONLY='Observe only';SAFE_FIXES='Fix safe things';ACTIVE_REMEDIATION='More active protection'};if($m.ContainsKey($Preset)){return [string]$m[$Preset]};return 'Custom settings'}
function Get-Diagnostics {
    $issues=@();$p=Get-PolicyProjection;$s=Get-SchedulerSnapshot;$a=Get-AcceptanceProjection;$l=Get-LegalProjection
    if(-not$p.ok){$issues+=@{code='POLICY_INVALID';severity='ACTION';title='Permission settings need repair';message='PUNTASH QA could not verify your permission settings. Automatic changes stay blocked until this is repaired.';action='RESET_POLICY'}}
    if(-not$l.valid){$issues+=@{code='LEGAL_INVALID';severity='ACTION';title='Installation integrity needs attention';message=$l.reason;action=$null}}
    if(-not$a.valid){$issues+=@{code='ACCEPTANCE_INVALID';severity='ACTION';title='Terms acceptance needs attention';message=$a.reason;action=$null}}
    $state='NOT_CONFIGURED';if($s.ok -and $null-ne$s.data.registration){$state=[string]$s.data.registration.status}
    if($state-in@('POLICY_INVALID','REGISTRATION_STATE_INVALID','SCHEDULER_STATUS_ERROR','STALE_LOCAL_REGISTRATION','MISSING_LOCAL_REGISTRATION','BLOCKED')){$issues+=@{code=$state;severity='ACTION';title='Automatic scan setup needs attention';message=(Get-SchedulerHumanMessage $state);action='RETRY_SCHEDULER'}}
    elseif($state-in@('NEEDS_PLATFORM_ACTIVATION','NEEDS_PLATFORM_UPDATE','NEEDS_PLATFORM_DEACTIVATION')){$issues+=@{code=$state;severity='INFO';title='Your AI platform still has one scheduling step';message=(Get-SchedulerHumanMessage $state);action=$null}}
    return [pscustomobject]@{ok=(@($issues|Where-Object{$_.severity-eq'ACTION'}).Count-eq0);issues=@($issues);policy=@{valid=$p.ok};scheduler=@{valid=$s.ok;state=$state};acceptance=$a;legal=$l;control=@{bind='127.0.0.1';local_only=$true;telemetry=$false}}
}
function Get-ApprovalRequestHash($Request) {
    $canonical=[ordered]@{
        request_id=[string]$Request.request_id
        created_at=[string]$Request.created_at
        policy_revision=$Request.policy_revision
        finding_id=[string]$Request.finding_id
        risk=[string]$Request.risk
        category=[string]$Request.category
        change_summary=[string]$Request.change_summary
        evidence_refs=@($Request.evidence_refs|ForEach-Object{[string]$_})
        target_paths=@($Request.target_paths|ForEach-Object{[string]$_})
        expected_behavior_proven=($Request.expected_behavior_proven-eq$true)
        reversible=($Request.reversible-eq$true)
    }
    $json=$canonical|ConvertTo-Json -Depth 8 -Compress
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Get-CurrentProjectFingerprint {
    try{
        $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName=$hostExe;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
        foreach($arg in @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$fingerprintTool,'-ProjectPath',$ProjectPath)){[void]$psi.ArgumentList.Add([string]$arg)}
        $proc=[Diagnostics.Process]::Start($psi);if(-not$proc.WaitForExit(120000)){try{$proc.Kill($true)}catch{};return $null}
        $out=$proc.StandardOutput.ReadToEnd();if($proc.ExitCode-ne0-or[string]::IsNullOrWhiteSpace($out)){return $null}
        return ($out|ConvertFrom-Json)
    }catch{return $null}
}
function Get-ProjectFreshness($Run) {
    $git=Get-Command git -ErrorAction SilentlyContinue;$isGit=$false
    if($git){try{$probe=& $git.Source -C $ProjectPath rev-parse --is-inside-work-tree 2>$null;$isGit=($LASTEXITCODE-eq0-and([string]($probe|Select-Object -First 1)).Trim().ToLowerInvariant()-eq'true')}catch{$isGit=$false}}
    if($isGit){
        try{
            $headOut=& $git.Source -C $ProjectPath rev-parse HEAD 2>$null;$headRc=$LASTEXITCODE
            if($headRc-eq0){
                $current=([string]($headOut|Select-Object -First 1)).Trim();$scanned=[string]$Run.project.head
                if([string]::IsNullOrWhiteSpace($scanned)){return [pscustomobject]@{ok=$false;state='STALE';reason='The latest scan does not record the project version that was checked. Run SCAN NOW again before relying on this result.'}}
                if($scanned.Trim().ToLowerInvariant()-ne$current.ToLowerInvariant()){return [pscustomobject]@{ok=$false;state='STALE';reason='The project changed after the verified scan. Run SCAN NOW again before releasing.'}}
                $args=@('-C',$ProjectPath,'status','--porcelain=v1','--untracked-files=all','--','.',':(exclude).comprehensive-qa/**',':(exclude).comprehensive-qa-backups/**')
                $statusOut=& $git.Source @args 2>$null;$statusRc=$LASTEXITCODE
                if($statusRc-ne0){return [pscustomobject]@{ok=$false;state='UNVERIFIABLE';reason='PUNTASH QA could not verify whether the project changed after the scan.'}}
                if(-not[string]::IsNullOrWhiteSpace(($statusOut|Out-String))){return [pscustomobject]@{ok=$false;state='STALE';reason='The project has changes that are not covered by the verified scan. Run SCAN NOW again after those changes are final.'}}
                return [pscustomobject]@{ok=$true;state='CURRENT';method='GIT';current_head=$current}
            }
        }catch{}
    }
    $fp=$Run.project.fingerprint
    if($null-eq$fp-or$fp.available-ne$true-or[string]$fp.algorithm-ne'PUNTASH_SOURCE_V1'){return [pscustomobject]@{ok=$false;state='UNVERIFIABLE';reason='This scan does not contain a project snapshot that PUNTASH QA can compare with the project now. Run SCAN NOW again.'}}
    $current=Get-CurrentProjectFingerprint
    if($null-eq$current-or$current.ok-ne$true){return [pscustomobject]@{ok=$false;state='UNVERIFIABLE';reason='PUNTASH QA could not safely compare the current project with the verified scan. Open Details if you need the technical reason.'}}
    if(([string]$fp.sha256).ToUpperInvariant()-ne([string]$current.sha256).ToUpperInvariant()){return [pscustomobject]@{ok=$false;state='STALE';reason='The project changed after the verified scan. Run SCAN NOW again before releasing.'}}
    return [pscustomobject]@{ok=$true;state='CURRENT';method='FINGERPRINT';fingerprint=[string]$current.sha256}
}
function Get-ReleaseReadiness($Data){
    $runs=@($Data.runs);if(-not$runs.Count){return @{record_valid=$false;state='NOT_SCANNED';label='Could not verify';ready=$false;reasons=@('Run a full scan before deciding whether this project is ready to release.')}}
    $r=$runs[0];$record=[string]$r._dashboard_record
    if([string]::IsNullOrWhiteSpace($record)-or$record-match'[\/]' -or $record-notmatch'\.json$'){return @{record_valid=$false;state='INCOMPLETE';label='Could not verify';ready=$false;reasons=@('The latest scan record is unavailable. Run SCAN NOW again.')}}
    $runPath=Join-Path $installRoot ('reports\dashboard\'+$record);if(-not(Test-Path $runPath -PathType Leaf)){return @{record_valid=$false;state='INCOMPLETE';label='Could not verify';ready=$false;reasons=@('The latest scan record is unavailable. Run SCAN NOW again.')}}
    $validator=Join-Path $PSScriptRoot 'validate-run.ps1'
    try{
        $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName=$hostExe;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;foreach($arg in @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$validator,'-RunPath',$runPath)){[void]$psi.ArgumentList.Add([string]$arg)};$proc=[Diagnostics.Process]::Start($psi);if(-not$proc.WaitForExit(30000)){try{$proc.Kill($true)}catch{};return @{record_valid=$false;state='INCOMPLETE';label='Could not verify';ready=$false;reasons=@('PUNTASH QA could not verify the latest scan record. Run SCAN NOW again.')}};if($proc.ExitCode-ne0){return @{record_valid=$false;state='INCOMPLETE';label='Could not verify';ready=$false;reasons=@('The latest scan record could not be verified. Run SCAN NOW again before relying on it.')}}
    }catch{return @{record_valid=$false;state='INCOMPLETE';label='Could not verify';ready=$false;reasons=@('PUNTASH QA could not verify the latest scan record. Run SCAN NOW again.')}}
    try{$fail=[int]$r.summary.fail;$blocked=[int]$r.summary.blocked;$nr=[int]$r.summary.not_run}catch{return @{record_valid=$true;state='INCOMPLETE';label='Could not verify';ready=$false;reasons=@('The latest scan result is incomplete. Run SCAN NOW again.')}}
    if($fail-or$blocked){$why=@();if($fail){$why+="$fail quality check(s) found a problem."};if($blocked){$why+="$blocked quality check(s) could not be completed."};return @{record_valid=$true;state='NOT_READY';label='Not yet';ready=$false;reasons=$why}}
    if($nr){return @{record_valid=$true;state='INCOMPLETE';label='Could not verify';ready=$false;reasons=@("$nr quality check(s) still need to run.")}}
    if(@($r.gates).Count-ne25-or@($r.lenses).Count-ne9){return @{record_valid=$true;state='INCOMPLETE';label='Could not verify';ready=$false;reasons=@('The latest scan is incomplete. Run SCAN NOW again.')}}
    $fresh=Get-ProjectFreshness $r
    if(-not$fresh.ok){return @{record_valid=$true;state=[string]$fresh.state;label=$(if([string]$fresh.state-eq'STALE'){'Scan again'}else{'Could not verify'});ready=$false;reasons=@([string]$fresh.reason)}}
    return @{record_valid=$true;state='READY';label='Ready';ready=$true;reasons=@('The latest verified scan still matches the project as it is now.');freshness_method=[string]$fresh.method}
}

function Get-ProjectHealth($Data,$Readiness) {
    $runs=@($Data.runs);if(-not$runs.Count){return @{label='Not scanned yet';kind='info';text='Run your first scan to see what PUNTASH QA finds.';verified=$false}}
    if([string]$Readiness.state-in@('INCOMPLETE','UNVERIFIABLE','STALE','NOT_SCANNED')){$reason=@($Readiness.reasons|Select-Object -First 1);return @{label='Could not fully verify';kind='warn';text=$(if($reason.Count){[string]$reason[0]}else{'The latest scan could not be fully verified.'});verified=$false}}
    $r=$runs[0];$fail=[int]$r.summary.fail;$blocked=[int]$r.summary.blocked;$nr=[int]$r.summary.not_run
    if($fail){return @{label='Action required';kind='bad';text="$fail quality check(s) found a problem.";verified=$true}}
    if($blocked-or$nr){return @{label='Could not fully verify';kind='warn';text='Some checks could not be completed. Review them before relying on the result.';verified=$false}}
    $open=@($r.findings|Where-Object{[string]$_.status-notin@('resolved','closed','fixed')});$text=$(if($open.Count){"$($open.Count) item(s) are worth reviewing."}else{'No current problem was found in the latest verified scan.'})
    return @{label='Good';kind='good';text=$text;verified=$true}
}
function Get-Activity($Data){$events=@();foreach($r in @($Data.runs|Select-Object -First 40)){if($r.completed_at){$events+=@{at=[string]$r.completed_at;type='SCAN_COMPLETED';title='Scan completed';detail="$($r.summary.pass) checked OK · $($r.summary.fail) problems · $($r.summary.blocked) incomplete";run_id=$r.run_id}};if($r.started_at){$events+=@{at=[string]$r.started_at;type='SCAN_STARTED';title='Scan started';detail='PUNTASH QA started checking the project.';run_id=$r.run_id}};foreach($e in @($r.automatic_remediation.entries)){if($null-ne$e){$events+=@{at=[string]$r.completed_at;type='REMEDIATION';title='Safe change recorded';detail=[string]$e.change_summary;finding_id=$e.finding_id;authorization_id=$e.authorization_id}}}}
    foreach($h in Read-JsonLines (Join-Path $stateDir 'OWNER_POLICY_HISTORY.jsonl') 80){$events+=@{at=[string]$h.changed_at;type='POLICY';title='Permissions or schedule changed';detail="$(Get-PermissionName ([string]$h.preset)) · automatic scans $(if($h.schedule_enabled){'on'}else{'off'})";policy_revision=$h.revision}}
    foreach($h in Read-JsonLines (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') 80){$events+=@{at=[string]$h.decided_at;type='APPROVAL';title="Change request $(if($h.decision-eq'APPROVE'){'approved'}else{'not approved'})";detail=[string]$h.change_summary;request_id=$h.request_id;authorization_id=$h.authorization_id}}
    return @($events|Where-Object{$_.at}|Sort-Object at -Descending|Select-Object -First 120)
}
function Get-Approvals {
    $reqs=Read-JsonLines (Join-Path $stateDir 'APPROVAL_REQUESTS.jsonl') 500;$decisions=Read-JsonLines (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') 500;$map=@{};foreach($d in $decisions){if($d.request_id){$map[[string]$d.request_id]=$d}}
    $out=@();$groups=@($reqs|Group-Object { [string]$_.request_id })
    foreach($g in $groups){$id=[string]$g.Name;if($id-notmatch'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'){continue};$r=@($g.Group)[-1];$summary=[string]$r.change_summary;$out+=@{request_id=$id;created_at=[string]$r.created_at;policy_revision=$r.policy_revision;finding_id=[string]$r.finding_id;risk=[string]$r.risk;category=[string]$r.category;change_summary=$summary.Substring(0,[Math]::Min(1000,$summary.Length));evidence_refs=@($r.evidence_refs|Select-Object -First 16);target_paths=@($r.target_paths|Select-Object -First 32);expected_behavior_proven=($r.expected_behavior_proven-eq$true);reversible=($r.reversible-eq$true);request_hash=(Get-ApprovalRequestHash $r);conflict=($g.Count-ne1);conflict_reason=$(if($g.Count-ne1){'This request ID appears more than once. Refresh or regenerate the request before deciding.'}else{''});decision=$map[$id]}}
    return @($out|Sort-Object created_at -Descending|Select-Object -First 100)
}
function Test-SharedScanLockBusy {
    $lockPath=Join-Path $stateDir 'SCHEDULED_RUN.lock';$probe=$null
    try{$probe=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);return $false}catch{return $true}finally{if($probe){$probe.Dispose()}}
}
function Test-RecentStartingStatus($Status) {
    if($null-eq$Status-or[string]$Status.last_result-ne'STARTING'){return $false}
    try{$ts=[DateTimeOffset]::Parse([string]$(if($Status.updated_at){$Status.updated_at}else{$Status.last_attempt}));return (([DateTimeOffset]::Now-$ts).TotalSeconds-lt30)}catch{return $false}
}
function Start-ManualScan {
    if($script:scanProcess -and -not$script:scanProcess.HasExited){return [pscustomobject]@{ok=$false;error='scan_already_running';message='A scan is already running.'}}
    $shared=Read-JsonFile (Join-Path $stateDir 'MANUAL_SCAN_STATUS.json');if((Test-SharedScanLockBusy)-or(Test-RecentStartingStatus $shared)){return [pscustomobject]@{ok=$false;error='scan_already_running';message='A scan is already running.'}}
    $p=Get-PolicyProjection;if(-not$p.ok){return [pscustomobject]@{ok=$false;error='owner_policy_invalid';message='Permission settings could not be verified. Repair them before starting a scan.'}}
    $mode=[string]$p.data.schedule.executor_mode;if($mode-eq'AGENT_MANAGED'){return [pscustomobject]@{ok=$false;error='scan_needs_external_agent';message='This project uses an external AI/platform scan runner. Start the scan from that platform, or configure a local runner.'}};if($mode-ne'LOCAL_COMMAND'){return [pscustomobject]@{ok=$false;error='scan_runner_not_configured';message='A scan runner has not been configured yet. Open Schedule & setup to choose how scans should run.'}}
    Write-JsonAtomic (Join-Path $stateDir 'MANUAL_SCAN_STATUS.json') ([ordered]@{updated_at=(Get-Date).ToString('o');last_attempt=(Get-Date).ToString('o');last_result='STARTING';message='PUNTASH QA is starting the scan.'})
    $psi=[Diagnostics.ProcessStartInfo]::new()
    $psi.FileName=$hostExe
    $psi.UseShellExecute=$false
    $psi.CreateNoWindow=$true
    foreach($arg in @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$manualRunner,'-ProjectPath',$ProjectPath)){[void]$psi.ArgumentList.Add([string]$arg)}
    $script:scanProcess=[Diagnostics.Process]::Start($psi)
    if(-not$script:scanProcess){return [pscustomobject]@{ok=$false;error='scan_start_failed';message='PUNTASH QA could not start the scan process.'}}
    return [pscustomobject]@{ok=$true;started=$true;pid=$script:scanProcess.Id}
}

Write-Host "DASHBOARD_CONTROL_URL=$baseUrl"; Write-Host 'DASHBOARD_CONTROL_BIND=127.0.0.1'
if (-not $NoBrowser) { Start-Process ($baseUrl + '#token=' + $ControlToken) }

try {
    while ($listener.IsListening) {
        $contextTask=$listener.GetContextAsync();while(-not$contextTask.Wait(1000)){if(((Get-Date)-$lastActivity).TotalMinutes-ge$IdleMinutes){break}}
        if(-not$contextTask.IsCompleted){break};$context=$contextTask.GetAwaiter().GetResult();$lastActivity=Get-Date
        $mutationHeld=$false
        try {
            $request=$context.Request;$path=$request.Url.AbsolutePath
            if($request.HttpMethod-eq'POST' -and $path-in@('/api/policy','/api/recovery','/api/scheduler-action','/api/approval')){if(-not(Enter-DashboardMutationLock)){Send-Json $context @{ok=$false;error='dashboard_mutation_busy';message='Another Dashboard change is still being saved. Try again in a moment.'} 409;continue};$mutationHeld=$true}
            if($path-like'/api/*'){
                if(-not(Authorized $request)){Send-Json $context @{ok=$false;error='unauthorized'} 403;continue}
                if($request.HttpMethod-eq'GET'){
                    if($path-eq'/api/dashboard-data'){$d=Get-DashboardData;Send-Json $context @{ok=$true;data=$d};continue}
                    if($path-eq'/api/overview'){$d=Get-DashboardData;$rr=Get-ReleaseReadiness $d;Send-Json $context @{ok=$true;overview=@{data=$d;policy=(Get-PolicyProjection);scheduler=(Get-SchedulerSnapshot);release_readiness=$rr;project_health=(Get-ProjectHealth $d $rr);diagnostics=(Get-Diagnostics)}};continue}
                    if($path-eq'/api/activity'){$d=Get-DashboardData;Send-Json $context @{ok=$true;activity=@(Get-Activity $d)};continue}
                    if($path-eq'/api/policy'){$p=Get-PolicyProjection;if($p.ok){Send-Json $context @{ok=$true;policy=$p.data}}else{Send-Json $context @{ok=$false;error=$p.error;details=$p.message} 409};continue}
                    if($path-eq'/api/scheduler'){$s=Get-SchedulerProjection;if($s.ok){Send-Json $context @{ok=$true;scheduler=$s.data}}else{Send-Json $context @{ok=$false;error=$s.error;details=$s.message} 409};continue}
                    if($path-eq'/api/scan-status'){$st=Read-JsonFile (Join-Path $stateDir 'MANUAL_SCAN_STATUS.json');if($null-eq$st){$st=[pscustomobject]@{last_result='NOT_RUN';message='No manual scan has been started yet.'}};$active=(($script:scanProcess -and -not $script:scanProcess.HasExited) -or (Test-SharedScanLockBusy) -or (Test-RecentStartingStatus $st));Send-Json $context @{ok=$true;active=$active;scan=$st};continue}
                    if($path-eq'/api/diagnostics'){Send-Json $context @{ok=$true;diagnostics=(Get-Diagnostics)};continue}
                    if($path-eq'/api/approvals'){Send-Json $context @{ok=$true;approvals=@(Get-Approvals)};continue}
                    if($path-eq'/api/report'){$f=Safe-ViewPath ([string]$request.QueryString['path']) -ReportsOnly;if(-not$f){Send-Json $context @{ok=$false;error='report_not_found'} 404}else{Send-Bytes $context ([IO.File]::ReadAllBytes($f)) (Content-Type $f)};continue}
                    if($path-eq'/api/evidence'){$f=Safe-ViewPath ([string]$request.QueryString['path']);if(-not$f){Send-Json $context @{ok=$false;error='evidence_not_found'} 404}else{Send-Bytes $context ([IO.File]::ReadAllBytes($f)) (Content-Type $f)};continue}
                }
                if($request.HttpMethod-eq'POST'){
                    if($path-eq'/api/shutdown'){Send-Json $context @{ok=$true};break}
                    if($path-eq'/api/scan-now'){try{$null=Read-BodyJson $request 4096}catch{Send-Json $context @{ok=$false;error=$_.Exception.Message} 400;continue};$r=Start-ManualScan;if($r.ok){Send-Json $context $r 202}else{Send-Json $context $r 409};continue}
                    if($path-eq'/api/scheduler-action'){try{$b=Read-BodyJson $request 8192}catch{Send-Json $context @{ok=$false;error=$_.Exception.Message} 400;continue};$action=[string]$b.action;if($action-notin@('apply','remove')){Send-Json $context @{ok=$false;error='invalid_scheduler_action'} 400;continue};try{if($action-eq'apply'){& $schedulerTool -Operation Apply -OwnerApproved|Out-Null}else{& $schedulerTool -Operation Remove -OwnerApproved|Out-Null};$s=Get-SchedulerProjection;Send-Json $context @{ok=$true;scheduler=$s.data}}catch{Send-Json $context @{ok=$false;error='scheduler_action_failed';message=$_.Exception.Message} 409};continue}
                    if($path-eq'/api/approval'){
                        try{$b=Read-BodyJson $request 16384}catch{Send-Json $context @{ok=$false;error=$_.Exception.Message} 400;continue};$rid=[string]$b.request_id;$decision=([string]$b.decision).ToUpperInvariant();$clientHash=([string]$b.request_hash).ToLowerInvariant();if($rid-notmatch'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'-or$decision-notin@('APPROVE','DENY')-or$clientHash-notmatch'^[0-9a-f]{64}$'){Send-Json $context @{ok=$false;error='invalid_approval_request'} 400;continue}
                        $existing=@(Read-JsonLines (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') 1000|Where-Object{[string]$_.request_id-eq$rid}|Select-Object -Last 1);if($existing.Count){Send-Json $context @{ok=$false;error='approval_already_decided';decision=$existing[0]} 409;continue}
                        $reqMatches=@(Read-JsonLines (Join-Path $stateDir 'APPROVAL_REQUESTS.jsonl') 1000|Where-Object{[string]$_.request_id-eq$rid});if(-not$reqMatches.Count){Send-Json $context @{ok=$false;error='approval_request_not_found'} 404;continue};if($reqMatches.Count-ne1){Send-Json $context @{ok=$false;error='approval_request_conflict';message='This approval request ID appears more than once. Refresh or regenerate the request before deciding.'} 409;continue};$req=$reqMatches[0];$currentHash=Get-ApprovalRequestHash $req;if(-not[string]::Equals($clientHash,$currentHash,[StringComparison]::OrdinalIgnoreCase)){Send-Json $context @{ok=$false;error='approval_request_changed_refresh_required';message='This request changed after it was displayed. Refresh before deciding.'} 409;continue}
                        if([string]$req.risk-notin@('LOW','MEDIUM','HIGH','PROTECTED')-or-not$req.finding_id-or-not$req.change_summary-or@($req.evidence_refs).Count-lt1-or@($req.target_paths).Count-lt1){Send-Json $context @{ok=$false;error='approval_request_invalid'} 409;continue}
                        $safe=$true;foreach($ev in @($req.evidence_refs)){if(-not(Safe-ViewPath ([string]$ev))){$safe=$false}};if(-not$safe){Send-Json $context @{ok=$false;error='approval_evidence_missing_or_unsafe'} 409;continue}
                        $pol=Get-PolicyProjection;if(-not$pol.ok-or$req.policy_revision-ne$pol.data.policy_revision){Send-Json $context @{ok=$false;error='approval_request_stale_policy_revision'} 409;continue}
                        $record=[ordered]@{request_id=$rid;request_hash=$currentHash;decided_at=(Get-Date).ToString('o');decision=$decision;finding_id=$req.finding_id;change_summary=[string]$req.change_summary;policy_revision=$req.policy_revision}
                        if($decision-eq'DENY'){Append-JsonLine (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') $record;Send-Json $context @{ok=$true;decision=$record};continue}
                        $args=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$authTool,'-Risk',[string]$req.risk,'-Category',[string]$req.category,'-FindingId',[string]$req.finding_id,'-ChangeSummary',[string]$req.change_summary,'-EvidenceRef');$args+=@($req.evidence_refs|ForEach-Object{[string]$_});$args+='-TargetPath';$args+=@($req.target_paths|ForEach-Object{[string]$_});if($req.expected_behavior_proven-eq$true){$args+='-ExpectedBehaviorProven'};if($req.reversible-eq$true){$args+='-Reversible'}
                        $out=& $hostExe @args 2>&1|Out-String;$rc=$LASTEXITCODE;if($rc-ne0-or$out-notmatch'CHANGE_AUTHORIZATION=ALLOW'-or$out-notmatch'AUTHORIZATION_ID=([A-Za-z0-9]+)'){$record.decision='SYSTEM_DENIED';$record.reason=$out.Substring(0,[Math]::Min(1000,$out.Length));Append-JsonLine (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') $record;Send-Json $context @{ok=$false;error='canonical_authorization_denied';decision=$record} 409;continue};$record.authorization_id=$Matches[1];Append-JsonLine (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') $record;Send-Json $context @{ok=$true;decision=$record};continue
                    }
                    if($path-eq'/api/recovery'){
                        try{$b=Read-BodyJson $request 8192}catch{Send-Json $context @{ok=$false;error=$_.Exception.Message} 400;continue};if([string]$b.action-ne'reset_policy_to_observe_only'){Send-Json $context @{ok=$false;error='invalid_recovery_action'} 400;continue}
                        $template=Read-JsonFile $ownerTemplate;if($null-eq$template){Send-Json $context @{ok=$false;error='safe_policy_template_invalid'} 500;continue};$template.permissions.preset='REPORT_ONLY';$template.permissions.custom_auto_change_risks=@();$template.permissions.custom_categories=@();$template.schedule.enabled=$false;$template.schedule.executor_mode='UNCONFIGURED';$template.schedule.executor.command='';$template.schedule.executor.arguments=@();$temp=Join-Path $stateDir ('.owner-policy-recovery-'+[guid]::NewGuid().ToString('N')+'.json')
                        try{$template|ConvertTo-Json -Depth 30|Set-Content $temp -Encoding UTF8;& $policyTool -Operation Apply -PolicyJsonPath $temp -OwnerApproved -ApprovalSource dashboard_local_control|Out-Null;$schedulerError=$null;try{& $schedulerTool -Operation Remove -OwnerApproved|Out-Null}catch{$schedulerError=$_.Exception.Message};$saved=(Get-PolicyProjection).data;$registration=Read-JsonFile (Join-Path $stateDir 'SCHEDULER_REGISTRATION.json');if(Test-Path $refreshTool){& $refreshTool -ProjectPath $ProjectPath|Out-Null};if($schedulerError-or($null-ne$registration-and[string]$registration.status-ne'DISABLED')){Send-Json $context @{ok=$false;error='recovery_scheduler_cleanup_failed';policy_safe=$true;message='Permissions were reset to Observe only, but PUNTASH QA could not prove that the automatic scan registration was removed. Automatic remediation remains blocked; repair the scheduler before relying on scan timing.';policy=$saved;scheduler_state=[string]$registration.status} 409}else{Send-Json $context @{ok=$true;message='Permission settings were reset to Observe only and automatic scan registration was removed.';policy=$saved}}}catch{Send-Json $context @{ok=$false;error='recovery_failed';message=$_.Exception.Message} 409}finally{Remove-Item $temp -Force -ErrorAction SilentlyContinue};continue
                    }
                    if($path-eq'/api/policy'){
                        try{$candidate=Read-BodyJson $request 65536}catch{Send-Json $context @{ok=$false;error=$_.Exception.Message} 400;continue};$temp=Join-Path $stateDir ('.owner-policy-candidate-'+[guid]::NewGuid().ToString('N')+'.json')
                        try{$candidate|ConvertTo-Json -Depth 30|Set-Content $temp -Encoding UTF8;& $policyTool -Operation Apply -PolicyJsonPath $temp -OwnerApproved -ApprovalSource dashboard_local_control|Out-Null;if($candidate.schedule.enabled){try{& $schedulerTool -Operation Apply -OwnerApproved|Out-Null}catch{}}else{try{& $schedulerTool -Operation Remove -OwnerApproved|Out-Null}catch{}};$saved=(Get-PolicyProjection).data;$sched=(Get-SchedulerProjection).data;if(Test-Path $refreshTool){& $refreshTool -ProjectPath $ProjectPath|Out-Null};Send-Json $context @{ok=$true;policy=$saved;scheduler=$sched}}catch{Send-Json $context @{ok=$false;error='policy_update_rejected';message=$_.Exception.Message} 400}finally{Remove-Item $temp -Force -ErrorAction SilentlyContinue};continue
                    }
                }
                Send-Json $context @{ok=$false;error='not_found'} 404;continue
            }
            if($request.HttpMethod-ne'GET'){Send-Text $context 'Method Not Allowed' 'text/plain' 405;continue}
            $rel=$path.TrimStart('/');if([string]::IsNullOrWhiteSpace($rel)-or$rel-eq'index.html'){$rel='dashboard/index.html'};if($rel-ne'dashboard/index.html'){Send-Text $context 'Not Found' 'text/plain' 404;continue};$file=Join-Path $installRoot 'dashboard\index.html';if(-not(Test-Path $file -PathType Leaf)){Send-Text $context 'Not Found' 'text/plain' 404;continue};Send-Bytes $context ([IO.File]::ReadAllBytes($file)) 'text/html; charset=utf-8'
        } catch { try { Send-Json $context @{ok=$false;error='server_error'} 500 } catch {} }
        finally {if($mutationHeld){Exit-DashboardMutationLock}}
    }
} finally {
    if($listener.IsListening){$listener.Stop()};$listener.Close();if($script:dashboardMutationMutex){$script:dashboardMutationMutex.Dispose()};Write-Host 'DASHBOARD_CONTROL_STOPPED=1'
}
