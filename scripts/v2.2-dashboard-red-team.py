#!/usr/bin/env python3
import hashlib,json,os,shutil,subprocess,sys,tempfile,time,urllib.error,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def ok(c,n):
    if not c: raise AssertionError('V22_DASHBOARD_REDTEAM_FAIL='+n)
    print('V22_DASHBOARD_REDTEAM_PASS='+n)

def req(url,token=None,method='GET',body=None,expect=200,headers_extra=None):
    headers={}
    if headers_extra: headers.update(headers_extra)
    data=None
    if token: headers['X-QA-Control-Token']=token
    if body is not None:
        data=json.dumps(body).encode();headers['Content-Type']='application/json'
    r=urllib.request.Request(url,data=data,method=method,headers=headers)
    try:
        with urllib.request.urlopen(r,timeout=15) as x:
            raw=x.read();code=x.status;ctype=x.headers.get('Content-Type','')
    except urllib.error.HTTPError as e:
        raw=e.read();code=e.code;ctype=e.headers.get('Content-Type','')
    if code!=expect: raise AssertionError(f'{method} {url}: expected {expect}, got {code}: {raw[:1000]!r}')
    if 'json' in ctype:
        return json.loads(raw)
    return raw

def apply_policy(install,candidate,source='manual_cli'):
    tmp=install/'state'/'candidate.json';tmp.write_text(json.dumps(candidate),encoding='utf-8')
    r=subprocess.run([sys.executable,str(install/'tools/policy-manager.py'),'apply','--policy-json',str(tmp),'--owner-approved','--approval-source',source],capture_output=True,text=True)
    if r.returncode: raise AssertionError(r.stderr+r.stdout)
    return json.loads(subprocess.run([sys.executable,str(install/'tools/policy-manager.py'),'get'],capture_output=True,text=True,check=True).stdout)

