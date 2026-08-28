$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'runtime\tools\path-safety.ps1')
function Assert([bool]$c,[string]$n){if(-not$c){throw "V21_PATH_SAFETY_FAIL=$n"};Write-Host "V21_PATH_SAFETY_PASS=$n"}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('qa-path-safety-'+[guid]::NewGuid().ToString('N'))
try{
 New-Item $temp -ItemType Directory|Out-Null;$normal=Join-Path $temp 'normal';$outside=Join-Path $temp 'outside';New-Item $normal,$outside -ItemType Directory|Out-Null
 Assert-NoReparsePoint -Path $normal -Label normal -Recursive;Assert $true 'normal_directory_allowed'
 $blocked=$false;try{Assert-PathWithin -Path $outside -Root $normal -Label outside}catch{$blocked=$true};Assert $blocked 'outside_root_path_rejected'
 $link=Join-Path $temp 'junction';$cmd="mklink /J `"$link`" `"$outside`"";& cmd.exe /d /c $cmd|Out-Null
 Assert (Test-Path $link) 'junction_fixture_created'
 $blocked=$false;try{Assert-NoReparsePoint -Path $link -Label junction -Recursive}catch{$blocked=$true};Assert $blocked 'root_junction_rejected'
 $nestedRoot=Join-Path $temp 'nested';New-Item $nestedRoot -ItemType Directory|Out-Null;$nested=Join-Path $nestedRoot 'escape';$cmd="mklink /J `"$nested`" `"$outside`"";& cmd.exe /d /c $cmd|Out-Null
 $blocked=$false;try{Assert-NoReparsePoint -Path $nestedRoot -Label nested -Recursive}catch{$blocked=$true};Assert $blocked 'nested_junction_rejected'
 # Installer -Force must fail before the human-acceptance UI when destination is redirected.
 $project=Join-Path $temp 'project';$external=Join-Path $temp 'external-target';New-Item $project,$external -ItemType Directory|Out-Null;'sentinel'|Set-Content (Join-Path $external 'sentinel.txt')
 $dest=Join-Path $project '.comprehensive-qa';$cmd="mklink /J `"$dest`" `"$external`"";& cmd.exe /d /c $cmd|Out-Null
 $child=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\install.ps1') -ProjectPath $project -Force 2>&1;$rc=$LASTEXITCODE
 Assert ($rc-ne0) 'force_installer_rejects_redirected_runtime'
 Assert ((Get-Content (Join-Path $external 'sentinel.txt') -Raw).Trim()-eq'sentinel') 'redirect_target_untouched'
 Assert (-not(Test-Path (Join-Path $external 'AGENT_INSTRUCTIONS.md'))) 'installer_wrote_nothing_through_junction'
 Write-Host 'V21_PATH_SAFETY_RESULT=PASS'
 $global:LASTEXITCODE=0
}finally{if(Test-Path $temp){Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}}
exit 0
