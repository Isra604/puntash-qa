param([switch]$BuildPackage)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$failures=New-Object System.Collections.Generic.List[string]
function Check([bool]$ok,[string]$name){if($ok){Write-Host "PASS: $name"}else{$failures.Add($name);Write-Host "FAIL: $name"}}
$version=(Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$manifest=Get-Content (Join-Path $root 'manifest.json') -Raw|ConvertFrom-Json
Check ([string]$manifest.version -eq $version) 'VERSION matches manifest.json'
Check ((Get-ChildItem (Join-Path $root 'runtime\gates') -Filter 'GATE-*.md').Count -eq 25) 'exactly 25 gate files'
foreach($i in 1..25){Check (Test-Path (Join-Path $root ('runtime\gates\GATE-{0:D2}.md' -f $i))) ("gate {0:D2} exists" -f $i)}
foreach($j in @('manifest.json','LEGAL_MANIFEST.json','runtime\config\update.json')){try{Get-Content (Join-Path $root $j)-Raw|ConvertFrom-Json|Out-Null;Check $true "$j valid JSON"}catch{Check $false "$j valid JSON"}}
$terms=(Get-Content (Join-Path $root 'TERMS_VERSION') -Raw).Trim();Check ([string]$manifest.terms_version -eq $terms) 'Terms version consistency'
$legalManifest=Get-Content (Join-Path $root 'LEGAL_MANIFEST.json')-Raw|ConvertFrom-Json
$legalOk=$true
foreach($p in $legalManifest.documents.PSObject.Properties){$path=Join-Path $root $p.Name;if(-not(Test-Path $path)){$legalOk=$false;continue};$actual=(Get-FileHash -Algorithm SHA256 $path).Hash.ToUpperInvariant();if($actual -ne ([string]$p.Value).ToUpperInvariant()){$legalOk=$false}}
Check $legalOk 'legal document SHA-256 manifest integrity'
$psFiles=Get-ChildItem $root -Recurse -Filter '*.ps1' -File|Where-Object{$_.FullName -notmatch '\\.git\\|\\dist\\'}
foreach($p in $psFiles){$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile($p.FullName,[ref]$tokens,[ref]$errors)|Out-Null;Check ($errors.Count -eq 0) ("PowerShell parse: "+(Resolve-Path $p.FullName -Relative))}
$required=@('START_HERE_WINDOWS.cmd','scripts\install-gui.ps1','runtime\START_HERE.md','runtime\tools\qa-doctor.ps1','runtime\tools\qa-doctor.sh','docs\PRODUCT_ROADMAP.md','.github\workflows\qa.yml')
foreach($r in $required){Check (Test-Path (Join-Path $root $r)) "$r present"}
$guideCount=(Get-ChildItem (Join-Path $root 'runtime\agent-guides') -Filter '*.md' -File).Count;Check ($guideCount -ge 5) 'agent quick guides present'
$update=Get-Content (Join-Path $root 'runtime\config\update.json')-Raw|ConvertFrom-Json;Check ($update.current_visibility -eq 'public') 'public update channel retained'
$tracked=git -C $root ls-files
$secretRegex='gh[op]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
$secretHit=$false
foreach($rel in $tracked){$p=Join-Path $root $rel;if(Test-Path $p -PathType Leaf){try{$txt=Get-Content $p -Raw -ErrorAction Stop;if($txt -match $secretRegex){$secretHit=$true;Write-Host "SECRET_SIGNATURE_HIT=$rel"}}catch{}}}
Check (-not $secretHit) 'no common secret signatures in tracked text files'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('qa-doctor-selftest-'+[guid]::NewGuid().ToString('N'))
try{New-Item -ItemType Directory $temp|Out-Null;& (Join-Path $root 'runtime\tools\qa-doctor.ps1') -ProjectPath $root -OutputDirectory $temp|Out-Host;Check (Test-Path (Join-Path $temp 'QA_DOCTOR.json')) 'QA Doctor produces JSON';$d=Get-Content (Join-Path $temp 'QA_DOCTOR.json')-Raw|ConvertFrom-Json;Check ($d.status -eq 'READY_FOR_AGENT_DISCOVERY') 'QA Doctor status contract'}finally{if(Test-Path $temp){Remove-Item $temp -Recurse -Force}}
if($BuildPackage){& (Join-Path $root 'scripts\build-release.ps1') -OutputDirectory '.selftest-dist'|Out-Host;$zip=Join-Path $root ".selftest-dist\COMPREHENSIVE-QA-GATE-SYSTEM-v$version.zip";Check (Test-Path $zip) 'release ZIP builds';if(Test-Path $zip){Add-Type -AssemblyName System.IO.Compression.FileSystem;$z=[IO.Compression.ZipFile]::OpenRead($zip);try{$names=@($z.Entries.FullName);Check (@($names|Where-Object{$_ -match '^runtime/gates/GATE-\d\d\.md$'}).Count -eq 25) 'release ZIP contains 25 gates';Check ($names -contains 'runtime/tools/qa-doctor.ps1') 'release ZIP contains QA Doctor';Check ($names -contains 'START_HERE_WINDOWS.cmd') 'release ZIP contains Easy Start launcher'}finally{$z.Dispose()}};Remove-Item (Join-Path $root '.selftest-dist') -Recurse -Force -ErrorAction SilentlyContinue}
if($failures.Count){Write-Host "SELF_TEST_RESULT=FAIL COUNT=$($failures.Count)";foreach($f in $failures){Write-Host "FAILED=$f"};exit 1}
Write-Host 'SELF_TEST_RESULT=PASS'
