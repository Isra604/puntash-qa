#!/usr/bin/env python3
import json, os, shutil, subprocess, sys, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def ok(cond,name):
    if not cond: raise AssertionError('V21_PORTABLE_TIMEOUT_FAIL='+name)
    print('V21_PORTABLE_TIMEOUT_PASS='+name)

def alive(pid):
    if os.name=='nt':
        r=subprocess.run(['tasklist','/FI',f'PID eq {pid}','/FO','CSV','/NH'],capture_output=True,text=True)
        return r.returncode==0 and str(pid) in r.stdout and 'No tasks are running' not in r.stdout
    try: os.kill(pid,0); return True
    except OSError: return False

def main():
    with tempfile.TemporaryDirectory(prefix='qa-v21-portable-timeout-') as td:
        td=Path(td);project=td/'project';install=project/'.comprehensive-qa';shutil.copytree(ROOT/'runtime',install);state=install/'state';state.mkdir(exist_ok=True)
        (install/'TERMS_VERSION').write_text((ROOT/'TERMS_VERSION').read_text(encoding='utf-8-sig'),encoding='utf-8')
        shutil.copy2(ROOT/'LEGAL_MANIFEST.json',install/'LEGAL_MANIFEST.json');legal=json.loads((ROOT/'LEGAL_MANIFEST.json').read_text(encoding='utf-8-sig'))['documents']
        for name in legal: shutil.copy2(ROOT/name,install/name)
        (state/'HUMAN_ACCEPTANCE_RECEIPT.json').write_text(json.dumps({'terms_version':(ROOT/'TERMS_VERSION').read_text(encoding='utf-8-sig').strip(),'accepted_by_human_attestation':True,'legal_document_sha256':legal}),encoding='utf-8')
        child=td/'child.py';parent=td/'parent.py';child_marker=td/'child-survived.txt';parent_marker=td/'parent-survived.txt';child_pid=td/'child.pid'
        child.write_text('import pathlib,sys,time\ntime.sleep(65)\npathlib.Path(sys.argv[1]).write_text("child survived",encoding="utf-8")\n',encoding='utf-8')
        parent.write_text('import pathlib,subprocess,sys,time\np=subprocess.Popen([sys.executable,sys.argv[1],sys.argv[2]])\npathlib.Path(sys.argv[3]).write_text(str(p.pid),encoding="utf-8")\ntime.sleep(65)\npathlib.Path(sys.argv[4]).write_text("parent survived",encoding="utf-8")\n',encoding='utf-8')
        pm=[sys.executable,str(install/'tools/policy-manager.py')];policy=json.loads(subprocess.run(pm+['get'],capture_output=True,text=True,check=True).stdout)
        policy['permissions']['preset']='REPORT_ONLY';policy['schedule']['enabled']=True;policy['schedule']['frequency']='DAILY';policy['schedule']['local_time']='03:00';policy['schedule']['executor_mode']='LOCAL_COMMAND';policy['schedule']['executor']['command']=sys.executable;policy['schedule']['executor']['arguments']=[str(parent),str(child),str(child_marker),str(child_pid),str(parent_marker)];policy['schedule']['executor']['timeout_minutes']=1
        cand=td/'policy.json';cand.write_text(json.dumps(policy),encoding='utf-8');r=subprocess.run(pm+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'],capture_output=True,text=True);ok(r.returncode==0,'timeout_policy_applied')
        start=time.monotonic();r=subprocess.run([sys.executable,str(install/'tools/scheduled-run.py')],capture_output=True,text=True,timeout=85);elapsed=time.monotonic()-start
        ok(r.returncode==9,'portable_runner_returns_timeout');ok(55<=elapsed<=80,'timeout_occurs_near_configured_limit')
        status=json.loads((state/'SCHEDULER_STATUS.json').read_text(encoding='utf-8-sig'));ok(status.get('last_result')=='TIMEOUT','timeout_status_recorded')
        ok(child_pid.exists(),'child_pid_observed_before_timeout');pid=int(child_pid.read_text().strip())
        time.sleep(7)
        ok(not parent_marker.exists(),'timed_out_parent_cannot_continue');ok(not child_marker.exists(),'timed_out_child_cannot_continue');ok(not alive(pid),'portable_timeout_kills_executor_child_process')
    print('V21_PORTABLE_TIMEOUT_RESULT=PASS');return 0
if __name__=='__main__':
    try:raise SystemExit(main())
    except Exception as e:print(e,file=sys.stderr);raise
