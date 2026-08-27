#!/usr/bin/env python3
import json,sys
from pathlib import Path
VALID_STATUS={"PASS","FAIL","BLOCKED","NOT_RUN","NOT_APPLICABLE"}
VALID_ASSURANCE={"STRONG","MODERATE","WEAK","INSUFFICIENT"}

def nonempty(v): return isinstance(v,str) and bool(v.strip())
def refs(v): return isinstance(v,list) and any((isinstance(x,str) and x.strip()) for x in v)
def load_map():
    p=Path(__file__).resolve().parents[1]/"gates"/"reliability-map.json"
    return json.loads(p.read_text(encoding="utf-8-sig"))

def validate(path):
    errors=[]
    try:data=json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except Exception as e:return [f"invalid_json: {e}"]
    try:relmap=load_map()
    except Exception as e:return [f"reliability_map_error: {e}"]
    if int(data.get("schema_version",0)) < 2: errors.append("schema_version must be >=2")
    gates=data.get("gates"); lenses=data.get("lenses")
    if not isinstance(gates,list) or len(gates)!=25: errors.append("exactly 25 gate records required")
    if not isinstance(lenses,list) or len(lenses)!=9: errors.append("exactly 9 lens records required")
    gate_nums=[]; lens_nums=[]
    def check_item(x,kind,numkey):
        num=x.get(numkey,x.get("id")); status=str(x.get("status","")).upper(); assurance=str(x.get("assurance","")).upper()
        if status not in VALID_STATUS: errors.append(f"{kind}-{num}: invalid status {status!r}")
        if assurance not in VALID_ASSURANCE: errors.append(f"{kind}-{num}: invalid assurance {assurance!r}")
        if status in {"PASS","FAIL"}:
            if str(x.get("evidence_freshness","")).upper()!="CURRENT": errors.append(f"{kind}-{num}: {status} requires evidence_freshness=CURRENT")
            if not refs(x.get("evidence_refs")): errors.append(f"{kind}-{num}: {status} requires non-empty evidence_refs")
        if status=="PASS" and assurance in {"WEAK","INSUFFICIENT"}: errors.append(f"{kind}-{num}: PASS forbidden with {assurance} evidence")
        if status=="FAIL" and assurance in {"WEAK","INSUFFICIENT"}: errors.append(f"{kind}-{num}: FAIL forbidden with {assurance} evidence; use BLOCKED/NOT_RUN until violation is adequately proven")
        if status=="PASS" and assurance=="MODERATE" and x.get("assurance_gap_non_material") is not True: errors.append(f"{kind}-{num}: MODERATE PASS requires assurance_gap_non_material=true")
        if status=="NOT_APPLICABLE":
            if not nonempty(x.get("applicability_rationale")): errors.append(f"{kind}-{num}: NOT_APPLICABLE requires applicability_rationale")
            if not refs(x.get("applicability_evidence")): errors.append(f"{kind}-{num}: NOT_APPLICABLE requires applicability_evidence")
        if kind=="LENS":
            if not nonempty(x.get("applicability_rationale")): errors.append(f"{kind}-{num}: applicability_rationale required for every lens decision")
            if not refs(x.get("applicability_evidence")): errors.append(f"{kind}-{num}: applicability_evidence required for every lens decision")
        if status in {"BLOCKED","NOT_RUN"} and not (nonempty(x.get("reason")) or nonempty(x.get("notes")) or nonempty(x.get("summary"))): errors.append(f"{kind}-{num}: {status} requires reason/notes")
        return num,status,assurance
    if isinstance(gates,list):
        for x in gates:
            if not isinstance(x,dict): errors.append("gate record must be object"); continue
            num,status,ass=check_item(x,"GATE","gate"); gate_nums.append(num)
        try:
            if sorted(gate_nums)!=list(range(1,26)): errors.append("gate numbers must be unique 1..25")
        except TypeError: errors.append("gate numbers must be integers 1..25")
    if isinstance(lenses,list):
        for x in lenses:
            if not isinstance(x,dict): errors.append("lens record must be object"); continue
            num,status,ass=check_item(x,"LENS","lens"); lens_nums.append(num)
        try:
            if sorted(lens_nums)!=list(range(1,10)): errors.append("lens numbers must be unique 1..9")
        except TypeError: errors.append("lens numbers must be integers 1..9")
    gate_by={g.get("gate"):g for g in gates or [] if isinstance(g,dict)}
    lens_by={l.get("lens"):l for l in lenses or [] if isinstance(l,dict)}
    unresolved=[l for l in lenses or [] if isinstance(l,dict) and str(l.get("status","")).upper() not in {"PASS","NOT_APPLICABLE"}]
    g25=gate_by.get(25)
    if g25 and str(g25.get("status","")).upper()=="PASS" and unresolved: errors.append("GATE-25 PASS forbidden while any lens is FAIL/BLOCKED/NOT_RUN")
    # Core contradictions: a gate that primarily owns an unresolved lens cannot silently PASS.
    blocking=relmap.get("blocking_gate_map",{})
    for lens_s,gnums in blocking.items():
        try:ln=int(lens_s)
        except:continue
        l=lens_by.get(ln)
        if not l or str(l.get("status","")).upper() in {"PASS","NOT_APPLICABLE"}: continue
        for gn in gnums:
            g=gate_by.get(gn)
            if not g or str(g.get("status","")).upper()!="PASS": continue
            ex=g.get("lens_exception_lenses") or []
            if g.get("lens_impact_reviewed") is not True or ln not in ex or not nonempty(g.get("lens_exception_rationale")):
                errors.append(f"GATE-{gn}: PASS contradicts unresolved LENS-{ln}; explicit reviewed non-material lens exception required")
    tt=data.get("test_trustworthiness")
    if not isinstance(tt,dict) or not isinstance(tt.get("applicable"),bool):
        errors.append("test_trustworthiness decision with applicable=true/false is required")
    elif tt.get("applicable") is False:
        if not nonempty(tt.get("applicability_rationale")): errors.append("test_trustworthiness NOT_APPLICABLE requires applicability_rationale")
        if not refs(tt.get("applicability_evidence")): errors.append("test_trustworthiness NOT_APPLICABLE requires applicability_evidence")
    else:
        status=str(tt.get("status","")).upper(); assurance=str(tt.get("assurance","")).upper(); dec=tt.get("decisive_suites") or []
        if status not in VALID_STATUS or status=="NOT_APPLICABLE": errors.append("test_trustworthiness applicable requires explicit non-N/A status")
        if assurance not in VALID_ASSURANCE: errors.append("test_trustworthiness applicable requires valid assurance")
        if status in {"PASS","FAIL"}:
            if str(tt.get("evidence_freshness","")).upper()!="CURRENT": errors.append("test_trustworthiness PASS/FAIL requires evidence_freshness=CURRENT")
            if not refs(tt.get("evidence_refs")): errors.append("test_trustworthiness PASS/FAIL requires evidence_refs")
        if status in {"BLOCKED","NOT_RUN"} and not (nonempty(tt.get("reason")) or nonempty(tt.get("notes"))): errors.append("test_trustworthiness BLOCKED/NOT_RUN requires reason")
        l1=lens_by.get(1)
        if not l1 or str(l1.get("status","")).upper()=="NOT_APPLICABLE": errors.append("test_trustworthiness applicable requires LENS-01 applicable")
        if dec:
            if status!="PASS": errors.append("decisive automated suites require test_trustworthiness status PASS")
            if assurance in {"WEAK","INSUFFICIENT"}: errors.append("decisive automated suites cannot rely on weak/insufficient test trustworthiness")
            if assurance=="MODERATE" and tt.get("assurance_gap_non_material") is not True: errors.append("MODERATE test_trustworthiness for decisive suites requires assurance_gap_non_material=true")
            if not l1 or str(l1.get("status","")).upper()!="PASS": errors.append("decisive automated suites require LENS-01 PASS")
    overall=str((data.get("evidence_assurance") or {}).get("overall","")).upper()
    if overall not in VALID_ASSURANCE: errors.append("evidence_assurance.overall invalid")
    else:
        rank={"INSUFFICIENT":0,"WEAK":1,"MODERATE":2,"STRONG":3}
        assessed=[]
        for x in (gates or [])+(lenses or []):
            if isinstance(x,dict) and str(x.get("assurance","")).upper() in rank: assessed.append(rank[str(x.get("assurance","")).upper()])
        if isinstance(tt,dict) and tt.get("applicable") is True and str(tt.get("assurance","")).upper() in rank: assessed.append(rank[str(tt.get("assurance","")).upper()])
        if assessed and rank[overall]>min(assessed): errors.append("evidence_assurance.overall cannot be stronger than the weakest gate/lens/test-trustworthiness assurance")
    return errors

def main():
    if len(sys.argv)!=2:
        print("Usage: validate-run.py <run.json>",file=sys.stderr);return 2
    errors=validate(sys.argv[1])
    if errors:
        print(f"RUN_VALIDATION=FAIL COUNT={len(errors)}")
        for e in errors: print("ERROR="+e)
        return 1
    print("RUN_VALIDATION=PASS")
    return 0
if __name__=="__main__": raise SystemExit(main())
