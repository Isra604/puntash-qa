#!/usr/bin/env python3
import copy, importlib.util, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
VAL=ROOT/'runtime'/'tools'/'validate-run.py'
spec=importlib.util.spec_from_file_location('qa_validate_run',VAL)
mod=importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)

def base_run():
    gates=[]
    for i in range(1,26):
        gates.append({"gate":i,"status":"PASS","assurance":"STRONG","summary":"red-team baseline","evidence_freshness":"CURRENT","evidence_refs":[f"evidence/GATE-{i:02d}.txt"],"lens_impact_reviewed":False,"lens_exception_lenses":[],"lens_exception_rationale":""})
    lenses=[]
    for i in range(1,10):
        lenses.append({"lens":i,"status":"PASS","assurance":"STRONG","applicability_rationale":"Applicable in synthetic red-team fixture","applicability_evidence":["profile/PROJECT_QA_PROFILE.md"],"evidence_freshness":"CURRENT","evidence_refs":[f"evidence/LENS-{i:02d}.txt"]})
    return {"schema_version":2,"run_id":"REDTEAM","project":{"name":"synthetic","branch":"main","head":"abc"},"completed_at":"2026-08-27T10:00:00Z","summary":{"pass":25,"fail":0,"blocked":0,"not_run":0,"not_applicable":0},"evidence_assurance":{"overall":"STRONG"},"findings_summary":{"open":0},"gates":gates,"lenses":lenses,"test_trustworthiness":{"applicable":True,"status":"PASS","assurance":"STRONG","evidence_freshness":"CURRENT","evidence_refs":["evidence/LENS-01/test-trust.txt"],"decisive_suites":["critical-suite"]},"findings":[],"changes":{}}

def expect(name,obj,accepted):
    errors=mod.validate_obj(obj) if hasattr(mod,'validate_obj') else None
    if errors is None:
        import json,tempfile
        with tempfile.NamedTemporaryFile('w',delete=False,suffix='.json',encoding='utf-8') as f:
            json.dump(obj,f); path=f.name
        try: errors=mod.validate(path)
        finally: Path(path).unlink(missing_ok=True)
    ok=not errors
    if ok!=accepted:
        print(f"REDTEAM_FAIL={name} expected={'ACCEPT' if accepted else 'REJECT'} got={'ACCEPT' if ok else 'REJECT'}")
        if errors:
            for e in errors: print('  '+e)
        raise SystemExit(1)
    print(f"REDTEAM_PASS={name}:{'ACCEPTED' if accepted else 'REJECTED'}")

b=base_run(); expect('valid_strong_25_plus_9',b,True)
x=copy.deepcopy(b); x['gates'][0]['assurance']='WEAK'; expect('false_pass_weak_evidence',x,False)
x=copy.deepcopy(b); x['gates'][0]['evidence_freshness']='STALE'; expect('stale_evidence_pass',x,False)
x=copy.deepcopy(b); x['gates'][0]['evidence_refs']=[]; expect('pass_without_evidence_refs',x,False)
x=copy.deepcopy(b); x['lenses'][7]['status']='NOT_APPLICABLE'; x['lenses'][7]['evidence_refs']=[]; x['lenses'][7].pop('applicability_evidence',None); expect('not_applicable_without_evidence',x,False)
x=copy.deepcopy(b); x['lenses']=x['lenses'][:-1]; expect('hidden_missing_lens',x,False)
x=copy.deepcopy(b); x['lenses'][0]['status']='FAIL'; x['lenses'][0]['evidence_freshness']='CURRENT'; x['lenses'][0]['evidence_refs']=['evidence/LENS-01/fail.txt']; x['gates'][24]['status']='FAIL'; x['gates'][24]['evidence_refs']=['evidence/GATE-25/fail.txt']; x['test_trustworthiness']={"applicable":False,"applicability_rationale":"Synthetic contradiction case does not rely on automated tests","applicability_evidence":["profile/PROJECT_QA_PROFILE.md"]}; expect('gate4_pass_lens1_fail_silent_contradiction',x,False)
x2=copy.deepcopy(x); x2['gates'][3]['lens_impact_reviewed']=True; x2['gates'][3]['lens_exception_lenses']=[1]; x2['gates'][3]['lens_exception_rationale']='Synthetic proof that lens failure is isolated outside Gate 04 scope'; x2['evidence_assurance']['overall']='STRONG'; expect('explicit_non_material_contradiction_exception',x2,True)
x=copy.deepcopy(b); x['test_trustworthiness'].pop('status',None); expect('decisive_tests_without_trust_status',x,False)
x=copy.deepcopy(b); x['gates'][0]['assurance']='MODERATE'; x['gates'][0]['assurance_gap_non_material']=True; expect('overall_assurance_overstates_weakest',x,False)
x=copy.deepcopy(b); x['gates'][0]['gate']=2; expect('duplicate_gate_identity',x,False)
x=copy.deepcopy(b); x['gates'][4]['status']='NOT_APPLICABLE'; x['gates'][4]['assurance']='STRONG'; x['gates'][4]['applicability_rationale']='Synthetic N/A'; x['gates'][4]['evidence_refs']=[]; x['gates'][4].pop('applicability_evidence',None); expect('gate_not_applicable_without_evidence',x,False)
print('V2_REDTEAM_RESULT=PASS')
