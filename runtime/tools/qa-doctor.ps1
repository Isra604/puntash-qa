param(
  [string]$ProjectPath,
  [string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$installRoot=Split-Path -Parent $PSScriptRoot
if(-not $ProjectPath){$ProjectPath=Split-Path -Parent $installRoot}
if(-not(Test-Path $ProjectPath -PathType Container)){throw "Project path not found: $ProjectPath"}
$project=(Resolve-Path $ProjectPath).Path
if(-not $OutputDirectory){$OutputDirectory=Join-Path $installRoot 'state'}
New-Item -ItemType Directory -Path $OutputDirectory -Force|Out-Null

$skip=@('.git','.comprehensive-qa','.comprehensive-qa-backups','node_modules','vendor','dist','build','out','target','.next','.nuxt','.venv','venv','env','__pycache__','.pytest_cache','.cache','.idea','.vs')
$files=New-Object System.Collections.Generic.List[System.IO.FileInfo]
$stack=New-Object System.Collections.Generic.Stack[System.IO.DirectoryInfo]
$stack.Push((Get-Item $project))
$maxFiles=5000
while($stack.Count -gt 0 -and $files.Count -lt $maxFiles){
  $dir=$stack.Pop()
  try{foreach($f in $dir.EnumerateFiles()){if($files.Count -ge $maxFiles){break};$files.Add($f)}}catch{}
  try{foreach($d in $dir.EnumerateDirectories()){if($skip -notcontains $d.Name){$stack.Push($d)}}}catch{}
}
function Rel($p){try{return [IO.Path]::GetRelativePath($project,$p)}catch{return $p.Substring($project.Length).TrimStart('\\','/')}}
$rels=@($files|ForEach-Object{Rel $_.FullName})

$manifestNames=@('package.json','pyproject.toml','requirements.txt','Pipfile','poetry.lock','go.mod','Cargo.toml','pom.xml','build.gradle','build.gradle.kts','settings.gradle','settings.gradle.kts','Gemfile','composer.json','mix.exs','Package.swift')
$manifests=@($files|Where-Object{$manifestNames -contains $_.Name}|ForEach-Object{Rel $_.FullName}|Sort-Object -Unique)
$projectFiles=@($files|Where-Object{$_.Extension -in @('.sln','.csproj','.fsproj','.vbproj')}|ForEach-Object{Rel $_.FullName}|Sort-Object -Unique)
$manifests=@($manifests+$projectFiles|Sort-Object -Unique)

$langMap=[ordered]@{'.ts'='TypeScript';'.tsx'='TypeScript/React';'.js'='JavaScript';'.jsx'='JavaScript/React';'.py'='Python';'.cs'='C#';'.java'='Java';'.kt'='Kotlin';'.go'='Go';'.rs'='Rust';'.rb'='Ruby';'.php'='PHP';'.swift'='Swift';'.dart'='Dart';'.cpp'='C++';'.cc'='C++';'.c'='C';'.h'='C/C++';'.sql'='SQL';'.tf'='Terraform';'.sh'='Shell';'.ps1'='PowerShell'}
$langCounts=[ordered]@{}
foreach($f in $files){$e=$f.Extension.ToLowerInvariant();if($langMap.Contains($e)){$n=$langMap[$e];if(-not$langCounts.Contains($n)){$langCounts[$n]=0};$langCounts[$n]++}}

$testSignal=@($rels|Where-Object{$_ -match '(^|[\\/])(test|tests|__tests__|spec|specs)([\\/]|$)' -or $_ -match '(test|spec)\.[^.]+$'}).Count -gt 0
$dbSignal=@($rels|Where-Object{$_ -match '(^|[\\/])(migrations?|prisma|supabase|database|db)([\\/]|$)' -or $_ -match '\.sql$' -or $_ -match 'schema\.(prisma|sql)$'}).Count -gt 0
$e2eSignal=@($rels|Where-Object{$_ -match 'playwright\.config|cypress\.config|(^|[\\/])e2e([\\/]|$)|selenium|webdriver'}).Count -gt 0
$ciSignal=(Test-Path (Join-Path $project '.github\workflows')) -or (Test-Path (Join-Path $project '.gitlab-ci.yml')) -or (Test-Path (Join-Path $project 'azure-pipelines.yml'))
$containerSignal=(Test-Path (Join-Path $project 'Dockerfile')) -or (@($rels|Where-Object{$_ -match 'docker-compose|compose\.ya?ml$'}).Count -gt 0)
$infraSignal=@($rels|Where-Object{$_ -match '\.tf$|(^|[\\/])(helm|k8s|kubernetes|terraform|infrastructure|infra)([\\/]|$)'}).Count -gt 0
$authSignal=@($rels|Where-Object{$_ -match '(^|[\\/])(auth|authentication|authorization|oauth|oidc|jwt)([\\/]|[._-])'}).Count -gt 0
$obsSignal=@($rels|Where-Object{$_ -match 'opentelemetry|telemetry|tracing|metrics|sentry|prometheus|grafana'}).Count -gt 0
$gitSignal=$false
if(Get-Command git -ErrorAction SilentlyContinue){try{git -C $project rev-parse --is-inside-work-tree 2>$null|Out-Null;if($LASTEXITCODE -eq 0){$gitSignal=$true}}catch{}}

$toolNames=@('git','node','npm','pnpm','yarn','python','python3','dotnet','java','mvn','gradle','go','cargo','rustc','docker','podman','bash','pwsh')
$tools=[ordered]@{}
foreach($t in $toolNames){$tools[$t]=[bool](Get-Command $t -ErrorAction SilentlyContinue)}

$packageScripts=@()
$package=Join-Path $project 'package.json'
if(Test-Path $package){try{$pj=Get-Content $package -Raw|ConvertFrom-Json;if($pj.scripts){$packageScripts=@($pj.scripts.PSObject.Properties.Name|Sort-Object)}}catch{}}
$buildSignal=(@($packageScripts|Where-Object{$_ -match 'build|compile|typecheck|lint'}).Count -gt 0) -or ($manifests.Count -gt 0)

$typeHints=New-Object System.Collections.Generic.List[string]
if(Test-Path $package){$typeHints.Add('Node/JavaScript ecosystem')}
if($manifests -match 'pyproject.toml|requirements.txt|Pipfile|poetry.lock'){$typeHints.Add('Python project')}
if($projectFiles.Count -gt 0){$typeHints.Add('.NET project')}
if($manifests -match 'go.mod'){$typeHints.Add('Go project')}
if($manifests -match 'Cargo.toml'){$typeHints.Add('Rust project')}
if($manifests -match 'pom.xml|build.gradle|build.gradle.kts'){$typeHints.Add('JVM project')}
if($infraSignal){$typeHints.Add('Infrastructure/configuration project signals')}
if($e2eSignal){$typeHints.Add('Browser/E2E project signals')}
if($typeHints.Count -eq 0){$typeHints.Add('Unknown/mixed project - agent discovery required')}

$gateSet=New-Object System.Collections.Generic.HashSet[int]
foreach($g in @(1,2,21,25)){[void]$gateSet.Add($g)}
if($buildSignal){foreach($g in @(3,17)){[void]$gateSet.Add($g)}}
if($testSignal){foreach($g in @(4,13,14)){[void]$gateSet.Add($g)}}
if($dbSignal){[void]$gateSet.Add(12)}
if($e2eSignal){[void]$gateSet.Add(15)}
if($ciSignal){[void]$gateSet.Add(24)}
if($obsSignal){[void]$gateSet.Add(20)}
if($authSignal){[void]$gateSet.Add(22)}
if($infraSignal -or $containerSignal){foreach($g in @(19,23)){[void]$gateSet.Add($g)}}
$gateEstimate=@($gateSet|Sort-Object)

$result=[ordered]@{
 schema_version=1
 doctor_version='1.0'
 status='READY_FOR_AGENT_DISCOVERY'
 generated_at=(Get-Date).ToString('o')
 project_path=$project
 scanned_files=$files.Count
 scan_file_limit=$maxFiles
 project_type_hints=@($typeHints)
 detected_languages=$langCounts
 manifests=$manifests
 package_scripts=$packageScripts
 signals=[ordered]@{git_repository=$gitSignal;tests=$testSignal;build_or_manifest=$buildSignal;database_or_schema=$dbSignal;browser_e2e=$e2eSignal;ci=$ciSignal;containers=$containerSignal;infrastructure=$infraSignal;authentication=$authSignal;observability=$obsSignal}
 local_tools=$tools
 local_evidence_gate_estimate=[ordered]@{count=$gateEstimate.Count;of=25;gates=$gateEstimate;meaning='Conservative local evidence signals only. This is NOT a gate status, PASS claim or applicability decision.'}
 note='QA Doctor output is a pre-discovery hint set. The AI agent must verify every relevant fact from direct current evidence.'
}
$jsonPath=Join-Path $OutputDirectory 'QA_DOCTOR.json'
$result|ConvertTo-Json -Depth 10|Set-Content $jsonPath -Encoding UTF8
$langText=if($langCounts.Count){($langCounts.GetEnumerator()|ForEach-Object{"$($_.Key)=$($_.Value)"}) -join ', '}else{'No common source extensions detected'}
$manifestText=if($manifests.Count){$manifests -join ', '}else{'None detected'}
$toolText=($tools.GetEnumerator()|Where-Object{$_.Value}|ForEach-Object{$_.Key}) -join ', '
$signalLines=($result.signals.GetEnumerator()|ForEach-Object{"- $($_.Key): $($_.Value)"}) -join "`r`n"
$md=@"
# QA Doctor Readiness Report

Status: READY_FOR_AGENT_DISCOVERY
Generated: $($result.generated_at)
Project: $project
Files sampled: $($files.Count) / limit $maxFiles

## Project hints
$(@($typeHints)|ForEach-Object{"- $_"}|Out-String)
## Languages
$langText

## Build/package manifests
$manifestText

## Signals
$signalLines

## Local tools detected
$toolText

## Conservative local evidence estimate
$($gateEstimate.Count)/25 gates have some local evidence/tool signal: $($gateEstimate -join ', ')

This estimate is NOT a QA verdict, PASS status or applicability decision. The AI agent must verify the project through Phase 0 and Discovery.
"@
$mdPath=Join-Path $OutputDirectory 'QA_DOCTOR.md'
Set-Content $mdPath $md -Encoding UTF8
Write-Host "QA_DOCTOR_STATUS=READY_FOR_AGENT_DISCOVERY"
Write-Host "QA_DOCTOR_SCANNED_FILES=$($files.Count)"
Write-Host "QA_DOCTOR_LOCAL_EVIDENCE_GATES=$($gateEstimate.Count)/25"
Write-Host "QA_DOCTOR_JSON=$jsonPath"
Write-Host "QA_DOCTOR_MD=$mdPath"
