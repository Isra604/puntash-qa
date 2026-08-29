param([Parameter(Mandatory=$true)][string]$RunPath)
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $RunPath -PathType Leaf)){throw "Run file not found: $RunPath"}
try{$r=Get-Content -LiteralPath $RunPath -Raw|ConvertFrom-Json}catch{Write-Host "RUN_VALIDATION=FAIL COUNT=1";Write-Host "ERROR=invalid JSON: $($_.Exception.Message)";exit 1}
$errors=New-Object System.Collections.Generic.List[string]
$status=@('PASS','FAIL','BLOCKED','NOT_RUN','NOT_APPLICABLE');$assurance=@('STRONG','MODERATE','WEAK','INSUFFICIENT');$allowedRoots=@('evidence','artifacts','profile','reports','remediation','dispositions')
$installRoot=Split-Path -Parent $PSScriptRoot
function NonEmpty($v){return ($null-ne$v-and-not[string]::IsNullOrWhiteSpace([string]$v))}
function HasRefs($v){if($null-eq$v){return $false};foreach($x in @($v)){if(NonEmpty $x){return $true}};return $false}
function Parse-Time($v){if($null-eq$v){return $null};if($v-is[DateTimeOffset]){return $v};if($v-is[DateTime]){return [DateTimeOffset]$v};if(-not(NonEmpty $v)){return $null};try{return [DateTimeOffset]::Parse([string]$v,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AllowWhiteSpaces)}catch{return $null}}
$preserved=New-Object System.Collections.Generic.List[object]
function Add-Refs($v,[string]$label){if($null-eq$v){return};foreach($x in @($v)){if(NonEmpty $x){$preserved.Add([pscustomobject]@{ref=[string]$x;label=$label})}}}
function Validate-Ref([string]$ref){
 if(-not(NonEmpty $ref)){return 'reference is empty'}
 $norm=$ref.Replace('\','/')
 if($norm.StartsWith('/')-or$norm-match'^[A-Za-z]:'){return 'absolute evidence paths are forbidden'}
 $parts=@($norm.Split('/')|Where-Object{$_-ne''})
 if($parts.Count-eq0-or$allowedRoots-notcontains$parts[0]){return "reference must be under a preserved QA evidence root"}
 if($parts-contains'..'){return 'path traversal is forbidden'}
 $cur=$installRoot
 foreach($part in $parts){
   $cur=Join-Path $cur $part
   if(-not(Test-Path -LiteralPath $cur)){return 'referenced evidence file does not exist'}
   $item=Get-Item -LiteralPath $cur -Force
   if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){return 'symlink/reparse evidence paths are forbidden'}
 }
 if(-not(Test-Path -LiteralPath $cur -PathType Leaf)){return 'referenced evidence path is not a file'}
 return $null
}
function Check-Item($x,[string]$kind,[int]$num){
 $st=([string]$x.status).ToUpperInvariant();$as=([string]$x.assurance).ToUpperInvariant()
 if($status-notcontains$st){$errors.Add("$kind-$num invalid status '$st'")};if($assurance-notcontains$as){$errors.Add("$kind-$num invalid assurance '$as'")}
 if($st-in@('PASS','FAIL')){if(([string]$x.evidence_freshness).ToUpperInvariant()-ne'CURRENT'){$errors.Add("$kind-$num $st requires evidence_freshness=CURRENT")};if(-not(HasRefs $x.evidence_refs)){$errors.Add("$kind-$num $st requires non-empty evidence_refs")}}
 if($st-eq'PASS'-and$as-in@('WEAK','INSUFFICIENT')){$errors.Add("$kind-$num PASS forbidden with $as evidence")};if($st-eq'FAIL'-and$as-in@('WEAK','INSUFFICIENT')){$errors.Add("$kind-$num FAIL forbidden with $as evidence; use BLOCKED/NOT_RUN until violation is adequately proven")}
 if($st-eq'PASS'-and$as-eq'MODERATE'-and$x.assurance_gap_non_material-ne$true){$errors.Add("$kind-$num MODERATE PASS requires assurance_gap_non_material=true")}
 if($st-eq'NOT_APPLICABLE'){if(-not(NonEmpty $x.applicability_rationale)){$errors.Add("$kind-$num NOT_APPLICABLE requires applicability_rationale")};if(-not(HasRefs $x.applicability_evidence)){$errors.Add("$kind-$num NOT_APPLICABLE requires applicability_evidence")}}
 if($kind-eq'LENS'){if(-not(NonEmpty $x.applicability_rationale)){$errors.Add("$kind-$num applicability_rationale required for every lens decision")};if(-not(HasRefs $x.applicability_evidence)){$errors.Add("$kind-$num applicability_evidence required for every lens decision")}}
 if($st-in@('BLOCKED','NOT_RUN')-and-not((NonEmpty $x.reason)-or(NonEmpty $x.notes)-or(NonEmpty $x.summary))){$errors.Add("$kind-$num $st requires reason/notes")}
 Add-Refs $x.evidence_refs "$kind-$num evidence_refs";Add-Refs $x.applicability_evidence "$kind-$num applicability_evidence"
}
try{$schema=[int]$r.schema_version}catch{$schema=0};if($schema-lt3){$errors.Add('schema_version must be >=3 for v2.1 current-run validation')}
if(-not(NonEmpty $r.run_id)){$errors.Add('run_id is required')}
if($schema-ge4){
 $fp=$r.project.fingerprint
 if($null-eq$r.project-or$null-eq$fp){$errors.Add('schema-v4 project.fingerprint object is required')}
 else{
  if([string]$fp.algorithm-ne'PUNTASH_SOURCE_V1'){$errors.Add('project.fingerprint.algorithm must be PUNTASH_SOURCE_V1')}
  if($fp.available-isnot[bool]){$errors.Add('project.fingerprint.available must be boolean')}
  elseif($fp.available-eq$true){
   if([string]$fp.sha256-notmatch'^[0-9A-Fa-f]{64}$'){$errors.Add('available project fingerprint requires 64-hex sha256')}
   foreach($key in @('file_count','byte_count')){$v=$fp.$key;if($v-is[bool]-or$v-isnot[int]-and$v-isnot[long]-or[int64]$v-lt0){$errors.Add("available project fingerprint $key must be a non-negative integer")}}
  }elseif(-not(NonEmpty $fp.reason)){$errors.Add('unavailable project fingerprint requires reason')}
 }
}
$started=Parse-Time $r.started_at;$completed=Parse-Time $r.completed_at;if($null-eq$started){$errors.Add('started_at must be a valid timestamp')};if($null-eq$completed){$errors.Add('completed_at must be a valid timestamp')};if($started-and$completed-and$completed-lt$started){$errors.Add('completed_at cannot precede started_at')}
$gates=@($r.gates);$lenses=@($r.lenses)
if($gates.Count-ne25){$errors.Add('exactly 25 gate records required')}else{$nums=@();foreach($g in $gates){$n=[int]$g.gate;$nums+=$n;Check-Item $g 'GATE' $n};if((($nums|Sort-Object)-join',')-ne((1..25)-join',')){$errors.Add('gate numbers must be unique 1..25')}}
if($lenses.Count-ne9){$errors.Add('exactly 9 lens records required')}else{$nums=@();foreach($l in $lenses){$n=[int]$l.lens;$nums+=$n;Check-Item $l 'LENS' $n};if((($nums|Sort-Object)-join',')-ne((1..9)-join',')){$errors.Add('lens numbers must be unique 1..9')}}
$g25=$gates|Where-Object{$_.gate-eq25}|Select-Object -First 1;$unresolved=@($lenses|Where-Object{$_.status-notin@('PASS','NOT_APPLICABLE')});if($g25.status-eq'PASS'-and$unresolved.Count){$errors.Add('GATE-25 PASS forbidden while any lens is FAIL/BLOCKED/NOT_RUN')}
$mapPath=Join-Path $installRoot 'gates\reliability-map.json';try{$relMap=Get-Content -LiteralPath $mapPath -Raw|ConvertFrom-Json}catch{$errors.Add("reliability_map_error: $($_.Exception.Message)");$relMap=$null}
if($relMap){foreach($lp in $relMap.blocking_gate_map.PSObject.Properties){$ln=[int]$lp.Name;$l=$lenses|Where-Object{$_.lens-eq$ln}|Select-Object -First 1;if($l-and$l.status-notin@('PASS','NOT_APPLICABLE')){foreach($gn in @($lp.Value)){$g=$gates|Where-Object{$_.gate-eq[int]$gn}|Select-Object -First 1;if($g-and$g.status-eq'PASS'){$ex=@($g.lens_exception_lenses);if($g.lens_impact_reviewed-ne$true-or$ex-notcontains$ln-or-not(NonEmpty $g.lens_exception_rationale)){$errors.Add("GATE-$gn PASS contradicts unresolved LENS-$ln; explicit reviewed non-material lens exception required")}}}}}}
$tt=$r.test_trustworthiness
if($null-eq$tt-or$tt.applicable-isnot[bool]){$errors.Add('test_trustworthiness decision with applicable=true/false is required')}
elseif($tt.applicable-eq$false){if(-not(NonEmpty $tt.applicability_rationale)){$errors.Add('test_trustworthiness NOT_APPLICABLE requires applicability_rationale')};if(-not(HasRefs $tt.applicability_evidence)){$errors.Add('test_trustworthiness NOT_APPLICABLE requires applicability_evidence')};Add-Refs $tt.applicability_evidence 'test_trustworthiness applicability_evidence'}
else{$ts=([string]$tt.status).ToUpperInvariant();$ta=([string]$tt.assurance).ToUpperInvariant();$l1=$lenses|Where-Object{$_.lens-eq1}|Select-Object -First 1;if($status-notcontains$ts-or$ts-eq'NOT_APPLICABLE'){$errors.Add('test_trustworthiness applicable requires explicit non-N/A status')};if($assurance-notcontains$ta){$errors.Add('test_trustworthiness applicable requires valid assurance')};if($ts-in@('PASS','FAIL')){if(([string]$tt.evidence_freshness).ToUpperInvariant()-ne'CURRENT'){$errors.Add('test_trustworthiness PASS/FAIL requires evidence_freshness=CURRENT')};if(-not(HasRefs $tt.evidence_refs)){$errors.Add('test_trustworthiness PASS/FAIL requires evidence_refs')}};if($ts-in@('BLOCKED','NOT_RUN')-and-not((NonEmpty $tt.reason)-or(NonEmpty $tt.notes))){$errors.Add('test_trustworthiness BLOCKED/NOT_RUN requires reason')};if($null-eq$l1-or$l1.status-eq'NOT_APPLICABLE'){$errors.Add('test_trustworthiness applicable requires LENS-01 applicable')};if(@($tt.decisive_suites).Count){if($ts-ne'PASS'){$errors.Add('decisive automated suites require test_trustworthiness status PASS')};if($ta-in@('WEAK','INSUFFICIENT')){$errors.Add('decisive automated suites cannot rely on weak/insufficient test trustworthiness')};if($ta-eq'MODERATE'-and$tt.assurance_gap_non_material-ne$true){$errors.Add('MODERATE test_trustworthiness for decisive suites requires assurance_gap_non_material=true')};if($null-eq$l1-or$l1.status-ne'PASS'){$errors.Add('decisive automated suites require LENS-01 PASS')}};Add-Refs $tt.evidence_refs 'test_trustworthiness evidence_refs'}
$overall=([string]$r.evidence_assurance.overall).ToUpperInvariant();if($assurance-notcontains$overall){$errors.Add('evidence_assurance.overall invalid')}else{$rank=@{INSUFFICIENT=0;WEAK=1;MODERATE=2;STRONG=3};$vals=New-Object System.Collections.Generic.List[int];foreach($x in @($gates)+@($lenses)){if($rank.ContainsKey(([string]$x.assurance).ToUpperInvariant())){$vals.Add($rank[([string]$x.assurance).ToUpperInvariant()])}};if($tt-and$tt.applicable-eq$true-and$rank.ContainsKey(([string]$tt.assurance).ToUpperInvariant())){$vals.Add($rank[([string]$tt.assurance).ToUpperInvariant()])};if($vals.Count-and$rank[$overall]-gt($vals|Measure-Object -Minimum).Minimum){$errors.Add('evidence_assurance.overall cannot be stronger than the weakest gate/lens/test-trustworthiness assurance')}}
# Automatic remediation declaration and authorization linkage.
$ar=$r.automatic_remediation
if($null-eq$ar-or$ar.performed-isnot[bool]-or$null-eq$ar.entries){$errors.Add('automatic_remediation with performed=true/false and entries=[] is required')}
else{
 $entries=@($ar.entries);if($ar.performed-eq$false-and$entries.Count){$errors.Add('automatic_remediation.performed=false requires entries=[]')};if($ar.performed-eq$true-and$entries.Count-eq0){$errors.Add('automatic_remediation.performed=true requires at least one remediation entry')}
 $history=@{};$histPath=Join-Path $installRoot 'state\CHANGE_AUTHORIZATION_HISTORY.jsonl';if(Test-Path -LiteralPath $histPath){$lineNo=0;foreach($line in Get-Content -LiteralPath $histPath){$lineNo++;if([string]::IsNullOrWhiteSpace($line)){continue};try{$rec=$line|ConvertFrom-Json;$aid=[string]$rec.authorization_id;if(NonEmpty $aid){if($history.ContainsKey($aid)){$errors.Add("authorization_history duplicate authorization_id: $aid")}else{$history[$aid]=$rec}}}catch{$errors.Add("authorization_history line $lineNo invalid JSON")}}}
 $used=@{};$idx=0
 foreach($e in $entries){$idx++;$prefix="automatic_remediation entry $idx";$aid=[string]$e.authorization_id;$fid=[string]$e.finding_id;$risk=([string]$e.risk).ToUpperInvariant();$category=[string]$e.category;$summary=[string]$e.change_summary;try{$rev=[int]$e.policy_revision}catch{$rev=0}
  if(-not(NonEmpty $aid)){$errors.Add("$prefix authorization_id required");continue};if($used.ContainsKey($aid)){$errors.Add("$prefix authorization_id must be unique within the run")}else{$used[$aid]=$true};if(-not(NonEmpty $fid)){$errors.Add("$prefix finding_id required")};if($risk-notin@('LOW','MEDIUM')){$errors.Add("$prefix risk must be LOW or MEDIUM")};if(-not(NonEmpty $category)){$errors.Add("$prefix category required")};if(-not(NonEmpty $summary)){$errors.Add("$prefix change_summary required")};if($rev-lt1){$errors.Add("$prefix policy_revision must be a positive integer")}
  foreach($field in @('authorization_evidence_refs','pre_fix_evidence_refs','post_fix_evidence_refs','revalidation_refs')){$rv=$e.$field;if(-not(HasRefs $rv)){$errors.Add("$prefix $field requires preserved evidence refs")};Add-Refs $rv "$prefix $field"}
  $authorized=@($e.authorized_target_paths);$changed=@($e.files_changed);foreach($pair in @(@('authorized_target_paths',$authorized),@('files_changed',$changed))){$field=[string]$pair[0];$paths=@($pair[1]);if($paths.Count-eq0-or@($paths|Where-Object{-not(NonEmpty $_)}).Count){$errors.Add("$prefix $field requires one or more paths")}else{$norms=@();foreach($pathS in $paths){$norm=([string]$pathS).Replace('\','/');$norms+=$norm;if($norm.StartsWith('/')-or$norm-match'^[A-Za-z]:'-or@($norm.Split('/'))-contains'..'-or@($norm.Split('/'))-contains'.'){$errors.Add("$prefix $field path must be project-relative without traversal: '$pathS'")}};if(@($norms|Select-Object -Unique).Count-ne$norms.Count){$errors.Add("$prefix $field contains duplicate paths")}}}
  if(-not$history.ContainsKey($aid)){$errors.Add("$prefix authorization_id '$aid' not found in authorization history");continue};$rec=$history[$aid];if([string]$rec.decision-ne'ALLOW'){$errors.Add("$prefix authorization record is not ALLOW")};foreach($pair in @(@('finding_id',$fid),@('risk',$risk),@('category',$category),@('change_summary',$summary))){if([string]$rec.($pair[0])-cne[string]$pair[1]){$errors.Add("$prefix $($pair[0]) does not match authorization record")}};if([int]$rec.policy_revision-ne$rev){$errors.Add("$prefix policy_revision does not match authorization record")}
  $expected=@($e.authorization_evidence_refs|ForEach-Object{([string]$_).Replace('\','/')}|Sort-Object -Unique);$actual=@($rec.evidence_refs|ForEach-Object{([string]$_).Replace('\','/')}|Sort-Object -Unique);if(($expected-join"`n")-cne($actual-join"`n")){$errors.Add("$prefix authorization_evidence_refs do not match authorization record")};$authTargets=@($e.authorized_target_paths|ForEach-Object{([string]$_).Replace('\','/')}|Sort-Object -Unique);$recordTargets=@($rec.target_paths|ForEach-Object{([string]$_).Replace('\','/')}|Sort-Object -Unique);$changedTargets=@($e.files_changed|ForEach-Object{([string]$_).Replace('\','/')}|Sort-Object -Unique);if($recordTargets.Count-eq0){$errors.Add("$prefix authorization record target_paths missing")};if(($authTargets-join"`n")-cne($recordTargets-join"`n")){$errors.Add("$prefix authorized_target_paths do not match authorization record")};if(($changedTargets-join"`n")-cne($authTargets-join"`n")){$errors.Add("$prefix files_changed must exactly match authorized_target_paths")};if($rec.expected_behavior_proven-ne$true-or$rec.reversible-ne$true){$errors.Add("$prefix authorization record lacks expected-behavior/reversibility proof")};$decided=Parse-Time $rec.decided_at;if($null-eq$decided){$errors.Add("$prefix authorization record decided_at invalid")}elseif($started-and$completed-and-not($decided-ge$started-and$decided-le$completed)){$errors.Add("$prefix authorization must be issued during the current run window")}
 }
}
# Preserved evidence path reality and reparse defense.
$seen=@{};foreach($item in $preserved){$key=([string]$item.ref).Replace('\','/');if($seen.ContainsKey($key)){continue};$seen[$key]=$true;$issue=Validate-Ref ([string]$item.ref);if($issue){$errors.Add("$($item.label): '$($item.ref)': $issue")}}
if($errors.Count){Write-Host "RUN_VALIDATION=FAIL COUNT=$($errors.Count)";$errors|ForEach-Object{Write-Host "ERROR=$_"};exit 1}
Write-Host 'RUN_VALIDATION=PASS'
