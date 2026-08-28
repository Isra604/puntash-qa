$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
function Assert([bool]$c,[string]$n){if(-not$c){throw "V21_REPRO_BUILD_FAIL=$n"};Write-Host "V21_REPRO_BUILD_PASS=$n"}
$status=@(& git -C $root status --porcelain=v1 --untracked-files=all);Assert ($status.Count-eq0) 'working_tree_clean_before_repro_build'
$a='.repro-dist-a';$b='.repro-dist-b'
try{
 & (Join-Path $root 'scripts\build-release.ps1') -OutputDirectory $a|Out-Null
 & (Join-Path $root 'scripts\build-release.ps1') -OutputDirectory $b|Out-Null
 $version=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim();$name="PUNTASH-QA-v$version.zip"
 $za=Join-Path $root "$a\$name";$zb=Join-Path $root "$b\$name";$shaA=(Get-FileHash $za -Algorithm SHA256).Hash;$shaB=(Get-FileHash $zb -Algorithm SHA256).Hash
 Assert ($shaA-eq$shaB) 'same_commit_produces_identical_zip_sha256'
 $ma=[IO.File]::ReadAllBytes((Join-Path $root "$a\release-manifest.json"));$mb=[IO.File]::ReadAllBytes((Join-Path $root "$b\release-manifest.json"));Assert ([Convert]::ToBase64String($ma)-eq[Convert]::ToBase64String($mb)) 'release_manifest_is_deterministic'
 $sa=[IO.File]::ReadAllBytes((Join-Path $root "$a\$name.sha256"));$sb=[IO.File]::ReadAllBytes((Join-Path $root "$b\$name.sha256"));Assert ([Convert]::ToBase64String($sa)-eq[Convert]::ToBase64String($sb)) 'sha_file_is_deterministic'
 $m=Get-Content (Join-Path $root "$a\release-manifest.json") -Raw|ConvertFrom-Json;$head=(& git -C $root rev-parse HEAD).Trim();$tree=(& git -C $root rev-parse 'HEAD^{tree}').Trim()
 Assert ([string]$m.source_commit-eq$head) 'manifest_binds_source_commit';Assert ([string]$m.source_tree-eq$tree) 'manifest_binds_source_tree';Assert ($m.reproducible_from_clean_head-eq$true) 'manifest_declares_clean_head_reproducibility'
 Write-Host "V21_REPRO_BUILD_SHA256=$shaA";Write-Host 'V21_REPRO_BUILD_RESULT=PASS';exit 0
}finally{foreach($d in @($a,$b)){$p=Join-Path $root $d;if(Test-Path $p){Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue}}}
