param([Parameter(Mandatory=$true)][string]$RunPath)
$ErrorActionPreference='Stop'
if(-not(Test-Path $RunPath -PathType Leaf)){throw "Run file not found: $RunPath"}
try{$r=Get-Content $RunPath -Raw|ConvertFrom-Json}catch{Write-Host "RUN_VALIDATION=FAIL COUNT=1";Write-Host "ERROR=invalid JSON: $($_.Exception.Message)";exit 1}
$errors=New-Object System.Collections.Generic.List[string]
$status=@('PASS','FAIL','BLOCKED','NOT_RUN','NOT_APPLICABLE');$assurance=@('STRONG','MODERATE','WEAK','INSUFFICIENT')
function NonEmpty($v){return ($null-ne $v -and -not[string]::IsNullOrWhiteSpace([string]$v))}
function HasRefs($v){if($null-eq$v){return $false};foreach($x in @($v)){if(NonEmpty $x){return $true}};return $false}
function Check-Item($x,[string]$kind,[int]$num){
 $st=([string]$x.status).ToUpperInvariant();$as=([string]$x.assurance).ToUpperInvariant()
 if($status -notcontains $st){$errors.Add("$kind-$num invalid status '$st'")}
 if($assurance -notcontains $as){$errors.Add("$kind-$num invalid assurance '$as'")}
 if($st -in @('PASS','FAIL')){if(([string]$x.evidence_freshness).ToUpperInvariant()-ne'CURRENT'){$errors.Add("$kind-$num $st requires evidence_freshness=CURRENT")};if(-not(HasRefs $x.evidence_refs)){$errors.Add("$kind-$num $st requires non-empty evidence_refs")}}
 if($st-eq'PASS'-and$as-in@('WEAK','INSUFFICIENT')){$errors.Add("$kind-$num PASS forbidden with $as evidence")}
 if($st-eq'FAIL'-and$as-in@('WEAK','INSUFFICIENT')){$errors.Add("$kind-$num FAIL forbidden with $as evidence; use BLOCKED/NOT_RUN until violation is adequately proven")}
 if($st-eq'PASS'-and$as-eq'MODERATE'-and$x.assurance_gap_non_material-ne$true){$errors.Add("$kind-$num MODERATE PASS requires assurance_gap_non_material=true")}
 if($st-eq'NOT_APPLICABLE'){if(-not(NonEmpty $x.applicability_rationale)){$errors.Add("$kind-$num NOT_APPLICABLE requires applicability_rationale")};if(-not(HasRefs $x.applicability_evidence)){$errors.Add("$kind-$num NOT_APPLICABLE requires applicability_evidence")}}
 if($kind-eq'LENS'){if(-not(NonEmpty $x.applicability_rationale)){$errors.Add("$kind-$num applicability_rationale required for every lens decision")};if(-not(HasRefs $x.applicability_evidence)){$errors.Add("$kind-$num applicability_evidence required for every lens decision")}}
 if($st-in@('BLOCKED','NOT_RUN')-and-not((NonEmpty $x.reason)-or(NonEmpty $x.notes)-or(NonEmpty $x.summary))){$errors.Add("$kind-$num $st requires reason/notes")}
}
if([int]$r.schema_version-lt2){$errors.Add('schema_version must be >=2')}
$gates=@($r.gates);$lenses=@($r.lenses)
if($gates.Count-ne25){$errors.Add('exactly 25 gate records required')}else{$nums=@();foreach($g in $gates){$n=[int]$g.gate;$nums+=$n;Check-Item $g 'GATE' $n};if(($nums|Sort-Object)-join','-ne((1..25)-join',')){$errors.Add('gate numbers must be unique 1..25')}}
if($lenses.Count-ne9){$errors.Add('exactly 9 lens records required')}else{$nums=@();foreach($l in $lenses){$n=[int]$l.lens;$nums+=$n;Check-Item $l 'LENS' $n};if(($nums|Sort-Object)-join','-ne((1..9)-join',')){$errors.Add('lens numbers must be unique 1..9')}}
$g25=$gates|Where-Object{$_.gate-eq25}|Select-Object -First 1;$unresolved=@($lenses|Where-Object{$_.status-notin@('PASS','NOT_APPLICABLE')})
if($g25.status-eq'PASS'-and$unresolved.Count){$errors.Add('GATE-25 PASS forbidden while any lens is FAIL/BLOCKED/NOT_RUN')}
$mapPath=Join-Path (Split-Path -Parent $PSScriptRoot) 'gates\reliability-map.json'
try{$relMap=Get-Content $mapPath -Raw|ConvertFrom-Json}catch{$errors.Add("reliability_map_error: $($_.Exception.Message)");$relMap=$null}
if($relMap){foreach($lp in $relMap.blocking_gate_map.PSObject.Properties){$ln=[int]$lp.Name;$l=$lenses|Where-Object{$_.lens-eq$ln}|Select-Object -First 1;if($l-and$l.status-notin@('PASS','NOT_APPLICABLE')){foreach($gn in @($lp.Value)){$g=$gates|Where-Object{$_.gate-eq[int]$gn}|Select-Object -First 1;if($g-and$g.status-eq'PASS'){$ex=@($g.lens_exception_lenses);if($g.lens_impact_reviewed-ne$true-or$ex-notcontains$ln-or-not(NonEmpty $g.lens_exception_rationale)){$errors.Add("GATE-$gn PASS contradicts unresolved LENS-$ln; explicit reviewed non-material lens exception required")}}}}}}
$tt=$r.test_trustworthiness
if($null-eq$tt-or$tt.applicable-isnot[bool]){$errors.Add('test_trustworthiness decision with applicable=true/false is required')}
elseif($tt.applicable-eq$false){if(-not(NonEmpty $tt.applicability_rationale)){$errors.Add('test_trustworthiness NOT_APPLICABLE requires applicability_rationale')};if(-not(HasRefs $tt.applicability_evidence)){$errors.Add('test_trustworthiness NOT_APPLICABLE requires applicability_evidence')}}
else{$ts=([string]$tt.status).ToUpperInvariant();$ta=([string]$tt.assurance).ToUpperInvariant();$l1=$lenses|Where-Object{$_.lens-eq1}|Select-Object -First 1;if($status-notcontains$ts-or$ts-eq'NOT_APPLICABLE'){$errors.Add('test_trustworthiness applicable requires explicit non-N/A status')};if($assurance-notcontains$ta){$errors.Add('test_trustworthiness applicable requires valid assurance')};if($ts-in@('PASS','FAIL')){if(([string]$tt.evidence_freshness).ToUpperInvariant()-ne'CURRENT'){$errors.Add('test_trustworthiness PASS/FAIL requires evidence_freshness=CURRENT')};if(-not(HasRefs $tt.evidence_refs)){$errors.Add('test_trustworthiness PASS/FAIL requires evidence_refs')}};if($ts-in@('BLOCKED','NOT_RUN')-and-not((NonEmpty $tt.reason)-or(NonEmpty $tt.notes))){$errors.Add('test_trustworthiness BLOCKED/NOT_RUN requires reason')};if($null-eq$l1-or$l1.status-eq'NOT_APPLICABLE'){$errors.Add('test_trustworthiness applicable requires LENS-01 applicable')};if(@($tt.decisive_suites).Count){if($ts-ne'PASS'){$errors.Add('decisive automated suites require test_trustworthiness status PASS')};if($ta-in@('WEAK','INSUFFICIENT')){$errors.Add('decisive automated suites cannot rely on weak/insufficient test trustworthiness')};if($ta-eq'MODERATE'-and$tt.assurance_gap_non_material-ne$true){$errors.Add('MODERATE test_trustworthiness for decisive suites requires assurance_gap_non_material=true')};if($null-eq$l1-or$l1.status-ne'PASS'){$errors.Add('decisive automated suites require LENS-01 PASS')}}}
$overall=([string]$r.evidence_assurance.overall).ToUpperInvariant()
if($assurance-notcontains$overall){$errors.Add('evidence_assurance.overall invalid')}
else{$rank=@{INSUFFICIENT=0;WEAK=1;MODERATE=2;STRONG=3};$vals=New-Object System.Collections.Generic.List[int];foreach($x in @($gates)+@($lenses)){if($rank.ContainsKey(([string]$x.assurance).ToUpperInvariant())){$vals.Add($rank[([string]$x.assurance).ToUpperInvariant()])}};if($tt-and$tt.applicable-eq$true-and$rank.ContainsKey(([string]$tt.assurance).ToUpperInvariant())){$vals.Add($rank[([string]$tt.assurance).ToUpperInvariant()])};if($vals.Count-and$rank[$overall]-gt($vals|Measure-Object -Minimum).Minimum){$errors.Add('evidence_assurance.overall cannot be stronger than the weakest gate/lens/test-trustworthiness assurance')}}
if($errors.Count){Write-Host "RUN_VALIDATION=FAIL COUNT=$($errors.Count)";$errors|ForEach-Object{Write-Host "ERROR=$_"};exit 1}
Write-Host 'RUN_VALIDATION=PASS'
