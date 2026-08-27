param(
 [Parameter(Mandatory=$true)][ValidateSet('LOW','MEDIUM','HIGH','PROTECTED')][string]$Risk,
 [Parameter(Mandatory=$true)][string]$Category,
 [Parameter(Mandatory=$true)][string]$FindingId,
 [Parameter(Mandatory=$true)][string]$ChangeSummary,
 [Parameter(Mandatory=$true)][string[]]$EvidenceRef,
 [switch]$ExpectedBehaviorProven,
 [switch]$Reversible
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$state=Join-Path $root 'state';New-Item -ItemType Directory $state -Force|Out-Null
$permPath=Join-Path $root 'config\permission-policy.json';if(-not(Test-Path $permPath)){$permPath=Join-Path $root 'templates\PERMISSION_POLICY.json'}
$policyTool=Join-Path $PSScriptRoot 'policy-manager.ps1'
$authorizationId=[guid]::NewGuid().ToString('N')
$decision='DENY';$reason='internal_error';$preset='UNKNOWN';$revision=$null
function Acquire-AuditLock {
 $path=Join-Path $state 'CHANGE_AUTHORIZATION.lock'
 for($i=0;$i-lt80;$i++){try{return [IO.File]::Open($path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{Start-Sleep -Milliseconds 125}}
 throw 'Timed out waiting for change-authorization audit lock.'
}
function Finish([int]$code){
 $lock=$null
 try{
  $lock=Acquire-AuditLock
  [ordered]@{authorization_id=$authorizationId;decided_at=(Get-Date).ToString('o');decision=$decision;reason=$reason;policy_revision=$revision;preset=$preset;risk=$Risk;category=$Category;finding_id=$FindingId;change_summary=$ChangeSummary;evidence_refs=@($EvidenceRef);expected_behavior_proven=[bool]$ExpectedBehaviorProven;reversible=[bool]$Reversible}|ConvertTo-Json -Depth 8 -Compress|Add-Content (Join-Path $state 'CHANGE_AUTHORIZATION_HISTORY.jsonl') -Encoding UTF8
 }finally{if($lock){$lock.Dispose()}}
 Write-Host "CHANGE_AUTHORIZATION=$decision REASON=$reason AUTHORIZATION_ID=$authorizationId PRESET=$preset RISK=$Risk CATEGORY=$Category"
 exit $code
}
if([string]::IsNullOrWhiteSpace($FindingId)-or$FindingId.Length-gt128){$reason='finding_id_invalid';Finish 10}
if([string]::IsNullOrWhiteSpace($ChangeSummary)-or$ChangeSummary.Length-gt1000){$reason='change_summary_invalid';Finish 10}
if(-not$EvidenceRef -or @($EvidenceRef).Count-gt16 -or @($EvidenceRef|Where-Object{[string]::IsNullOrWhiteSpace($_)-or$_.Length-gt2048}).Count){$reason='evidence_refs_required_or_invalid';Finish 10}
try{$p=(& $policyTool -Operation Get|Out-String)|ConvertFrom-Json;$perm=Get-Content $permPath -Raw|ConvertFrom-Json}catch{$reason='owner_policy_or_permission_policy_invalid';Finish 10}
$revision=$p.policy_revision;$preset=[string]$p.permissions.preset
if(-not$p.configured -or $p.approval.approved_by_human-ne$true){$reason='owner_policy_unconfigured';Finish 10}
if(@($perm.hard_boundaries)-contains$Category -or $Risk-in@('HIGH','PROTECTED')){$reason='high_or_protected_requires_owner_approval';Finish 10}
if(@($perm.auto_change_categories)-notcontains$Category){$reason='category_not_auto_changeable';Finish 10}
if(-not$ExpectedBehaviorProven){$reason='expected_behavior_not_proven';Finish 10}
if(-not$Reversible){$reason='automatic_change_must_be_reversible';Finish 10}
if($preset-eq'CUSTOM'){$risks=@($p.permissions.custom_auto_change_risks);$cats=@($p.permissions.custom_categories)}else{$risks=@($perm.presets.$preset.auto_change_risks);$cats=@($perm.auto_change_categories)}
if($risks-notcontains$Risk -or $cats-notcontains$Category){$reason='preset_ceiling';Finish 10}
$decision='ALLOW';$reason='within_owner_policy_ceiling';Finish 0
