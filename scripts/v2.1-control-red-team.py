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
        def auth(risk,category,*flags,finding='F-REDTEAM',summary='bounded red-team change',evidence=('evidence/redteam.txt',),targets=('docs/redteam.md',)):
            cmd=auth_tool+['--risk',risk,'--category',category,'--finding-id',finding,'--change-summary',summary]
            for ref in evidence: cmd += ['--evidence-ref',ref]
            for target in targets: cmd += ['--target-path',target]
            cmd += list(flags)
            return cmd
        scheduler=[sys.executable,str(install/'tools/scheduler.py')]
        scheduled_runner=[sys.executable,str(install/'tools/scheduled-run.py')]
        (install/'TERMS_VERSION').write_text((ROOT/'TERMS_VERSION').read_text(encoding='utf-8-sig'),encoding='utf-8')
        shutil.copy2(ROOT/'LEGAL_MANIFEST.json',install/'LEGAL_MANIFEST.json');legal_docs=json.loads((ROOT/'LEGAL_MANIFEST.json').read_text(encoding='utf-8-sig'))['documents']
        for legal_name in legal_docs: shutil.copy2(ROOT/legal_name,install/legal_name)
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
        ok(run(auth('LOW','documentation','--expected-behavior-proven','--reversible')).returncode==0,'safe_fix_low_reversible_allowed')
        ok(subprocess.run(auth_tool+['--risk','LOW','--category','documentation','--expected-behavior-proven','--reversible'],capture_output=True).returncode!=0,'authorization_requires_finding_summary_and_evidence')
        auth_history=state/'CHANGE_AUTHORIZATION_HISTORY.jsonl';ok(auth_history.exists(),'authorization_audit_history_created')
        last_auth=json.loads(auth_history.read_text(encoding='utf-8-sig').splitlines()[-1]);ok(bool(last_auth.get('authorization_id')) and last_auth.get('policy_revision') is not None,'authorization_audit_records_id_and_policy_revision')
        ok(subprocess.run(auth('MEDIUM','source_code','--expected-behavior-proven','--reversible'),capture_output=True).returncode!=0,'safe_fix_medium_denied')
        ok(subprocess.run(auth('LOW','architecture','--expected-behavior-proven','--reversible'),capture_output=True).returncode!=0,'hard_boundary_denied')
        ok(subprocess.run(auth('LOW','documentation','--reversible'),capture_output=True).returncode!=0,'unproven_expected_behavior_denied')
        # ACTIVE
        active=json.loads((state/'OWNER_POLICY.json').read_text(encoding='utf-8-sig'));active['permissions']['preset']='ACTIVE_REMEDIATION';cand.write_text(json.dumps(active),encoding='utf-8')
        run(policy_tool+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'])
        ok(subprocess.run(auth('MEDIUM','source_code','--expected-behavior-proven'),capture_output=True).returncode!=0,'active_nonreversible_denied')
        ok(run(auth('MEDIUM','source_code','--expected-behavior-proven','--reversible')).returncode==0,'active_medium_reversible_allowed')
        ok(subprocess.run(auth('HIGH','source_code','--expected-behavior-proven','--reversible'),capture_output=True).returncode!=0,'active_high_denied')
        # Scheduler mutation still requires explicit owner approval.
        ok(subprocess.run(scheduler+['apply'],capture_output=True).returncode!=0,'scheduler_self_activation_denied')
        # Secret persistence blocked.
        bad=json.loads((state/'OWNER_POLICY.json').read_text(encoding='utf-8-sig'));bad['schedule']['executor_mode']='LOCAL_COMMAND';bad['schedule']['executor']['command']='tool';bad['schedule']['executor']['arguments']=['sk-'+'A'*30];cand.write_text(json.dumps(bad),encoding='utf-8')
        ok(subprocess.run(policy_tool+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'],capture_output=True).returncode!=0,'executor_secret_persistence_denied')
        # Executor resource/shape policy bounds.
        bounded=json.loads((state/'OWNER_POLICY.json').read_text(encoding='utf-8-sig'));bounded['schedule']['executor_mode']='LOCAL_COMMAND';bounded['schedule']['executor']['command']=sys.executable
        bounded['schedule']['executor']['timeout_minutes']=0;cand.write_text(json.dumps(bounded),encoding='utf-8');ok(subprocess.run(policy_tool+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'],capture_output=True).returncode!=0,'invalid_executor_timeout_denied')
        bounded['schedule']['executor']['timeout_minutes']=240;bounded['schedule']['executor']['log_retention_days']=366;cand.write_text(json.dumps(bounded),encoding='utf-8');ok(subprocess.run(policy_tool+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'],capture_output=True).returncode!=0,'invalid_log_retention_denied')
        bounded['schedule']['executor']['log_retention_days']=30;bounded['schedule']['executor']['arguments']=['x']*65;cand.write_text(json.dumps(bounded),encoding='utf-8');ok(subprocess.run(policy_tool+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'],capture_output=True).returncode!=0,'executor_argument_count_bound_enforced')
        # Scheduled runner must re-validate human acceptance and owner approval on every invocation.
        live=json.loads((state/'OWNER_POLICY.json').read_text(encoding='utf-8-sig'));live['permissions']['preset']='REPORT_ONLY';live['schedule']['enabled']=True;live['schedule']['executor_mode']='LOCAL_COMMAND';live['schedule']['executor']['command']=sys.executable;live['schedule']['executor']['arguments']=['-c','print(\"scheduled-ok\")'];cand.write_text(json.dumps(live),encoding='utf-8')
        run(policy_tool+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'])
        terms=(install/'TERMS_VERSION').read_text(encoding='utf-8-sig').strip();receipt=state/'HUMAN_ACCEPTANCE_RECEIPT.json'
        receipt.write_text(json.dumps({'terms_version':terms,'accepted_by_human_attestation':False,'legal_document_sha256':legal_docs}),encoding='utf-8')
        ok(subprocess.run(scheduled_runner,capture_output=True).returncode==5,'scheduled_run_rejects_nonhuman_receipt')
        receipt.write_text(json.dumps({'terms_version':'0.0.0','accepted_by_human_attestation':True,'legal_document_sha256':legal_docs}),encoding='utf-8')
        ok(subprocess.run(scheduled_runner,capture_output=True).returncode==5,'scheduled_run_rejects_stale_terms_receipt')
        receipt.write_text(json.dumps({'terms_version':terms,'accepted_by_human_attestation':True,'legal_document_sha256':dict(legal_docs, **{'TERMS_OF_USE.md':'0'*64})}),encoding='utf-8')
        ok(subprocess.run(scheduled_runner,capture_output=True).returncode==5,'scheduled_run_rejects_legal_hash_mismatch')
        receipt.write_text(json.dumps({'terms_version':terms,'accepted_by_human_attestation':True,'acceptance_method':'interactive_windows_gui_update_clickwrap','package_version':'2.1.0'}),encoding='utf-8')
        ok(subprocess.run(scheduled_runner,capture_output=True).returncode==5,'scheduled_run_rejects_hashless_nonlegacy_receipt')
        (install/'INSTALLATION.json').write_text(json.dumps({'version':'2.1.0','previous_version':'2.0.0','terms_version':terms}),encoding='utf-8')
        ok(subprocess.run(scheduled_runner,capture_output=True).returncode==0,'scheduled_run_accepts_recognized_legacy_updater_receipt')
        legacy_status=json.loads((state/'SCHEDULER_STATUS.json').read_text(encoding='utf-8-sig'));ok(legacy_status.get('acceptance_receipt_integrity')=='LEGACY_UPDATE_RECEIPT','scheduled_run_marks_legacy_receipt_integrity')
        receipt.write_text(json.dumps({'terms_version':terms,'accepted_by_human_attestation':True,'legal_document_sha256':legal_docs}),encoding='utf-8')
        tampered=json.loads((state/'OWNER_POLICY.json').read_text(encoding='utf-8-sig'));tampered['approval']['approved_by_human']=False;(state/'OWNER_POLICY.json').write_text(json.dumps(tampered),encoding='utf-8')
        ok(subprocess.run(scheduled_runner,capture_output=True).returncode==6,'scheduled_run_rejects_unapproved_policy')
        (state/'OWNER_POLICY.json').write_text('{bad-json',encoding='utf-8')
        ok(subprocess.run(scheduled_runner,capture_output=True).returncode==6,'scheduled_run_rejects_malformed_policy')
        run(policy_tool+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'])
        old_log=state/'scheduler/logs/SCHEDULED-old.stdout.log';old_log.parent.mkdir(parents=True,exist_ok=True);old_log.write_text('old',encoding='utf-8');os_time=time.time()-40*86400;__import__('os').utime(old_log,(os_time,os_time))
        ok(subprocess.run(scheduled_runner,capture_output=True).returncode==0,'scheduled_run_accepts_current_human_receipt_and_approved_policy')
        ok(not old_log.exists(),'scheduled_log_retention_prunes_old_logs')
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
            # Static server must not expose state/evidence/legal files.
            try: urllib.request.urlopen(url+'state/OWNER_POLICY.json',timeout=5); raise AssertionError('state file served publicly')
            except urllib.error.HTTPError as e: ok(e.code==404,'control_static_state_file_denied')
            try: urllib.request.urlopen(url+'data.js',timeout=5); raise AssertionError('dashboard data served publicly')
            except urllib.error.HTTPError as e: ok(e.code==404,'control_static_dashboard_data_denied')
            try: urllib.request.urlopen(url+'api/dashboard-data',timeout=5); raise AssertionError('dashboard data api allowed without token')
            except urllib.error.HTTPError as e: ok(e.code==403,'control_dashboard_data_requires_token')
            req=urllib.request.Request(url+'api/dashboard-data',headers={'X-QA-Control-Token':token});dash_data=json.loads(urllib.request.urlopen(req,timeout=5).read());ok(dash_data.get('ok') is True and 'data' in dash_data,'control_authenticated_dashboard_data_allowed')
            reports=install/'reports';reports.mkdir(exist_ok=True);(reports/'redteam-report.md').write_text('# report\n',encoding='utf-8');(state/'sensitive.txt').write_text('secret-local-state',encoding='utf-8')
            try: urllib.request.urlopen(url+'api/report?path=redteam-report.md',timeout=5); raise AssertionError('report api allowed without token')
            except urllib.error.HTTPError as e: ok(e.code==403,'control_report_requires_token')
            req=urllib.request.Request(url+'api/report?path=redteam-report.md',headers={'X-QA-Control-Token':token});body=urllib.request.urlopen(req,timeout=5).read().decode();ok('# report' in body,'control_authenticated_report_allowed')
            for bad_path in ('../state/sensitive.txt','reports/../state/sensitive.txt','%2e%2e/state/sensitive.txt'):
                try:
                    req=urllib.request.Request(url+'api/report?path='+bad_path,headers={'X-QA-Control-Token':token});urllib.request.urlopen(req,timeout=5);raise AssertionError('report traversal allowed')
                except urllib.error.HTTPError as e: ok(e.code==404,'control_report_traversal_denied_'+bad_path.replace('/','_').replace('%','pct'))
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
