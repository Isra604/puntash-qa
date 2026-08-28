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
import json,sys,datetime,pathlib
run_dir,dash_dir,project,install_root=map(pathlib.Path,sys.argv[1:])
runs=[]
for p in run_dir.glob('*.json'):
    try:
        r=json.loads(p.read_text(encoding='utf-8-sig'))
        if not r.get('run_id'): continue
        runs.append(r)
    except Exception: pass
runs.sort(key=lambda r:str(r.get('completed_at','')),reverse=True)
runs=runs[:250]
version='unknown'
try: version=json.loads((install_root/'INSTALLATION.json').read_text(encoding='utf-8-sig')).get('version','unknown')
except Exception: pass
update=None
try: update=json.loads((install_root/'state'/'LAST_UPDATE_CHECK.json').read_text(encoding='utf-8-sig'))
except Exception: pass
def read_json(p):
    try:return json.loads(p.read_text(encoding='utf-8-sig'))
    except Exception:return None
owner_path=install_root/'state'/'OWNER_POLICY.json'
if not owner_path.exists() and (install_root/'templates'/'OWNER_POLICY.json').exists(): owner_path.write_bytes((install_root/'templates'/'OWNER_POLICY.json').read_bytes())
owner=read_json(owner_path)
registration=read_json(install_root/'state'/'SCHEDULER_REGISTRATION.json')
scheduler_status=read_json(install_root/'state'/'SCHEDULER_STATUS.json')
data={'schema_version':2,'generated_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'system_version':version,'project_path':str(project),'run_count':len(runs),'update':update,'owner_policy':owner,'scheduler_registration':registration,'scheduler_status':scheduler_status,'runs':runs}
(dash_dir/'data.js').write_text('window.QA_DASHBOARD_DATA = '+json.dumps(data,separators=(',',':'))+';\n',encoding='utf-8')
print(f'DASHBOARD_REFRESHED={len(runs)}')
print(f'DASHBOARD={dash_dir / "index.html"}')
PY
