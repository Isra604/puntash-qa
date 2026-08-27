param(
 [Parameter(Mandatory=$true)][ValidateSet('LOW','MEDIUM','HIGH','PROTECTED')][string]$Risk,
 [Parameter(Mandatory=$true)][string]$Category,
 [switch]$ExpectedBehaviorProven,
 [switch]$Reversible
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$policyPath=Join-Path $root 'state\OWNER_POLICY.json'
$permPath=Join-Path $root 'config\permission-policy.json';if(-not(Test-Path $permPath)){$permPath=Join-Path $root 'templates\PERMISSION_POLICY.json'}
function Deny([string]$reason){Write-Host "CHANGE_AUTHORIZATION=DENY REASON=$reason";exit 10}
if(-not(Test-Path $policyPath)){Deny 'owner_policy_missing'}
$p=Get-Content $policyPath -Raw|ConvertFrom-Json;$perm=Get-Content $permPath -Raw|ConvertFrom-Json
if(-not$p.configured -or -not$p.approval.approved_by_human){Deny 'owner_policy_unconfigured'}
if(@($perm.hard_boundaries)-contains$Category -or $Risk-in@('HIGH','PROTECTED')){Deny 'high_or_protected_requires_owner_approval'}
if(@($perm.auto_change_categories)-notcontains$Category){Deny 'category_not_auto_changeable'}
if(-not$ExpectedBehaviorProven){Deny 'expected_behavior_not_proven'}
$preset=[string]$p.permissions.preset
if($preset-eq'CUSTOM'){$risks=@($p.permissions.custom_auto_change_risks);$cats=@($p.permissions.custom_categories)}else{$risks=@($perm.presets.$preset.auto_change_risks);$cats=@($perm.auto_change_categories)}
if($risks-notcontains$Risk -or $cats-notcontains$Category){Deny 'preset_ceiling'}
if($preset-eq'SAFE_FIXES' -and -not$Reversible){Deny 'safe_fix_must_be_reversible'}
Write-Host "CHANGE_AUTHORIZATION=ALLOW PRESET=$preset RISK=$Risk CATEGORY=$Category"
exit 0
