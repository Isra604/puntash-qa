param(
  [ValidateSet('Get','Apply')][string]$Operation='Get',
  [string]$PolicyJsonPath,
  [switch]$OwnerApproved,
  [ValidateSet('dashboard_local_control','agent_owner_conversation','installer_optional_setup','manual_cli','UNCONFIGURED')][string]$ApprovalSource='UNCONFIGURED',
  [string]$ProjectPath
)
$ErrorActionPreference='Stop'
$installRoot=Split-Path -Parent $PSScriptRoot
if(-not $ProjectPath){$ProjectPath=Split-Path -Parent $installRoot}
$stateDir=Join-Path $installRoot 'state';New-Item -ItemType Directory $stateDir -Force|Out-Null
$policyPath=Join-Path $stateDir 'OWNER_POLICY.json'
$templatePath=Join-Path $installRoot 'templates\OWNER_POLICY.json'
$permissionPath=Join-Path $installRoot 'config\permission-policy.json'
if(-not(Test-Path $permissionPath)){throw "Permission policy missing: $permissionPath"}
$perm=Get-Content $permissionPath -Raw|ConvertFrom-Json
function Initialize-Policy {
  if(-not(Test-Path $policyPath)){
    if(-not(Test-Path $templatePath)){throw 'OWNER_POLICY template missing.'}
    Copy-Item $templatePath $policyPath -Force
  }
}
function Hash-Text([string]$s){$bytes=[Text.Encoding]::UTF8.GetBytes($s);$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')}finally{$sha.Dispose()}}
function Validate-Policy($p){
  $errors=New-Object System.Collections.Generic.List[string]
  if([int]$p.schema_version-ne1){$errors.Add('schema_version must equal 1')}
  $presets=@($perm.presets.PSObject.Properties.Name)
  if($presets-notcontains[string]$p.permissions.preset){$errors.Add("invalid permissions preset: $($p.permissions.preset)")}
  $risks=@('LOW','MEDIUM')
  foreach($r in @($p.permissions.custom_auto_change_risks)){if($risks-notcontains[string]$r){$errors.Add("custom auto-change risk not allowed: $r")}}
  $allowedCats=@($perm.auto_change_categories)
  foreach($c in @($p.permissions.custom_categories)){
    if($allowedCats-notcontains[string]$c){$errors.Add("custom category not allowed: $c")}
    if(@($perm.hard_boundaries)-contains[string]$c){$errors.Add("hard boundary cannot be auto-authorized: $c")}
  }
  $sched=$p.schedule
  if($sched.frequency-notin@('DAILY','WEEKDAYS','WEEKLY')){$errors.Add("unsupported schedule frequency: $($sched.frequency)")}
  if([string]$sched.local_time-notmatch '^(?:[01]\d|2[0-3]):[0-5]\d$'){$errors.Add('schedule.local_time must be HH:mm')}
  if($sched.executor_mode-notin@('UNCONFIGURED','LOCAL_COMMAND','AGENT_MANAGED')){$errors.Add("invalid executor_mode: $($sched.executor_mode)")}
  if($sched.executor_mode-eq'LOCAL_COMMAND'-and[string]::IsNullOrWhiteSpace([string]$sched.executor.command)){$errors.Add('LOCAL_COMMAND requires executor.command')}
  $secretRegex='gh[op]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
  $serialized=$p|ConvertTo-Json -Depth 12 -Compress
  if($serialized-match$secretRegex){$errors.Add('OWNER_POLICY must not contain credentials/tokens/private keys')}
  if($errors.Count){throw ('Owner policy validation failed: '+($errors -join '; '))}
}
Initialize-Policy
if($Operation-eq'Get'){
  $p=Get-Content $policyPath -Raw|ConvertFrom-Json
  $p|ConvertTo-Json -Depth 12
  exit 0
}
if(-not $OwnerApproved){throw 'Policy mutation requires explicit human owner approval. An AI agent may pass this only after the owner directly chose the policy in the current interaction.'}
if($ApprovalSource-eq'UNCONFIGURED'){throw 'ApprovalSource is required for policy mutation.'}
if(-not $PolicyJsonPath -or -not(Test-Path $PolicyJsonPath -PathType Leaf)){throw 'PolicyJsonPath is required and must exist.'}
$new=Get-Content $PolicyJsonPath -Raw|ConvertFrom-Json
Validate-Policy $new
$oldRaw=Get-Content $policyPath -Raw
$old=ConvertFrom-Json $oldRaw
$revision=[int]$old.policy_revision+1
$new.configured=$true
$new.configured_at=(Get-Date).ToString('o')
$new.configured_via=$ApprovalSource
$new.policy_revision=$revision
$new.approval.approved_by_human=$true
$new.approval.approved_at=(Get-Date).ToString('o')
$new.approval.source=$ApprovalSource
$newRaw=$new|ConvertTo-Json -Depth 12
Validate-Policy ($newRaw|ConvertFrom-Json)
$temp="$policyPath.tmp.$([guid]::NewGuid().ToString('N'))"
Set-Content $temp $newRaw -Encoding UTF8
Move-Item $temp $policyPath -Force
$history=Join-Path $stateDir 'OWNER_POLICY_HISTORY.jsonl'
[ordered]@{
 changed_at=(Get-Date).ToString('o');revision=$revision;source=$ApprovalSource;owner_approved=$true;
 old_hash=(Hash-Text $oldRaw);new_hash=(Hash-Text $newRaw);preset=[string]$new.permissions.preset;
 schedule_enabled=[bool]$new.schedule.enabled;executor_mode=[string]$new.schedule.executor_mode
}|ConvertTo-Json -Compress|Add-Content $history -Encoding UTF8
Write-Host "OWNER_POLICY_APPLIED=1 REVISION=$revision PRESET=$($new.permissions.preset) SCHEDULE=$($new.schedule.enabled)"
