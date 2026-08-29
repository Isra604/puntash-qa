#!/usr/bin/env python3
import json,shutil,subprocess,sys,tempfile,time,threading,urllib.request,urllib.error
from datetime import datetime,timezone,timedelta
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def ok(cond,name):
    if not cond: raise AssertionError('V22_FINAL_ADVERSARIAL_FAIL='+name)
    print('V22_FINAL_ADVERSARIAL_PASS='+name)

def call(url,token=None,method='GET',body=None,expect=200,headers_extra=None,timeout=20):
    headers=dict(headers_extra or {})
    if token: headers['X-QA-Control-Token']=token
    data=None
    if body is not None:
        data=json.dumps(body).encode('utf-8');headers['Content-Type']='application/json'
    req=urllib.request.Request(url,data=data,method=method,headers=headers)
    try:
        with urllib.request.urlopen(req,timeout=timeout) as r: raw=r.read();code=r.status;ctype=r.headers.get('Content-Type','')
    except urllib.error.HTTPError as e: raw=e.read();code=e.code;ctype=e.headers.get('Content-Type','')
    if code!=expect: raise AssertionError(f'{method} {url}: expected {expect}, got {code}: {raw[:1000]!r}')
    return json.loads(raw) if 'json' in ctype else raw

def install_fixture(project:Path):
    install=project/'.comprehensive-qa';shutil.copytree(ROOT/'runtime',install);state=install/'state';state.mkdir(exist_ok=True)
    (install/'reports/dashboard').mkdir(parents=True,exist_ok=True);(install/'evidence').mkdir(exist_ok=True);(project/'docs').mkdir(exist_ok=True)
    shutil.copy2(ROOT/'TERMS_VERSION',install/'TERMS_VERSION');shutil.copy2(ROOT/'LEGAL_MANIFEST.json',install/'LEGAL_MANIFEST.json')
    legal=json.loads((ROOT/'LEGAL_MANIFEST.json').read_text(encoding='utf-8-sig'))['documents']
    for name in legal: shutil.copy2(ROOT/name,install/name)
    (install/'INSTALLATION.json').write_text(json.dumps({'version':'2.2.0','previous_version':'2.1.0'}),encoding='utf-8')
    (state/'HUMAN_ACCEPTANCE_RECEIPT.json').write_text(json.dumps({'terms_version':(ROOT/'TERMS_VERSION').read_text().strip(),'accepted_by_human_attestation':True,'legal_document_sha256':legal}),encoding='utf-8')
    return install,state

def policy_get(install):
    return json.loads(subprocess.run([sys.executable,str(install/'tools/policy-manager.py'),'get'],capture_output=True,text=True,check=True).stdout)

def policy_apply(install,p):
    tmp=install/'state'/('candidate-'+str(time.time_ns())+'.json');tmp.write_text(json.dumps(p),encoding='utf-8')
    r=subprocess.run([sys.executable,str(install/'tools/policy-manager.py'),'apply','--policy-json',str(tmp),'--owner-approved','--approval-source','manual_cli'],capture_output=True,text=True)
    tmp.unlink(missing_ok=True)
    if r.returncode: raise AssertionError(r.stderr+r.stdout)
    return policy_get(install)

def git(project,*args):
    return subprocess.run(['git','-C',str(project),*args],capture_output=True,text=True,check=True).stdout.strip()

