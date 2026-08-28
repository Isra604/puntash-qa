param(
  [string]$ProjectPath,
  [int]$MaxRuns = 250
)
$ErrorActionPreference='Stop'
$installRoot=Split-Path -Parent $PSScriptRoot
if(-not $ProjectPath){$ProjectPath=Split-Path -Parent $installRoot}
$project=(Resolve-Path $ProjectPath).Path
$runDir=Join-Path $installRoot 'reports\dashboard'
$dashDir=Join-Path $installRoot 'dashboard'
$stateDir=Join-Path $installRoot 'state'
New-Item -ItemType Directory -Path $runDir -Force|Out-Null
New-Item -ItemType Directory -Path $dashDir -Force|Out-Null
New-Item -ItemType Directory -Path $stateDir -Force|Out-Null
$runs=@()
Get-ChildItem $runDir -Filter '*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
  try {
    $r=Get-Content $_.FullName -Raw|ConvertFrom-Json
    if(-not $r.run_id){throw 'run_id missing'}
    $runs += $r
  } catch { Write-Warning "Skipping invalid dashboard run $($_.Name): $($_.Exception.Message)" }
}
$runs=@($runs|Sort-Object {[string]$_.completed_at} -Descending|Select-Object -First $MaxRuns)
$version='unknown'
$meta=Join-Path $installRoot 'INSTALLATION.json'
if(Test-Path $meta){try{$version=[string]((Get-Content $meta -Raw|ConvertFrom-Json).version)}catch{}}
$updateState=$null;$updatePath=Join-Path $installRoot 'state\LAST_UPDATE_CHECK.json';if(Test-Path $updatePath){try{$updateState=Get-Content $updatePath -Raw|ConvertFrom-Json}catch{}}
$ownerPolicy=$null;$ownerPath=Join-Path $installRoot 'state\OWNER_POLICY.json';if(-not(Test-Path $ownerPath)){$ownerTemplate=Join-Path $installRoot 'templates\OWNER_POLICY.json';if(Test-Path $ownerTemplate){Copy-Item $ownerTemplate $ownerPath -Force}};if(Test-Path $ownerPath){try{$ownerPolicy=Get-Content $ownerPath -Raw|ConvertFrom-Json}catch{}}
$schedulerRegistration=$null;$schedulerPath=Join-Path $installRoot 'state\SCHEDULER_REGISTRATION.json';if(Test-Path $schedulerPath){try{$schedulerRegistration=Get-Content $schedulerPath -Raw|ConvertFrom-Json}catch{}}
$schedulerStatus=$null;$schedulerRunPath=Join-Path $installRoot 'state\SCHEDULER_STATUS.json';if(Test-Path $schedulerRunPath){try{$schedulerStatus=Get-Content $schedulerRunPath -Raw|ConvertFrom-Json}catch{}}
$data=[ordered]@{schema_version=2;generated_at=(Get-Date).ToString('o');system_version=$version;project_path=$project;run_count=$runs.Count;update=$updateState;owner_policy=$ownerPolicy;scheduler_registration=$schedulerRegistration;scheduler_status=$schedulerStatus;runs=$runs}
$json=$data|ConvertTo-Json -Depth 20 -Compress
Set-Content (Join-Path $dashDir 'data.js') ("window.QA_DASHBOARD_DATA = $json;") -Encoding UTF8
Write-Host "DASHBOARD_REFRESHED=$($runs.Count)"
Write-Host "DASHBOARD=$(Join-Path $dashDir 'index.html')"
