param([string]$ProjectPath)
$ErrorActionPreference='Stop'
$installRoot=Split-Path -Parent $PSScriptRoot
if(-not $ProjectPath){$ProjectPath=Split-Path -Parent $installRoot}
$control=Join-Path $PSScriptRoot 'dashboard-control.ps1'
if(Test-Path $control){
    $args="-NoProfile -ExecutionPolicy Bypass -File `"$control`" -ProjectPath `"$ProjectPath`""
    Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden
    Write-Host 'DASHBOARD_CONTROL_STARTED=1'
    exit 0
}
$refresh=Join-Path $PSScriptRoot 'dashboard-refresh.ps1'
if(Test-Path $refresh){& $refresh -ProjectPath $ProjectPath|Out-Host}
$index=Join-Path $installRoot 'dashboard\index.html'
if(-not(Test-Path $index)){throw "Dashboard not found: $index"}
Start-Process $index
Write-Host "DASHBOARD_OPENED_READ_ONLY=$index"