def make_valid_run(install,run_id,head,completed,fingerprint=None):
    gates=[];lenses=[]
    for i in range(1,26):
        rel=f'evidence/GATE-{run_id}-{i:02d}.txt';(install/rel).write_text('gate evidence',encoding='utf-8')
        gates.append({'gate':i,'status':'PASS','assurance':'STRONG','summary':'Verified','evidence_freshness':'CURRENT','evidence_refs':[rel],'lens_impact_reviewed':False,'lens_exception_lenses':[],'lens_exception_rationale':''})
    (install/'profile').mkdir(exist_ok=True);(install/'profile/PROJECT_QA_PROFILE.md').write_text('profile',encoding='utf-8')
    for i in range(1,10):
        rel=f'evidence/LENS-{run_id}-{i:02d}.txt';(install/rel).write_text('lens evidence',encoding='utf-8')
        lenses.append({'lens':i,'status':'PASS','assurance':'STRONG','applicability_rationale':'Applicable','applicability_evidence':['profile/PROJECT_QA_PROFILE.md'],'evidence_freshness':'CURRENT','evidence_refs':[rel]})
    trust=f'evidence/TRUST-{run_id}.txt';(install/trust).write_text('trusted test evidence',encoding='utf-8')
    started=(datetime.fromisoformat(completed)-timedelta(minutes=1)).isoformat()
    project_obj={'name':'redteam','branch':'main','head':head}
    schema=3
    if fingerprint is not None:
        schema=4;project_obj['fingerprint']=fingerprint
    obj={'schema_version':schema,'run_id':run_id,'project':project_obj,'started_at':started,'completed_at':completed,'summary':{'pass':25,'fail':0,'blocked':0,'not_run':0,'not_applicable':0},'evidence_assurance':{'overall':'STRONG'},'findings_summary':{'open':0},'gates':gates,'lenses':lenses,'test_trustworthiness':{'applicable':True,'status':'PASS','assurance':'STRONG','evidence_freshness':'CURRENT','evidence_refs':[trust],'decisive_suites':['critical']},'findings':[],'changes':{},'automatic_remediation':{'performed':False,'entries':[]}}
    (install/'reports/dashboard'/f'{run_id}.json').write_text(json.dumps(obj),encoding='utf-8')
    return obj

