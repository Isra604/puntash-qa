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
New-Item -ItemType Directory -Path $runDir,$dashDir,$stateDir -Force|Out-Null
$runs=@()
Get-ChildItem $runDir -Filter '*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
  try {
    $r=Get-Content $_.FullName -Raw|ConvertFrom-Json
    if(-not $r.run_id){throw 'run_id missing'}
    $r|Add-Member -NotePropertyName '_dashboard_record' -NotePropertyValue $_.Name -Force
    $runs += $r
  } catch { Write-Warning "Skipping invalid dashboard run $($_.Name): $($_.Exception.Message)" }
}
$runs=@($runs|Sort-Object {[string]$_.completed_at} -Descending|Select-Object -First $MaxRuns)
function Read-JsonSafe([string]$Path){try{if(Test-Path $Path -PathType Leaf){return Get-Content $Path -Raw|ConvertFrom-Json}}catch{};return $null}
$version='unknown';$meta=Read-JsonSafe (Join-Path $installRoot 'INSTALLATION.json');if($meta){$version=[string]$meta.version}else{try{$version=(Get-Content (Join-Path (Split-Path -Parent $installRoot) 'VERSION') -Raw).Trim()}catch{}}
$updateState=Read-JsonSafe (Join-Path $stateDir 'LAST_UPDATE_CHECK.json')
$ownerPath=Join-Path $stateDir 'OWNER_POLICY.json';if(-not(Test-Path $ownerPath)){$ownerTemplate=Join-Path $installRoot 'templates\OWNER_POLICY.json';if(Test-Path $ownerTemplate){Copy-Item $ownerTemplate $ownerPath -Force}}
$ownerPolicy=Read-JsonSafe $ownerPath
$schedulerRegistration=Read-JsonSafe (Join-Path $stateDir 'SCHEDULER_REGISTRATION.json')
$schedulerStatus=Read-JsonSafe (Join-Path $stateDir 'SCHEDULER_STATUS.json')
$manualStatus=Read-JsonSafe (Join-Path $stateDir 'MANUAL_SCAN_STATUS.json')
$doctor=Read-JsonSafe (Join-Path $stateDir 'QA_DOCTOR.json')
$receipt=Read-JsonSafe (Join-Path $stateDir 'HUMAN_ACCEPTANCE_RECEIPT.json')
$terms='';try{$terms=(Get-Content (Join-Path $installRoot 'TERMS_VERSION') -Raw).Trim()}catch{}
$acceptance=[ordered]@{present=($null-ne$receipt);current_terms_version=$terms;accepted_terms_version=$(if($receipt){[string]$receipt.terms_version}else{$null});human_attested=$(if($receipt){$receipt.accepted_by_human_attestation-eq$true}else{$false});terms_match=$(if($receipt){[string]$receipt.terms_version-eq$terms}else{$false})}
$data=[ordered]@{schema_version=3;generated_at=(Get-Date).ToString('o');system_version=$version;project_path=$project;run_count=$runs.Count;update=$updateState;owner_policy=$ownerPolicy;scheduler_registration=$schedulerRegistration;scheduler_status=$schedulerStatus;manual_scan_status=$manualStatus;acceptance=$acceptance;qa_doctor=$doctor;runs=$runs}
$json=$data|ConvertTo-Json -Depth 30 -Compress
$dest=Join-Path $dashDir 'data.js';$tmp=$dest+'.tmp.'+[guid]::NewGuid().ToString('N');[IO.File]::WriteAllText($tmp,"window.QA_DASHBOARD_DATA = $json;`n",(New-Object Text.UTF8Encoding($false)));try{Move-Item -LiteralPath $tmp -Destination $dest -Force}finally{Remove-Item $tmp -Force -ErrorAction SilentlyContinue}
Write-Host "DASHBOARD_REFRESHED=$($runs.Count)"
Write-Host "DASHBOARD=$dest"
