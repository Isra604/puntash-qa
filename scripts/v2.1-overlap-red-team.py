#!/usr/bin/env python3
import json, shutil, subprocess, sys, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def ok(cond,name):
    if not cond: raise AssertionError('V21_OVERLAP_REDTEAM_FAIL='+name)
    print('V21_OVERLAP_REDTEAM_PASS='+name)

def setup(td):
    project=Path(td)/'project'; install=project/'.comprehensive-qa'; shutil.copytree(ROOT/'runtime',install)
    state=install/'state'; state.mkdir(exist_ok=True)
    (install/'TERMS_VERSION').write_text((ROOT/'TERMS_VERSION').read_text(encoding='utf-8-sig'),encoding='utf-8')
    shutil.copy2(ROOT/'LEGAL_MANIFEST.json',install/'LEGAL_MANIFEST.json')
    legal=json.loads((ROOT/'LEGAL_MANIFEST.json').read_text(encoding='utf-8-sig'))['documents']
    for name in legal: shutil.copy2(ROOT/name,install/name)
    (state/'HUMAN_ACCEPTANCE_RECEIPT.json').write_text(json.dumps({'terms_version':(ROOT/'TERMS_VERSION').read_text(encoding='utf-8-sig').strip(),'accepted_by_human_attestation':True,'legal_document_sha256':legal}),encoding='utf-8')
    helper=Path(td)/'long executor.py'; marker=Path(td)/'executor-started.marker'
    helper.write_text('import pathlib,sys,time\npathlib.Path(sys.argv[1]).write_text("started",encoding="utf-8")\ntime.sleep(7)\nprint("done")\n',encoding='utf-8')
    pm=[sys.executable,str(install/'tools/policy-manager.py')]
    base=json.loads(subprocess.run(pm+['get'],capture_output=True,text=True,check=True).stdout)
    base['permissions']['preset']='REPORT_ONLY';base['schedule']['enabled']=True;base['schedule']['executor_mode']='LOCAL_COMMAND';base['schedule']['frequency']='DAILY';base['schedule']['local_time']='03:00';base['schedule']['executor']['command']=sys.executable;base['schedule']['executor']['arguments']=[str(helper),str(marker)];base['schedule']['executor']['timeout_minutes']=2
    cand=Path(td)/'policy.json';cand.write_text(json.dumps(base),encoding='utf-8')
    r=subprocess.run(pm+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'],capture_output=True,text=True)
    if r.returncode: raise AssertionError('policy apply failed '+r.stdout+r.stderr)
    return project,install,marker

def exercise(cmd,marker,label):
    marker.unlink(missing_ok=True)
    first=subprocess.Popen(cmd,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    deadline=time.time()+5
    while time.time()<deadline and not marker.exists() and first.poll() is None: time.sleep(.05)
    ok(marker.exists() and first.poll() is None,label+'_first_run_active')
    second=subprocess.run(cmd,capture_output=True,text=True,timeout=5)
    ok(second.returncode==8,label+'_second_overlap_rejected')
    # Critical race: failed contender must not unlink/recreate the lock namespace.
    third=subprocess.run(cmd,capture_output=True,text=True,timeout=5)
    ok(third.returncode==8,label+'_third_overlap_still_rejected_after_second_failure')
    out,err=first.communicate(timeout=15)
    ok(first.returncode==0,label+'_first_run_completes_successfully')

def main():
    with tempfile.TemporaryDirectory(prefix='qa-v21-overlap-') as td:
        project,install,marker=setup(td)
        exercise([sys.executable,str(install/'tools/scheduled-run.py')],marker,'portable')
        if sys.platform.startswith('win'):
            ps=shutil.which('powershell.exe') or shutil.which('pwsh')
            ok(bool(ps),'windows_powershell_available')
            exercise([ps,'-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',str(install/'tools/scheduled-run.ps1')],marker,'windows_native')
    print('V21_OVERLAP_REDTEAM_RESULT=PASS')
    return 0
if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as e: print(e,file=sys.stderr); raise
