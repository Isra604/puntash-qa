#!/usr/bin/env python3
import argparse,hashlib,json,re,sys
from datetime import datetime,timezone
from pathlib import Path
SECRET=re.compile(r'gh[op]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----')

def now(): return datetime.now(timezone.utc).astimezone().isoformat()
def validate(p,perm):
    e=[]
    if p.get('schema_version')!=1:e.append('schema_version must equal 1')
    presets=set(perm['presets'])
    if p.get('permissions',{}).get('preset') not in presets:e.append('invalid permissions preset')
    allowed_risk={'LOW','MEDIUM'}
    for r in p.get('permissions',{}).get('custom_auto_change_risks',[]):
        if r not in allowed_risk:e.append(f'custom auto-change risk not allowed: {r}')
    allowed=set(perm['auto_change_categories']); hard=set(perm['hard_boundaries'])
    for c in p.get('permissions',{}).get('custom_categories',[]):
        if c not in allowed:e.append(f'custom category not allowed: {c}')
        if c in hard:e.append(f'hard boundary cannot be auto-authorized: {c}')
    s=p.get('schedule',{})
    if s.get('frequency') not in {'DAILY','WEEKDAYS','WEEKLY'}:e.append('unsupported schedule frequency')
    if not re.match(r'^(?:[01]\d|2[0-3]):[0-5]\d$',str(s.get('local_time',''))):e.append('schedule.local_time must be HH:mm')
    if s.get('executor_mode') not in {'UNCONFIGURED','LOCAL_COMMAND','AGENT_MANAGED'}:e.append('invalid executor_mode')
    if s.get('executor_mode')=='LOCAL_COMMAND' and not str(s.get('executor',{}).get('command','')).strip():e.append('LOCAL_COMMAND requires executor.command')
    if SECRET.search(json.dumps(p)):e.append('OWNER_POLICY must not contain credentials/tokens/private keys')
    if e:raise ValueError('; '.join(e))
def main():
    ap=argparse.ArgumentParser();ap.add_argument('operation',choices=['get','apply']);ap.add_argument('--policy-json');ap.add_argument('--owner-approved',action='store_true');ap.add_argument('--approval-source',default='UNCONFIGURED');args=ap.parse_args()
    install=Path(__file__).resolve().parent.parent;state=install/'state';state.mkdir(exist_ok=True);policy=state/'OWNER_POLICY.json';template=install/'templates/OWNER_POLICY.json';perm_path=install/'config/permission-policy.json';perm_path=perm_path if perm_path.exists() else install/'templates/PERMISSION_POLICY.json';perm=json.loads(perm_path.read_text(encoding='utf-8-sig'))
    if not policy.exists():policy.write_bytes(template.read_bytes())
    if args.operation=='get':print(policy.read_text(encoding='utf-8-sig'));return 0
    if not args.owner_approved:raise SystemExit('Policy mutation requires explicit human owner approval.')
    if args.approval_source=='UNCONFIGURED':raise SystemExit('approval-source required')
    p=json.loads(Path(args.policy_json).read_text(encoding='utf-8-sig'));validate(p,perm)
    old_raw=policy.read_text(encoding='utf-8-sig');old=json.loads(old_raw);rev=int(old.get('policy_revision',0))+1
    p['configured']=True;p['configured_at']=now();p['configured_via']=args.approval_source;p['policy_revision']=rev;p['approval']={'approved_by_human':True,'approved_at':now(),'source':args.approval_source};new_raw=json.dumps(p,indent=2)+'\n';validate(p,perm)
    tmp=policy.with_suffix('.tmp');tmp.write_text(new_raw,encoding='utf-8');tmp.replace(policy)
    h={'changed_at':now(),'revision':rev,'source':args.approval_source,'owner_approved':True,'old_hash':hashlib.sha256(old_raw.encode()).hexdigest(),'new_hash':hashlib.sha256(new_raw.encode()).hexdigest(),'preset':p['permissions']['preset'],'schedule_enabled':bool(p['schedule']['enabled']),'executor_mode':p['schedule']['executor_mode']}
    with (state/'OWNER_POLICY_HISTORY.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps(h,separators=(',',':'))+'\n')
    print(f"OWNER_POLICY_APPLIED=1 REVISION={rev} PRESET={p['permissions']['preset']} SCHEDULE={p['schedule']['enabled']}")
    return 0
if __name__=='__main__':
    try:raise SystemExit(main())
    except Exception as e:print('OWNER_POLICY_ERROR='+str(e),file=sys.stderr);raise SystemExit(1)
