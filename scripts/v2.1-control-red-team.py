#!/usr/bin/env python3
import json,shutil,subprocess,sys,tempfile,time,urllib.request,urllib.error
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def ok(cond,name):
    if not cond: raise AssertionError('V21_CONTROL_REDTEAM_FAIL='+name)
    print('V21_CONTROL_REDTEAM_PASS='+name)

def run(cmd,expect=0):
    r=subprocess.run(cmd,capture_output=True,text=True)
    if r.returncode!=expect:
        raise AssertionError(f'command rc {r.returncode} expected {expect}: {cmd}\nOUT={r.stdout}\nERR={r.stderr}')
    return r

def main():
    with tempfile.TemporaryDirectory(prefix='qa-v21-control-redteam-') as td:
        project=Path(td)/'project';install=project/'.comprehensive-qa';shutil.copytree(ROOT/'runtime',install)
        state=install/'state';state.mkdir(exist_ok=True)
        policy_tool=[sys.executable,str(install/'tools/policy-manager.py')]
        auth_tool=[sys.executable,str(install/'tools/authorize-change.py')]
        scheduler=[sys.executable,str(install/'tools/scheduler.py')]
        # Remove config copy to prove direct v2.0-upgrade compatibility fallback.
        try:(install/'config/permission-policy.json').unlink()
        except FileNotFoundError:pass
        base=json.loads(run(policy_tool+['get']).stdout)
        ok(base['configured'] is False and base['permissions']['preset']=='REPORT_ONLY' and base['schedule']['enabled'] is False,'safe_unconfigured_default')
        cand=Path(td)/'candidate.json';cand.write_text(json.dumps(base),encoding='utf-8')
        r=subprocess.run(policy_tool+['apply','--policy-json',str(cand),'--approval-source','agent_owner_conversation'],capture_output=True,text=True)
        ok(r.returncode!=0,'agent_cannot_mutate_policy_without_owner_approved_flag')
        # SAFE_FIXES
        base['permissions']['preset']='SAFE_FIXES';cand.write_text(json.dumps(base),encoding='utf-8')
        run(policy_tool+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'])
        ok(run(auth_tool+['--risk','LOW','--category','documentation','--expected-behavior-proven','--reversible']).returncode==0,'safe_fix_low_reversible_allowed')
        ok(subprocess.run(auth_tool+['--risk','MEDIUM','--category','source_code','--expected-behavior-proven','--reversible'],capture_output=True).returncode!=0,'safe_fix_medium_denied')
        ok(subprocess.run(auth_tool+['--risk','LOW','--category','architecture','--expected-behavior-proven','--reversible'],capture_output=True).returncode!=0,'hard_boundary_denied')
        ok(subprocess.run(auth_tool+['--risk','LOW','--category','documentation','--reversible'],capture_output=True).returncode!=0,'unproven_expected_behavior_denied')
        # ACTIVE
        active=json.loads((state/'OWNER_POLICY.json').read_text(encoding='utf-8-sig'));active['permissions']['preset']='ACTIVE_REMEDIATION';cand.write_text(json.dumps(active),encoding='utf-8')
        run(policy_tool+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'])
        ok(run(auth_tool+['--risk','MEDIUM','--category','source_code','--expected-behavior-proven']).returncode==0,'active_medium_allowed')
        ok(subprocess.run(auth_tool+['--risk','HIGH','--category','source_code','--expected-behavior-proven','--reversible'],capture_output=True).returncode!=0,'active_high_denied')
        # Scheduler mutation still requires explicit owner approval.
        ok(subprocess.run(scheduler+['apply'],capture_output=True).returncode!=0,'scheduler_self_activation_denied')
        # Secret persistence blocked.
        bad=json.loads((state/'OWNER_POLICY.json').read_text(encoding='utf-8-sig'));bad['schedule']['executor_mode']='LOCAL_COMMAND';bad['schedule']['executor']['command']='tool';bad['schedule']['executor']['arguments']=['sk-'+'A'*30];cand.write_text(json.dumps(bad),encoding='utf-8')
        ok(subprocess.run(policy_tool+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'],capture_output=True).returncode!=0,'executor_secret_persistence_denied')
        # Structural executor contract: no shell/eval primitives in either runner.
        ps=(install/'tools/scheduled-run.ps1').read_text(encoding='utf-8-sig').lower();py=(install/'tools/scheduled-run.py').read_text(encoding='utf-8-sig').lower()
        ok('invoke-expression' not in ps and 'iex ' not in ps and 'shell=true' not in py and 'os.system' not in py,'executor_no_eval_or_shell_true')
        # Control center portable live loopback/token test.
        token='redteam-token';p=subprocess.Popen([sys.executable,str(install/'tools/dashboard-control.py'),'--project',str(project),'--port','0','--idle-minutes','1','--no-browser','--token',token],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            url_line=p.stdout.readline().strip();bind=p.stdout.readline().strip();ok(url_line.startswith('DASHBOARD_CONTROL_URL=http://127.0.0.1:'),'control_url_loopback_only');ok(bind=='DASHBOARD_CONTROL_BIND=127.0.0.1','control_bind_loopback_only');url=url_line.split('=',1)[1]
            try: urllib.request.urlopen(url+'api/policy',timeout=5); raise AssertionError('unauthorized api allowed')
            except urllib.error.HTTPError as e: ok(e.code==403,'control_missing_token_denied')
            req=urllib.request.Request(url+'api/policy',headers={'X-QA-Control-Token':token});data=json.loads(urllib.request.urlopen(req,timeout=5).read());ok(data['ok'],'control_valid_token_read')
            req=urllib.request.Request(url+'api/shutdown',data=b'',method='POST',headers={'X-QA-Control-Token':token});urllib.request.urlopen(req,timeout=5).read();p.wait(timeout=10);ok(p.returncode==0,'control_clean_shutdown')
        finally:
            if p.poll() is None:p.kill()
        html=(install/'dashboard/index.html').read_text(encoding='utf-8-sig')
        ok("location.protocol==='http:'&&!!CONTROL_TOKEN" in html,'file_dashboard_is_read_only_without_control_token')
        ok((state/'OWNER_POLICY_HISTORY.jsonl').exists(),'policy_audit_history_present')
    print('V21_CONTROL_REDTEAM_RESULT=PASS')
    return 0
if __name__=='__main__':
    try: raise SystemExit(main())
    except Exception as e: print(str(e),file=sys.stderr);raise
