$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$temp=Join-Path ([IO.Path]::GetTempPath()) ('qa-v21-win-auth-'+[guid]::NewGuid().ToString('N'))
function Assert([bool]$ok,[string]$name){if(-not$ok){throw "V21_WIN_AUTH_REDTEAM_FAIL=$name"};Write-Host "V21_WIN_AUTH_REDTEAM_PASS=$name"}
function Invoke-Auth([string]$install,[string]$risk,[string]$category,[string]$Target='docs\auth-test.md',[switch]$Expected,[switch]$Reversible){
 $tool=Join-Path $install 'tools\authorize-change.ps1';$args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$tool,'-Risk',$risk,'-Category',$category,'-FindingId','F-WIN-AUTH','-ChangeSummary','bounded Windows authorization test','-EvidenceRef','evidence\auth.txt','-TargetPath',$Target);if($Expected){$args+='-ExpectedBehaviorProven'};if($Reversible){$args+='-Reversible'};$out=& powershell.exe @args 2>&1;$rc=$LASTEXITCODE;return [pscustomobject]@{rc=$rc;out=($out|Out-String)}
}
try{
 $project=Join-Path $temp 'project with spaces';$install=Join-Path $project '.comprehensive-qa';New-Item -ItemType Directory $project -Force|Out-Null;Copy-Item (Join-Path $root 'runtime') $install -Recurse -Force;New-Item -ItemType Directory (Join-Path $install 'state') -Force|Out-Null
 $pm=Join-Path $install 'tools\policy-manager.ps1';$candidate=Join-Path $temp 'policy.json';$p=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pm -Operation Get|Out-String)|ConvertFrom-Json;$p.permissions.preset='SAFE_FIXES';$p|ConvertTo-Json -Depth 20|Set-Content $candidate -Encoding UTF8;& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pm -Operation Apply -PolicyJsonPath $candidate -OwnerApproved -ApprovalSource manual_cli|Out-Null;Assert ($LASTEXITCODE-eq0) 'safe_policy_applied'
 $r=Invoke-Auth $install 'LOW' 'documentation' -Expected -Reversible;Assert ($r.rc-eq0 -and $r.out-match'CHANGE_AUTHORIZATION=ALLOW' -and $r.out-match'AUTHORIZATION_ID=') 'safe_low_reversible_allow'
 $r=Invoke-Auth $install 'LOW' 'documentation' '.env.production' -Expected -Reversible;Assert ($r.rc-ne0) 'env_target_denied'
 $r=Invoke-Auth $install 'LOW' 'documentation' '.github\workflows\qa.yml' -Expected -Reversible;Assert ($r.rc-ne0) 'github_workflow_target_denied'
 $r=Invoke-Auth $install 'LOW' 'documentation' '.git\config' -Expected -Reversible;Assert ($r.rc-ne0) 'git_metadata_target_denied'
 $r=Invoke-Auth $install 'LOW' 'documentation' 'src\..\.env' -Expected -Reversible;Assert ($r.rc-ne0) 'traversal_target_denied'
 $r=Invoke-Auth $install 'MEDIUM' 'source_code' -Expected -Reversible;Assert ($r.rc-ne0 -and $r.out-match'CHANGE_AUTHORIZATION=DENY') 'safe_medium_denied'
 $r=Invoke-Auth $install 'LOW' 'architecture' -Expected -Reversible;Assert ($r.rc-ne0) 'hard_boundary_denied'
 $p=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pm -Operation Get|Out-String)|ConvertFrom-Json;$p.permissions.preset='ACTIVE_REMEDIATION';$p|ConvertTo-Json -Depth 20|Set-Content $candidate -Encoding UTF8;& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $pm -Operation Apply -PolicyJsonPath $candidate -OwnerApproved -ApprovalSource manual_cli|Out-Null
 $r=Invoke-Auth $install 'MEDIUM' 'source_code' -Expected;Assert ($r.rc-ne0 -and $r.out-match'automatic_change_must_be_reversible') 'active_irreversible_denied'
 $r=Invoke-Auth $install 'MEDIUM' 'source_code' -Expected -Reversible;Assert ($r.rc-eq0) 'active_medium_reversible_allowed'
 $r=Invoke-Auth $install 'HIGH' 'source_code' -Expected -Reversible;Assert ($r.rc-ne0) 'active_high_denied'
 $history=Join-Path $install 'state\CHANGE_AUTHORIZATION_HISTORY.jsonl';$lines=@(Get-Content $history|Where-Object{-not[string]::IsNullOrWhiteSpace($_)});Assert ($lines.Count-ge6) 'authorization_audit_lines_preserved';$items=@($lines|ForEach-Object{$_|ConvertFrom-Json});Assert (@($items.authorization_id|Select-Object -Unique).Count-eq$items.Count) 'authorization_ids_unique';Assert (@($items|Where-Object{$null-eq$_.policy_revision}).Count-eq0) 'authorization_audit_records_policy_revision'
 $state=Join-Path $install 'state';$cur=Get-Content (Join-Path $state 'OWNER_POLICY.json') -Raw|ConvertFrom-Json;$cur.permissions.preset='SAFE_FIXES';$cur|ConvertTo-Json -Depth 20|Set-Content (Join-Path $state 'OWNER_POLICY.json') -Encoding UTF8;$r=Invoke-Auth $install 'LOW' 'documentation' -Expected -Reversible;Assert ($r.rc-ne0 -and $r.out-match'owner_policy') 'tampered_policy_fails_closed_in_windows_authorizer'
 Write-Host 'V21_WIN_AUTH_REDTEAM_RESULT=PASS';exit 0
}finally{if(Test-Path $temp){Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}}
