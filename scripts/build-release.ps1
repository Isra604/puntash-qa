param([string]$OutputDirectory='dist')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$version=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$terms=(Get-Content (Join-Path $root 'TERMS_VERSION') -Raw).Trim()
$out=Join-Path $root $OutputDirectory
New-Item -ItemType Directory -Path $out -Force | Out-Null
$zipName="COMPREHENSIVE-QA-GATE-SYSTEM-v$version.zip"
$zipPath=Join-Path $out $zipName
if(Test-Path $zipPath){Remove-Item $zipPath -Force}
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$fs=[IO.File]::Open($zipPath,[IO.FileMode]::Create)
$archive=New-Object IO.Compression.ZipArchive($fs,[IO.Compression.ZipArchiveMode]::Create)
try{
  $tracked=git -C $root ls-files
  foreach($rel in $tracked){
    if($rel -like 'dist/*'){continue}
    $full=Join-Path $root $rel
    if(Test-Path $full -PathType Leaf){[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$full,$rel.Replace('\\','/'),[IO.Compression.CompressionLevel]::Optimal)|Out-Null}
  }
}finally{$archive.Dispose();$fs.Dispose()}
$sha=(Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToUpperInvariant()
Set-Content (Join-Path $out "$zipName.sha256") "$sha  $zipName" -Encoding ascii
[ordered]@{schema_version=1;name='Universal Comprehensive QA Gate System';version=$version;tag="v$version";asset_name=$zipName;sha256=$sha;terms_version=$terms;repository='Isra604/comprehensive-qa-gate-system';generated_at=(Get-Date).ToUniversalTime().ToString('o')}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $out 'release-manifest.json') -Encoding UTF8
Write-Host "ZIP=$zipPath";Write-Host "SHA256=$sha";Write-Host "VERSION=$version"
