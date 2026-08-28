param([string]$OutputDirectory='dist')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$version=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$terms=(Get-Content (Join-Path $root 'TERMS_VERSION') -Raw).Trim()
$status=@(& git -C $root status --porcelain=v1 --untracked-files=all)
if($LASTEXITCODE-ne0){throw 'Unable to determine Git working-tree state.'}
if($status.Count){throw "Release packaging requires a clean Git working tree. Commit or remove all changes before building.`n$($status-join"`n")"}
$head=(& git -C $root rev-parse HEAD).Trim();if($LASTEXITCODE-ne0-or-not$head){throw 'Unable to resolve source commit.'}
$tree=(& git -C $root rev-parse 'HEAD^{tree}').Trim();if($LASTEXITCODE-ne0-or-not$tree){throw 'Unable to resolve source tree.'}
$sourceTime=(& git -C $root show -s --format=%cI HEAD).Trim();if($LASTEXITCODE-ne0-or-not$sourceTime){throw 'Unable to resolve source commit time.'}
$out=Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Path $out -Force|Out-Null
$zipName="PUNTASH-QA-v$version.zip";$zipPath=Join-Path $out $zipName
if(Test-Path -LiteralPath $zipPath){Remove-Item -LiteralPath $zipPath -Force}
& git -C $root archive '--format=zip' "--output=$zipPath" HEAD
if($LASTEXITCODE-ne0-or-not(Test-Path -LiteralPath $zipPath -PathType Leaf)){throw 'git archive failed to create release ZIP.'}
$sha=(Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToUpperInvariant()
[IO.File]::WriteAllText((Join-Path $out "$zipName.sha256"),"$sha  $zipName`n",(New-Object Text.UTF8Encoding($false)))
$manifest=[ordered]@{schema_version=2;name='PUNTASH QA';version=$version;tag="v$version";asset_name=$zipName;sha256=$sha;terms_version=$terms;repository='Isra604/puntash-qa';source_commit=$head;source_tree=$tree;source_commit_time=$sourceTime;reproducible_from_clean_head=$true}|ConvertTo-Json -Depth 5
$manifest=$manifest.Replace("`r`n","`n").Replace("`r","`n")+"`n";[IO.File]::WriteAllText((Join-Path $out 'release-manifest.json'),$manifest,(New-Object Text.UTF8Encoding($false)))
Write-Host "ZIP=$zipPath";Write-Host "SHA256=$sha";Write-Host "VERSION=$version";Write-Host "SOURCE_COMMIT=$head";Write-Host "SOURCE_TREE=$tree"
