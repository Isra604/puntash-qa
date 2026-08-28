$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$temp=Join-Path ([IO.Path]::GetTempPath()) ('qa-v21-timeout-'+[guid]::NewGuid().ToString('N'))
function Assert([bool]$ok,[string]$name){if(-not$ok){throw "V21_TIMEOUT_REDTEAM_FAIL=$name"};Write-Host "V21_TIMEOUT_REDTEAM_PASS=$name"}
try{
 $project=Join-Path $temp 'project with spaces';$install=Join-Path $project '.comprehensive-qa';New-Item -ItemType Directory $project -Force|Out-Null;Copy-Item (Join-Path $root 'runtime') $install -Recurse -Force
 New-Item -ItemType Directory (Join-Path $install 'state') -Force|Out-Null
 foreach($f in @('TERMS_VERSION','LEGAL_MANIFEST.json','LICENSE','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','NOTICE','CREDITS.md')){Copy-Item (Join-Path $root $f) (Join-Path $install $f) -Force}
 $legal=(Get-Content (Join-Path $install 'LEGAL_MANIFEST.json') -Raw|ConvertFrom-Json).documents;$terms=(Get-Content (Join-Path $install 'TERMS_VERSION') -Raw).Trim();[ordered]@{terms_version=$terms;accepted_by_human_attestation=$true;legal_document_sha256=$legal}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $install 'state\HUMAN_ACCEPTANCE_RECEIPT.json') -Encoding UTF8
 $helper=Join-Path $project 'timeout helper.py';$pidFile=Join-Path $project 'child.pid';$marker=Join-Path $project 'survived.txt'
 @"
import pathlib,subprocess,sys,time
pidfile=pathlib.Path(sys.argv[1]);marker=pathlib.Path(sys.argv[2])
child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(120)'])
pidfile.write_text(str(child.pid))
time.sleep(90)
marker.write_text('survived')
"@|Set-Content $helper -Encoding UTF8
 $policy=Get-Content (Join-Path $install 'templates\OWNER_POLICY.json') -Raw|ConvertFrom-Json;$policy.permissions.preset='REPORT_ONLY';$policy.schedule.enabled=$true;$policy.schedule.executor_mode='LOCAL_COMMAND';$policy.schedule.executor.command=(Get-Command python.exe -ErrorAction Stop).Source;$policy.schedule.executor.arguments=@($helper,$pidFile,$marker);$policy.schedule.executor.timeout_minutes=1;$candidate=Join-Path $temp 'policy.json';$policy|ConvertTo-Json -Depth 20|Set-Content $candidate -Encoding UTF8
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $install 'tools\policy-manager.ps1') -Operation Apply -PolicyJsonPath $candidate -OwnerApproved -ApprovalSource manual_cli|Out-Null;Assert ($LASTEXITCODE-eq0) 'timeout_policy_applied'
 $sw=[Diagnostics.Stopwatch]::StartNew();& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $install 'tools\scheduled-run.ps1') -ProjectPath $project|Out-Null;$rc=$LASTEXITCODE;$sw.Stop();Assert ($rc-eq9) 'windows_runner_returns_timeout';Assert ($sw.Elapsed.TotalSeconds-ge55 -and $sw.Elapsed.TotalSeconds-lt90) 'timeout_occurs_near_configured_limit'
 $status=Get-Content (Join-Path $install 'state\SCHEDULER_STATUS.json') -Raw|ConvertFrom-Json;Assert ($status.last_result-eq'TIMEOUT') 'timeout_status_recorded'
 Assert (Test-Path $pidFile) 'child_pid_observed_before_timeout';$childPid=[int](Get-Content $pidFile -Raw);Start-Sleep -Seconds 2;$alive=$null;try{$alive=Get-Process -Id $childPid -ErrorAction Stop}catch{};Assert ($null-eq$alive) 'timeout_kills_executor_child_process';Assert (-not(Test-Path $marker)) 'timed_out_process_tree_cannot_continue_after_kill'
 Write-Host 'V21_TIMEOUT_REDTEAM_RESULT=PASS'
 exit 0
}finally{if(Test-Path $temp){Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}}
