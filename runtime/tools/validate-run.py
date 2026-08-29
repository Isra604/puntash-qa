#!/usr/bin/env python3
import json, os, re, sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath

VALID_STATUS={"PASS","FAIL","BLOCKED","NOT_RUN","NOT_APPLICABLE"}
VALID_ASSURANCE={"STRONG","MODERATE","WEAK","INSUFFICIENT"}
VALID_REMEDIATION_RISK={"LOW","MEDIUM"}
EVIDENCE_ROOTS={"evidence","artifacts","profile","reports","remediation","dispositions"}

def nonempty(v): return isinstance(v,str) and bool(v.strip())
def refs(v): return isinstance(v,list) and any((isinstance(x,str) and x.strip()) for x in v)

def parse_time(v):
    if not nonempty(v): return None
    try:
        s=v.strip().replace('Z','+00:00')
        d=datetime.fromisoformat(s)
        if d.tzinfo is None: d=d.replace(tzinfo=timezone.utc)
        return d.astimezone(timezone.utc)
    except Exception:return None

def load_map(install_root):
    p=Path(install_root)/"gates"/"reliability-map.json"
    return json.loads(p.read_text(encoding="utf-8-sig"))

def validate_preserved_ref(ref,install_root):
    if not nonempty(ref): return "reference is empty"
    raw=ref.strip().replace('\\','/')
    if raw.startswith('/') or re.match(r'^[A-Za-z]:',raw): return "absolute evidence paths are forbidden"
    pp=PurePosixPath(raw)
    if not pp.parts or pp.parts[0] not in EVIDENCE_ROOTS: return f"reference must be under one of {sorted(EVIDENCE_ROOTS)}"
    if any(part in {'','..'} for part in pp.parts): return "path traversal is forbidden"
    base=Path(install_root).resolve()
    candidate=(base/Path(*pp.parts)).resolve()
    try:candidate.relative_to(base)
    except ValueError:return "symlink/path escape outside QA runtime is forbidden"
    if not candidate.is_file(): return "referenced evidence file does not exist"
    return None

def load_auth_history(install_root):
    path=Path(install_root)/'state'/'CHANGE_AUTHORIZATION_HISTORY.jsonl'
    records={}; errors=[]
    if not path.is_file(): return records,errors
    for i,line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(),1):
        if not line.strip():continue
        try:r=json.loads(line)
        except Exception as e:errors.append(f"authorization_history line {i} invalid JSON: {e}");continue
        aid=r.get('authorization_id')
        if nonempty(aid):
            if aid in records:errors.append(f"authorization_history duplicate authorization_id: {aid}")
            records[aid]=r
    return records,errors

