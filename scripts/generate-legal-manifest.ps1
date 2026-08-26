$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$version=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$terms=(Get-Content (Join-Path $root 'TERMS_VERSION') -Raw).Trim()
$documents=@('LICENSE','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','NOTICE','CREDITS.md')
$hashes=[ordered]@{}
foreach($name in $documents){$path=Join-Path $root $name;if(-not(Test-Path $path)){throw "Missing legal document: $name"};$hashes[$name]=(Get-FileHash -Algorithm SHA256 $path).Hash.ToUpperInvariant()}
[ordered]@{system='Universal Comprehensive QA Gate System';package_version=$version;terms_version=$terms;algorithm='SHA-256';line_endings='LF';documents=$hashes}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $root 'LEGAL_MANIFEST.json') -Encoding UTF8
Write-Host "LEGAL_MANIFEST_UPDATED=$version TERMS=$terms"
