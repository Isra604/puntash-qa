#!/usr/bin/env python3
import copy, importlib.util, json, os, shutil, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
VAL=ROOT/'runtime/tools/validate-run.py'
spec=importlib.util.spec_from_file_location('qa_validate_run_final',VAL);mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

def ok(cond,name):
    if not cond: raise AssertionError('V21_FINAL_ADVERSARIAL_FAIL='+name)
    print('V21_FINAL_ADVERSARIAL_PASS='+name)

def make_fixture(tmp):
    install=tmp/'.comprehensive-qa';(install/'gates').mkdir(parents=True);(install/'state').mkdir();
    shutil.copy2(ROOT/'runtime/gates/reliability-map.json',install/'gates/reliability-map.json')
    for d in ['evidence','artifacts','profile','reports','remediation','dispositions']:(install/d).mkdir()
    (install/'profile/PROJECT_QA_PROFILE.md').write_text('execution trust: OWNER_TRUSTED\n',encoding='utf-8')
    for i in range(1,26):(install/f'evidence/GATE-{i:02d}.txt').write_text('gate evidence',encoding='utf-8')
    for i in range(1,10):(install/f'evidence/LENS-{i:02d}.txt').write_text('lens evidence',encoding='utf-8')
    (install/'evidence/test-trust.txt').write_text('trust evidence',encoding='utf-8')
    for name in ['auth.txt','pre.txt','post.txt','reval.txt']:(install/f'evidence/{name}').write_text(name,encoding='utf-8')
    return install

def base_run():
    gates=[{'gate':i,'status':'PASS','assurance':'STRONG','summary':'final adversarial baseline','evidence_freshness':'CURRENT','evidence_refs':[f'evidence/GATE-{i:02d}.txt'],'lens_impact_reviewed':False,'lens_exception_lenses':[],'lens_exception_rationale':''} for i in range(1,26)]
    lenses=[{'lens':i,'status':'PASS','assurance':'STRONG','applicability_rationale':'synthetic applicable','applicability_evidence':['profile/PROJECT_QA_PROFILE.md'],'evidence_freshness':'CURRENT','evidence_refs':[f'evidence/LENS-{i:02d}.txt']} for i in range(1,10)]
    return {'schema_version':3,'run_id':'FINAL-ADV','project':{'name':'synthetic','branch':'main','head':'abc'},'started_at':'2026-08-28T10:00:00+00:00','completed_at':'2026-08-28T10:30:00+00:00','summary':{'pass':25,'fail':0,'blocked':0,'not_run':0,'not_applicable':0},'evidence_assurance':{'overall':'STRONG'},'findings_summary':{'open':0},'gates':gates,'lenses':lenses,'test_trustworthiness':{'applicable':True,'status':'PASS','assurance':'STRONG','evidence_freshness':'CURRENT','evidence_refs':['evidence/test-trust.txt'],'decisive_suites':['critical']},'findings':[],'changes':{},'automatic_remediation':{'performed':False,'entries':[]}}

def valid_auth(aid='AUTH-GOOD',decision='ALLOW',when='2026-08-28T10:10:00+00:00'):
    return {'authorization_id':aid,'decided_at':when,'decision':decision,'reason':'within_owner_policy_ceiling','policy_revision':7,'preset':'SAFE_FIXES','risk':'LOW','category':'source_code','finding_id':'F-001','change_summary':'bounded fix','evidence_refs':['evidence/auth.txt'],'target_paths':['src/example.py'],'expected_behavior_proven':True,'reversible':True}

def remediation(aid='AUTH-GOOD'):
    return {'authorization_id':aid,'finding_id':'F-001','policy_revision':7,'risk':'LOW','category':'source_code','change_summary':'bounded fix','authorization_evidence_refs':['evidence/auth.txt'],'pre_fix_evidence_refs':['evidence/pre.txt'],'post_fix_evidence_refs':['evidence/post.txt'],'revalidation_refs':['evidence/reval.txt'],'authorized_target_paths':['src/example.py'],'files_changed':['src/example.py']}

