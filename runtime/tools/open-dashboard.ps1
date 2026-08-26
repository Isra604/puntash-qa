param([string]$ProjectPath)
$ErrorActionPreference='Stop'
$installRoot=Split-Path -Parent $PSScriptRoot
if(-not $ProjectPath){$ProjectPath=Split-Path -Parent $installRoot}
$refresh=Join-Path $PSScriptRoot 'dashboard-refresh.ps1'
if(Test-Path $refresh){& $refresh -ProjectPath $ProjectPath|Out-Host}
$index=Join-Path $installRoot 'dashboard\index.html'
if(-not(Test-Path $index)){throw "Dashboard not found: $index"}
Start-Process $index
Write-Host "DASHBOARD_OPENED=$index"
