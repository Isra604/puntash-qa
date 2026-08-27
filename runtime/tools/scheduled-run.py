#!/usr/bin/env python3
import json,os,shutil,subprocess,sys,time
from datetime import datetime,timezone
from pathlib import Path
try: import fcntl
except ImportError: fcntl=None

def now(): return datetime.now(timezone.utc).astimezone().isoformat()
def main():
    install=Path(__file__).resolve().parent.parent;project=install.parent;state=install/'state';state.mkdir(exist_ok=True);status=state/'SCHEDULER_STATUS.json';policy=state/'OWNER_POLICY.json';accept=state/'HUMAN_ACCEPTANCE_RECEIPT.json';logs=state/'scheduler/logs';logs.mkdir(parents=True,exist_ok=True)
    def save(result,message,**extra):
        d={'updated_at':now(),'last_attempt':now(),'last_result':result,'message':message};d.update(extra);status.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
    if not accept.exists():save('BLOCKED','Human acceptance receipt missing.');return 5
    if not policy.exists():save('BLOCKED','OWNER_POLICY missing.');return 6
    p=json.loads(policy.read_text(encoding='utf-8-sig'))
    if not p.get('configured'):save('BLOCKED','OWNER_POLICY is not configured.');return 6
    s=p.get('schedule',{})
    if not s.get('enabled'):save('DISABLED','Schedule disabled by owner.');return 0
    if s.get('executor_mode')!='LOCAL_COMMAND':save('NEEDS_EXECUTOR',f"Local scheduled runner cannot execute mode {s.get('executor_mode')}. ");return 7
    cmd=str(s.get('executor',{}).get('command','')).strip();exe=shutil.which(cmd) or (cmd if Path(cmd).is_file() else None)
    if not exe:save('NEEDS_EXECUTOR',f'Executor not found: {cmd}');return 7
    lock_path=state/'SCHEDULED_RUN.lock';lock=open(lock_path,'a+')
    try:
        if fcntl:
            try:fcntl.flock(lock.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError:save('SKIPPED_OVERLAP','Another scheduled QA run is already active.');return 8
        run='SCHEDULED-'+datetime.now().strftime('%Y%m%d-%H%M%S');out=logs/f'{run}.stdout.log';err=logs/f'{run}.stderr.log';prompt=install/'prompts/SCHEDULED_QA.md';prompt=prompt if prompt.exists() else install/'templates/SCHEDULED_QA.md'
        args=[str(a).replace('{project}',str(project)).replace('{install}',str(install)).replace('{prompt_file}',str(prompt)) for a in s.get('executor',{}).get('arguments',[])]
        timeout=int(s.get('executor',{}).get('timeout_minutes',240) or 240);timeout=timeout if 1<=timeout<=1440 else 240
        save('RUNNING','Scheduled QA executor started.',run_id=run,executor=cmd,started_at=now())
        with out.open('wb') as o,err.open('wb') as e:
            try:r=subprocess.run([exe,*args],cwd=project,stdout=o,stderr=e,timeout=timeout*60,shell=False)
            except subprocess.TimeoutExpired:save('TIMEOUT',f'Executor exceeded {timeout} minutes.',run_id=run,stdout=str(out),stderr=str(err));return 9
        if r.returncode==0:save('SUCCESS','Scheduled QA executor completed.',run_id=run,exit_code=0,stdout=str(out),stderr=str(err),completed_at=now());return 0
        save('FAILED',f'Executor exited with code {r.returncode}.',run_id=run,exit_code=r.returncode,stdout=str(out),stderr=str(err),completed_at=now());return r.returncode or 1
    finally:
        try:
            if fcntl:fcntl.flock(lock.fileno(),fcntl.LOCK_UN)
            lock.close();lock_path.unlink(missing_ok=True)
        except Exception:pass
if __name__=='__main__':raise SystemExit(main())