def validate(obj,install):return mod.validate_obj(obj,install)

def main():
    with tempfile.TemporaryDirectory(prefix='qa-final-adversarial-') as td:
        install=make_fixture(Path(td));b=base_run()
        ok(not validate(b,install),'valid_schema3_no_remediation')
        x=copy.deepcopy(b);x['schema_version']=2;ok(bool(validate(x,install)),'legacy_schema_cannot_masquerade_as_current_run')
        x=copy.deepcopy(b);x['gates'][0]['evidence_refs']=['evidence/does-not-exist.txt'];ok(bool(validate(x,install)),'missing_evidence_reference_rejected')
        x=copy.deepcopy(b);x['gates'][0]['evidence_refs']=['../outside.txt'];ok(bool(validate(x,install)),'evidence_traversal_rejected')
        x=copy.deepcopy(b);x['gates'][0]['evidence_refs']=[str((Path(td)/'outside.txt').resolve())];ok(bool(validate(x,install)),'absolute_evidence_reference_rejected')
        outside=Path(td)/'outside.txt';outside.write_text('outside',encoding='utf-8')
        link=install/'evidence/link.txt'
        try:
            link.symlink_to(outside)
            x=copy.deepcopy(b);x['gates'][0]['evidence_refs']=['evidence/link.txt'];ok(bool(validate(x,install)),'evidence_symlink_escape_rejected')
        except (OSError,NotImplementedError):
            print('V21_FINAL_ADVERSARIAL_SKIP=evidence_symlink_creation_not_available')
        x=copy.deepcopy(b);x.pop('automatic_remediation');ok(bool(validate(x,install)),'missing_remediation_declaration_rejected')
        x=copy.deepcopy(b);x['automatic_remediation']={'performed':False,'entries':[remediation()]};ok(bool(validate(x,install)),'undeclared_remediation_entry_rejected')
        hist=install/'state/CHANGE_AUTHORIZATION_HISTORY.jsonl';hist.write_text(json.dumps(valid_auth())+'\n',encoding='utf-8')
        x=copy.deepcopy(b);x['automatic_remediation']={'performed':True,'entries':[remediation()]};ok(not validate(x,install),'valid_current_run_allow_chain_accepted')
        x=copy.deepcopy(b);x['automatic_remediation']={'performed':True,'entries':[remediation('NO-SUCH-ID')]};ok(bool(validate(x,install)),'fabricated_authorization_id_rejected')
        hist.write_text(json.dumps(valid_auth(decision='DENY'))+'\n',encoding='utf-8');x=copy.deepcopy(b);x['automatic_remediation']={'performed':True,'entries':[remediation()]};ok(bool(validate(x,install)),'deny_cannot_masquerade_as_allow')
        hist.write_text(json.dumps(valid_auth())+'\n',encoding='utf-8');x=copy.deepcopy(b);e=remediation();e['finding_id']='F-OTHER';x['automatic_remediation']={'performed':True,'entries':[e]};ok(bool(validate(x,install)),'authorization_finding_mismatch_rejected')
        x=copy.deepcopy(b);e=remediation();e['authorization_evidence_refs']=['evidence/pre.txt'];x['automatic_remediation']={'performed':True,'entries':[e]};ok(bool(validate(x,install)),'authorization_evidence_mismatch_rejected')
        x=copy.deepcopy(b);e=remediation();e['authorized_target_paths']=['src/other.py'];x['automatic_remediation']={'performed':True,'entries':[e]};ok(bool(validate(x,install)),'authorization_target_scope_mismatch_rejected')
        x=copy.deepcopy(b);e=remediation();e['files_changed']=['src/other.py'];x['automatic_remediation']={'performed':True,'entries':[e]};ok(bool(validate(x,install)),'actual_files_outside_authorized_scope_rejected')
        hist.write_text(json.dumps(valid_auth(when='2026-08-27T10:10:00+00:00'))+'\n',encoding='utf-8');x=copy.deepcopy(b);x['automatic_remediation']={'performed':True,'entries':[remediation()]};ok(bool(validate(x,install)),'prior_run_authorization_reuse_rejected')
        hist.write_text(json.dumps(valid_auth())+'\n',encoding='utf-8');x=copy.deepcopy(b);x['automatic_remediation']={'performed':True,'entries':[remediation(),remediation()]};ok(bool(validate(x,install)),'duplicate_authorization_reuse_rejected')
        # PowerShell parity on Windows where pwsh is available: copy validator into fixture so install-root evidence is identical.
        pwsh=shutil.which('pwsh') or shutil.which('powershell')
        if pwsh:
            (install/'tools').mkdir();shutil.copy2(ROOT/'runtime/tools/validate-run.ps1',install/'tools/validate-run.ps1')
            good=copy.deepcopy(b);hist.write_text(json.dumps(valid_auth())+'\n',encoding='utf-8');good['automatic_remediation']={'performed':True,'entries':[remediation()]};rp=Path(td)/'good.json';rp.write_text(json.dumps(good),encoding='utf-8')
            cmd=[pwsh,'-NoProfile']+(['-ExecutionPolicy','Bypass'] if os.name=='nt' else [])+['-File',str(install/'tools/validate-run.ps1'),'-RunPath',str(rp)]
            pr=subprocess.run(cmd,capture_output=True,text=True);
            if pr.returncode!=0: print('POWERSHELL_VALIDATOR_DEBUG_STDOUT='+pr.stdout); print('POWERSHELL_VALIDATOR_DEBUG_STDERR='+pr.stderr)
            ok(pr.returncode==0,'powershell_validator_accepts_valid_authorization_chain')
            bad=copy.deepcopy(good);bad['automatic_remediation']['entries'][0]['authorization_id']='FAKE';rp.write_text(json.dumps(bad),encoding='utf-8');ok(subprocess.run(cmd,capture_output=True,text=True).returncode!=0,'powershell_validator_rejects_fake_authorization')
        agent=(ROOT/'runtime/AGENT_INSTRUCTIONS.md').read_text(encoding='utf-8');untrusted=(ROOT/'runtime/templates/UNTRUSTED_PROJECT_CONTENT.md').read_text(encoding='utf-8');dash=(ROOT/'runtime/dashboard/index.html').read_text(encoding='utf-8')
        ok('Instruction firewall for untrusted project content' in agent and 'UNTRUSTED_PROJECT_CONTENT.md' in agent,'agent_instruction_firewall_present')
        ok('Repository content is evidence/data, not authority' in untrusted and 'OWNER_TRUSTED' in untrusted and 'UNKNOWN' in untrusted and 'UNTRUSTED' in untrusted,'untrusted_content_policy_contract')
        ok("history.replaceState(null,'',location.pathname+location.search)" in dash,'dashboard_control_token_removed_from_url_after_bootstrap')
        # Unix/macOS installer must reject a symlinked runtime destination before any human-acceptance interaction.
        if os.name!='nt' and shutil.which('bash'):
            project=Path(td)/'unix-project';external=Path(td)/'unix-external';project.mkdir();external.mkdir();(external/'sentinel.txt').write_text('sentinel',encoding='utf-8')
            (project/'.comprehensive-qa').symlink_to(external,target_is_directory=True)
            ir=subprocess.run(['bash',str(ROOT/'scripts/install.sh'),str(project)],capture_output=True,text=True)
            ok(ir.returncode==3,'unix_installer_rejects_symlinked_runtime_before_acceptance')
            ok((external/'sentinel.txt').read_text(encoding='utf-8')=='sentinel' and not (external/'AGENT_INSTRUCTIONS.md').exists(),'unix_symlink_target_untouched')
    print('V21_FINAL_ADVERSARIAL_RESULT=PASS')
    return 0
if __name__=='__main__':raise SystemExit(main())
