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
$historyPath=Join-Path $stateDir 'OWNER_POLICY_HISTORY.jsonl'
$templatePath=Join-Path $installRoot 'templates\OWNER_POLICY.json'
$permissionPath=Join-Path $installRoot 'config\permission-policy.json'
if(-not(Test-Path $permissionPath)){$permissionPath=Join-Path $installRoot 'templates\PERMISSION_POLICY.json'}
if(-not(Test-Path $permissionPath -PathType Leaf)){throw 'Permission policy missing from config and compatibility template paths.'}
$perm=Get-Content $permissionPath -Raw|ConvertFrom-Json
$validWeekdays=@('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday')
$approvalSources=@('dashboard_local_control','agent_owner_conversation','installer_optional_setup','manual_cli')

function Initialize-Policy {
  if(-not(Test-Path $policyPath)){
    if(-not(Test-Path $templatePath -PathType Leaf)){throw 'OWNER_POLICY template missing.'}
    Copy-Item $templatePath $policyPath -Force
  }
}
function Hash-File([string]$path){
  $stream=[IO.File]::OpenRead($path);$sha=[Security.Cryptography.SHA256]::Create()
  try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose();$stream.Dispose()}
}
function Is-IntegerValue($value){return ($value -is [byte] -or $value -is [sbyte] -or $value -is [int16] -or $value -is [uint16] -or $value -is [int32] -or $value -is [uint32] -or $value -is [int64] -or $value -is [uint64])}
function Is-ArrayLike($value){return ($null-ne$value -and $value-isnot[string] -and $value-is[System.Collections.IEnumerable])}
function Validate-StringArray($value,[string]$name,[int]$max,[System.Collections.Generic.List[string]]$errors){
  if(-not(Is-ArrayLike $value)){$errors.Add("$name must be an array");return @()}
  $items=@($value);if($items.Count-gt$max){$errors.Add("$name exceeds $max entries")}
  foreach($item in $items){if($item-isnot[string]){$errors.Add("$name entries must be strings");break}}
  return $items
}
function Reject-UnknownFields($obj,[string[]]$allowed,[string]$name,[System.Collections.Generic.List[string]]$errors){
  if($null-eq$obj){return}
  foreach($prop in @($obj.PSObject.Properties.Name)){if($allowed-notcontains[string]$prop){$errors.Add("$name contains unknown field: $prop")}}
}
function Validate-PermissionPolicy($policy){
  $errors=New-Object System.Collections.Generic.List[string]
  Reject-UnknownFields $policy @('schema_version','model','change_risks','presets','auto_change_categories','hard_boundaries','protected_path_prefixes','protected_path_basenames','protected_path_suffixes','protected_path_name_prefixes','rules') 'permission policy' $errors
  if([int]$policy.schema_version-ne2){$errors.Add('permission policy schema_version must equal 2')}
  if([string]$policy.model-ne'owner-controlled-agent-remediation'){$errors.Add('permission policy model is invalid')}
  if($null-eq$policy.presets){$errors.Add('permission policy presets must be an object')}
  $presetNames=@($policy.presets.PSObject.Properties.Name);$required=@('REPORT_ONLY','SAFE_FIXES','ACTIVE_REMEDIATION','CUSTOM')
  if((@($presetNames|Sort-Object)-join',') -ne (@($required|Sort-Object)-join',')){$errors.Add('permission policy presets must exactly define REPORT_ONLY, SAFE_FIXES, ACTIVE_REMEDIATION, CUSTOM')}
  $auto=Validate-StringArray $policy.auto_change_categories 'permission policy auto_change_categories' 128 $errors
  $hard=Validate-StringArray $policy.hard_boundaries 'permission policy hard_boundaries' 128 $errors
  $prefixes=Validate-StringArray $policy.protected_path_prefixes 'permission policy protected_path_prefixes' 128 $errors
  $basenames=Validate-StringArray $policy.protected_path_basenames 'permission policy protected_path_basenames' 128 $errors
  $suffixes=Validate-StringArray $policy.protected_path_suffixes 'permission policy protected_path_suffixes' 64 $errors
  $namePrefixes=Validate-StringArray $policy.protected_path_name_prefixes 'permission policy protected_path_name_prefixes' 32 $errors
  $canonicalAuto=@('documentation','tests','source_code','local_non_secret_config','dependency_hygiene')
  $canonicalHard=@('material_product_intent','architecture','public_api_contracts','security_policy','privacy_policy','authentication_semantics','authorization_semantics','database_schema','migrations','production_data','credentials','deployments','production','billing_or_paid_calls','destructive_operations','ci_workflow_or_runner_configuration','qa_authority_or_policy','version_control_metadata')
  $canonicalPrefixes=@('.comprehensive-qa','.git','.hg','.svn','.github','.circleci','.buildkite','.teamcity','.ssh','.aws','.azure','.kube','secrets','credentials')
  $canonicalBasenames=@('.gitlab-ci.yml','jenkinsfile','azure-pipelines.yml','bitbucket-pipelines.yml','codeowners','.npmrc','.pypirc','.netrc','id_rsa','id_ed25519','credentials.json','service-account.json')
  $canonicalSuffixes=@('.key','.pem','.p12','.pfx','.jks','.keystore')
  $canonicalNamePrefixes=@('.env')
  foreach($pair in @(@($auto,$canonicalAuto,'auto_change_categories'),@($hard,$canonicalHard,'hard_boundaries'),@($prefixes,$canonicalPrefixes,'protected_path_prefixes'),@($basenames,$canonicalBasenames,'protected_path_basenames'),@($suffixes,$canonicalSuffixes,'protected_path_suffixes'),@($namePrefixes,$canonicalNamePrefixes,'protected_path_name_prefixes'))){
    $actual=@($pair[0]);$want=@($pair[1]);$label=[string]$pair[2]
    if(@($actual|Select-Object -Unique).Count-ne$actual.Count){$errors.Add("permission policy $label contains duplicates")}
    if((@($actual|Sort-Object)-join',') -ne (@($want|Sort-Object)-join',')){$errors.Add("permission policy $label violates canonical managed values")}
  }
  foreach($x in $auto){if($hard-contains$x){$errors.Add("permission policy auto-change category overlaps hard boundary: $x")}}
  $expected=@{REPORT_ONLY=@();SAFE_FIXES=@('LOW');ACTIVE_REMEDIATION=@('LOW','MEDIUM');CUSTOM=@()}
  foreach($name in $required){
    $node=$policy.presets.$name;Reject-UnknownFields $node @('auto_change_risks','description') "permission policy preset $name" $errors
    $risks=Validate-StringArray $node.auto_change_risks "permission policy $name auto_change_risks" 2 $errors
    if((@($risks|Sort-Object)-join',') -ne (@($expected[$name]|Sort-Object)-join',')){$errors.Add("permission policy $name auto_change_risks violates canonical ceiling")}
  }
  foreach($rule in @('agent_may_never_self_elevate','owner_approval_required_for_policy_mutation','hard_boundaries_override_all_presets','unknown_change_risk_requires_approval','ambiguous_expected_behavior_requires_approval','all_automatic_changes_must_be_reversible','automatic_change_requires_finding_evidence_and_authorization_id','automatic_change_requires_declared_target_paths')){if($policy.rules.$rule-ne$true){$errors.Add("permission policy safety rule must be true: $rule")}}
  if($errors.Count){throw ('Permission policy validation failed: '+($errors-join'; '))}
}
function Validate-Policy($p,[int64]$sourceBytes=-1){
  $errors=New-Object System.Collections.Generic.List[string]
  if($null-eq$p -or $p-is[string]){throw 'OWNER_POLICY must be an object.'}
  Reject-UnknownFields $p @('schema_version','configured','configured_at','configured_via','permissions','schedule','approval','policy_revision') 'OWNER_POLICY' $errors
  if([int]$p.schema_version-ne1){$errors.Add('schema_version must equal 1')}
  if($p.configured-isnot[bool]){$errors.Add('configured must be boolean')}
  if(-not(Is-IntegerValue $p.policy_revision)-or[int64]$p.policy_revision-lt0){$errors.Add('policy_revision must be a non-negative integer')}
  if($null-ne$p.configured_at -and $p.configured_at-isnot[string] -and $p.configured_at-isnot[datetime]){$errors.Add('configured_at must be null/string/datetime')}
  if(([string]$p.configured_via-ne'UNCONFIGURED')-and($approvalSources-notcontains[string]$p.configured_via)){$errors.Add('configured_via is invalid')}
  if($null-eq$p.permissions){$errors.Add('permissions must be an object')}else{
    Reject-UnknownFields $p.permissions @('preset','custom_auto_change_risks','custom_categories','notes') 'permissions' $errors
    if($p.permissions.notes-isnot[string]-or([string]$p.permissions.notes).Length-gt2000){$errors.Add('permissions.notes must be a string <= 2000 characters')}
    $presets=@($perm.presets.PSObject.Properties.Name);if($presets-notcontains[string]$p.permissions.preset){$errors.Add("invalid permissions preset: $($p.permissions.preset)")}
    $customRisks=Validate-StringArray $p.permissions.custom_auto_change_risks 'permissions.custom_auto_change_risks' 2 $errors
    foreach($risk in $customRisks){if($risk-notin@('LOW','MEDIUM')){$errors.Add("custom auto-change risk not allowed: $risk")}}
    if(@($customRisks|Select-Object -Unique).Count-ne@($customRisks).Count){$errors.Add('permissions.custom_auto_change_risks contains duplicates')}
    $allowedCats=@($perm.auto_change_categories);$hard=@($perm.hard_boundaries);$customCats=Validate-StringArray $p.permissions.custom_categories 'permissions.custom_categories' ([Math]::Max(1,$allowedCats.Count)) $errors
    foreach($cat in $customCats){if($allowedCats-notcontains[string]$cat){$errors.Add("custom category not allowed: $cat")};if($hard-contains[string]$cat){$errors.Add("hard boundary cannot be auto-authorized: $cat")}}
    if(@($customCats|Select-Object -Unique).Count-ne@($customCats).Count){$errors.Add('permissions.custom_categories contains duplicates')}
  }
  if($null-eq$p.schedule){$errors.Add('schedule must be an object')}else{
    Reject-UnknownFields $p.schedule @('enabled','frequency','local_time','days_of_week','executor_mode','executor','timezone_mode') 'schedule' $errors
    if($p.schedule.enabled-isnot[bool]){$errors.Add('schedule.enabled must be boolean')}
    if($p.schedule.frequency-notin@('DAILY','WEEKDAYS','WEEKLY')){$errors.Add("unsupported schedule frequency: $($p.schedule.frequency)")}
    if([string]$p.schedule.local_time-notmatch'^(?:[01]\d|2[0-3]):[0-5]\d$'){$errors.Add('schedule.local_time must be HH:mm')}
    if([string]$p.schedule.timezone_mode-ne'LOCAL'){$errors.Add('schedule.timezone_mode must equal LOCAL')}
    $days=Validate-StringArray $p.schedule.days_of_week 'schedule.days_of_week' 7 $errors;foreach($day in $days){if($validWeekdays-notcontains[string]$day){$errors.Add("invalid weekly day: $day")}}
    if(@($days|Select-Object -Unique).Count-ne@($days).Count){$errors.Add('schedule.days_of_week contains duplicates')}
    if($p.schedule.frequency-eq'WEEKLY'-and@($days).Count-eq0){$errors.Add('WEEKLY schedule requires at least one day_of_week')}
    if($p.schedule.frequency-ne'WEEKLY'-and@($days).Count-gt0){$errors.Add('days_of_week must be empty unless frequency is WEEKLY')}
    if($p.schedule.executor_mode-notin@('UNCONFIGURED','LOCAL_COMMAND','AGENT_MANAGED')){$errors.Add("invalid executor_mode: $($p.schedule.executor_mode)")}
    if($null-eq$p.schedule.executor){$errors.Add('schedule.executor must be an object')}else{
      Reject-UnknownFields $p.schedule.executor @('command','arguments','timeout_minutes','log_retention_days') 'schedule.executor' $errors
      if($p.schedule.executor.command-isnot[string]){$errors.Add('executor.command must be a string')}elseif($p.schedule.executor.command.Length-gt4096){$errors.Add('executor.command exceeds 4096 characters')}
      if($p.schedule.executor_mode-eq'LOCAL_COMMAND'-and[string]::IsNullOrWhiteSpace([string]$p.schedule.executor.command)){$errors.Add('LOCAL_COMMAND requires executor.command')}
      $arguments=Validate-StringArray $p.schedule.executor.arguments 'executor.arguments' 64 $errors;foreach($arg in $arguments){if($arg-is[string]-and$arg.Length-gt4096){$errors.Add('executor argument exceeds 4096 characters');break}}
      foreach($spec in @(@('timeout_minutes',1,1440),@('log_retention_days',1,365))){$name=$spec[0];$value=$p.schedule.executor.$name;if(-not(Is-IntegerValue $value)){$errors.Add("executor.$name must be an integer")}elseif([int64]$value-lt[int]$spec[1]-or[int64]$value-gt[int]$spec[2]){$errors.Add("executor.$name must be between $($spec[1]) and $($spec[2])")}}
    }
  }
  if($null-eq$p.approval){$errors.Add('approval must be an object')}else{
    Reject-UnknownFields $p.approval @('approved_by_human','approved_at','source') 'approval' $errors
    if($p.approval.approved_by_human-isnot[bool]){$errors.Add('approval.approved_by_human must be boolean')}
    if($null-ne$p.approval.approved_at -and $p.approval.approved_at-isnot[string] -and $p.approval.approved_at-isnot[datetime]){$errors.Add('approval.approved_at must be null/string/datetime')}
    if(([string]$p.approval.source-ne'UNCONFIGURED')-and($approvalSources-notcontains[string]$p.approval.source)){$errors.Add('approval.source is invalid')}
  }
  if($p.configured-eq$false){if([int64]$p.policy_revision-ne0-or$p.approval.approved_by_human-ne$false-or[string]$p.configured_via-ne'UNCONFIGURED'){$errors.Add('unconfigured policy must remain revision 0 with no human approval')}}
  elseif($p.configured-eq$true){if([int64]$p.policy_revision-lt1-or$p.approval.approved_by_human-ne$true){$errors.Add('configured policy requires revision >=1 and human approval')};if([string]$p.configured_via-ne[string]$p.approval.source){$errors.Add('configured_via must match approval.source')}}
  $serialized=$p|ConvertTo-Json -Depth 20 -Compress;if($serialized-match'gh[op]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'){$errors.Add('OWNER_POLICY must not contain credentials/tokens/private keys')}
  if($sourceBytes-gt65536){$errors.Add('OWNER_POLICY exceeds 65536 bytes')}
  if($errors.Count){throw ('Owner policy validation failed: '+($errors-join'; '))}
}
function Acquire-PolicyLock{$path=Join-Path $stateDir 'OWNER_POLICY.lock';for($i=0;$i-lt80;$i++){try{return [IO.File]::Open($path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{Start-Sleep -Milliseconds 125}};throw 'Timed out waiting for OWNER_POLICY mutation lock.'}
function Get-LatestHistoryEntry{if(-not(Test-Path $historyPath)){return $null};$lines=@(Get-Content $historyPath|Where-Object{-not[string]::IsNullOrWhiteSpace($_)});if(-not$lines.Count){return $null};return ($lines[-1]|ConvertFrom-Json)}
function Verify-CurrentIntegrity($current){
  if($current.configured-eq$false){if([int64]$current.policy_revision-ne0-or$current.approval.approved_by_human-ne$false){throw 'unconfigured OWNER_POLICY has inconsistent revision/approval state'};return}
  $entry=Get-LatestHistoryEntry;if($null-eq$entry){throw 'configured OWNER_POLICY is missing authorization history'}
  if([int64]$entry.revision-ne[int64]$current.policy_revision){throw 'OWNER_POLICY revision does not match latest audit entry'}
  $actual=Hash-File $policyPath;if(([string]$entry.new_hash).ToLowerInvariant()-ne$actual){throw 'OWNER_POLICY hash does not match latest audit entry'}
}
function Next-Revision([string]$oldRaw){$oldRev=0;try{$old=$oldRaw|ConvertFrom-Json;if(Is-IntegerValue $old.policy_revision){$oldRev=[int64]$old.policy_revision}}catch{};$histRev=0;try{$entry=Get-LatestHistoryEntry;if($entry-and(Is-IntegerValue $entry.revision)){$histRev=[int64]$entry.revision}}catch{};return ([Math]::Max($oldRev,$histRev)+1)}

Validate-PermissionPolicy $perm
Initialize-Policy
if($Operation-eq'Get'){$raw=Get-Content $policyPath -Raw;$current=$raw|ConvertFrom-Json;Validate-Policy $current (Get-Item $policyPath).Length;Verify-CurrentIntegrity $current;$current|ConvertTo-Json -Depth 20;return}
if(-not$OwnerApproved){throw 'Policy mutation requires explicit human owner approval. An AI agent may pass this only after the owner directly chose the policy in the current interaction.'}
if($ApprovalSource-eq'UNCONFIGURED'){throw 'ApprovalSource is required for policy mutation.'}
if(-not$PolicyJsonPath -or -not(Test-Path $PolicyJsonPath -PathType Leaf)){throw 'PolicyJsonPath is required and must exist.'}
$sourceBytes=(Get-Item $PolicyJsonPath).Length;$new=Get-Content $PolicyJsonPath -Raw|ConvertFrom-Json;Validate-Policy $new $sourceBytes
$lock=$null
try{
  $lock=Acquire-PolicyLock;$oldRaw=Get-Content $policyPath -Raw;$oldHash=Hash-File $policyPath;$recoveryReason=$null
  try{$old=$oldRaw|ConvertFrom-Json;Validate-Policy $old (Get-Item $policyPath).Length;Verify-CurrentIntegrity $old}catch{$recoveryReason=$_.Exception.Message}
  $revision=Next-Revision $oldRaw;$new.configured=$true;$new.configured_at=(Get-Date).ToString('o');$new.configured_via=$ApprovalSource;$new.policy_revision=$revision;$new.approval=[pscustomobject]@{approved_by_human=$true;approved_at=(Get-Date).ToString('o');source=$ApprovalSource};Validate-Policy $new
  $temp=Join-Path $stateDir ('.OWNER_POLICY.'+[guid]::NewGuid().ToString('N')+'.tmp');$replaceBackup=Join-Path $stateDir ('.OWNER_POLICY.'+[guid]::NewGuid().ToString('N')+'.bak')
  try{$new|ConvertTo-Json -Depth 20|Set-Content $temp -Encoding UTF8;$newHash=Hash-File $temp;[IO.File]::Replace($temp,$policyPath,$replaceBackup)}finally{Remove-Item $replaceBackup -Force -ErrorAction SilentlyContinue;Remove-Item $temp -Force -ErrorAction SilentlyContinue}
  [ordered]@{changed_at=(Get-Date).ToString('o');revision=$revision;source=$ApprovalSource;owner_approved=$true;old_hash=$oldHash;new_hash=$newHash;preset=[string]$new.permissions.preset;schedule_enabled=[bool]$new.schedule.enabled;executor_mode=[string]$new.schedule.executor_mode;recovery_from_invalid_policy=[bool]$recoveryReason;recovery_reason=$recoveryReason}|ConvertTo-Json -Compress|Add-Content $historyPath -Encoding UTF8
}finally{if($lock){$lock.Dispose()}}
Write-Host "OWNER_POLICY_APPLIED=1 REVISION=$revision PRESET=$($new.permissions.preset) SCHEDULE=$($new.schedule.enabled)"
