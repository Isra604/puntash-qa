param(
  [string]$BackupPath
)
$ErrorActionPreference='Stop'
$installRoot=Split-Path -Parent $PSScriptRoot
$projectRoot=Split-Path -Parent $installRoot
$backupRoot=Join-Path $projectRoot '.comprehensive-qa-backups'
Add-Type -AssemblyName System.Windows.Forms
if(-not $BackupPath){
  if(-not(Test-Path $backupRoot)){throw 'No QA update backups were found.'}
  $BackupPath=(Get-ChildItem $backupRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if(-not(Test-Path $BackupPath)){throw "Backup not found: $BackupPath"}
$result=[System.Windows.Forms.MessageBox]::Show("Rollback the managed QA runtime to:`r`n$BackupPath`r`n`r`nReports, evidence and current project data will be preserved.",'Confirm QA System Rollback',[System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Warning)
if($result -ne [System.Windows.Forms.DialogResult]::Yes){Write-Host 'Rollback cancelled.';exit 4}
foreach($d in @('gates','templates','agent-guides')){$target=Join-Path $installRoot $d;if(Test-Path $target){Remove-Item $target -Recurse -Force};$source=Join-Path $BackupPath $d;if(Test-Path $source){Copy-Item $source $target -Recurse -Force}}
New-Item -ItemType Directory -Path (Join-Path $installRoot 'tools') -Force | Out-Null
Copy-Item (Join-Path $BackupPath 'tools\*') (Join-Path $installRoot 'tools') -Recurse -Force
foreach($f in @('AGENT_INSTRUCTIONS.md','START_HERE.md','LICENSE','NOTICE','CREDITS.md','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','TERMS_VERSION','LEGAL_MANIFEST.json','INSTALLATION.json')){$src=Join-Path $BackupPath $f;$dst=Join-Path $installRoot $f;if(Test-Path $src){Copy-Item $src $dst -Force}elseif($f -eq 'START_HERE.md' -and (Test-Path $dst)){Remove-Item $dst -Force}}
$uc=Join-Path $BackupPath 'config\update.json';if(Test-Path $uc){Copy-Item $uc (Join-Path $installRoot 'config\update.json') -Force}
$r=Join-Path $BackupPath 'state\HUMAN_ACCEPTANCE_RECEIPT.json';if(Test-Path $r){Copy-Item $r (Join-Path $installRoot 'state\HUMAN_ACCEPTANCE_RECEIPT.json') -Force}
[ordered]@{rolled_back_at=(Get-Date).ToString('o');backup=$BackupPath;status='SUCCESS'}|ConvertTo-Json -Compress|Add-Content (Join-Path $installRoot 'state\UPDATE_HISTORY.jsonl') -Encoding UTF8
Write-Host "ROLLBACK_SUCCESS=$BackupPath"
