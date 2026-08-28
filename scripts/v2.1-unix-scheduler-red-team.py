#!/usr/bin/env python3
import json, os, shutil, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def ok(c,n):
    if not c: raise AssertionError('V21_UNIX_SCHED_REDTEAM_FAIL='+n)
    print('V21_UNIX_SCHED_REDTEAM_PASS='+n)

def run(cmd,env,rc=0):
    r=subprocess.run(cmd,capture_output=True,text=True,env=env)
    if r.returncode!=rc:
        raise AssertionError(f'command rc {r.returncode} expected {rc}: {cmd}\nOUT={r.stdout}\nERR={r.stderr}')
    return r

def main():
    if os.name=='nt':
        print('V21_UNIX_SCHED_REDTEAM_SKIP=windows')
        return 0
    with tempfile.TemporaryDirectory(prefix='qa-v21-unix-sched-') as td:
        td=Path(td);fakebin=td/'bin';fakebin.mkdir();store=td/'crontab.txt';fail=td/'fail';store.write_text('MAILTO=ops@example.test\n17 2 * * * /existing/job\n',encoding='utf-8')
        fake=fakebin/'crontab';fake.write_text("#!/usr/bin/env python3\nimport os,sys\nfrom pathlib import Path\nstore=Path(os.environ['FAKE_CRONTAB_STORE'])\nfail=Path(os.environ['FAKE_CRONTAB_FAIL'])\nif fail.exists():\n    print('synthetic crontab backend failure',file=sys.stderr);raise SystemExit(2)\nif sys.argv[1:]==['-l']:\n    if not store.exists(): print('no crontab for qa',file=sys.stderr);raise SystemExit(1)\n    sys.stdout.write(store.read_text());raise SystemExit(0)\nif sys.argv[1:]==['-']:\n    store.write_text(sys.stdin.read());raise SystemExit(0)\nprint('unsupported',file=sys.stderr);raise SystemExit(3)\n",encoding='utf-8',newline='\n');fake.chmod(0o755)
        env=os.environ.copy();env['PATH']=str(fakebin)+os.pathsep+env.get('PATH','');env['FAKE_CRONTAB_STORE']=str(store);env['FAKE_CRONTAB_FAIL']=str(fail)
        project=td/'project with spaces';install=project/'.comprehensive-qa';shutil.copytree(ROOT/'runtime',install);(install/'state').mkdir(exist_ok=True)
        pt=[sys.executable,str(install/'tools/policy-manager.py')];sc=[sys.executable,str(install/'tools/scheduler.py')];candidate=td/'policy.json'
        policy=json.loads(run(pt+['get'],env).stdout);policy['permissions']['preset']='REPORT_ONLY';policy['schedule'].update(enabled=True,executor_mode='LOCAL_COMMAND',frequency='DAILY',local_time='03:11',days_of_week=[]);policy['schedule']['executor']['command']=sys.executable;candidate.write_text(json.dumps(policy),encoding='utf-8');run(pt+['apply','--policy-json',str(candidate),'--owner-approved','--approval-source','manual_cli'],env)
        run(sc+['apply','--owner-approved'],env);text=store.read_text();ok('MAILTO=ops@example.test' in text and '/existing/job' in text,'existing_crontab_entries_preserved');ok(text.count('# BEGIN COMPREHENSIVE-QA-')==1,'managed_cron_block_added_once');ok('11 3 * * *' in text and 'scheduled-run.py' in text,'daily_cron_line_targets_python_runner')
        st=json.loads(run(sc+['status'],env).stdout);ok(st['registered'] is True and st['registration']['status']=='ACTIVE','unix_scheduler_status_active')
        policy=json.loads(run(pt+['get'],env).stdout);policy['schedule'].update(frequency='WEEKLY',local_time='04:22',days_of_week=['Monday','Friday']);candidate.write_text(json.dumps(policy),encoding='utf-8');run(pt+['apply','--policy-json',str(candidate),'--owner-approved','--approval-source','manual_cli'],env);run(sc+['apply','--owner-approved'],env);text=store.read_text();ok(text.count('# BEGIN COMPREHENSIVE-QA-')==1,'cron_reapply_does_not_duplicate_managed_block');ok('22 4 * * 1,5' in text,'weekly_day_mapping_is_correct')
        run(sc+['remove','--owner-approved'],env);text=store.read_text();ok('# BEGIN COMPREHENSIVE-QA-' not in text and '/existing/job' in text,'scheduler_remove_only_removes_owned_cron_block')
        fail.write_text('1');status=json.loads(run(sc+['status'],env).stdout);ok(status['registration']['status']=='SCHEDULER_STATUS_ERROR','crontab_backend_failure_surfaces_in_status')
        r=subprocess.run(sc+['apply','--owner-approved'],capture_output=True,text=True,env=env);ok(r.returncode!=0,'crontab_backend_failure_blocks_apply');ok('/existing/job' in store.read_text(),'crontab_backend_failure_never_overwrites_existing_entries')
        print('V21_UNIX_SCHED_REDTEAM_RESULT=PASS')
    return 0
if __name__=='__main__':raise SystemExit(main())
