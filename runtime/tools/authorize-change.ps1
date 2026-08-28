param(
 [Parameter(Mandatory=$true)][ValidateSet('LOW','MEDIUM','HIGH','PROTECTED')][string]$Risk,
 [Parameter(Mandatory=$true)][string]$Category,
 [Parameter(Mandatory=$true)][string]$FindingId,
 [Parameter(Mandatory=$true)][string]$ChangeSummary,
 [Parameter(Mandatory=$true)][string[]]$EvidenceRef,
 [Parameter(Mandatory=$true)][string[]]$TargetPath,
 [switch]$ExpectedBehaviorProven,
 [switch]$Reversible
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$projectRoot=Split-Path -Parent $root
$state=Join-Path $root 'state';New-Item -ItemType Directory $state -Force|Out-Null
$permPath=Join-Path $root 'config\permission-policy.json';if(-not(Test-Path $permPath)){$permPath=Join-Path $root 'templates\PERMISSION_POLICY.json'}
$policyTool=Join-Path $PSScriptRoot 'policy-manager.ps1'
$authorizationId=[guid]::NewGuid().ToString('N')
$decision='DENY';$reason='internal_error';$preset='UNKNOWN';$revision=$null;$normalizedTargets=@()
function Acquire-AuditLock {
 $path=Join-Path $state 'CHANGE_AUTHORIZATION.lock'
 for($i=0;$i-lt80;$i++){try{return [IO.File]::Open($path,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{Start-Sleep -Milliseconds 125}}
 throw 'Timed out waiting for change-authorization audit lock.'
}
function Finish([int]$code){
 $lock=$null
 try{
  $lock=Acquire-AuditLock
  [ordered]@{authorization_id=$authorizationId;decided_at=(Get-Date).ToString('o');decision=$decision;reason=$reason;policy_revision=$revision;preset=$preset;risk=$Risk;category=$Category;finding_id=$FindingId;change_summary=$ChangeSummary;evidence_refs=@($EvidenceRef);target_paths=@($normalizedTargets);expected_behavior_proven=[bool]$ExpectedBehaviorProven;reversible=[bool]$Reversible}|ConvertTo-Json -Depth 8 -Compress|Add-Content (Join-Path $state 'CHANGE_AUTHORIZATION_HISTORY.jsonl') -Encoding UTF8
 }finally{if($lock){$lock.Dispose()}}
 Write-Host "CHANGE_AUTHORIZATION=$decision REASON=$reason AUTHORIZATION_ID=$authorizationId PRESET=$preset RISK=$Risk CATEGORY=$Category"
 exit $code
}
function Test-Reparse([string]$Path){try{$i=Get-Item -LiteralPath $Path -Force -ErrorAction Stop;return (($i.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0)}catch{return $false}}
function Normalize-Target([string]$Value,$perm){
 $raw=[string]$Value;$v=$raw.Replace('\','/');if($v-ne$v.Trim()){throw 'target_path_whitespace_ambiguous'}
 $hasControl=@($v.ToCharArray()|Where-Object{[int]$_-lt32}).Count-gt0
 if([string]::IsNullOrWhiteSpace($v)-or$v.Length-gt2048-or$hasControl){throw 'target_path_invalid'}
 if($v.StartsWith('/')-or$v-match'^[A-Za-z]:'){throw 'target_path_absolute_forbidden'}
 $rawParts=@($v.Split('/'));if(@($rawParts|Where-Object{$_-eq''}).Count){throw 'target_path_empty_segment_forbidden'};$parts=$rawParts;if($parts.Count-eq0-or$parts-contains'..'-or$parts-contains'.'){throw 'target_path_traversal_forbidden'}
 $reserved=@('con','prn','aux','nul','com1','com2','com3','com4','com5','com6','com7','com8','com9','lpt1','lpt2','lpt3','lpt4','lpt5','lpt6','lpt7','lpt8','lpt9');foreach($part in $parts){$low=$part.ToLowerInvariant();$stem=($low-split'\.',2)[0];if($part.EndsWith(' ')-or$part.EndsWith('.')-or$part.Contains(':')-or$reserved-contains$stem){throw 'target_path_platform_alias_forbidden'}}
 $lower=@($parts|ForEach-Object{$_.ToLowerInvariant()});$prefixes=@($perm.protected_path_prefixes|ForEach-Object{([string]$_).ToLowerInvariant()});$basenames=@($perm.protected_path_basenames|ForEach-Object{([string]$_).ToLowerInvariant()});$suffixes=@($perm.protected_path_suffixes|ForEach-Object{([string]$_).ToLowerInvariant()});$namePrefixes=@($perm.protected_path_name_prefixes|ForEach-Object{([string]$_).ToLowerInvariant()})
 if($prefixes-contains$lower[0]){throw 'target_path_protected_prefix'}
 $base=$lower[-1];if($basenames-contains$base){throw 'target_path_protected_name'};foreach($np in $namePrefixes){if($base.StartsWith($np)){throw 'target_path_protected_name'}};foreach($s in $suffixes){if($base.EndsWith($s)){throw 'target_path_protected_name'}}
 if(Test-Reparse $projectRoot){throw 'project_root_reparse_requires_owner_approval'}
 $cur=$projectRoot;foreach($part in $parts){$cur=Join-Path $cur $part;if(Test-Reparse $cur){throw 'target_path_reparse_or_symlink_forbidden'}}
 $target=Join-Path $projectRoot ($parts -join [IO.Path]::DirectorySeparatorChar);if(Test-Path -LiteralPath $target){$item=Get-Item -LiteralPath $target -Force;if($item.PSIsContainer){throw 'target_path_directory_forbidden'};$fsutil=Get-Command fsutil.exe -ErrorAction SilentlyContinue;if(-not$fsutil){throw 'target_path_link_state_unverifiable'};$links=@(& $fsutil.Source hardlink list $target 2>$null);if($LASTEXITCODE-ne0){throw 'target_path_link_state_unverifiable'};if(@($links|Where-Object{-not[string]::IsNullOrWhiteSpace($_)}).Count-gt1){throw 'target_path_hardlink_forbidden'}}
 $rootFull=[IO.Path]::GetFullPath($projectRoot).TrimEnd('\','/');$candidate=[IO.Path]::GetFullPath((Join-Path $projectRoot ($parts -join [IO.Path]::DirectorySeparatorChar)));$prefix=$rootFull+[IO.Path]::DirectorySeparatorChar;if(-not($candidate.Equals($rootFull,[StringComparison]::OrdinalIgnoreCase)-or$candidate.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase))){throw 'target_path_escape_forbidden'}
 return ($parts-join'/')
}
if([string]::IsNullOrWhiteSpace($FindingId)-or$FindingId.Length-gt128){$reason='finding_id_invalid';Finish 10}
if([string]::IsNullOrWhiteSpace($ChangeSummary)-or$ChangeSummary.Length-gt1000){$reason='change_summary_invalid';Finish 10}
if(-not$EvidenceRef -or @($EvidenceRef).Count-gt16 -or @($EvidenceRef|Where-Object{[string]::IsNullOrWhiteSpace($_)-or$_.Length-gt2048}).Count){$reason='evidence_refs_required_or_invalid';Finish 10}
if(-not$TargetPath -or @($TargetPath).Count-gt32){$reason='target_paths_required_or_invalid';Finish 10}
try{$p=(& $policyTool -Operation Get|Out-String)|ConvertFrom-Json;$perm=Get-Content $permPath -Raw|ConvertFrom-Json}catch{$reason='owner_policy_or_permission_policy_invalid';Finish 10}
$revision=$p.policy_revision;$preset=[string]$p.permissions.preset
try{foreach($t in @($TargetPath)){$normalizedTargets+=Normalize-Target $t $perm}}catch{$reason=$_.Exception.Message;Finish 10}
if(@($normalizedTargets|Select-Object -Unique).Count-ne@($normalizedTargets).Count){$reason='target_paths_duplicate';Finish 10}
if(-not$p.configured -or $p.approval.approved_by_human-ne$true){$reason='owner_policy_unconfigured';Finish 10}
if(@($perm.hard_boundaries)-contains$Category -or $Risk-in@('HIGH','PROTECTED')){$reason='high_or_protected_requires_owner_approval';Finish 10}
if(@($perm.auto_change_categories)-notcontains$Category){$reason='category_not_auto_changeable';Finish 10}
if(-not$ExpectedBehaviorProven){$reason='expected_behavior_not_proven';Finish 10}
if(-not$Reversible){$reason='automatic_change_must_be_reversible';Finish 10}
if($preset-eq'CUSTOM'){$risks=@($p.permissions.custom_auto_change_risks);$cats=@($p.permissions.custom_categories)}else{$risks=@($perm.presets.$preset.auto_change_risks);$cats=@($perm.auto_change_categories)}
if($risks-notcontains$Risk -or $cats-notcontains$Category){$reason='preset_ceiling';Finish 10}
$decision='ALLOW';$reason='within_owner_policy_ceiling';Finish 0