def validate_obj(data,install_root=None):
    errors=[]
    install_root=Path(install_root or Path(__file__).resolve().parents[1])
    try:relmap=load_map(install_root)
    except Exception as e:return [f"reliability_map_error: {e}"]
    try:schema=int(data.get("schema_version",0))
    except Exception:schema=0
    if schema < 3: errors.append("schema_version must be >=3 for v2.1 current-run validation")
    if not nonempty(data.get('run_id')): errors.append('run_id is required')
    project=data.get('project')
    if schema >= 4:
        if not isinstance(project,dict): errors.append('schema-v4 project object is required')
        else:
            fp=project.get('fingerprint')
            if not isinstance(fp,dict): errors.append('schema-v4 project.fingerprint object is required')
            else:
                if fp.get('algorithm')!='PUNTASH_SOURCE_V1': errors.append('project.fingerprint.algorithm must be PUNTASH_SOURCE_V1')
                if not isinstance(fp.get('available'),bool): errors.append('project.fingerprint.available must be boolean')
                elif fp.get('available') is True:
                    if not isinstance(fp.get('sha256'),str) or not re.fullmatch(r'[0-9A-Fa-f]{64}',fp.get('sha256','')): errors.append('available project fingerprint requires 64-hex sha256')
                    for key in ('file_count','byte_count'):
                        v=fp.get(key)
                        if isinstance(v,bool) or not isinstance(v,int) or v<0: errors.append(f'available project fingerprint {key} must be a non-negative integer')
                elif not nonempty(fp.get('reason')): errors.append('unavailable project fingerprint requires reason')
    started=parse_time(data.get('started_at')); completed=parse_time(data.get('completed_at'))
    if started is None:errors.append('started_at must be a valid timestamp')
    if completed is None:errors.append('completed_at must be a valid timestamp')
    if started and completed and completed<started:errors.append('completed_at cannot precede started_at')
    gates=data.get("gates"); lenses=data.get("lenses")
    if not isinstance(gates,list) or len(gates)!=25: errors.append("exactly 25 gate records required")
    if not isinstance(lenses,list) or len(lenses)!=9: errors.append("exactly 9 lens records required")
    gate_nums=[]; lens_nums=[]; preserved=[]
    def add_refs(v,label):
        if not isinstance(v,list):return
        for ref in v:
            if isinstance(ref,str) and ref.strip():preserved.append((ref,label))
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
        add_refs(x.get('evidence_refs'),f'{kind}-{num} evidence_refs')
        add_refs(x.get('applicability_evidence'),f'{kind}-{num} applicability_evidence')
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
        add_refs(tt.get('applicability_evidence'),'test_trustworthiness applicability_evidence')
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
        add_refs(tt.get('evidence_refs'),'test_trustworthiness evidence_refs')
    overall=str((data.get("evidence_assurance") or {}).get("overall","")).upper()
    if overall not in VALID_ASSURANCE: errors.append("evidence_assurance.overall invalid")
    else:
        rank={"INSUFFICIENT":0,"WEAK":1,"MODERATE":2,"STRONG":3}; assessed=[]
        for x in (gates or [])+(lenses or []):
            if isinstance(x,dict) and str(x.get("assurance","")).upper() in rank: assessed.append(rank[str(x.get("assurance","")).upper()])
        if isinstance(tt,dict) and tt.get("applicable") is True and str(tt.get("assurance","")).upper() in rank: assessed.append(rank[str(tt.get("assurance","")).upper()])
        if assessed and rank[overall]>min(assessed): errors.append("evidence_assurance.overall cannot be stronger than the weakest gate/lens/test-trustworthiness assurance")

    # Evidence reality: labels are insufficient; preserved references must exist and stay within the QA runtime.
    checked=set()
    for ref,label in preserved:
        key=ref.replace('\\','/')
        if key in checked:continue
        checked.add(key)
        issue=validate_preserved_ref(ref,install_root)
        if issue:errors.append(f"{label}: {ref!r}: {issue}")

    # Automatic remediation integrity: every current-run mutation must bind to a unique ALLOW record.
    ar=data.get('automatic_remediation')
    if not isinstance(ar,dict) or not isinstance(ar.get('performed'),bool) or not isinstance(ar.get('entries'),list):
        errors.append('automatic_remediation with performed=true/false and entries=[] is required')
    else:
        entries=ar.get('entries') or []
        if ar['performed'] is False and entries:errors.append('automatic_remediation.performed=false requires entries=[]')
        if ar['performed'] is True and not entries:errors.append('automatic_remediation.performed=true requires at least one remediation entry')
        history,history_errors=load_auth_history(install_root);errors.extend(history_errors)
        used=set()
        for idx,e in enumerate(entries,1):
            prefix=f'automatic_remediation entry {idx}'
            if not isinstance(e,dict):errors.append(prefix+' must be an object');continue
            aid=e.get('authorization_id'); fid=e.get('finding_id'); risk=str(e.get('risk','')).upper(); category=e.get('category'); summary=e.get('change_summary'); rev=e.get('policy_revision')
            if not nonempty(aid):errors.append(prefix+' authorization_id required');continue
            if aid in used:errors.append(prefix+' authorization_id must be unique within the run')
            used.add(aid)
            if not nonempty(fid):errors.append(prefix+' finding_id required')
            if risk not in VALID_REMEDIATION_RISK:errors.append(prefix+' risk must be LOW or MEDIUM')
            if not nonempty(category):errors.append(prefix+' category required')
            if not nonempty(summary):errors.append(prefix+' change_summary required')
            if not isinstance(rev,int) or isinstance(rev,bool) or rev<1:errors.append(prefix+' policy_revision must be a positive integer')
            for field in ('authorization_evidence_refs','pre_fix_evidence_refs','post_fix_evidence_refs','revalidation_refs'):
                rv=e.get(field)
                if not refs(rv):errors.append(prefix+f' {field} requires preserved evidence refs')
                add_refs(rv,prefix+' '+field)
            authorized=e.get('authorized_target_paths')
            changed=e.get('files_changed')
            for field_name,paths in (('authorized_target_paths',authorized),('files_changed',changed)):
                if not isinstance(paths,list) or not paths or any(not nonempty(x) for x in paths):
                    errors.append(prefix+f' {field_name} requires one or more paths')
                    continue
                normalized=[]
                for path_s in paths:
                    norm=str(path_s).replace('\\','/')
                    normalized.append(norm)
                    if norm.startswith('/') or re.match(r'^[A-Za-z]:',norm) or '..' in PurePosixPath(norm).parts or '.' in PurePosixPath(norm).parts:
                        errors.append(prefix+f' {field_name} path must be project-relative without traversal: {path_s!r}')
                if len(set(normalized))!=len(normalized):errors.append(prefix+f' {field_name} contains duplicate paths')
            rec=history.get(aid)
            if not rec:errors.append(prefix+f' authorization_id {aid!r} not found in authorization history');continue
            if rec.get('decision')!='ALLOW':errors.append(prefix+' authorization record is not ALLOW')
            pairs=[('finding_id',fid),('risk',risk),('category',category),('change_summary',summary),('policy_revision',rev)]
            for key,val in pairs:
                if rec.get(key)!=val:errors.append(prefix+f' {key} does not match authorization record')
            expected_refs={str(x).replace('\\','/') for x in (e.get('authorization_evidence_refs') or [])}
            actual_refs={str(x).replace('\\','/') for x in (rec.get('evidence_refs') or [])}
            if expected_refs!=actual_refs:errors.append(prefix+' authorization_evidence_refs do not match authorization record')
            authorized_set={str(x).replace('\\','/') for x in (e.get('authorized_target_paths') or [])}
            record_targets={str(x).replace('\\','/') for x in (rec.get('target_paths') or [])}
            changed_set={str(x).replace('\\','/') for x in (e.get('files_changed') or [])}
            if not record_targets:errors.append(prefix+' authorization record target_paths missing')
            if authorized_set!=record_targets:errors.append(prefix+' authorized_target_paths do not match authorization record')
            if changed_set!=authorized_set:errors.append(prefix+' files_changed must exactly match authorized_target_paths')
            if rec.get('expected_behavior_proven') is not True or rec.get('reversible') is not True:errors.append(prefix+' authorization record lacks expected-behavior/reversibility proof')
            decided=parse_time(rec.get('decided_at'))
            if decided is None:errors.append(prefix+' authorization record decided_at invalid')
            elif started and completed and not (started<=decided<=completed):errors.append(prefix+' authorization must be issued during the current run window')
        # refs added by remediation entries are validated after they are collected.
        newly=[x for x in preserved if x[0].replace('\\','/') not in checked]
        for ref,label in newly:
            key=ref.replace('\\','/');checked.add(key);issue=validate_preserved_ref(ref,install_root)
            if issue:errors.append(f"{label}: {ref!r}: {issue}")
    return errors

def validate(path):
    try:data=json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except Exception as e:return [f"invalid_json: {e}"]
    return validate_obj(data)

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