def main():
  html=(ROOT/'runtime/dashboard/index.html').read_text(encoding='utf-8')
  for token in ['SCAN NOW','Observe only','Fix safe things','More active protection','Fix PUNTASH QA','Ask PUNTASH','Things to review','Your decisions','Overview','Details','Stays on this computer · no data sent by this Dashboard','/api/scan-now','/api/approval','/api/evidence','/api/recovery','const esc=','history.replaceState']:
      ok(token in html,'ui_contract_'+hashlib.sha256(token.encode()).hexdigest()[:8])
  ok('<script src="https://' not in html and '<link href="https://' not in html,'no_external_dashboard_dependencies')
  ok(not any(x in html for x in ['innerHTML=f.title','innerHTML=f.summary','innerHTML=f.description','innerHTML=e.detail','innerHTML=e.message']),'no_obvious_raw_field_innerhtml')
  with tempfile.TemporaryDirectory(prefix='puntash-v22-dashboard-') as td:
    project=Path(td)/'project';install=project/'.comprehensive-qa';project.mkdir();shutil.copytree(ROOT/'runtime',install)
    state=install/'state';state.mkdir(exist_ok=True);(install/'reports/dashboard').mkdir(parents=True,exist_ok=True);(install/'evidence').mkdir(exist_ok=True);(project/'docs').mkdir()
    # Install legal/Terms fixture.
    shutil.copy2(ROOT/'TERMS_VERSION',install/'TERMS_VERSION');shutil.copy2(ROOT/'LEGAL_MANIFEST.json',install/'LEGAL_MANIFEST.json')
    legal=json.loads((ROOT/'LEGAL_MANIFEST.json').read_text(encoding='utf-8-sig'))['documents']
    for name in legal: shutil.copy2(ROOT/name,install/name)
    (install/'INSTALLATION.json').write_text(json.dumps({'version':'2.2.0','previous_version':'2.1.0'}),encoding='utf-8')
    (state/'HUMAN_ACCEPTANCE_RECEIPT.json').write_text(json.dumps({'terms_version':(ROOT/'TERMS_VERSION').read_text().strip(),'accepted_by_human_attestation':True,'legal_document_sha256':legal}),encoding='utf-8')
    # Initial human-approved REPORT_ONLY policy with no runner.
    base=json.loads(subprocess.run([sys.executable,str(install/'tools/policy-manager.py'),'get'],capture_output=True,text=True,check=True).stdout)
    base['permissions']['preset']='REPORT_ONLY';base=apply_policy(install,base)
    token='v22-redteam-token'
    proc=subprocess.Popen([sys.executable,str(install/'tools/dashboard-control.py'),'--project',str(project),'--port','0','--idle-minutes','5','--no-browser','--token',token],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    try:
      line=proc.stdout.readline().strip();bind=proc.stdout.readline().strip();ok(line.startswith('DASHBOARD_CONTROL_URL=http://127.0.0.1:'),'loopback_url');ok(bind=='DASHBOARD_CONTROL_BIND=127.0.0.1','loopback_bind');baseurl=line.split('=',1)[1]
      req(baseurl+'api/overview',expect=403);ok(True,'unauthorized_overview_denied')
      req(baseurl+'api/overview',token,expect=403,headers_extra={'Origin':'http://evil.example'});ok(True,'cross_origin_token_reuse_denied')
      req(baseurl+'state/OWNER_POLICY.json',expect=404);ok(True,'state_static_denied')
      ov=req(baseurl+'api/overview',token);ok(ov['ok'] and ov['overview']['diagnostics']['acceptance']['valid'],'overview_human_acceptance_projection')
      # Scan Now refuses false start without a runner.
      no=req(baseurl+'api/scan-now',token,'POST',{},409);ok(no['error']=='scan_runner_not_configured','scan_now_requires_real_runner')
      # Evidence safe read + traversal and state escape denial.
      (install/'evidence/proof.txt').write_text('proof-data',encoding='utf-8')
      ok(req(baseurl+'api/evidence?path=evidence%2Fproof.txt',token)==b'proof-data','evidence_safe_read')
      req(baseurl+'api/evidence?path=..%2Fstate%2FOWNER_POLICY.json',token,expect=404);ok(True,'evidence_traversal_denied')
      req(baseurl+'api/evidence?path=state%2FOWNER_POLICY.json',token,expect=404);ok(True,'evidence_state_root_denied')
      # Configure a real local executor through canonical policy API.
      pol=req(baseurl+'api/policy',token)['policy'];pol['permissions']['preset']='SAFE_FIXES';pol['schedule']['enabled']=False;pol['schedule']['executor_mode']='LOCAL_COMMAND';pol['schedule']['executor']['command']=sys.executable;pol['schedule']['executor']['arguments']=['-c','import time; print("manual-ok"); time.sleep(2)'];saved=req(baseurl+'api/policy',token,'POST',pol);ok(saved['ok'] and saved['policy']['permissions']['preset']=='SAFE_FIXES','policy_gui_uses_canonical_manager')
      start=req(baseurl+'api/scan-now',token,'POST',{},202);ok(start['started'],'scan_now_starts_real_runner')
      time.sleep(.35);st=req(baseurl+'api/scan-status',token);ok(st['active'] and st['scan']['last_result'] in {'STARTING','RUNNING'},'scan_now_live_status')
      # A separately launched scheduled runner cannot overlap the manual runner because shared OS lock is canonical.
      live=json.loads(subprocess.run([sys.executable,str(install/'tools/policy-manager.py'),'get'],capture_output=True,text=True,check=True).stdout);live['schedule']['enabled']=True;live=apply_policy(install,live)
      overlap=subprocess.run([sys.executable,str(install/'tools/scheduled-run.py')],capture_output=True,text=True);ok(overlap.returncode==8,'manual_and_scheduled_shared_overlap_lock')
      deadline=time.time()+12
      while time.time()<deadline:
        st=req(baseurl+'api/scan-status',token)
        if not st['active']:break
        time.sleep(.25)
      if st['scan']['last_result']!='SUCCESS':
        print('MANUAL_FINAL_STATUS='+json.dumps(st,indent=2),file=sys.stderr)
        mlog=state/'manual/logs'
        if mlog.exists():
          for lp in sorted(mlog.glob('*')):
            try: print('MANUAL_LOG '+lp.name+'='+lp.read_text(encoding='utf-8-sig',errors='replace'),file=sys.stderr)
            except Exception: pass
      ok(st['scan']['last_result']=='SUCCESS','manual_scan_success')
      # Approval queue exact request -> canonical allow.
      current=json.loads(subprocess.run([sys.executable,str(install/'tools/policy-manager.py'),'get'],capture_output=True,text=True,check=True).stdout)
      approval={'request_id':'REQ-V22-1','created_at':'2026-08-28T20:00:00+00:00','policy_revision':current['policy_revision'],'finding_id':'F-V22-1','risk':'LOW','category':'documentation','change_summary':'Update a local documentation note','evidence_refs':['evidence/proof.txt'],'target_paths':['docs/approved.md'],'expected_behavior_proven':True,'reversible':True}
      with (state/'APPROVAL_REQUESTS.jsonl').open('a',encoding='utf-8') as h:h.write(json.dumps(approval)+'\n')
      q=req(baseurl+'api/approvals',token)['approvals'];item=next(x for x in q if x['request_id']=='REQ-V22-1');ok(item['request_hash'] and not item.get('conflict'),'approval_queue_visible')
      dec=req(baseurl+'api/approval',token,'POST',{'request_id':'REQ-V22-1','request_hash':item['request_hash'],'decision':'APPROVE'});ok(dec['ok'] and dec['decision'].get('authorization_id'),'approval_invokes_canonical_authorization')
      req(baseurl+'api/approval',token,'POST',{'request_id':'REQ-V22-1','request_hash':item['request_hash'],'decision':'APPROVE'},409);ok(True,'approval_reuse_denied')
      # Protected request reaches canonical DENY, never UI bypass.
      approval2=dict(approval,request_id='REQ-V22-2',finding_id='F-V22-2',risk='PROTECTED',category='architecture',target_paths=['docs/protected.md'],policy_revision=current['policy_revision'])
      with (state/'APPROVAL_REQUESTS.jsonl').open('a',encoding='utf-8') as h:h.write(json.dumps(approval2)+'\n')
      item2=next(x for x in req(baseurl+'api/approvals',token)['approvals'] if x['request_id']=='REQ-V22-2')
      d=req(baseurl+'api/approval',token,'POST',{'request_id':'REQ-V22-2','request_hash':item2['request_hash'],'decision':'APPROVE'},409);ok(d['error']=='canonical_authorization_denied','protected_approval_cannot_bypass_policy')
      # A stale request is refused after policy revision changes.
      approval3=dict(approval,request_id='REQ-V22-3',finding_id='F-V22-3',policy_revision=current['policy_revision'])
      with (state/'APPROVAL_REQUESTS.jsonl').open('a',encoding='utf-8') as h:h.write(json.dumps(approval3)+'\n')
      item3=next(x for x in req(baseurl+'api/approvals',token)['approvals'] if x['request_id']=='REQ-V22-3')
      latest=json.loads(subprocess.run([sys.executable,str(install/'tools/policy-manager.py'),'get'],capture_output=True,text=True,check=True).stdout);latest['permissions']['preset']='REPORT_ONLY';apply_policy(install,latest)
      req(baseurl+'api/approval',token,'POST',{'request_id':'REQ-V22-3','request_hash':item3['request_hash'],'decision':'APPROVE'},409);ok(True,'stale_approval_policy_revision_denied')
      # Recovery from corrupt Owner Policy is fail closed then canonical safe reset.
      (state/'OWNER_POLICY.json').write_text('{bad-json',encoding='utf-8')
      dg=req(baseurl+'api/diagnostics',token)['diagnostics'];ok(any(x['code']=='POLICY_INVALID' for x in dg['issues']),'recovery_detects_invalid_policy')
      rec=req(baseurl+'api/recovery',token,'POST',{'action':'reset_policy_to_observe_only'});ok(rec['ok'] and rec['policy']['permissions']['preset']=='REPORT_ONLY' and rec['policy']['schedule']['enabled'] is False,'recovery_resets_canonical_safe_state')
      # Scheduler endpoint refuses arbitrary actions.
      req(baseurl+'api/scheduler-action',token,'POST',{'action':'run-shell'},400);ok(True,'scheduler_action_allowlist')
      # Body bounds.
      huge=b'{' + b'"x":"' + b'A'*70000 + b'"}'
      rr=urllib.request.Request(baseurl+'api/policy',data=huge,method='POST',headers={'X-QA-Control-Token':token,'Content-Type':'application/json'})
      try: urllib.request.urlopen(rr,timeout=5);raise AssertionError('large body accepted')
      except urllib.error.HTTPError as e:ok(e.code in (400,413),'api_body_bound')
      req(baseurl+'api/shutdown',token,'POST',{});proc.wait(timeout=10);ok(proc.returncode==0,'clean_shutdown')
    finally:
      if proc.poll() is None:proc.kill()
  print('V22_DASHBOARD_REDTEAM_RESULT=PASS')
if __name__=='__main__':
  try:main()
  except Exception as e:print(str(e),file=sys.stderr);raise
