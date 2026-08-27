$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$version=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$terms=(Get-Content (Join-Path $root 'TERMS_VERSION') -Raw).Trim()
$documents=@('LICENSE','TERMS_OF_USE.md','DISCLAIMER.md','DATA_RESPONSIBILITY_NOTICE.md','HUMAN_ACCEPTANCE.md','NOTICE','CREDITS.md')
$utf8NoBom=New-Object System.Text.UTF8Encoding($false)
$hashes=[ordered]@{}
foreach($name in $documents){
  $path=Join-Path $root $name
  if(-not(Test-Path $path -PathType Leaf)){throw "Missing legal document: $name"}
  $text=[IO.File]::ReadAllText($path)
  $text=$text.Replace("`r`n","`n").Replace("`r","`n")
  [IO.File]::WriteAllText($path,$text,$utf8NoBom)
  $stream=[IO.File]::OpenRead($path);$sha=[Security.Cryptography.SHA256]::Create()
  try{$hashes[$name]=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToUpperInvariant()}finally{$sha.Dispose();$stream.Dispose()}
}
$manifest=[ordered]@{system='Universal Comprehensive QA Gate System';package_version=$version;terms_version=$terms;algorithm='SHA-256';line_endings='LF';documents=$hashes}|ConvertTo-Json -Depth 6
$manifest=$manifest.Replace("`r`n","`n").Replace("`r","`n")+"`n"
[IO.File]::WriteAllText((Join-Path $root 'LEGAL_MANIFEST.json'),$manifest,$utf8NoBom)
Write-Host "LEGAL_MANIFEST_UPDATED=$version TERMS=$terms"
