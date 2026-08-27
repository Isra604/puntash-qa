#!/usr/bin/env python3
import json, shutil, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def ok(c,n):
    if not c: raise AssertionError('V21_CONCURRENCY_REDTEAM_FAIL='+n)
    print('V21_CONCURRENCY_REDTEAM_PASS='+n)

def run(cmd):
    r=subprocess.run(cmd,capture_output=True,text=True)
    if r.returncode:
        raise AssertionError(f'command failed {cmd}\nOUT={r.stdout}\nERR={r.stderr}')
    return r

def apply_initial(pt,candidate,policy):
    candidate.write_text(json.dumps(policy),encoding='utf-8')
    run(pt+['apply','--policy-json',str(candidate),'--owner-approved','--approval-source','manual_cli'])

def main():
    with tempfile.TemporaryDirectory(prefix='qa-v21-concurrency-') as td:
        project=Path(td)/'project with spaces';install=project/'.comprehensive-qa';shutil.copytree(ROOT/'runtime',install);state=install/'state';state.mkdir(exist_ok=True)
        pt=[sys.executable,str(install/'tools/policy-manager.py')]
        base=json.loads(run(pt+['get']).stdout);base['permissions']['preset']='SAFE_FIXES'
        candidates=[]
        for n in range(10):
            p=json.loads(json.dumps(base));p['permissions']['notes']=f'concurrent-{n}';c=Path(td)/f'candidate-{n}.json';c.write_text(json.dumps(p),encoding='utf-8');candidates.append(c)
        procs=[subprocess.Popen(pt+['apply','--policy-json',str(c),'--owner-approved','--approval-source','manual_cli'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for c in candidates]
        results=[p.communicate(timeout=30)+(p.returncode,) for p in procs]
        ok(all(rc==0 for _,_,rc in results),'python_policy_concurrent_mutations_all_complete')
        hist=[json.loads(x) for x in (state/'OWNER_POLICY_HISTORY.jsonl').read_text(encoding='utf-8-sig').splitlines() if x.strip()]
        revs=sorted(x['revision'] for x in hist)
        ok(revs==list(range(1,11)),'python_policy_revisions_are_monotonic_unique')
        final=json.loads((state/'OWNER_POLICY.json').read_text(encoding='utf-8-sig'));ok(final['policy_revision']==10,'python_policy_final_revision_matches_history')
        # concurrent authorization decisions must never lose audit entries
        auth=[sys.executable,str(install/'tools/authorize-change.py')]
        commands=[]
        for n in range(20):
            commands.append(auth+['--risk','LOW','--category','documentation','--finding-id',f'F-{n}','--change-summary',f'concurrent auth {n}','--evidence-ref',f'evidence/{n}.txt','--expected-behavior-proven','--reversible'])
        procs=[subprocess.Popen(c,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for c in commands]
        results=[p.communicate(timeout=30)+(p.returncode,) for p in procs]
        ok(all(rc==0 for _,_,rc in results),'authorization_concurrent_allows_complete')
        ah=[json.loads(x) for x in (state/'CHANGE_AUTHORIZATION_HISTORY.jsonl').read_text(encoding='utf-8-sig').splitlines() if x.strip()]
        ok(len(ah)==20 and len({x['authorization_id'] for x in ah})==20,'authorization_audit_has_all_unique_decisions')
        ok(all(x['policy_revision']==10 for x in ah),'authorization_decisions_bind_current_policy_revision')
        # Windows PowerShell implementation concurrency parity
        ps=shutil.which('powershell.exe')
        if ps:
            project2=Path(td)/'powershell project with spaces';install2=project2/'.comprehensive-qa';shutil.copytree(ROOT/'runtime',install2);(install2/'state').mkdir(exist_ok=True)
            tool=install2/'tools/policy-manager.ps1';candidate=Path(td)/'ps-candidate.json'
            get=subprocess.run([ps,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(tool),'-Operation','Get'],capture_output=True,text=True)
            ok(get.returncode==0,'powershell_policy_get_valid')
            b=json.loads(get.stdout);b['permissions']['preset']='SAFE_FIXES';candidate.write_text(json.dumps(b),encoding='utf-8')
            procs=[subprocess.Popen([ps,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(tool),'-Operation','Apply','-PolicyJsonPath',str(candidate),'-OwnerApproved','-ApprovalSource','manual_cli'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for _ in range(6)]
            results=[p.communicate(timeout=45)+(p.returncode,) for p in procs]
            ok(all(rc==0 for _,_,rc in results),'powershell_policy_concurrent_mutations_all_complete')
            hist2=[json.loads(x) for x in (install2/'state/OWNER_POLICY_HISTORY.jsonl').read_text(encoding='utf-8-sig').splitlines() if x.strip()]
            ok(sorted(x['revision'] for x in hist2)==list(range(1,7)),'powershell_policy_revisions_are_monotonic_unique')
            final2=json.loads((install2/'state/OWNER_POLICY.json').read_text(encoding='utf-8-sig'));ok(final2['policy_revision']==6,'powershell_policy_final_revision_matches_history')
        print('V21_CONCURRENCY_REDTEAM_RESULT=PASS')
    return 0
if __name__=='__main__':raise SystemExit(main())
