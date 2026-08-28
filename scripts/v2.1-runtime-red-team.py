#!/usr/bin/env python3
import json, shutil, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def ok(c,n):
    if not c: raise AssertionError('V21_RUNTIME_REDTEAM_FAIL='+n)
    print('V21_RUNTIME_REDTEAM_PASS='+n)

def run(cmd, rc=0):
    r=subprocess.run(cmd,capture_output=True,text=True)
    if r.returncode!=rc:
        raise AssertionError(f'command rc {r.returncode} expected {rc}: {cmd}\nOUT={r.stdout}\nERR={r.stderr}')
    return r

def status(scheduler):
    return json.loads(run(scheduler+['status']).stdout)['registration'] or {}

def apply_policy(policy_tool, candidate, obj):
    candidate.write_text(json.dumps(obj),encoding='utf-8')
    run(policy_tool+['apply','--policy-json',str(candidate),'--owner-approved','--approval-source','manual_cli'])
    return json.loads(run(policy_tool+['get']).stdout)

def main():
    with tempfile.TemporaryDirectory(prefix='qa-v21-runtime-redteam-') as td:
        project=Path(td)/'project with spaces';install=project/'.comprehensive-qa';shutil.copytree(ROOT/'runtime',install)
        state=install/'state';state.mkdir(exist_ok=True)
        policy_tool=[sys.executable,str(install/'tools/policy-manager.py')]
        scheduler=[sys.executable,str(install/'tools/scheduler.py')]
        candidate=Path(td)/'policy.json'
        policy=json.loads(run(policy_tool+['get']).stdout)
        policy['permissions']['preset']='REPORT_ONLY'
        policy['schedule'].update(enabled=True,frequency='DAILY',local_time='03:00',days_of_week=[],executor_mode='AGENT_MANAGED')
        policy=apply_policy(policy_tool,candidate,policy)
        run(scheduler+['apply','--owner-approved'])
        st=status(scheduler);ok(st.get('status')=='NEEDS_PLATFORM_ACTIVATION','agent_managed_requires_activation')
        ok(subprocess.run(scheduler+['mark-agent-managed','--external-id','platform-qa-1'],capture_output=True,text=True).returncode!=0,'agent_managed_mark_requires_owner_approval')
        ok(subprocess.run(scheduler+['mark-agent-managed','--owner-approved','--external-id','sk-'+'A'*30],capture_output=True,text=True).returncode!=0,'agent_managed_external_id_rejects_secret_like_value')
        run(scheduler+['mark-agent-managed','--owner-approved','--external-id','platform-qa-1'])
        st=status(scheduler);ok(st.get('status')=='AGENT_MANAGED_ACTIVE' and st.get('external_id')=='platform-qa-1','agent_managed_activation_bound_to_external_id')
        old_sig=st.get('schedule_signature')
        policy=json.loads(run(policy_tool+['get']).stdout);policy['schedule']['local_time']='04:15';policy=apply_policy(policy_tool,candidate,policy)
        st=status(scheduler);ok(st.get('status')=='NEEDS_PLATFORM_UPDATE' and st.get('schedule_signature')!=old_sig,'agent_managed_policy_change_requires_external_update')
        run(scheduler+['apply','--owner-approved']);ok(status(scheduler).get('status')=='NEEDS_PLATFORM_UPDATE','agent_managed_apply_preserves_update_requirement')
        run(scheduler+['mark-agent-managed','--owner-approved','--external-id','platform-qa-1']);ok(status(scheduler).get('status')=='AGENT_MANAGED_ACTIVE','agent_managed_updated_schedule_reactivated')
        policy=json.loads(run(policy_tool+['get']).stdout);policy['schedule']['executor_mode']='UNCONFIGURED';policy=apply_policy(policy_tool,candidate,policy)
        st=status(scheduler);ok(st.get('status')=='NEEDS_PLATFORM_DEACTIVATION','agent_managed_mode_change_requires_external_deactivation')
        run(scheduler+['apply','--owner-approved']);ok(status(scheduler).get('status')=='NEEDS_PLATFORM_DEACTIVATION','agent_managed_apply_blocks_new_mode_until_deactivation')
        ok(subprocess.run(scheduler+['confirm-agent-managed-disabled','--owner-approved'],capture_output=True,text=True).returncode!=0,'deactivation_confirmation_requires_exact_external_id')
        ok(subprocess.run(scheduler+['confirm-agent-managed-disabled','--owner-approved','--external-id','wrong-id'],capture_output=True,text=True).returncode!=0,'deactivation_confirmation_rejects_wrong_external_id')
        run(scheduler+['confirm-agent-managed-disabled','--owner-approved','--external-id','platform-qa-1'])
        st=status(scheduler);ok(not st.get('external_id') and st.get('status') in {'DISABLED','NEEDS_EXECUTOR'},'external_reference_cleared_only_after_exact_confirmation')
        policy=json.loads(run(policy_tool+['get']).stdout);policy['schedule'].update(enabled=True,executor_mode='AGENT_MANAGED',local_time='05:00');policy=apply_policy(policy_tool,candidate,policy)
        run(scheduler+['apply','--owner-approved']);run(scheduler+['mark-agent-managed','--owner-approved','--external-id','platform-qa-2'])
        policy=json.loads(run(policy_tool+['get']).stdout);policy['schedule']['enabled']=False;policy=apply_policy(policy_tool,candidate,policy)
        run(scheduler+['remove','--owner-approved']);ok(status(scheduler).get('status')=='NEEDS_PLATFORM_DEACTIVATION','owner_disable_requires_external_deactivation')
        run(scheduler+['confirm-agent-managed-disabled','--owner-approved','--external-id','platform-qa-2']);ok(status(scheduler).get('status')=='DISABLED','owner_disable_closes_only_after_external_deactivation_confirmation')
        print('V21_RUNTIME_REDTEAM_RESULT=PASS')
    return 0
if __name__=='__main__':raise SystemExit(main())
