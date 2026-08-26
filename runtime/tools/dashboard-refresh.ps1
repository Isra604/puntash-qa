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
New-Item -ItemType Directory -Path $runDir -Force|Out-Null
New-Item -ItemType Directory -Path $dashDir -Force|Out-Null
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
$data=[ordered]@{schema_version=1;generated_at=(Get-Date).ToString('o');system_version=$version;project_path=$project;run_count=$runs.Count;update=$updateState;runs=$runs}
$json=$data|ConvertTo-Json -Depth 20 -Compress
Set-Content (Join-Path $dashDir 'data.js') ("window.QA_DASHBOARD_DATA = $json;") -Encoding UTF8
Write-Host "DASHBOARD_REFRESHED=$($runs.Count)"
Write-Host "DASHBOARD=$(Join-Path $dashDir 'index.html')"
