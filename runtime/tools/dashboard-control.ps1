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
if (-not (Test-Path $ownerPolicyPath)) { Copy-Item $ownerTemplate $ownerPolicyPath -Force }
$refreshTool = Join-Path $PSScriptRoot 'dashboard-refresh.ps1'
$policyTool = Join-Path $PSScriptRoot 'policy-manager.ps1'
$schedulerTool = Join-Path $PSScriptRoot 'scheduler.ps1'
if (Test-Path $refreshTool) { & $refreshTool -ProjectPath $ProjectPath | Out-Null }

if ($Port -eq 0) {
    $probe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $probe.Start()
    $Port = ([Net.IPEndPoint]$probe.LocalEndpoint).Port
    $probe.Stop()
}
if (-not $ControlToken) {
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $ControlToken = ([BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
}
$baseUrl = "http://127.0.0.1:$Port/"
$listener = [Net.HttpListener]::new()
$listener.Prefixes.Add($baseUrl)
$listener.Start()
$lastActivity = Get-Date

function Set-CommonHeaders($response) {
    $response.Headers['Cache-Control'] = 'no-store'
    $response.Headers['X-Content-Type-Options'] = 'nosniff'
    $response.Headers['Referrer-Policy'] = 'no-referrer'
    $response.Headers['Content-Security-Policy'] = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none'; base-uri 'none'"
}
function Send-Bytes($context, [byte[]]$bytes, [string]$contentType, [int]$statusCode = 200) {
    $context.Response.StatusCode = $statusCode
    $context.Response.ContentType = $contentType
    Set-CommonHeaders $context.Response
    $context.Response.ContentLength64 = $bytes.Length
    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $context.Response.OutputStream.Close()
}
function Send-Text($context, [string]$text, [string]$contentType = 'text/plain; charset=utf-8', [int]$statusCode = 200) {
    Send-Bytes $context ([Text.Encoding]::UTF8.GetBytes($text)) $contentType $statusCode
}
function Send-Json($context, $object, [int]$statusCode = 200) {
    Send-Text $context ($object | ConvertTo-Json -Depth 20 -Compress) 'application/json; charset=utf-8' $statusCode
}
function Authorized($request) {
    $token = [string]$request.Headers['X-QA-Control-Token']
    if ($token -ne $ControlToken) { return $false }
    $origin = [string]$request.Headers['Origin']
    if ($origin -and $origin -ne $baseUrl.TrimEnd('/')) { return $false }
    return $true
}
function Safe-StaticPath([string]$urlPath) {
    $path = $urlPath.TrimStart('/')
    if ([string]::IsNullOrWhiteSpace($path) -or $path -eq 'index.html') { $path = 'dashboard/index.html' }
    elseif ($path -eq 'data.js') { $path = 'dashboard/data.js' }
    if ($path -ne 'dashboard/index.html') { return $null }
    return Join-Path $installRoot ($path.Replace('/', [IO.Path]::DirectorySeparatorChar))
}
function Safe-ReportPath([string]$relative) {
    if ([string]::IsNullOrWhiteSpace($relative)) { return $null }
    $decoded=[Uri]::UnescapeDataString($relative).Replace('/',[IO.Path]::DirectorySeparatorChar).TrimStart([IO.Path]::DirectorySeparatorChar)
    if ($decoded.Split([IO.Path]::DirectorySeparatorChar) -contains '..') { return $null }
    if ($decoded.StartsWith('reports'+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { $decoded=$decoded.Substring(8) }
    $reportsRoot=[IO.Path]::GetFullPath((Join-Path $installRoot 'reports'))+[IO.Path]::DirectorySeparatorChar
    $candidate=[IO.Path]::GetFullPath((Join-Path $installRoot ('reports'+[IO.Path]::DirectorySeparatorChar+$decoded)))
    if(-not $candidate.StartsWith($reportsRoot,[StringComparison]::OrdinalIgnoreCase)){return $null}
    if([IO.Path]::GetExtension($candidate).ToLowerInvariant() -notin @('.md','.txt','.json')){return $null}
    return $candidate
}
function Content-Type([string]$path) {
    switch ([IO.Path]::GetExtension($path).ToLowerInvariant()) {
        '.html' { return 'text/html; charset=utf-8' }
        '.js' { return 'application/javascript; charset=utf-8' }
        '.json' { return 'application/json; charset=utf-8' }
        '.md' { return 'text/plain; charset=utf-8' }
        '.txt' { return 'text/plain; charset=utf-8' }
        default { return 'application/octet-stream' }
    }
}

Write-Host "DASHBOARD_CONTROL_URL=$baseUrl"
Write-Host 'DASHBOARD_CONTROL_BIND=127.0.0.1'
if (-not $NoBrowser) {
    Start-Process ($baseUrl + '#token=' + $ControlToken)
}

try {
    while ($listener.IsListening) {
        $contextTask = $listener.GetContextAsync()
        while (-not $contextTask.Wait(1000)) {
            if (((Get-Date) - $lastActivity).TotalMinutes -ge $IdleMinutes) { break }
        }
        if (-not $contextTask.IsCompleted) { break }
        $context = $contextTask.GetAwaiter().GetResult()
        $lastActivity = Get-Date
        try {
            $request = $context.Request
            $path = $request.Url.AbsolutePath
            if ($path -like '/api/*') {
                if (-not (Authorized $request)) {
                    Send-Json $context @{ok=$false;error='unauthorized'} 403
                    continue
                }
                if ($path -eq '/api/dashboard-data' -and $request.HttpMethod -eq 'GET') {
                    $dataPath=Join-Path $installRoot 'dashboard\data.js'
                    if(-not(Test-Path $dataPath -PathType Leaf)){Send-Json $context @{ok=$false;error='dashboard_data_not_found'} 404;continue}
                    $raw=Get-Content $dataPath -Raw
                    $json=$raw -replace '^\s*window\.QA_DASHBOARD_DATA\s*=\s*','' -replace ';\s*$',''
                    try{$data=$json|ConvertFrom-Json}catch{Send-Json $context @{ok=$false;error='dashboard_data_invalid'} 500;continue}
                    Send-Json $context @{ok=$true;data=$data}
                    continue
                }
                if ($path -eq '/api/report' -and $request.HttpMethod -eq 'GET') {
                    $reportFile=Safe-ReportPath ([string]$request.QueryString['path'])
                    if(-not $reportFile -or -not(Test-Path $reportFile -PathType Leaf)){Send-Json $context @{ok=$false;error='report_not_found'} 404;continue}
                    Send-Bytes $context ([IO.File]::ReadAllBytes($reportFile)) (Content-Type $reportFile)
                    continue
                }
                if ($path -eq '/api/policy' -and $request.HttpMethod -eq 'GET') {
                    try {
                        $policyRaw = & $policyTool -Operation Get | Out-String
                        $policy = $policyRaw | ConvertFrom-Json
                        Send-Json $context @{ok=$true;policy=$policy}
                    } catch {
                        Send-Json $context @{ok=$false;error='owner_policy_invalid';details=$_.Exception.Message} 409
                    }
                    continue
                }
                if ($path -eq '/api/scheduler' -and $request.HttpMethod -eq 'GET') {
                    $raw = & $schedulerTool -Operation Status | Out-String
                    $scheduler = $raw | ConvertFrom-Json
                    Send-Json $context @{ok=$true;scheduler=$scheduler}
                    continue
                }
                if ($path -eq '/api/policy' -and $request.HttpMethod -eq 'POST') {
                    if ($request.ContentLength64 -lt 0 -or $request.ContentLength64 -gt 65536) {
                        Send-Json $context @{ok=$false;error='invalid_body_size'} 413
                        continue
                    }
                    $reader = New-Object IO.StreamReader($request.InputStream, $request.ContentEncoding)
                    $body = $reader.ReadToEnd(); $reader.Dispose()
                    try { $candidate = $body | ConvertFrom-Json } catch { Send-Json $context @{ok=$false;error='invalid_json'} 400; continue }
                    $temp = Join-Path ([IO.Path]::GetTempPath()) ('qa-owner-policy-' + [guid]::NewGuid().ToString('N') + '.json')
                    try {
                        $candidate | ConvertTo-Json -Depth 20 | Set-Content $temp -Encoding UTF8
                        & $policyTool -Operation Apply -PolicyJsonPath $temp -OwnerApproved -ApprovalSource dashboard_local_control | Out-Null
                        $schedulerMessage = $null
                        $schedulerOk = $true
                        try {
                            if ($candidate.schedule.enabled) { & $schedulerTool -Operation Apply -OwnerApproved | Out-Null }
                            else { & $schedulerTool -Operation Remove -OwnerApproved | Out-Null }
                        } catch {
                            $schedulerOk = $false
                            $schedulerMessage = $_.Exception.Message
                        }
                        if (Test-Path $refreshTool) { & $refreshTool -ProjectPath $ProjectPath | Out-Null }
                        $saved = Get-Content $ownerPolicyPath -Raw | ConvertFrom-Json
                        $schedRaw = & $schedulerTool -Operation Status | Out-String
                        $sched = $schedRaw | ConvertFrom-Json
                        Send-Json $context @{ok=$true;policy=$saved;scheduler=$sched;scheduler_apply_ok=$schedulerOk;scheduler_message=$schedulerMessage}
                    } catch {
                        Send-Json $context @{ok=$false;error=$_.Exception.Message} 400
                    } finally {
                        Remove-Item $temp -Force -ErrorAction SilentlyContinue
                    }
                    continue
                }
                if ($path -eq '/api/shutdown' -and $request.HttpMethod -eq 'POST') {
                    Send-Json $context @{ok=$true;message='Control Center shutting down.'}
                    break
                }
                Send-Json $context @{ok=$false;error='not_found'} 404
                continue
            }
            if ($request.HttpMethod -ne 'GET') { Send-Text $context 'Method Not Allowed' 'text/plain' 405; continue }
            $file = Safe-StaticPath $path
            if (-not $file -or -not (Test-Path $file -PathType Leaf)) { Send-Text $context 'Not Found' 'text/plain' 404; continue }
            Send-Bytes $context ([IO.File]::ReadAllBytes($file)) (Content-Type $file)
        } catch {
            try { Send-Json $context @{ok=$false;error='server_error'} 500 } catch {}
        }
    }
} finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
    Write-Host 'DASHBOARD_CONTROL_STOPPED=1'
}
