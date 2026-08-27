#!/usr/bin/env python3
import json,sys
from pathlib import Path
VALID_STATUS={"PASS","FAIL","BLOCKED","NOT_RUN","NOT_APPLICABLE"}
VALID_ASSURANCE={"STRONG","MODERATE","WEAK","INSUFFICIENT"}

def nonempty(v): return isinstance(v,str) and bool(v.strip())
def validate(path):
    errors=[]
    try:data=json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except Exception as e:return [f"invalid_json: {e}"]
    if int(data.get("schema_version",0)) < 2: errors.append("schema_version must be >=2")
    gates=data.get("gates"); lenses=data.get("lenses")
    if not isinstance(gates,list) or len(gates)!=25: errors.append("exactly 25 gate records required")
    if not isinstance(lenses,list) or len(lenses)!=9: errors.append("exactly 9 lens records required")
    gate_nums=[]; lens_nums=[]
    def check_item(x,kind,numkey):
        num=x.get(numkey,x.get("id")); status=str(x.get("status","")).upper(); assurance=str(x.get("assurance","")).upper()
        if status not in VALID_STATUS: errors.append(f"{kind}-{num}: invalid status {status!r}")
        if assurance not in VALID_ASSURANCE: errors.append(f"{kind}-{num}: invalid assurance {assurance!r}")
        if status=="PASS" and assurance in {"WEAK","INSUFFICIENT"}: errors.append(f"{kind}-{num}: PASS forbidden with {assurance} evidence")
        if status=="PASS" and assurance=="MODERATE" and x.get("assurance_gap_non_material") is not True: errors.append(f"{kind}-{num}: MODERATE PASS requires assurance_gap_non_material=true")
        if status=="NOT_APPLICABLE" and not nonempty(x.get("applicability_rationale")): errors.append(f"{kind}-{num}: NOT_APPLICABLE requires applicability_rationale")
        if status in {"BLOCKED","NOT_RUN"} and not (nonempty(x.get("reason")) or nonempty(x.get("notes")) or nonempty(x.get("summary"))): errors.append(f"{kind}-{num}: {status} requires reason/notes")
        return num,status,assurance
    if isinstance(gates,list):
        for x in gates:
            if not isinstance(x,dict): errors.append("gate record must be object"); continue
            num,status,ass=check_item(x,"GATE","gate"); gate_nums.append(num)
        if sorted(gate_nums)!=list(range(1,26)): errors.append("gate numbers must be unique 1..25")
    if isinstance(lenses,list):
        for x in lenses:
            if not isinstance(x,dict): errors.append("lens record must be object"); continue
            num,status,ass=check_item(x,"LENS","lens"); lens_nums.append(num)
        if sorted(lens_nums)!=list(range(1,10)): errors.append("lens numbers must be unique 1..9")
    # Gate 25 is final consistency/DoD: PASS requires every lens resolved as PASS/N/A.
    if isinstance(gates,list) and isinstance(lenses,list):
        g25=next((g for g in gates if g.get("gate")==25),None)
        unresolved=[l for l in lenses if str(l.get("status","")).upper() not in {"PASS","NOT_APPLICABLE"}]
        if g25 and str(g25.get("status","")).upper()=="PASS" and unresolved: errors.append("GATE-25 PASS forbidden while any lens is FAIL/BLOCKED/NOT_RUN")
    tt=data.get("test_trustworthiness",{})
    if isinstance(tt,dict) and tt.get("applicable") is True:
        dec=tt.get("decisive_suites") or []
        l1=next((l for l in lenses or [] if isinstance(l,dict) and l.get("lens")==1),None)
        if not l1 or str(l1.get("status","")).upper()=="NOT_APPLICABLE": errors.append("test_trustworthiness applicable requires LENS-01 applicable")
        if dec and l1 and str(l1.get("status","")).upper()=="PASS" and str(l1.get("assurance","")).upper() in {"WEAK","INSUFFICIENT"}: errors.append("decisive automated tests cannot rely on weak LENS-01 PASS")
    overall=str((data.get("evidence_assurance") or {}).get("overall","")).upper()
    if overall not in VALID_ASSURANCE: errors.append("evidence_assurance.overall invalid")
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
