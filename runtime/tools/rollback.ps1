param(
  [string]$BackupPath
)
$ErrorActionPreference='Stop'
$installRoot=Split-Path -Parent $PSScriptRoot
$projectRoot=Split-Path -Parent $installRoot
$backupRoot=Join-Path $projectRoot '.comprehensive-qa-backups'
$pathSafety=Join-Path $PSScriptRoot 'path-safety.ps1'
if(-not(Test-Path -LiteralPath $pathSafety -PathType Leaf)){throw 'Path-safety helper missing from installed runtime.'}
. $pathSafety
Assert-NoReparsePoint -Path $installRoot -Label 'installed QA runtime before rollback' -Recursive
Assert-PathWithin -Path $backupRoot -Root $projectRoot -Label 'rollback backup root'
Assert-NoReparsePoint -Path $backupRoot -Label 'rollback backup root' -Recursive
Add-Type -AssemblyName System.Windows.Forms
if(-not $BackupPath){
  if(-not(Test-Path $backupRoot)){throw 'No QA update backups were found.'}
  $BackupPath=(Get-ChildItem $backupRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if(-not(Test-Path -LiteralPath $BackupPath -PathType Container)){throw "Backup not found: $BackupPath"}
$BackupPath=(Resolve-Path -LiteralPath $BackupPath).Path
Assert-PathWithin -Path $BackupPath -Root $backupRoot -Label 'rollback backup selection' -MustExist
Assert-NoReparsePoint -Path $BackupPath -Label 'rollback backup selection' -Recursive
$result=[System.Windows.Forms.MessageBox]::Show("Rollback the managed QA runtime to:`r`n$BackupPath`r`n`r`nReports, evidence and current project data will be preserved.",'Confirm QA System Rollback',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning)
if($result -ne [System.Windows.Forms.DialogResult]::Yes){Write-Host 'Rollback cancelled.';exit 4}
$schedulerPreflight=Join-Path $installRoot 'tools\prepare-scheduler-for-rollback.ps1'
if(Test-Path $schedulerPreflight){
  $preflightOutput=& $schedulerPreflight -ProjectPath $projectRoot 2>&1
  $preflightRc=$LASTEXITCODE
  $preflightOutput|ForEach-Object{Write-Host $_}
  if($preflightRc-ne0){
    $externalLine=@($preflightOutput|Where-Object{[string]$_ -like 'EXTERNAL_ID=*'}|Select-Object -First 1)
    $externalId=if($externalLine){([string]$externalLine).Substring(12)}else{''}
    $message=if($preflightRc-eq13){"Rollback is blocked because an external AI/platform schedule is still recorded as active.`r`n`r`nExternal ID: $externalId`r`n`r`nDisable that schedule in the AI platform, confirm deactivation with the current v2.1 scheduler tool, then retry rollback."}else{"Rollback is blocked because scheduled execution could not be proven safely paused.`r`n`r`nNo managed runtime files were changed. Resolve the scheduler state and retry."}
    [System.Windows.Forms.MessageBox]::Show($message,'QA Rollback Blocked',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Warning)|Out-Null
    Write-Host "ROLLBACK_ABORTED_SCHEDULER_PREFLIGHT=$preflightRc"
    exit $preflightRc
  }
  Write-Host 'SCHEDULER_PAUSED_FOR_ROLLBACK=1'
}elseif(Test-Path (Join-Path $installRoot 'tools\scheduler.ps1')){
  throw 'Rollback scheduler preflight tool is missing from a runtime that contains scheduler support.'
}
foreach($d in @('gates','templates','agent-guides','dashboard','prompts')){$target=Join-Path $installRoot $d;Assert-PathWithin -Path $target -Root $installRoot -Label "rollback target $d";Assert-NoReparsePoint -Path $target -Label "rollback target $d" -Recursive;if(Test-Path $target){Remove-Item -LiteralPath $target -Recurse -Force};$source=Join-Path $BackupPath $d;if(Test-Path $source){Copy-Item $source $target -Recurse -Force}}
$toolsTarget=Join-Path $installRoot 'tools';Assert-PathWithin -Path $toolsTarget -Root $installRoot -Label 'rollback tools target';Assert-NoReparsePoint -Path $toolsTarget -Label 'rollback tools target' -Recursive;if(Test-Path $toolsTarget){Remove-Item -LiteralPath $toolsTarget -Recurse -Force};$toolsSource=Join-Path $BackupPath 'tools';if(Test-Path $toolsSource){Copy-Item $toolsSource $toolsTarget -Recurse -Force}
foreach($f in @('AGENT_INSTRUCTIONS.md','START_HERE.md','OPEN_DASHBOARD.cmd','LICENSE','NOTICE','CREDITS.md','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','TERMS_VERSION','LEGAL_MANIFEST.json','INSTALLATION.json')){$src=Join-Path $BackupPath $f;$dst=Join-Path $installRoot $f;if(Test-Path $src){Copy-Item $src $dst -Force}elseif($f -in @('START_HERE.md','OPEN_DASHBOARD.cmd') -and (Test-Path $dst)){Remove-Item $dst -Force}}
$uc=Join-Path $BackupPath 'config\update.json';if(Test-Path $uc){Copy-Item $uc (Join-Path $installRoot 'config\update.json') -Force}
$pc=Join-Path $BackupPath 'config\permission-policy.json';$pct=Join-Path $installRoot 'config\permission-policy.json';if(Test-Path $pc){Copy-Item $pc $pct -Force}elseif(Test-Path $pct){Remove-Item $pct -Force}
$schedulerRegistrationPath=Join-Path $installRoot 'state\SCHEDULER_REGISTRATION.json'
$priorRegistration=$null
if(Test-Path $schedulerRegistrationPath){try{$priorRegistration=Get-Content $schedulerRegistrationPath -Raw|ConvertFrom-Json}catch{}}
$paused=[ordered]@{updated_at=(Get-Date).ToString('o');status='PAUSED_AFTER_ROLLBACK';message='Scheduled execution was proven paused before rollback; owner policy/state were preserved.'}
if($priorRegistration){foreach($prop in $priorRegistration.PSObject.Properties){if(-not$paused.Contains($prop.Name)){$paused[$prop.Name]=$prop.Value}}}
$paused|ConvertTo-Json -Depth 12|Set-Content $schedulerRegistrationPath -Encoding UTF8
$r=Join-Path $BackupPath 'state\HUMAN_ACCEPTANCE_RECEIPT.json';if(Test-Path $r){Copy-Item $r (Join-Path $installRoot 'state\HUMAN_ACCEPTANCE_RECEIPT.json') -Force}
[ordered]@{rolled_back_at=(Get-Date).ToString('o');backup=$BackupPath;status='SUCCESS'}|ConvertTo-Json -Compress|Add-Content (Join-Path $installRoot 'state\UPDATE_HISTORY.jsonl') -Encoding UTF8
Write-Host "ROLLBACK_SUCCESS=$BackupPath"