def start_server(install,project,token):
    p=subprocess.Popen([sys.executable,str(install/'tools/dashboard-control.py'),'--project',str(project),'--port','0','--idle-minutes','10','--no-browser','--token',token],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    url=p.stdout.readline().strip();bind=p.stdout.readline().strip()
    if not url.startswith('DASHBOARD_CONTROL_URL='): raise AssertionError('server did not start: '+url+' '+p.stderr.read())
    return p,url.split('=',1)[1]

def main():
    html=(ROOT/'runtime/dashboard/index.html').read_text(encoding='utf-8')
    ok('OVERVIEW?.project_health' in html and 'Open Control Center to verify' in html,'home_health_uses_verified_projection')
    ok('request_hash:a.request_hash' in html and 'a.conflict' in html,'approval_ui_binds_visible_request_hash')
    with tempfile.TemporaryDirectory(prefix='puntash-v22-final-adversarial-') as td:
        project=Path(td)/'project';project.mkdir()
        subprocess.run(['git','init','-q',str(project)],check=True);git(project,'config','user.email','redteam@example.invalid');git(project,'config','user.name','PUNTASH QA Red Team')
        (project/'app.txt').write_text('baseline\n',encoding='utf-8');git(project,'add','app.txt');git(project,'commit','-q','-m','baseline');head1=git(project,'rev-parse','HEAD')
        install,state=install_fixture(project)
        p=policy_get(install);p['permissions']['preset']='SAFE_FIXES';p['schedule']['enabled']=False;p['schedule']['executor_mode']='LOCAL_COMMAND';p['schedule']['executor']['command']=sys.executable;p['schedule']['executor']['arguments']=['-c','import time; time.sleep(3)'];policy_apply(install,p)
        completed=(datetime.now(timezone.utc)-timedelta(seconds=10)).isoformat();make_valid_run(install,'RUN-VALID-1',head1,completed)
        token='v22-final-redteam-token';server,base=start_server(install,project,token);server2=None
        try:
            call(base+'api/overview',token,expect=403,headers_extra={'Origin':'http://evil.example'});ok(True,'foreign_browser_origin_denied_even_with_token')
            ov=call(base+'api/overview',token)['overview'];ok(ov['release_readiness']['ready'] is True and ov['project_health']['label']=='Good','clean_current_git_scan_can_be_ready')
            (project/'app.txt').write_text('changed but uncommitted\n',encoding='utf-8')
            ov=call(base+'api/overview',token)['overview'];ok(ov['release_readiness']['state']=='STALE' and ov['release_readiness']['ready'] is False,'uncommitted_change_invalidates_release_readiness');ok(ov['project_health']['label']!='Good','stale_project_cannot_show_good_health')
            git(project,'add','app.txt');git(project,'commit','-q','-m','changed');head2=git(project,'rev-parse','HEAD')
            ov=call(base+'api/overview',token)['overview'];ok(ov['release_readiness']['state']=='STALE','new_git_head_invalidates_old_scan')
            make_valid_run(install,'RUN-VALID-2',head2,datetime.now(timezone.utc).isoformat())
            ov=call(base+'api/overview',token)['overview'];ok(ov['release_readiness']['ready'] is True,'new_scan_on_current_clean_head_restores_readiness')
            fake={'schema_version':3,'run_id':'RUN-FAKE-FUTURE','project':{'name':'redteam','branch':'main','head':head2},'started_at':'2099-01-01T00:00:00+00:00','completed_at':'2099-01-01T00:01:00+00:00','summary':{'pass':25,'fail':0,'blocked':0,'not_run':0,'not_applicable':0},'gates':[],'lenses':[],'findings':[],'changes':{},'automatic_remediation':{'performed':False,'entries':[]}}
            fake_path=install/'reports/dashboard/RUN-FAKE-FUTURE.json';fake_path.write_text(json.dumps(fake),encoding='utf-8')
            ov=call(base+'api/overview',token)['overview'];ok(ov['release_readiness']['ready'] is False and ov['release_readiness']['state']=='INCOMPLETE','invalid_latest_report_cannot_false_ready');ok(ov['project_health']['label']!='Good','invalid_latest_report_cannot_false_good_home');fake_path.unlink()
            current=policy_get(install);proof=install/'evidence/approval-proof.txt';proof.write_text('proof',encoding='utf-8')
            req1={'request_id':'REQ-TOCTOU-1','created_at':datetime.now(timezone.utc).isoformat(),'policy_revision':current['policy_revision'],'finding_id':'F-TOCTOU','risk':'LOW','category':'documentation','change_summary':'Owner saw this exact request','evidence_refs':['evidence/approval-proof.txt'],'target_paths':['docs/seen.md'],'expected_behavior_proven':True,'reversible':True}
            reqfile=state/'APPROVAL_REQUESTS.jsonl';reqfile.write_text(json.dumps(req1)+'\n',encoding='utf-8')
            item=next(x for x in call(base+'api/approvals',token)['approvals'] if x['request_id']=='REQ-TOCTOU-1');old_hash=item['request_hash']
            mutated=dict(req1,change_summary='Request changed after display',target_paths=['docs/changed.md']);reqfile.write_text(json.dumps(mutated)+'\n',encoding='utf-8')
            r=call(base+'api/approval',token,'POST',{'request_id':'REQ-TOCTOU-1','request_hash':old_hash,'decision':'APPROVE'},409);ok(r['error']=='approval_request_changed_refresh_required','approval_toctou_hash_mismatch_rejected')
            req2=dict(req1,request_id='REQ-DUP-1',finding_id='F-DUP');req2b=dict(req2,change_summary='Conflicting duplicate',target_paths=['docs/other.md'])
            reqfile.write_text(json.dumps(req2)+'\n'+json.dumps(req2b)+'\n',encoding='utf-8')
            item=next(x for x in call(base+'api/approvals',token)['approvals'] if x['request_id']=='REQ-DUP-1');ok(item['conflict'] is True,'duplicate_approval_id_flagged_for_owner')
            r=call(base+'api/approval',token,'POST',{'request_id':'REQ-DUP-1','request_hash':item['request_hash'],'decision':'APPROVE'},409);ok(r['error']=='approval_request_conflict','duplicate_approval_id_cannot_be_approved');reqfile.write_text('',encoding='utf-8')
            (state/'SCHEDULER_REGISTRATION.json').write_text(json.dumps({'status':'AGENT_MANAGED_ACTIVE','platform':'agent-managed','external_id':'external-redteam-1'}),encoding='utf-8');(state/'OWNER_POLICY.json').write_text('{broken',encoding='utf-8')
            r=call(base+'api/recovery',token,'POST',{'action':'reset_policy_to_observe_only'},409);ok(r.get('policy_safe') is True and r.get('error')=='recovery_scheduler_cleanup_failed','recovery_does_not_false_claim_external_scheduler_removed')
            safe=policy_get(install);ok(safe['permissions']['preset']=='REPORT_ONLY' and safe['schedule']['enabled'] is False,'recovery_partial_failure_still_leaves_permissions_fail_safe');(state/'SCHEDULER_REGISTRATION.json').write_text(json.dumps({'status':'DISABLED'}),encoding='utf-8')
            stub=install/'tools/scheduler.py'
            stub.write_text('''#!/usr/bin/env python3\nimport json,sys,time\nfrom pathlib import Path\nstate=Path(__file__).resolve().parent.parent/"state";reg=state/"SCHEDULER_REGISTRATION.json";started=state/"STUB_APPLY_STARTED"\nop=sys.argv[1] if len(sys.argv)>1 else "status"\ndef save(status): reg.write_text(json.dumps({"status":status}),encoding="utf-8")\nif op=="apply": started.write_text("1",encoding="utf-8");time.sleep(0.7);save("ACTIVE");print("APPLY")\nelif op=="remove": save("DISABLED");print("REMOVE")\nelif op=="status":\n d=json.loads(reg.read_text()) if reg.exists() else {"status":"DISABLED"};print(json.dumps(d))\nelse: raise SystemExit(2)\n''',encoding='utf-8')
            p=policy_get(install);p['schedule']['executor_mode']='LOCAL_COMMAND';p['schedule']['executor']['command']=sys.executable;p['schedule']['executor']['arguments']=['-c','pass'];p['schedule']['enabled']=False;p=policy_apply(install,p)
            pa=json.loads(json.dumps(p));pa['schedule']['enabled']=True;pb=json.loads(json.dumps(p));pb['schedule']['enabled']=False;results=[]
            server2,base2=start_server(install,project,'v22-final-redteam-token-2')
            def post_policy(url,tok,body):
                try:results.append(call(url+'api/policy',tok,'POST',body,timeout=20))
                except Exception as e:results.append(e)
            th=threading.Thread(target=post_policy,args=(base,token,pa));th.start();deadline=time.time()+5
            while time.time()<deadline and not (state/'STUB_APPLY_STARTED').exists(): time.sleep(.02)
            ok((state/'STUB_APPLY_STARTED').exists(),'cross_process_policy_scheduler_race_fixture_reached_apply');th2=threading.Thread(target=post_policy,args=(base2,'v22-final-redteam-token-2',pb));th2.start();th.join(10);th2.join(10)
            final_policy=policy_get(install);final_reg=json.loads((state/'SCHEDULER_REGISTRATION.json').read_text());ok(final_policy['schedule']['enabled'] is False and final_reg['status']=='DISABLED','cross_process_policy_scheduler_mutations_finish_consistent')
            shutil.copy2(ROOT/'runtime/tools/scheduler.py',stub)
            p=policy_get(install);p['schedule']['enabled']=False;p['schedule']['executor_mode']='LOCAL_COMMAND';p['schedule']['executor']['command']=sys.executable;p['schedule']['executor']['arguments']=['-c','import time; time.sleep(3)'];policy_apply(install,p)
            call(base+'api/scan-now',token,'POST',{},202);deadline=time.time()+5
            while time.time()<deadline:
                st=call(base+'api/scan-status',token)
                if st['scan'].get('last_result')=='RUNNING':break
                time.sleep(.05)
            ok(st['scan'].get('last_result')=='RUNNING','first_manual_scan_reaches_running');blocked=call(base2+'api/scan-now','v22-final-redteam-token-2','POST',{},409);ok(blocked.get('error')=='scan_already_running','second_control_center_rejects_active_shared_scan');time.sleep(.25)
            st2=call(base2+'api/scan-status','v22-final-redteam-token-2');ok(st2['active'] is True and st2['scan'].get('last_result')=='RUNNING','overlapping_second_control_center_cannot_hide_active_scan')
            deadline=time.time()+8
            while time.time()<deadline:
                st=call(base+'api/scan-status',token)
                if not st['active']:break
                time.sleep(.15)
            ok(st['scan'].get('last_result')=='SUCCESS','winning_manual_scan_status_survives_overlap_attempt');call(base2+'api/shutdown','v22-final-redteam-token-2','POST',{});server2.wait(timeout=5);server2=None
            call(base+'api/shutdown',token,'POST',{});server.wait(timeout=5)
        finally:
            if server2 is not None and server2.poll() is None: server2.kill()
            if server.poll() is None: server.kill()
    # Non-Git projects use the canonical project fingerprint to prove scan freshness.
    with tempfile.TemporaryDirectory(prefix='puntash-v22-fingerprint-') as td2:
        project2=Path(td2)/'plain-project';project2.mkdir();(project2/'app.txt').write_text('plain baseline\n',encoding='utf-8')
        install2,state2=install_fixture(project2)
        fp_run=subprocess.run([sys.executable,str(install2/'tools/project-fingerprint.py'),str(project2)],capture_output=True,text=True,check=True)
        fp=json.loads(fp_run.stdout);ok(fp.get('ok') is True and fp.get('algorithm')=='PUNTASH_SOURCE_V1' and len(str(fp.get('sha256','')))==64,'non_git_project_fingerprint_created')
        fp_record={'algorithm':fp['algorithm'],'available':True,'sha256':fp['sha256'],'file_count':fp['file_count'],'byte_count':fp['byte_count'],'reason':''}
        make_valid_run(install2,'RUN-NONGIT-1','',datetime.now(timezone.utc).isoformat(),fp_record)
        p2=policy_get(install2);p2['permissions']['preset']='REPORT_ONLY';policy_apply(install2,p2)
        srv2,url2=start_server(install2,project2,'v22-fingerprint-token')
        try:
            ov=call(url2+'api/overview','v22-fingerprint-token')['overview'];ok(ov['release_readiness']['ready'] is True and ov['release_readiness'].get('freshness_method')=='FINGERPRINT','non_git_matching_fingerprint_can_be_ready')
            (project2/'app.txt').write_text('plain changed\n',encoding='utf-8')
            ov=call(url2+'api/overview','v22-fingerprint-token')['overview'];ok(ov['release_readiness']['state']=='STALE' and ov['release_readiness']['ready'] is False,'non_git_file_change_invalidates_ready')
            fp2=json.loads(subprocess.run([sys.executable,str(install2/'tools/project-fingerprint.py'),str(project2)],capture_output=True,text=True,check=True).stdout)
            fp_record2={'algorithm':fp2['algorithm'],'available':True,'sha256':fp2['sha256'],'file_count':fp2['file_count'],'byte_count':fp2['byte_count'],'reason':''}
            make_valid_run(install2,'RUN-NONGIT-2','',datetime.now(timezone.utc).isoformat(),fp_record2)
            ov=call(url2+'api/overview','v22-fingerprint-token')['overview'];ok(ov['release_readiness']['ready'] is True,'non_git_new_snapshot_restores_ready')
            call(url2+'api/shutdown','v22-fingerprint-token','POST',{});srv2.wait(timeout=5)
        finally:
            if srv2.poll() is None:srv2.kill()
    print('V22_FINAL_ADVERSARIAL_RESULT=PASS')

if __name__=='__main__':
    try: main()
    except Exception as e:
        print(str(e),file=sys.stderr);raise
