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
function Get-Diagnostics {
    $issues=@();$p=Get-PolicyProjection;$s=Get-SchedulerSnapshot;$a=Get-AcceptanceProjection;$l=Get-LegalProjection
    if(-not$p.ok){$issues+=@{code='POLICY_INVALID';severity='ACTION';title='Permission settings need repair';message='PUNTASH QA could not verify your permission settings. Automatic changes stay blocked until this is repaired.';action='RESET_POLICY'}}
    if(-not$l.valid){$issues+=@{code='LEGAL_INVALID';severity='ACTION';title='Installation integrity needs attention';message=$l.reason;action=$null}}
    if(-not$a.valid){$issues+=@{code='ACCEPTANCE_INVALID';severity='ACTION';title='Terms acceptance needs attention';message=$a.reason;action=$null}}
    $state='NOT_CONFIGURED';if($s.ok -and $null-ne$s.data.registration){$state=[string]$s.data.registration.status}
    if($state-in@('POLICY_INVALID','REGISTRATION_STATE_INVALID','SCHEDULER_STATUS_ERROR','STALE_LOCAL_REGISTRATION','MISSING_LOCAL_REGISTRATION','BLOCKED')){$issues+=@{code=$state;severity='ACTION';title='Automatic scan setup needs attention';message=[string]$s.data.registration.message;action='RETRY_SCHEDULER'}}
    elseif($state-in@('NEEDS_PLATFORM_ACTIVATION','NEEDS_PLATFORM_UPDATE','NEEDS_PLATFORM_DEACTIVATION')){$issues+=@{code=$state;severity='INFO';title='Your AI platform still has one scheduling step';message=[string]$s.data.registration.message;action=$null}}
    return [pscustomobject]@{ok=(@($issues|Where-Object{$_.severity-eq'ACTION'}).Count-eq0);issues=@($issues);policy=@{valid=$p.ok};scheduler=@{valid=$s.ok;state=$state};acceptance=$a;legal=$l;control=@{bind='127.0.0.1';local_only=$true;telemetry=$false}}
}
function Get-ReleaseReadiness($Data){
    $runs=@($Data.runs);if(-not$runs.Count){return @{state='NOT_SCANNED';label='Could not verify';ready=$false;reasons=@('Run a full scan before deciding whether this project is ready to release.')}}
    $r=$runs[0];$fail=[int]$r.summary.fail;$blocked=[int]$r.summary.blocked;$nr=[int]$r.summary.not_run
    if($fail-or$blocked){$why=@();if($fail){$why+="$fail quality check(s) found a problem."};if($blocked){$why+="$blocked quality check(s) could not be completed."};return @{state='NOT_READY';label='Not yet';ready=$false;reasons=$why}}
    if($nr){return @{state='INCOMPLETE';label='Could not fully verify';ready=$false;reasons=@("$nr quality check(s) were not run.")}}
    if(@($r.gates).Count-ne25-or@($r.lenses).Count-ne9){return @{state='INCOMPLETE';label='Could not fully verify';ready=$false;reasons=@('The latest scan does not contain the complete 25-check and 9-lens record.')}}
    $record=[string]$r._dashboard_record;if([string]::IsNullOrWhiteSpace($record)-or$record-match'[\\/]' -or $record-notmatch'\.json$'){return @{state='INCOMPLETE';label='Could not fully verify';ready=$false;reasons=@('The latest structured scan record is unavailable.')}}
    $runPath=Join-Path $installRoot ('reports\dashboard\'+$record);if(-not(Test-Path $runPath -PathType Leaf)){return @{state='INCOMPLETE';label='Could not fully verify';ready=$false;reasons=@('The latest structured scan record is unavailable.')}}
    $validator=Join-Path $PSScriptRoot 'validate-run.ps1'
    try{
        $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName=$hostExe;$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;foreach($arg in @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$validator,'-RunPath',$runPath)){[void]$psi.ArgumentList.Add([string]$arg)};$proc=[Diagnostics.Process]::Start($psi);if(-not$proc.WaitForExit(30000)){try{$proc.Kill($true)}catch{};return @{state='INCOMPLETE';label='Could not fully verify';ready=$false;reasons=@('The latest scan record validation timed out.')}};if($proc.ExitCode-ne0){return @{state='INCOMPLETE';label='Could not fully verify';ready=$false;reasons=@('The latest scan record did not pass PUNTASH QA evidence validation.')}}
    }catch{return @{state='INCOMPLETE';label='Could not fully verify';ready=$false;reasons=@('The latest scan record could not be validated.')}}
    return @{state='READY';label='Ready';ready=$true;reasons=@('The latest complete scan passed structured evidence validation.')}
}
function Get-Activity($Data){$events=@();foreach($r in @($Data.runs|Select-Object -First 40)){if($r.completed_at){$events+=@{at=[string]$r.completed_at;type='SCAN_COMPLETED';title='Scan completed';detail="$($r.summary.pass) checked OK · $($r.summary.fail) problems · $($r.summary.blocked) incomplete";run_id=$r.run_id}};if($r.started_at){$events+=@{at=[string]$r.started_at;type='SCAN_STARTED';title='Scan started';detail='PUNTASH QA started checking the project.';run_id=$r.run_id}};foreach($e in @($r.automatic_remediation.entries)){if($null-ne$e){$events+=@{at=[string]$r.completed_at;type='REMEDIATION';title='Safe change recorded';detail=[string]$e.change_summary;finding_id=$e.finding_id;authorization_id=$e.authorization_id}}}}
    foreach($h in Read-JsonLines (Join-Path $stateDir 'OWNER_POLICY_HISTORY.jsonl') 80){$events+=@{at=[string]$h.changed_at;type='POLICY';title='Permissions or schedule changed';detail="Mode: $($h.preset) · automatic scans: $(if($h.schedule_enabled){'on'}else{'off'})";policy_revision=$h.revision}}
    foreach($h in Read-JsonLines (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') 80){$events+=@{at=[string]$h.decided_at;type='APPROVAL';title="Change request $(if($h.decision-eq'APPROVE'){'approved'}else{'not approved'})";detail=[string]$h.change_summary;request_id=$h.request_id;authorization_id=$h.authorization_id}}
    return @($events|Where-Object{$_.at}|Sort-Object at -Descending|Select-Object -First 120)
}
function Get-Approvals {
    $reqs=Read-JsonLines (Join-Path $stateDir 'APPROVAL_REQUESTS.jsonl') 500;$decisions=Read-JsonLines (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') 500;$map=@{};foreach($d in $decisions){if($d.request_id){$map[[string]$d.request_id]=$d}}
    $out=@();foreach($r in $reqs){$id=[string]$r.request_id;if($id-notmatch'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'){continue};$out+=@{request_id=$id;created_at=[string]$r.created_at;policy_revision=$r.policy_revision;finding_id=[string]$r.finding_id;risk=[string]$r.risk;category=[string]$r.category;change_summary=([string]$r.change_summary).Substring(0,[Math]::Min(1000,([string]$r.change_summary).Length));evidence_refs=@($r.evidence_refs|Select-Object -First 16);target_paths=@($r.target_paths|Select-Object -First 32);expected_behavior_proven=($r.expected_behavior_proven-eq$true);reversible=($r.reversible-eq$true);decision=$map[$id]}}
    return @($out|Sort-Object created_at -Descending|Select-Object -First 100)
}
function Start-ManualScan {
    if($script:scanProcess -and -not$script:scanProcess.HasExited){return [pscustomobject]@{ok=$false;error='scan_already_running';message='A scan is already running.'}}
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
        try {
            $request=$context.Request;$path=$request.Url.AbsolutePath
            if($path-like'/api/*'){
                if(-not(Authorized $request)){Send-Json $context @{ok=$false;error='unauthorized'} 403;continue}
                if($request.HttpMethod-eq'GET'){
                    if($path-eq'/api/dashboard-data'){$d=Get-DashboardData;Send-Json $context @{ok=$true;data=$d};continue}
                    if($path-eq'/api/overview'){$d=Get-DashboardData;Send-Json $context @{ok=$true;overview=@{data=$d;policy=(Get-PolicyProjection);scheduler=(Get-SchedulerSnapshot);release_readiness=(Get-ReleaseReadiness $d);diagnostics=(Get-Diagnostics)}};continue}
                    if($path-eq'/api/activity'){$d=Get-DashboardData;Send-Json $context @{ok=$true;activity=@(Get-Activity $d)};continue}
                    if($path-eq'/api/policy'){$p=Get-PolicyProjection;if($p.ok){Send-Json $context @{ok=$true;policy=$p.data}}else{Send-Json $context @{ok=$false;error=$p.error;details=$p.message} 409};continue}
                    if($path-eq'/api/scheduler'){$s=Get-SchedulerProjection;if($s.ok){Send-Json $context @{ok=$true;scheduler=$s.data}}else{Send-Json $context @{ok=$false;error=$s.error;details=$s.message} 409};continue}
                    if($path-eq'/api/scan-status'){$st=Read-JsonFile (Join-Path $stateDir 'MANUAL_SCAN_STATUS.json');if($null-eq$st){$st=[pscustomobject]@{last_result='NOT_RUN';message='No manual scan has been started yet.'}};$active=(($script:scanProcess -and -not $script:scanProcess.HasExited) -or ([string]$st.last_result -eq 'RUNNING'));Send-Json $context @{ok=$true;active=$active;scan=$st};continue}
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
                        try{$b=Read-BodyJson $request 16384}catch{Send-Json $context @{ok=$false;error=$_.Exception.Message} 400;continue};$rid=[string]$b.request_id;$decision=([string]$b.decision).ToUpperInvariant();if($rid-notmatch'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'-or$decision-notin@('APPROVE','DENY')){Send-Json $context @{ok=$false;error='invalid_approval_request'} 400;continue}
                        $existing=@(Read-JsonLines (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') 1000|Where-Object{[string]$_.request_id-eq$rid}|Select-Object -Last 1);if($existing.Count){Send-Json $context @{ok=$false;error='approval_already_decided';decision=$existing[0]} 409;continue}
                        $req=@(Read-JsonLines (Join-Path $stateDir 'APPROVAL_REQUESTS.jsonl') 1000|Where-Object{[string]$_.request_id-eq$rid}|Select-Object -Last 1);if(-not$req.Count){Send-Json $context @{ok=$false;error='approval_request_not_found'} 404;continue};$req=$req[0]
                        if([string]$req.risk-notin@('LOW','MEDIUM','HIGH','PROTECTED')-or-not$req.finding_id-or-not$req.change_summary-or@($req.evidence_refs).Count-lt1-or@($req.target_paths).Count-lt1){Send-Json $context @{ok=$false;error='approval_request_invalid'} 409;continue}
                        $safe=$true;foreach($ev in @($req.evidence_refs)){if(-not(Safe-ViewPath ([string]$ev))){$safe=$false}};if(-not$safe){Send-Json $context @{ok=$false;error='approval_evidence_missing_or_unsafe'} 409;continue}
                        $pol=Get-PolicyProjection;if(-not$pol.ok-or$req.policy_revision-ne$pol.data.policy_revision){Send-Json $context @{ok=$false;error='approval_request_stale_policy_revision'} 409;continue}
                        $record=[ordered]@{request_id=$rid;decided_at=(Get-Date).ToString('o');decision=$decision;finding_id=$req.finding_id;change_summary=[string]$req.change_summary;policy_revision=$req.policy_revision}
                        if($decision-eq'DENY'){Append-JsonLine (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') $record;Send-Json $context @{ok=$true;decision=$record};continue}
                        $args=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$authTool,'-Risk',[string]$req.risk,'-Category',[string]$req.category,'-FindingId',[string]$req.finding_id,'-ChangeSummary',[string]$req.change_summary,'-EvidenceRef');$args+=@($req.evidence_refs|ForEach-Object{[string]$_});$args+='-TargetPath';$args+=@($req.target_paths|ForEach-Object{[string]$_});if($req.expected_behavior_proven-eq$true){$args+='-ExpectedBehaviorProven'};if($req.reversible-eq$true){$args+='-Reversible'}
                        $out=& $hostExe @args 2>&1|Out-String;$rc=$LASTEXITCODE;if($rc-ne0-or$out-notmatch'CHANGE_AUTHORIZATION=ALLOW'-or$out-notmatch'AUTHORIZATION_ID=([A-Za-z0-9]+)'){$record.decision='SYSTEM_DENIED';$record.reason=$out.Substring(0,[Math]::Min(1000,$out.Length));Append-JsonLine (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') $record;Send-Json $context @{ok=$false;error='canonical_authorization_denied';decision=$record} 409;continue};$record.authorization_id=$Matches[1];Append-JsonLine (Join-Path $stateDir 'OWNER_APPROVAL_DECISIONS.jsonl') $record;Send-Json $context @{ok=$true;decision=$record};continue
                    }
                    if($path-eq'/api/recovery'){
                        try{$b=Read-BodyJson $request 8192}catch{Send-Json $context @{ok=$false;error=$_.Exception.Message} 400;continue};if([string]$b.action-ne'reset_policy_to_observe_only'){Send-Json $context @{ok=$false;error='invalid_recovery_action'} 400;continue}
                        $template=Read-JsonFile $ownerTemplate;if($null-eq$template){Send-Json $context @{ok=$false;error='safe_policy_template_invalid'} 500;continue};$template.permissions.preset='REPORT_ONLY';$template.permissions.custom_auto_change_risks=@();$template.permissions.custom_categories=@();$template.schedule.enabled=$false;$template.schedule.executor_mode='UNCONFIGURED';$template.schedule.executor.command='';$template.schedule.executor.arguments=@();$temp=Join-Path $stateDir ('.owner-policy-recovery-'+[guid]::NewGuid().ToString('N')+'.json')
                        try{$template|ConvertTo-Json -Depth 30|Set-Content $temp -Encoding UTF8;& $policyTool -Operation Apply -PolicyJsonPath $temp -OwnerApproved -ApprovalSource dashboard_local_control|Out-Null;try{& $schedulerTool -Operation Remove -OwnerApproved|Out-Null}catch{};$saved=(Get-PolicyProjection).data;if(Test-Path $refreshTool){& $refreshTool -ProjectPath $ProjectPath|Out-Null};Send-Json $context @{ok=$true;message='Permission settings were reset to Observe only. Automatic scans are off.';policy=$saved}}catch{Send-Json $context @{ok=$false;error='recovery_failed';message=$_.Exception.Message} 409}finally{Remove-Item $temp -Force -ErrorAction SilentlyContinue};continue
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
    }
} finally {
    if($listener.IsListening){$listener.Stop()};$listener.Close();Write-Host 'DASHBOARD_CONTROL_STOPPED=1'
}
