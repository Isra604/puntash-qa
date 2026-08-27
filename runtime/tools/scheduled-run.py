#!/usr/bin/env python3
import hashlib,json,os,shutil,signal,subprocess,sys,time
from datetime import datetime,timezone
from pathlib import Path
try: import fcntl
except ImportError: fcntl=None

def now(): return datetime.now(timezone.utc).astimezone().isoformat()
def main():
    acceptance_integrity='UNVERIFIED'
    install=Path(__file__).resolve().parent.parent;project=install.parent;state=install/'state';state.mkdir(exist_ok=True);status=state/'SCHEDULER_STATUS.json';policy=state/'OWNER_POLICY.json';accept=state/'HUMAN_ACCEPTANCE_RECEIPT.json';logs=state/'scheduler/logs';logs.mkdir(parents=True,exist_ok=True)
    def save(result,message,**extra):
        d={'updated_at':now(),'last_attempt':now(),'last_result':result,'message':message,'acceptance_receipt_integrity':acceptance_integrity};d.update(extra);status.write_text(json.dumps(d,indent=2)+'\n',encoding='utf-8')
    if not accept.exists():save('BLOCKED','Human acceptance receipt missing.');return 5
    try: receipt=json.loads(accept.read_text(encoding='utf-8-sig'))
    except Exception: save('BLOCKED','Human acceptance receipt is invalid JSON.');return 5
    current_terms=(install/'TERMS_VERSION').read_text(encoding='utf-8-sig').strip() if (install/'TERMS_VERSION').exists() else ''
    if receipt.get('accepted_by_human_attestation') is not True or str(receipt.get('terms_version',''))!=current_terms: save('BLOCKED','Human acceptance receipt does not prove acceptance of the current Terms version.');return 5
    try: legal_manifest=json.loads((install/'LEGAL_MANIFEST.json').read_text(encoding='utf-8-sig'))
    except Exception: save('BLOCKED','LEGAL_MANIFEST is missing or invalid.');return 5
    for name,expected in legal_manifest.get('documents',{}).items():
        doc=install/name
        if not doc.is_file():save('BLOCKED',f'Installed legal document is missing: {name}');return 5
        actual=hashlib.sha256(doc.read_bytes()).hexdigest().upper()
        if actual!=str(expected).upper():save('BLOCKED',f'Installed legal document hash mismatch: {name}');return 5
    receipt_hashes=receipt.get('legal_document_sha256');legacy_acceptance=False
    if not isinstance(receipt_hashes,dict):
        try:
            installation=json.loads((install/'INSTALLATION.json').read_text(encoding='utf-8-sig'))
            prev=tuple(int(x) for x in str(installation.get('previous_version','')).split('.')[:3])
            legacy_acceptance=(receipt.get('acceptance_method')=='interactive_windows_gui_update_clickwrap' and prev<(2,1,0) and str(receipt.get('package_version',''))==str(installation.get('version','')) and str(receipt.get('terms_version',''))==current_terms)
        except Exception: legacy_acceptance=False
        if not legacy_acceptance: save('BLOCKED','Human acceptance receipt is missing legal document hashes and is not a recognized legacy updater receipt.');return 5
    else:
        for name,expected in legal_manifest.get('documents',{}).items():
            if str(receipt_hashes.get(name,'')).upper()!=str(expected).upper(): save('BLOCKED',f'Human acceptance receipt legal hash mismatch: {name}');return 5
    acceptance_integrity='LEGACY_UPDATE_RECEIPT' if legacy_acceptance else 'HASH_VERIFIED'
    if not policy.exists():save('BLOCKED','OWNER_POLICY missing.');return 6
    try: p=json.loads(policy.read_text(encoding='utf-8-sig'))
    except Exception: save('BLOCKED','OWNER_POLICY is invalid JSON.');return 6
    if not isinstance(p.get('schedule'),dict) or not isinstance(p.get('schedule',{}).get('executor'),dict): save('BLOCKED','OWNER_POLICY schedule structure is invalid.');return 6
    try: retention=int(p.get('schedule',{}).get('executor',{}).get('log_retention_days',30) or 30)
    except Exception: save('BLOCKED','OWNER_POLICY log retention is invalid.');return 6
    retention=retention if 1<=retention<=365 else 30
    cutoff=time.time()-retention*86400
    for old in logs.glob('SCHEDULED-*.*.log'):
        try:
            if old.stat().st_mtime<cutoff:old.unlink()
        except OSError:pass
    if not p.get('configured') or p.get('approval',{}).get('approved_by_human') is not True:save('BLOCKED','OWNER_POLICY is not human-approved/configured.');return 6
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
        run='SCHEDULED-'+datetime.now().strftime('%Y%m%d-%H%M%S-%f');out=logs/f'{run}.stdout.log';err=logs/f'{run}.stderr.log';prompt=install/'prompts/SCHEDULED_QA.md';prompt=prompt if prompt.exists() else install/'templates/SCHEDULED_QA.md'
        args=[str(a).replace('{project}',str(project)).replace('{install}',str(install)).replace('{prompt_file}',str(prompt)) for a in s.get('executor',{}).get('arguments',[])]
        timeout=int(s.get('executor',{}).get('timeout_minutes',240) or 240);timeout=timeout if 1<=timeout<=1440 else 240
        save('RUNNING','Scheduled QA executor started.',run_id=run,executor=cmd,started_at=now(),acceptance_receipt_integrity=('LEGACY_UPDATE_RECEIPT' if legacy_acceptance else 'HASH_VERIFIED'))
        with out.open('wb') as o,err.open('wb') as e:
            proc=subprocess.Popen([exe,*args],cwd=project,stdout=o,stderr=e,shell=False,start_new_session=True)
            try:
                rc=proc.wait(timeout=timeout*60)
            except subprocess.TimeoutExpired:
                try:os.killpg(proc.pid,signal.SIGTERM)
                except Exception:
                    try:proc.terminate()
                    except Exception:pass
                try:proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    try:os.killpg(proc.pid,signal.SIGKILL)
                    except Exception:
                        try:proc.kill()
                        except Exception:pass
                    try:proc.wait(timeout=5)
                    except Exception:pass
                save('TIMEOUT',f'Executor exceeded {timeout} minutes.',run_id=run,stdout=str(out),stderr=str(err),completed_at=now());return 9
        if rc==0:save('SUCCESS','Scheduled QA executor completed.',run_id=run,exit_code=0,stdout=str(out),stderr=str(err),completed_at=now());return 0
        save('FAILED',f'Executor exited with code {rc}.',run_id=run,exit_code=rc,stdout=str(out),stderr=str(err),completed_at=now());return rc if 0<rc<256 else 1
    finally:
        try:
            if fcntl:fcntl.flock(lock.fileno(),fcntl.LOCK_UN)
            lock.close();lock_path.unlink(missing_ok=True)
        except Exception:pass
if __name__=='__main__':raise SystemExit(main())
