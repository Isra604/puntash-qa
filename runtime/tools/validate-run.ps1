param([Parameter(Mandatory=$true)][string]$RunPath)
$ErrorActionPreference='Stop'
if(-not(Test-Path $RunPath -PathType Leaf)){throw "Run file not found: $RunPath"}
try{$r=Get-Content $RunPath -Raw|ConvertFrom-Json}catch{Write-Host "RUN_VALIDATION=FAIL COUNT=1";Write-Host "ERROR=invalid JSON: $($_.Exception.Message)";exit 1}
$errors=New-Object System.Collections.Generic.List[string]
$status=@('PASS','FAIL','BLOCKED','NOT_RUN','NOT_APPLICABLE');$assurance=@('STRONG','MODERATE','WEAK','INSUFFICIENT')
function NonEmpty($v){return ($null-ne $v -and -not[string]::IsNullOrWhiteSpace([string]$v))}
function Check-Item($x,[string]$kind,[int]$num){
 $st=[string]$x.status;$as=[string]$x.assurance
 if($status -notcontains $st){$errors.Add("$kind-$num invalid status '$st'")}
 if($assurance -notcontains $as){$errors.Add("$kind-$num invalid assurance '$as'")}
 if($st -eq 'PASS' -and $as -in @('WEAK','INSUFFICIENT')){$errors.Add("$kind-$num PASS forbidden with $as evidence")}
 if($st -eq 'PASS' -and $as -eq 'MODERATE' -and $x.assurance_gap_non_material -ne $true){$errors.Add("$kind-$num MODERATE PASS requires assurance_gap_non_material=true")}
 if($st -eq 'NOT_APPLICABLE' -and -not(NonEmpty $x.applicability_rationale)){$errors.Add("$kind-$num NOT_APPLICABLE requires applicability_rationale")}
 if($st -in @('BLOCKED','NOT_RUN') -and -not((NonEmpty $x.reason)-or(NonEmpty $x.notes)-or(NonEmpty $x.summary))){$errors.Add("$kind-$num $st requires reason/notes")}
}
if([int]$r.schema_version -lt 2){$errors.Add('schema_version must be >=2')}
$gates=@($r.gates);$lenses=@($r.lenses)
if($gates.Count-ne25){$errors.Add('exactly 25 gate records required')}else{$nums=@();foreach($g in $gates){$n=[int]$g.gate;$nums+=$n;Check-Item $g 'GATE' $n};if(($nums|Sort-Object)-join',' -ne ((1..25)-join',')){$errors.Add('gate numbers must be unique 1..25')}}
if($lenses.Count-ne9){$errors.Add('exactly 9 lens records required')}else{$nums=@();foreach($l in $lenses){$n=[int]$l.lens;$nums+=$n;Check-Item $l 'LENS' $n};if(($nums|Sort-Object)-join',' -ne ((1..9)-join',')){$errors.Add('lens numbers must be unique 1..9')}}
$g25=$gates|Where-Object{$_.gate-eq25}|Select-Object -First 1
$unresolved=@($lenses|Where-Object{$_.status-notin@('PASS','NOT_APPLICABLE')})
if($g25.status-eq'PASS'-and$unresolved.Count){$errors.Add('GATE-25 PASS forbidden while any lens is FAIL/BLOCKED/NOT_RUN')}
if($r.test_trustworthiness.applicable-eq$true){$l1=$lenses|Where-Object{$_.lens-eq1}|Select-Object -First 1;if($null-eq$l1-or$l1.status-eq'NOT_APPLICABLE'){$errors.Add('test_trustworthiness applicable requires LENS-01 applicable')}}
if($assurance-notcontains[string]$r.evidence_assurance.overall){$errors.Add('evidence_assurance.overall invalid')}
if($errors.Count){Write-Host "RUN_VALIDATION=FAIL COUNT=$($errors.Count)";$errors|ForEach-Object{Write-Host "ERROR=$_"};exit 1}
Write-Host 'RUN_VALIDATION=PASS'
