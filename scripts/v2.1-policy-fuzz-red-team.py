#!/usr/bin/env python3
import copy,json,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def ok(c,n):
    if not c: raise AssertionError('V21_POLICY_FUZZ_FAIL='+n)
    print('V21_POLICY_FUZZ_PASS='+n)

def run(cmd,rc=0):
    r=subprocess.run(cmd,capture_output=True,text=True)
    if r.returncode!=rc: raise AssertionError(f'rc {r.returncode} expected {rc}: {cmd}\nOUT={r.stdout}\nERR={r.stderr}')
    return r

def main():
  with tempfile.TemporaryDirectory(prefix='qa-v21-policy-fuzz-') as td:
    td=Path(td);project=td/'project';install=project/'.comprehensive-qa';shutil.copytree(ROOT/'runtime',install);(install/'state').mkdir(exist_ok=True)
    py=[sys.executable,str(install/'tools/policy-manager.py')];candidate=td/'candidate.json';base=json.loads(run(py+['get']).stdout)
    cases=[]
    def add(name,mut):
      p=copy.deepcopy(base);mut(p);cases.append((name,p))
    add('enabled_string_rejected',lambda p:p['schedule'].__setitem__('enabled','false'))
    add('timeout_boolean_rejected',lambda p:p['schedule']['executor'].__setitem__('timeout_minutes',True))
    add('arguments_object_rejected',lambda p:p['schedule']['executor'].__setitem__('arguments',{'x':'y'}))
    add('unknown_top_level_rejected',lambda p:p.__setitem__('hidden_authority',True))
    add('unknown_executor_field_rejected',lambda p:p['schedule']['executor'].__setitem__('shell',True))
    add('weekly_without_days_rejected',lambda p:p['schedule'].update(frequency='WEEKLY',days_of_week=[]))
    add('daily_with_days_rejected',lambda p:p['schedule'].update(frequency='DAILY',days_of_week=['Sunday']))
    add('duplicate_custom_risk_rejected',lambda p:p['permissions'].__setitem__('custom_auto_change_risks',['LOW','LOW']))
    add('hard_boundary_custom_category_rejected',lambda p:p['permissions'].__setitem__('custom_categories',['architecture']))
    add('secret_like_executor_rejected',lambda p:p['schedule']['executor'].__setitem__('command','sk-'+'A'*30))
    add('timezone_other_than_local_rejected',lambda p:p['schedule'].__setitem__('timezone_mode','UTC'))
    for name,obj in cases:
      candidate.write_text(json.dumps(obj),encoding='utf-8');r=subprocess.run(py+['apply','--policy-json',str(candidate),'--owner-approved','--approval-source','manual_cli'],capture_output=True,text=True);ok(r.returncode!=0,name)
    # establish a valid configured policy, then tamper without history update
    good=copy.deepcopy(base);good['permissions']['preset']='SAFE_FIXES';candidate.write_text(json.dumps(good),encoding='utf-8');run(py+['apply','--policy-json',str(candidate),'--owner-approved','--approval-source','manual_cli'])
    state=install/'state';current=json.loads((state/'OWNER_POLICY.json').read_text(encoding='utf-8-sig'));current['permissions']['preset']='ACTIVE_REMEDIATION';(state/'OWNER_POLICY.json').write_text(json.dumps(current,indent=2)+'\n',encoding='utf-8')
    ok(subprocess.run(py+['get'],capture_output=True,text=True).returncode!=0,'valid_json_policy_tampering_detected_by_audit_hash')
    auth=[sys.executable,str(install/'tools/authorize-change.py'),'--risk','MEDIUM','--category','source_code','--finding-id','F-TAMPER','--change-summary','tampered attempt','--evidence-ref','evidence/x','--target-path','src/tamper.py','--expected-behavior-proven','--reversible']
    ok(subprocess.run(auth,capture_output=True,text=True).returncode!=0,'authorize_change_fails_closed_on_tampered_policy')
    # owner-approved recovery restores integrity and advances revision
    candidate.write_text(json.dumps(good),encoding='utf-8');run(py+['apply','--policy-json',str(candidate),'--owner-approved','--approval-source','manual_cli']);restored=json.loads(run(py+['get']).stdout);ok(restored['policy_revision']==2 and restored['permissions']['preset']=='SAFE_FIXES','owner_approved_recovery_restores_audit_integrity')
    last=json.loads((state/'OWNER_POLICY_HISTORY.jsonl').read_text(encoding='utf-8-sig').splitlines()[-1]);ok(last.get('recovery_from_invalid_policy') is True and bool(last.get('recovery_reason')),'policy_recovery_is_explicitly_audited')
    # corrupt permission policy safety ceiling -> manager must refuse even GET
    perm=install/'templates/PERMISSION_POLICY.json';data=json.loads(perm.read_text());data['presets']['SAFE_FIXES']['auto_change_risks']=['LOW','MEDIUM'];perm.write_text(json.dumps(data),encoding='utf-8')
    cfg=install/'config/permission-policy.json'
    if cfg.exists(): cfg.unlink()
    ok(subprocess.run(py+['get'],capture_output=True,text=True).returncode!=0,'permission_policy_ceiling_tampering_detected')
    # PowerShell parity on Windows for selected strict/tamper cases
    ps=shutil.which('powershell.exe')
    if ps:
      project2=td/'ps-project';install2=project2/'.comprehensive-qa';shutil.copytree(ROOT/'runtime',install2);(install2/'state').mkdir(exist_ok=True);tool=install2/'tools/policy-manager.ps1';c2=td/'ps-candidate.json'
      g=run([ps,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(tool),'-Operation','Get']);b=json.loads(g.stdout);bad=copy.deepcopy(b);bad['schedule']['enabled']='false';c2.write_text(json.dumps(bad),encoding='utf-8');r=subprocess.run([ps,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(tool),'-Operation','Apply','-PolicyJsonPath',str(c2),'-OwnerApproved','-ApprovalSource','manual_cli'],capture_output=True,text=True);ok(r.returncode!=0,'powershell_enabled_string_rejected')
      b['permissions']['preset']='SAFE_FIXES';c2.write_text(json.dumps(b),encoding='utf-8');run([ps,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(tool),'-Operation','Apply','-PolicyJsonPath',str(c2),'-OwnerApproved','-ApprovalSource','manual_cli']);state2=install2/'state';cur=json.loads((state2/'OWNER_POLICY.json').read_text(encoding='utf-8-sig'));cur['permissions']['preset']='ACTIVE_REMEDIATION';(state2/'OWNER_POLICY.json').write_text(json.dumps(cur),encoding='utf-8');r=subprocess.run([ps,'-NoProfile','-ExecutionPolicy','Bypass','-File',str(tool),'-Operation','Get'],capture_output=True,text=True);ok(r.returncode!=0,'powershell_valid_json_policy_tampering_detected')
    print('V21_POLICY_FUZZ_RESULT=PASS')
  return 0
if __name__=='__main__':raise SystemExit(main())
