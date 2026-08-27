#!/usr/bin/env python3
import argparse,hashlib,json,shlex,shutil,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path

def now():return datetime.now(timezone.utc).astimezone().isoformat()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('operation',choices=['status','apply','remove','mark-agent-managed']);ap.add_argument('--owner-approved',action='store_true');ap.add_argument('--external-id',default='');a=ap.parse_args()
 install=Path(__file__).resolve().parent.parent;project=install.parent;state=install/'state';state.mkdir(exist_ok=True);policy=state/'OWNER_POLICY.json';reg=state/'SCHEDULER_REGISTRATION.json';marker='COMPREHENSIVE-QA-'+hashlib.sha256(str(project).encode()).hexdigest()[:12]
 def save(status,message,**extra):
  d={'updated_at':now(),'status':status,'message':message,'task_name':marker,'platform':'unix-cron'};d.update(extra);reg.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
 def crontab_get():
  r=subprocess.run(['crontab','-l'],capture_output=True,text=True);return '' if r.returncode else r.stdout
 def remove_entry(text):
  lines=text.splitlines();out=[];skip=False
  for line in lines:
   if line.strip()==f'# BEGIN {marker}':skip=True;continue
   if line.strip()==f'# END {marker}':skip=False;continue
   if not skip:out.append(line)
  return '\n'.join(out).rstrip()+('\n' if out else '')
 if a.operation=='status':
  exists=False
  if shutil.which('crontab'):exists=f'# BEGIN {marker}' in crontab_get()
  print(json.dumps({'task_name':marker,'registered':exists,'registration':json.loads(reg.read_text()) if reg.exists() else None},indent=2));return 0
 if not a.owner_approved:raise SystemExit('Scheduler mutation requires explicit human owner approval.')
 if a.operation=='remove':
  if shutil.which('crontab'):
   text=remove_entry(crontab_get());subprocess.run(['crontab','-'],input=text,text=True,check=True)
  save('DISABLED','Local cron schedule removed by owner.');print('SCHEDULER_REMOVED='+marker);return 0
 if not policy.exists():raise SystemExit('OWNER_POLICY missing.')
 p=json.loads(policy.read_text(encoding='utf-8-sig'));s=p.get('schedule',{})
 if not p.get('configured') or not p.get('approval',{}).get('approved_by_human'):raise SystemExit('OWNER_POLICY is not human-approved/configured.')
 if a.operation=='mark-agent-managed':
  if not s.get('enabled') or s.get('executor_mode')!='AGENT_MANAGED':raise SystemExit('Policy is not enabled for AGENT_MANAGED scheduling.')
  save('AGENT_MANAGED_ACTIVE','External AI/platform scheduler marked active.',external_id=a.external_id,frequency=s.get('frequency'),local_time=s.get('local_time'));print('SCHEDULER_AGENT_MANAGED=ACTIVE');return 0
 if not s.get('enabled'):raise SystemExit('Schedule is disabled in OWNER_POLICY.')
 if s.get('executor_mode')=='UNCONFIGURED':save('NEEDS_EXECUTOR','Schedule intent exists but no executor is configured.');print('SCHEDULER_NEEDS_EXECUTOR=1');return 7
 if s.get('executor_mode')=='AGENT_MANAGED':save('NEEDS_PLATFORM_ACTIVATION','Schedule must be activated by the AI platform scheduler.',frequency=s.get('frequency'),local_time=s.get('local_time'));print('SCHEDULER_NEEDS_PLATFORM_ACTIVATION=1');return 0
 if s.get('executor_mode')!='LOCAL_COMMAND':raise SystemExit('Unsupported executor mode.')
 if not shutil.which('crontab'):save('BLOCKED','crontab is unavailable on this system.');print('SCHEDULER_CRONTAB_UNAVAILABLE=1');return 7
 hh,mm=map(int,s.get('local_time','03:00').split(':'));freq=s.get('frequency','DAILY')
 dow='*'
 if freq=='WEEKDAYS':dow='1-5'
 elif freq=='WEEKLY':
  m={'Sunday':'0','Monday':'1','Tuesday':'2','Wednesday':'3','Thursday':'4','Friday':'5','Saturday':'6'};days=s.get('days_of_week') or ['Sunday'];dow=','.join(m[d] for d in days if d in m) or '0'
 runner=install/'tools/scheduled-run.sh';cron=f'{mm} {hh} * * {dow} {shlex.quote(str(runner))}'
 text=remove_entry(crontab_get())+f'# BEGIN {marker}\n{cron}\n# END {marker}\n';subprocess.run(['crontab','-'],input=text,text=True,check=True)
 save('ACTIVE','Local cron scheduled QA registered.',frequency=freq,local_time=s.get('local_time'),executor_mode='LOCAL_COMMAND');print(f'SCHEDULER_ACTIVE={marker} TIME={s.get("local_time")} FREQUENCY={freq}');return 0
if __name__=='__main__':
 try:raise SystemExit(main())
 except Exception as e:print('SCHEDULER_ERROR='+str(e),file=sys.stderr);raise SystemExit(1)
