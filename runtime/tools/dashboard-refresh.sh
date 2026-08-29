#!/usr/bin/env bash
set -euo pipefail
INSTALL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${1:-$(cd "$INSTALL_ROOT/.." && pwd)}"
RUN_DIR="$INSTALL_ROOT/reports/dashboard"
DASH_DIR="$INSTALL_ROOT/dashboard"
mkdir -p "$RUN_DIR" "$DASH_DIR" "$INSTALL_ROOT/state"
PYTHON_BIN=''
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then PYTHON_BIN='python3';
elif command -v python >/dev/null 2>&1 && python -c 'import sys' >/dev/null 2>&1; then PYTHON_BIN='python';
else
  echo "Python is required to refresh the dashboard automatically on this platform. Run history remains preserved under reports/dashboard." >&2
  exit 2
fi
"$PYTHON_BIN" - "$RUN_DIR" "$DASH_DIR" "$PROJECT" "$INSTALL_ROOT" <<'PY'
import json,sys,datetime,pathlib,os,time
run_dir,dash_dir,project,install_root=map(pathlib.Path,sys.argv[1:])
runs=[]
for p in run_dir.glob('*.json'):
    try:
        r=json.loads(p.read_text(encoding='utf-8-sig'))
        if not r.get('run_id'): continue
        r['_dashboard_record']=p.name
        runs.append(r)
    except Exception: pass
runs.sort(key=lambda r:str(r.get('completed_at','')),reverse=True);runs=runs[:250]
def read_json(p):
    try:return json.loads(p.read_text(encoding='utf-8-sig'))
    except Exception:return None
version='unknown'
meta=read_json(install_root/'INSTALLATION.json')
if isinstance(meta,dict):version=str(meta.get('version','unknown'))
owner_path=install_root/'state'/'OWNER_POLICY.json'
if not owner_path.exists() and (install_root/'templates'/'OWNER_POLICY.json').exists():owner_path.write_bytes((install_root/'templates'/'OWNER_POLICY.json').read_bytes())
receipt=read_json(install_root/'state'/'HUMAN_ACCEPTANCE_RECEIPT.json')
try:terms=(install_root/'TERMS_VERSION').read_text(encoding='utf-8-sig').strip()
except Exception:terms=''
acceptance={'present':isinstance(receipt,dict),'current_terms_version':terms,'accepted_terms_version':str(receipt.get('terms_version','')) if isinstance(receipt,dict) else None,'human_attested':bool(isinstance(receipt,dict) and receipt.get('accepted_by_human_attestation') is True),'terms_match':bool(isinstance(receipt,dict) and str(receipt.get('terms_version',''))==terms)}
data={'schema_version':3,'generated_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'system_version':version,'project_path':str(project),'run_count':len(runs),'update':read_json(install_root/'state'/'LAST_UPDATE_CHECK.json'),'owner_policy':read_json(owner_path),'scheduler_registration':read_json(install_root/'state'/'SCHEDULER_REGISTRATION.json'),'scheduler_status':read_json(install_root/'state'/'SCHEDULER_STATUS.json'),'manual_scan_status':read_json(install_root/'state'/'MANUAL_SCAN_STATUS.json'),'acceptance':acceptance,'qa_doctor':read_json(install_root/'state'/'QA_DOCTOR.json'),'runs':runs}
target=dash_dir/'data.js';tmp=target.with_name(target.name+f'.tmp.{os.getpid()}.{time.time_ns()}')
try:
    tmp.write_text('window.QA_DASHBOARD_DATA = '+json.dumps(data,separators=(',',':'))+';\n',encoding='utf-8',newline='\n')
    os.replace(tmp,target)
finally:
    try:tmp.unlink(missing_ok=True)
    except OSError:pass
print(f'DASHBOARD_REFRESHED={len(runs)}');print(f'DASHBOARD={target}')
PY
