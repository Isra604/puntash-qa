#!/usr/bin/env python3
import argparse
import hashlib
import json
import mimetypes
import os
import re
import secrets
import subprocess
import sys
import threading
import time
import webbrowser
from datetime import datetime, timezone
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse
try:
    import fcntl
except ImportError:
    fcntl = None
try:
    import msvcrt
except ImportError:
    msvcrt = None

INSTALL = Path(__file__).resolve().parent.parent
TOOLS = INSTALL / 'tools'
STATE = INSTALL / 'state'
STATE.mkdir(exist_ok=True)
POLICY = STATE / 'OWNER_POLICY.json'
TEMPLATE = INSTALL / 'templates' / 'OWNER_POLICY.json'
if not POLICY.exists() and TEMPLATE.exists():
    POLICY.write_bytes(TEMPLATE.read_bytes())

MAX_BODY = 65536
MAX_VIEW_BYTES = 2 * 1024 * 1024
MAX_IMAGE_BYTES = 8 * 1024 * 1024
SAFE_TEXT_EXT = {'.md', '.txt', '.json', '.log', '.csv', '.xml', '.yaml', '.yml'}
SAFE_IMAGE_EXT = {'.png', '.jpg', '.jpeg', '.webp'}
SAFE_EVIDENCE_ROOTS = {'evidence', 'artifacts', 'profile', 'reports', 'remediation', 'dispositions'}
REQUEST_ID = re.compile(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$')


def now():
    return datetime.now(timezone.utc).astimezone().isoformat()


def read_json(path: Path):
    try:
        value = json.loads(path.read_text(encoding='utf-8-sig'))
        return value
    except Exception:
        return None


def read_jsonl(path: Path, limit=500):
    if not path.is_file():
        return []
    values = []
    try:
        lines = path.read_text(encoding='utf-8-sig', errors='replace').splitlines()[-limit:]
    except Exception:
        return []
    for line in lines:
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
            if isinstance(obj, dict):
                values.append(obj)
        except Exception:
            continue
    return values


def atomic_write(path: Path, text: str):
    tmp = path.with_name(path.name + f'.tmp.{os.getpid()}.{time.time_ns()}')
    try:
        with tmp.open('w', encoding='utf-8', newline='\n') as h:
            h.write(text)
            h.flush()
            os.fsync(h.fileno())
        os.replace(tmp, path)
    finally:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass


def append_jsonl(path: Path, obj: dict, lock: threading.Lock):
    line = json.dumps(obj, separators=(',', ':'), ensure_ascii=False) + '\n'
    with lock:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open('a', encoding='utf-8', newline='\n') as h:
            h.write(line)
            h.flush()
            os.fsync(h.fileno())


def run_json(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, shell=False)
    if r.returncode:
        raise RuntimeError((r.stderr or r.stdout).strip() or f'command failed {r.returncode}')
    return json.loads(r.stdout)


def policy_command():
    return [sys.executable, str(TOOLS / 'policy-manager.py')]


def scheduler_command():
    return [sys.executable, str(TOOLS / 'scheduler.py')]


def read_dashboard_runs():
    run_dir = INSTALL / 'reports' / 'dashboard'
    run_dir.mkdir(parents=True, exist_ok=True)
    values = []
    for path in run_dir.glob('*.json'):
        try:
            obj = json.loads(path.read_text(encoding='utf-8-sig'))
            if isinstance(obj, dict) and obj.get('run_id'):
                obj['_dashboard_record'] = path.name
                values.append(obj)
        except Exception:
            continue
    values.sort(key=lambda x: str(x.get('completed_at', '')), reverse=True)
    return values[:250]


def acceptance_projection():
    receipt = read_json(STATE / 'HUMAN_ACCEPTANCE_RECEIPT.json')
    terms = ''
    try:
        terms = (INSTALL / 'TERMS_VERSION').read_text(encoding='utf-8-sig').strip()
    except Exception:
        pass
    result = {'present': isinstance(receipt, dict), 'valid': False, 'terms_version': terms, 'accepted_terms_version': None, 'reason': 'Human acceptance has not been recorded.'}
    if not isinstance(receipt, dict):
        return result
    result['accepted_terms_version'] = str(receipt.get('terms_version', ''))
    if receipt.get('accepted_by_human_attestation') is not True:
        result['reason'] = 'The acceptance record does not contain a human attestation.'
        return result
    if str(receipt.get('terms_version', '')) != terms:
        result['reason'] = 'The Terms have changed since acceptance.'
        return result
    manifest = read_json(INSTALL / 'LEGAL_MANIFEST.json')
    if not isinstance(manifest, dict) or not isinstance(manifest.get('documents'), dict):
        result['reason'] = 'The legal integrity manifest could not be verified.'
        return result
    receipt_hashes = receipt.get('legal_document_sha256')
    if isinstance(receipt_hashes, dict):
        for name, expected in manifest['documents'].items():
            doc = INSTALL / name
            if not doc.is_file():
                result['reason'] = f'A required legal document is missing: {name}'
                return result
            actual = hashlib.sha256(doc.read_bytes()).hexdigest().upper()
            if actual != str(expected).upper() or str(receipt_hashes.get(name, '')).upper() != str(expected).upper():
                result['reason'] = 'The legal acceptance record no longer matches the installed legal documents.'
                return result
    else:
        # Preserve recognized v2.0 -> v2.1 updater compatibility without exposing receipt internals.
        installation = read_json(INSTALL / 'INSTALLATION.json') or {}
        try:
            previous = tuple(int(x) for x in str(installation.get('previous_version', '')).split('.')[:3])
        except Exception:
            previous = (999, 999, 999)
        legacy = receipt.get('acceptance_method') == 'interactive_windows_gui_update_clickwrap' and previous < (2, 1, 0) and str(receipt.get('package_version', '')) == str(installation.get('version', ''))
        if not legacy:
            result['reason'] = 'The acceptance record cannot be integrity-verified.'
            return result
    result['valid'] = True
    result['reason'] = 'Current Terms were accepted by a human and the local legal record is valid.'
    return result


def legal_projection():
    manifest = read_json(INSTALL / 'LEGAL_MANIFEST.json')
    if not isinstance(manifest, dict) or not isinstance(manifest.get('documents'), dict):
        return {'valid': False, 'reason': 'Legal integrity manifest is missing or invalid.'}
    for name, expected in manifest['documents'].items():
        path = INSTALL / name
        if not path.is_file():
            return {'valid': False, 'reason': f'Required legal document is missing: {name}'}
        if hashlib.sha256(path.read_bytes()).hexdigest().upper() != str(expected).upper():
            return {'valid': False, 'reason': f'Legal document integrity check failed: {name}'}
    return {'valid': True, 'reason': 'Installed legal documents match the integrity manifest.'}


def collect_dashboard_data(project: Path):
    runs = read_dashboard_runs()
    install_meta = read_json(INSTALL / 'INSTALLATION.json') or {}
    owner = read_json(STATE / 'OWNER_POLICY.json')
    registration = read_json(STATE / 'SCHEDULER_REGISTRATION.json')
    scheduler_status = read_json(STATE / 'SCHEDULER_STATUS.json')
    manual_status = read_json(STATE / 'MANUAL_SCAN_STATUS.json')
    update = read_json(STATE / 'LAST_UPDATE_CHECK.json')
    doctor = read_json(STATE / 'QA_DOCTOR.json')
    data = {
        'schema_version': 3,
        'generated_at': now(),
        'system_version': str(install_meta.get('version', 'unknown')),
        'project_path': str(project),
        'run_count': len(runs),
        'update': update,
        'owner_policy': owner,
        'scheduler_registration': registration,
        'scheduler_status': scheduler_status,
        'manual_scan_status': manual_status,
        'acceptance': acceptance_projection(),
        'qa_doctor': doctor,
        'runs': runs,
    }
    try:
        atomic_write(INSTALL / 'dashboard' / 'data.js', 'window.QA_DASHBOARD_DATA = ' + json.dumps(data, separators=(',', ':'), ensure_ascii=False) + ';\n')
    except Exception:
        pass
    return data


def latest_run_file(runs):
    if not runs:
        return None
    name = str(runs[0].get('_dashboard_record', ''))
    if not name or '/' in name or '\\' in name:
        return None
    path = INSTALL / 'reports' / 'dashboard' / name
    return path if path.is_file() else None


def project_freshness(project: Path, run: dict):
    # Prefer Git when a real commit is available; fall back to the canonical
    # content fingerprint so non-Git projects can still prove freshness.
    try:
        probe = subprocess.run(['git','-C',str(project),'rev-parse','--is-inside-work-tree'], capture_output=True, text=True, shell=False, timeout=10)
        is_git = probe.returncode == 0 and probe.stdout.strip().lower() == 'true'
    except Exception:
        is_git = False
    if is_git:
        try:
            head_run = subprocess.run(['git','-C',str(project),'rev-parse','HEAD'], capture_output=True, text=True, shell=False, timeout=10)
            if head_run.returncode == 0:
                current_head = head_run.stdout.strip()
                scanned_head = str((run.get('project') or {}).get('head') or '').strip()
                if not scanned_head:
                    return {'ok': False, 'state': 'STALE', 'reason': 'The latest scan does not record the project version that was checked. Run SCAN NOW again before relying on this result.'}
                if scanned_head.lower() != current_head.lower():
                    return {'ok': False, 'state': 'STALE', 'reason': 'The project changed after the verified scan. Run SCAN NOW again before releasing.'}
                status_run = subprocess.run([
                    'git','-C',str(project),'status','--porcelain=v1','--untracked-files=all','--','.',
                    ':(exclude).comprehensive-qa/**',':(exclude).comprehensive-qa-backups/**'
                ], capture_output=True, text=True, shell=False, timeout=15)
                if status_run.returncode != 0:
                    return {'ok': False, 'state': 'UNVERIFIABLE', 'reason': 'PUNTASH QA could not verify whether the project changed after the scan.'}
                if status_run.stdout.strip():
                    return {'ok': False, 'state': 'STALE', 'reason': 'The project has changes that are not covered by the verified scan. Run SCAN NOW again after those changes are final.'}
                return {'ok': True, 'state': 'CURRENT', 'method': 'GIT', 'current_head': current_head}
        except Exception:
            pass
    scanned_fp = ((run.get('project') or {}).get('fingerprint') or {})
    if not isinstance(scanned_fp, dict) or scanned_fp.get('available') is not True or scanned_fp.get('algorithm') != 'PUNTASH_SOURCE_V1':
        return {'ok': False, 'state': 'UNVERIFIABLE', 'reason': 'This scan does not contain a project snapshot that PUNTASH QA can compare with the project now. Run SCAN NOW again.'}
    try:
        rr = subprocess.run([sys.executable, str(TOOLS / 'project-fingerprint.py'), str(project)], capture_output=True, text=True, shell=False, timeout=120)
        current = json.loads(rr.stdout) if rr.stdout.strip() else {}
        if rr.returncode != 0 or current.get('ok') is not True:
            return {'ok': False, 'state': 'UNVERIFIABLE', 'reason': 'PUNTASH QA could not safely compare the current project with the verified scan. Open Details if you need the technical reason.'}
        if not secrets.compare_digest(str(scanned_fp.get('sha256','')).upper(), str(current.get('sha256','')).upper()):
            return {'ok': False, 'state': 'STALE', 'reason': 'The project changed after the verified scan. Run SCAN NOW again before releasing.'}
        return {'ok': True, 'state': 'CURRENT', 'method': 'FINGERPRINT', 'fingerprint': current.get('sha256')}
    except Exception:
        return {'ok': False, 'state': 'UNVERIFIABLE', 'reason': 'PUNTASH QA could not safely compare the current project with the verified scan.'}


def release_readiness(runs, project: Path):
    base = {'record_valid': False}
    if not runs:
        return {**base, 'state': 'NOT_SCANNED', 'label': 'Could not verify', 'ready': False, 'reasons': ['Run a full scan before deciding whether this project is ready to release.']}
    r = runs[0]
    path = latest_run_file(runs)
    if not path:
        return {**base, 'state': 'INCOMPLETE', 'label': 'Could not verify', 'ready': False, 'reasons': ['The latest scan record is unavailable. Run SCAN NOW again.']}
    validator = TOOLS / 'validate-run.py'
    try:
        rr = subprocess.run([sys.executable, str(validator), str(path)], capture_output=True, text=True, shell=False, timeout=30)
        if rr.returncode != 0:
            return {**base, 'state': 'INCOMPLETE', 'label': 'Could not verify', 'ready': False, 'reasons': ['The latest scan record could not be verified. Run SCAN NOW again before relying on it.']}
    except Exception:
        return {**base, 'state': 'INCOMPLETE', 'label': 'Could not verify', 'ready': False, 'reasons': ['PUNTASH QA could not verify the latest scan record. Run SCAN NOW again.']}
    base['record_valid'] = True
    s = r.get('summary') or {}
    try:
        fail = int(s.get('fail', 0) or 0); blocked = int(s.get('blocked', 0) or 0); not_run = int(s.get('not_run', 0) or 0)
    except Exception:
        return {**base, 'state': 'INCOMPLETE', 'label': 'Could not verify', 'ready': False, 'reasons': ['The latest scan result is incomplete. Run SCAN NOW again.']}
    if fail or blocked:
        reasons = []
        if fail: reasons.append(f'{fail} quality check(s) found a problem.')
        if blocked: reasons.append(f'{blocked} quality check(s) could not be completed.')
        return {**base, 'state': 'NOT_READY', 'label': 'Not yet', 'ready': False, 'reasons': reasons}
    if not_run:
        return {**base, 'state': 'INCOMPLETE', 'label': 'Could not verify', 'ready': False, 'reasons': [f'{not_run} quality check(s) still need to run.']}
    if len(r.get('gates') or []) != 25 or len(r.get('lenses') or []) != 9:
        return {**base, 'state': 'INCOMPLETE', 'label': 'Could not verify', 'ready': False, 'reasons': ['The latest scan is incomplete. Run SCAN NOW again.']}
    freshness = project_freshness(project, r)
    if not freshness.get('ok'):
        return {**base, 'state': freshness.get('state','INCOMPLETE'), 'label': 'Scan again' if freshness.get('state') == 'STALE' else 'Could not verify', 'ready': False, 'reasons': [freshness.get('reason','Project freshness could not be verified.')]}
    result={**base, 'state': 'READY', 'label': 'Ready', 'ready': True, 'reasons': ['The latest verified scan still matches the project as it is now.'], 'freshness_method': freshness.get('method')}
    result['record_valid']=True
    return result


def project_health(runs, readiness):
    if not runs:
        return {'label': 'Not scanned yet', 'kind': 'info', 'text': 'Run your first scan to see what PUNTASH QA finds.', 'verified': False}
    r = runs[0]
    if readiness.get('state') in {'INCOMPLETE','UNVERIFIABLE','STALE','NOT_SCANNED'}:
        reason = (readiness.get('reasons') or ['The latest scan could not be fully verified.'])[0]
        return {'label': 'Could not fully verify', 'kind': 'warn', 'text': reason, 'verified': False}
    s = r.get('summary') or {}
    try:
        fail=int(s.get('fail',0) or 0); blocked=int(s.get('blocked',0) or 0); not_run=int(s.get('not_run',0) or 0)
    except Exception:
        return {'label':'Could not fully verify','kind':'warn','text':'The latest scan summary is invalid.','verified':False}
    if fail:
        return {'label':'Action required','kind':'bad','text':f'{fail} quality check(s) found a problem.','verified':True}
    if blocked or not_run:
        return {'label':'Could not fully verify','kind':'warn','text':'Some checks could not be completed. Review them before relying on the result.','verified':False}
    findings = [f for f in (r.get('findings') or []) if str(f.get('status','open')).lower() not in {'resolved','closed','fixed'}]
    text = f'{len(findings)} item(s) are worth reviewing.' if findings else 'No current problem was found in the latest verified scan.'
    return {'label':'Good','kind':'good','text':text,'verified':True}


def scheduler_projection():
    try:
        return {'ok': True, 'data': run_json(scheduler_command() + ['status'])}
    except Exception as exc:
        return {'ok': False, 'error': 'scheduler_status_error', 'message': str(exc)}

def scheduler_snapshot():
    reg = read_json(STATE / 'SCHEDULER_REGISTRATION.json')
    return {'ok': True, 'data': {'registered': bool(isinstance(reg, dict) and reg.get('status') in {'ACTIVE','AGENT_MANAGED_ACTIVE'}), 'registration': reg}}


def policy_projection():
    try:
        return {'ok': True, 'data': run_json(policy_command() + ['get'])}
    except Exception as exc:
        return {'ok': False, 'error': 'owner_policy_invalid', 'message': str(exc)}


def scheduler_human_message(state):
    return {
        'POLICY_INVALID':'PUNTASH QA cannot verify the automatic-scan settings. Repair permissions before relying on automatic scans.',
        'REGISTRATION_STATE_INVALID':'The saved automatic-scan setup is damaged and needs repair.',
        'SCHEDULER_STATUS_ERROR':'PUNTASH QA could not verify the automatic-scan service on this computer.',
        'STALE_LOCAL_REGISTRATION':'An old automatic-scan entry needs cleanup.',
        'MISSING_LOCAL_REGISTRATION':'Automatic scans are enabled, but the expected local scan entry is missing.',
        'BLOCKED':'Automatic scans are blocked by a setup problem.',
        'NEEDS_PLATFORM_ACTIVATION':'Your AI platform still needs to turn this automatic schedule on.',
        'NEEDS_PLATFORM_UPDATE':'Your AI platform schedule needs to be updated to match these settings.',
        'NEEDS_PLATFORM_DEACTIVATION':'Automatic scans are off here, but your AI platform still needs to remove its schedule.',
    }.get(str(state or ''),'Automatic scan setup needs attention.')


def permission_name(preset):
    return {'REPORT_ONLY':'Observe only','SAFE_FIXES':'Fix safe things','ACTIVE_REMEDIATION':'More active protection'}.get(str(preset or ''),'Custom settings')


def diagnostics(project: Path):
    issues = []
    policy = policy_projection()
    scheduler = scheduler_snapshot()
    acceptance = acceptance_projection()
    legal = legal_projection()
    if not policy['ok']:
        issues.append({'code': 'POLICY_INVALID', 'severity': 'ACTION', 'title': 'Permission settings need repair', 'message': 'PUNTASH QA could not verify your permission settings. Automatic changes stay blocked until this is repaired.', 'action': 'RESET_POLICY'})
    if not legal['valid']:
        issues.append({'code': 'LEGAL_INVALID', 'severity': 'ACTION', 'title': 'Installation integrity needs attention', 'message': legal['reason'], 'action': None})
    if not acceptance['valid']:
        issues.append({'code': 'ACCEPTANCE_INVALID', 'severity': 'ACTION', 'title': 'Terms acceptance needs attention', 'message': acceptance['reason'], 'action': None})
    sched_reg = ((scheduler.get('data') or {}).get('registration') if scheduler.get('ok') else None) or {}
    sched_state = str(sched_reg.get('status', ''))
    if sched_state in {'POLICY_INVALID', 'REGISTRATION_STATE_INVALID', 'SCHEDULER_STATUS_ERROR', 'STALE_LOCAL_REGISTRATION', 'MISSING_LOCAL_REGISTRATION', 'BLOCKED'}:
        issues.append({'code': sched_state or 'SCHEDULER_ERROR', 'severity': 'ACTION', 'title': 'Automatic scan setup needs attention', 'message': str(sched_reg.get('message') or 'PUNTASH QA could not verify the automatic scan setup.'), 'action': 'RETRY_SCHEDULER'})
    elif sched_state in {'NEEDS_PLATFORM_ACTIVATION', 'NEEDS_PLATFORM_UPDATE', 'NEEDS_PLATFORM_DEACTIVATION'}:
        issues.append({'code': sched_state, 'severity': 'INFO', 'title': 'Your AI platform still has one scheduling step', 'message': scheduler_human_message(sched_state), 'action': None})
    return {
        'ok': not any(x['severity'] == 'ACTION' for x in issues),
        'issues': issues,
        'policy': {'valid': policy['ok']},
        'scheduler': {'valid': scheduler['ok'], 'state': sched_state or 'NOT_CONFIGURED'},
        'acceptance': acceptance,
        'legal': legal,
        'control': {'bind': '127.0.0.1', 'local_only': True, 'telemetry': False},
    }


def activity(project: Path, runs):
    events = []
    for r in runs[:40]:
        completed = str(r.get('completed_at') or '')
        started = str(r.get('started_at') or '')
        rid = str(r.get('run_id') or '')
        summary = r.get('summary') or {}
        if completed:
            events.append({'at': completed, 'type': 'SCAN_COMPLETED', 'title': 'Scan completed', 'detail': f"{summary.get('pass',0)} checked OK · {summary.get('fail',0)} problems · {summary.get('blocked',0)} incomplete", 'run_id': rid})
        if started:
            events.append({'at': started, 'type': 'SCAN_STARTED', 'title': 'Scan started', 'detail': 'PUNTASH QA started checking the project.', 'run_id': rid})
        auto = r.get('automatic_remediation') or {}
        for entry in (auto.get('entries') or [])[:20]:
            events.append({'at': completed or started, 'type': 'REMEDIATION', 'title': 'Safe change recorded', 'detail': str(entry.get('change_summary') or 'PUNTASH QA recorded an authorized change.'), 'finding_id': entry.get('finding_id'), 'authorization_id': entry.get('authorization_id')})
    for h in read_jsonl(STATE / 'OWNER_POLICY_HISTORY.jsonl', 80):
        events.append({'at': str(h.get('changed_at') or ''), 'type': 'POLICY', 'title': 'Permissions or automatic scans changed', 'detail': f"{permission_name(h.get('preset'))} · automatic scans {'on' if h.get('schedule_enabled') else 'off'}", 'policy_revision': h.get('revision')})
    for h in read_jsonl(STATE / 'OWNER_APPROVAL_DECISIONS.jsonl', 80):
        decision = str(h.get('decision') or '')
        events.append({'at': str(h.get('decided_at') or ''), 'type': 'APPROVAL', 'title': 'Change request ' + ('approved' if decision == 'APPROVE' else 'not approved'), 'detail': str(h.get('change_summary') or h.get('request_id') or ''), 'request_id': h.get('request_id'), 'authorization_id': h.get('authorization_id')})
    events = [e for e in events if e.get('at')]
    events.sort(key=lambda e: e['at'], reverse=True)
    return events[:120]


def safe_view_path(raw: str, reports_only=False):
    value = unquote(str(raw or '').replace('\\', '/')).lstrip('/')
    if not value or len(value) > 2048:
        return None
    rel = Path(value)
    if rel.is_absolute() or '..' in rel.parts or '.' in rel.parts:
        return None
    parts = list(rel.parts)
    if reports_only and parts and parts[0].lower() == 'reports':
        parts = parts[1:]
    root = INSTALL / 'reports' if reports_only else INSTALL
    if reports_only:
        if not parts: return None
        candidate = root.joinpath(*parts)
    else:
        if not parts or parts[0].lower() not in SAFE_EVIDENCE_ROOTS:
            return None
        candidate = root.joinpath(*parts)
    try:
        resolved_root = root.resolve()
        resolved = candidate.resolve()
        resolved.relative_to(resolved_root)
    except Exception:
        return None
    ext = resolved.suffix.lower()
    allowed = SAFE_TEXT_EXT | SAFE_IMAGE_EXT
    if ext not in allowed or not resolved.is_file():
        return None
    try:
        size = resolved.stat().st_size
    except OSError:
        return None
    if ext in SAFE_IMAGE_EXT:
        if size > MAX_IMAGE_BYTES: return None
    elif size > MAX_VIEW_BYTES:
        return None
    return resolved


def request_hash(req: dict):
    return hashlib.sha256(json.dumps(req, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode('utf-8')).hexdigest()


def approval_queue():
    requests = read_jsonl(STATE / 'APPROVAL_REQUESTS.jsonl', 500)
    decisions = read_jsonl(STATE / 'OWNER_APPROVAL_DECISIONS.jsonl', 500)
    decided = {str(d.get('request_id')): d for d in decisions if d.get('request_id')}
    grouped = {}
    for req in requests:
        rid = str(req.get('request_id') or '')
        if REQUEST_ID.fullmatch(rid): grouped.setdefault(rid, []).append(req)
    out = []
    for rid, group in grouped.items():
        req = group[-1]
        item = {
            'request_id': rid,
            'created_at': str(req.get('created_at') or ''),
            'policy_revision': req.get('policy_revision'),
            'finding_id': str(req.get('finding_id') or ''),
            'risk': str(req.get('risk') or ''),
            'category': str(req.get('category') or ''),
            'change_summary': str(req.get('change_summary') or '')[:1000],
            'evidence_refs': [str(x) for x in (req.get('evidence_refs') or [])[:16]],
            'target_paths': [str(x) for x in (req.get('target_paths') or [])[:32]],
            'expected_behavior_proven': req.get('expected_behavior_proven') is True,
            'reversible': req.get('reversible') is True,
            'request_hash': request_hash(req),
            'conflict': len(group) != 1,
            'conflict_reason': 'This request ID appears more than once. Refresh or regenerate the request before deciding.' if len(group) != 1 else '',
            'decision': decided.get(rid),
        }
        out.append(item)
    out.sort(key=lambda x: x['created_at'], reverse=True)
    return out[:100]


def validate_approval_request(req):
    rid = str(req.get('request_id') or '')
    if not REQUEST_ID.fullmatch(rid): raise ValueError('approval_request_id_invalid')
    if str(req.get('risk') or '') not in {'LOW', 'MEDIUM', 'HIGH', 'PROTECTED'}: raise ValueError('approval_risk_invalid')
    if not str(req.get('category') or '').strip(): raise ValueError('approval_category_invalid')
    if not str(req.get('finding_id') or '').strip(): raise ValueError('approval_finding_invalid')
    if not str(req.get('change_summary') or '').strip(): raise ValueError('approval_summary_invalid')
    ev = req.get('evidence_refs') or []
    targets = req.get('target_paths') or []
    if not isinstance(ev, list) or not 1 <= len(ev) <= 16: raise ValueError('approval_evidence_invalid')
    if not isinstance(targets, list) or not 1 <= len(targets) <= 32: raise ValueError('approval_targets_invalid')
    for ref in ev:
        if not safe_view_path(str(ref), reports_only=False):
            raise ValueError('approval_evidence_missing_or_unsafe')


@contextmanager
def state_exclusive_lock(name, timeout=30):
    path = STATE / name
    lock = path.open('a+b'); acquired = False; deadline = time.monotonic() + timeout
    try:
        while not acquired:
            if os.name == 'nt' and msvcrt:
                lock.seek(0, os.SEEK_END)
                if lock.tell() == 0: lock.write(b'0'); lock.flush()
                lock.seek(0)
                try: msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1); acquired = True
                except OSError: pass
            elif fcntl:
                try: fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB); acquired = True
                except BlockingIOError: pass
            else:
                raise RuntimeError('No supported OS file-lock primitive is available for Dashboard mutations.')
            if not acquired:
                if time.monotonic() >= deadline: raise TimeoutError('dashboard_mutation_lock_timeout')
                time.sleep(0.05)
        yield
    finally:
        if acquired:
            try:
                lock.seek(0)
                if os.name == 'nt' and msvcrt: msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
                elif fcntl: fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
            except Exception: pass
        lock.close()


def shared_scan_lock_busy():
    lock_path = STATE / 'SCHEDULED_RUN.lock'
    lock = lock_path.open('a+b')
    acquired = False
    try:
        if os.name == 'nt' and msvcrt:
            lock.seek(0, os.SEEK_END)
            if lock.tell() == 0:
                lock.write(b'0'); lock.flush()
            lock.seek(0)
            try:
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1); acquired = True
            except OSError:
                return True
        elif fcntl:
            try:
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB); acquired = True
            except BlockingIOError:
                return True
        else:
            return True
        return False
    finally:
        if acquired:
            try:
                lock.seek(0)
                if os.name == 'nt' and msvcrt: msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)
                elif fcntl: fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
            except Exception:
                pass
        lock.close()


def recent_starting_status(status):
    if not isinstance(status, dict) or str(status.get('last_result') or '') != 'STARTING':
        return False
    try:
        ts = datetime.fromisoformat(str(status.get('updated_at') or status.get('last_attempt') or ''))
        if ts.tzinfo is None: ts = ts.replace(tzinfo=timezone.utc)
        return (datetime.now(timezone.utc) - ts.astimezone(timezone.utc)).total_seconds() < 30
    except Exception:
        return False

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--project')
    ap.add_argument('--port', type=int, default=0)
    ap.add_argument('--idle-minutes', type=int, default=30)
    ap.add_argument('--no-browser', action='store_true')
    ap.add_argument('--token')
    a = ap.parse_args()
    project = Path(a.project).resolve() if a.project else INSTALL.parent.resolve()
    token = a.token or secrets.token_hex(32)
    last = [time.monotonic()]
    stop = threading.Event()
    approval_lock = threading.Lock()
    scan_lock = threading.Lock()
    scan_proc = [None]
    policy_tool = policy_command()
    scheduler_tool = scheduler_command()

    def start_scan():
        with scan_lock:
            proc = scan_proc[0]
            if proc is not None and proc.poll() is None:
                return None, 'scan_already_running'
            shared_status = read_json(STATE / 'MANUAL_SCAN_STATUS.json') or {}
            if shared_scan_lock_busy() or recent_starting_status(shared_status):
                return None, 'scan_already_running'
            # Fast preflight so the UI gets an immediate useful answer.
            try:
                policy = run_json(policy_tool + ['get'])
            except Exception:
                return None, 'owner_policy_invalid'
            mode = str((policy.get('schedule') or {}).get('executor_mode') or '')
            if mode == 'AGENT_MANAGED': return None, 'scan_needs_external_agent'
            if mode != 'LOCAL_COMMAND': return None, 'scan_runner_not_configured'
            runner = TOOLS / 'manual-run.py'
            atomic_write(STATE / 'MANUAL_SCAN_STATUS.json', json.dumps({'updated_at': now(), 'last_attempt': now(), 'last_result': 'STARTING', 'message': 'PUNTASH QA is starting the scan.'}, separators=(',', ':')) + '\n')
            proc = subprocess.Popen([sys.executable, str(runner)], cwd=str(project), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, shell=False)
            scan_proc[0] = proc
            return proc.pid, None

    class H(BaseHTTPRequestHandler):
        server_version = 'PuntashQAControl/2.2'
        def log_message(self, *args):
            pass
        def headers_common(self):
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.send_header('Cross-Origin-Resource-Policy', 'same-origin')
            self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
        def send_bytes(self, b, ctype='application/octet-stream', code=200):
            self.send_response(code); self.send_header('Content-Type', ctype); self.headers_common(); self.send_header('Content-Length', str(len(b))); self.end_headers(); self.wfile.write(b)
        def send_json(self, obj, code=200):
            self.send_bytes(json.dumps(obj, separators=(',', ':'), ensure_ascii=False).encode('utf-8'), 'application/json; charset=utf-8', code)
        def authorized(self):
            if self.headers.get('X-QA-Control-Token', '') != token: return False
            origin = self.headers.get('Origin', '')
            expected = f'http://127.0.0.1:{self.server.server_address[1]}'
            return not origin or origin == expected
        def read_body(self, max_bytes=MAX_BODY):
            try: n = int(self.headers.get('Content-Length', '-1'))
            except ValueError: n = -1
            if n < 0 or n > max_bytes: raise ValueError('invalid_body_size')
            try: return json.loads(self.rfile.read(n)) if n else {}
            except Exception: raise ValueError('invalid_json')
        def api_get(self, path, query):
            if not self.authorized(): return self.send_json({'ok': False, 'error': 'unauthorized'}, 403)
            data = None
            if path in {'/api/dashboard-data', '/api/overview', '/api/activity'}:
                data = collect_dashboard_data(project)
            if path == '/api/dashboard-data': return self.send_json({'ok': True, 'data': data})
            if path == '/api/overview':
                pol = policy_projection(); sched = scheduler_snapshot(); runs = data.get('runs') or []
                readiness = release_readiness(runs, project)
                return self.send_json({'ok': True, 'overview': {'data': data, 'policy': pol, 'scheduler': sched, 'release_readiness': readiness, 'project_health': project_health(runs, readiness), 'diagnostics': diagnostics(project)}})
            if path == '/api/activity': return self.send_json({'ok': True, 'activity': activity(project, data.get('runs') or [])})
            if path == '/api/report':
                raw = (parse_qs(query).get('path') or [''])[0]
                f = safe_view_path(raw, reports_only=True)
                if not f: return self.send_json({'ok': False, 'error': 'report_not_found'}, 404)
                return self.send_bytes(f.read_bytes(), mimetypes.guess_type(str(f))[0] or 'text/plain; charset=utf-8')
            if path == '/api/evidence':
                raw = (parse_qs(query).get('path') or [''])[0]
                f = safe_view_path(raw, reports_only=False)
                if not f: return self.send_json({'ok': False, 'error': 'evidence_not_found'}, 404)
                return self.send_bytes(f.read_bytes(), mimetypes.guess_type(str(f))[0] or 'text/plain; charset=utf-8')
            if path == '/api/policy':
                pol = policy_projection()
                return self.send_json({'ok': True, 'policy': pol['data']}) if pol['ok'] else self.send_json({'ok': False, 'error': pol['error'], 'details': pol['message']}, 409)
            if path == '/api/scheduler':
                sched = scheduler_projection()
                return self.send_json({'ok': True, 'scheduler': sched['data']}) if sched['ok'] else self.send_json({'ok': False, 'error': sched['error'], 'details': sched['message']}, 409)
            if path == '/api/scan-status':
                status = read_json(STATE / 'MANUAL_SCAN_STATUS.json') or {'last_result': 'NOT_RUN', 'message': 'No manual scan has been started yet.'}
                proc = scan_proc[0]
                active = bool(proc is not None and proc.poll() is None) or shared_scan_lock_busy() or recent_starting_status(status)
                return self.send_json({'ok': True, 'active': active, 'scan': status})
            if path == '/api/diagnostics': return self.send_json({'ok': True, 'diagnostics': diagnostics(project)})
            if path == '/api/approvals': return self.send_json({'ok': True, 'approvals': approval_queue()})
            return self.send_json({'ok': False, 'error': 'not_found'}, 404)
        def do_GET(self):
            last[0] = time.monotonic(); parsed = urlparse(self.path); path = parsed.path
            if path.startswith('/api/'): return self.api_get(path, parsed.query)
            rel = unquote(path.lstrip('/')) or 'dashboard/index.html'
            if rel == 'index.html': rel = 'dashboard/index.html'
            if rel != 'dashboard/index.html': return self.send_bytes(b'Not Found', 'text/plain', 404)
            p = INSTALL / rel
            if not p.is_file(): return self.send_bytes(b'Not Found', 'text/plain', 404)
            self.send_bytes(p.read_bytes(), 'text/html; charset=utf-8')
        def do_POST(self):
            last[0] = time.monotonic(); path = urlparse(self.path).path
            if not self.authorized(): return self.send_json({'ok': False, 'error': 'unauthorized'}, 403)
            if path == '/api/shutdown':
                self.send_json({'ok': True}); stop.set(); return
            if path == '/api/scan-now':
                try:
                    _ = self.read_body(4096)
                except ValueError as exc:
                    return self.send_json({'ok': False, 'error': str(exc)}, 400 if str(exc) == 'invalid_json' else 413)
                pid, error = start_scan()
                if error:
                    messages = {
                        'scan_already_running': 'A scan is already running.',
                        'owner_policy_invalid': 'Permission settings could not be verified. Repair them before starting a scan.',
                        'scan_needs_external_agent': 'This project uses an external AI/platform scan runner. Start the scan from that platform, or configure a local runner.',
                        'scan_runner_not_configured': 'A scan runner has not been configured yet. Open Schedule & setup to choose how scans should run.',
                    }
                    return self.send_json({'ok': False, 'error': error, 'message': messages.get(error, error)}, 409)
                return self.send_json({'ok': True, 'started': True, 'pid': pid}, 202)
            if path == '/api/scheduler-action':
                try: body = self.read_body(8192)
                except ValueError as exc: return self.send_json({'ok': False, 'error': str(exc)}, 400)
                action = str(body.get('action') or '')
                if action not in {'apply', 'remove'}: return self.send_json({'ok': False, 'error': 'invalid_scheduler_action'}, 400)
                try:
                    with state_exclusive_lock('DASHBOARD_MUTATION.lock'):
                        r = subprocess.run(scheduler_tool + [action, '--owner-approved'], capture_output=True, text=True, shell=False)
                        sched = scheduler_projection()
                except TimeoutError:
                    return self.send_json({'ok': False, 'error': 'dashboard_mutation_busy', 'message': 'Another Dashboard change is still being saved. Try again in a moment.'}, 409)
                return self.send_json({'ok': r.returncode in (0, 7), 'scheduler': sched.get('data'), 'message': (r.stdout or r.stderr).strip(), 'exit_code': r.returncode}, 200 if r.returncode in (0, 7) else 409)
            if path == '/api/approval':
                try: body = self.read_body(16384)
                except ValueError as exc: return self.send_json({'ok': False, 'error': str(exc)}, 400)
                rid = str(body.get('request_id') or '')
                decision = str(body.get('decision') or '').upper()
                client_hash = str(body.get('request_hash') or '').lower()
                if not REQUEST_ID.fullmatch(rid) or decision not in {'APPROVE', 'DENY'} or not re.fullmatch(r'[0-9a-f]{64}', client_hash): return self.send_json({'ok': False, 'error': 'invalid_approval_request'}, 400)
                with approval_lock:
                    try:
                        with state_exclusive_lock('DASHBOARD_MUTATION.lock'):
                            existing = {str(x.get('request_id')): x for x in read_jsonl(STATE / 'OWNER_APPROVAL_DECISIONS.jsonl', 1000)}
                            if rid in existing: return self.send_json({'ok': False, 'error': 'approval_already_decided', 'decision': existing[rid]}, 409)
                            requests = [x for x in read_jsonl(STATE / 'APPROVAL_REQUESTS.jsonl', 1000) if str(x.get('request_id')) == rid]
                            if not requests: return self.send_json({'ok': False, 'error': 'approval_request_not_found'}, 404)
                            if len(requests) != 1: return self.send_json({'ok': False, 'error': 'approval_request_conflict', 'message': 'This approval request ID appears more than once. Refresh or regenerate the request before deciding.'}, 409)
                            req = requests[0]
                            current_hash = request_hash(req)
                            if not secrets.compare_digest(client_hash, current_hash): return self.send_json({'ok': False, 'error': 'approval_request_changed_refresh_required', 'message': 'This request changed after it was displayed. Refresh before deciding.'}, 409)
                            try: validate_approval_request(req)
                            except Exception as exc: return self.send_json({'ok': False, 'error': str(exc)}, 409)
                            pol = policy_projection()
                            if not pol['ok']: return self.send_json({'ok': False, 'error': 'owner_policy_invalid'}, 409)
                            if req.get('policy_revision') != pol['data'].get('policy_revision'): return self.send_json({'ok': False, 'error': 'approval_request_stale_policy_revision'}, 409)
                            record = {'request_id': rid, 'request_hash': current_hash, 'decided_at': now(), 'decision': decision, 'finding_id': req.get('finding_id'), 'change_summary': str(req.get('change_summary') or '')[:1000], 'policy_revision': req.get('policy_revision')}
                            if decision == 'DENY':
                                append_jsonl(STATE / 'OWNER_APPROVAL_DECISIONS.jsonl', record, threading.Lock())
                                return self.send_json({'ok': True, 'decision': record})
                            cmd = [sys.executable, str(TOOLS / 'authorize-change.py'), '--risk', str(req['risk']), '--category', str(req['category']), '--finding-id', str(req['finding_id']), '--change-summary', str(req['change_summary'])]
                            for ref in req.get('evidence_refs') or []: cmd += ['--evidence-ref', str(ref)]
                            for target in req.get('target_paths') or []: cmd += ['--target-path', str(target)]
                            if req.get('expected_behavior_proven') is True: cmd += ['--expected-behavior-proven']
                            if req.get('reversible') is True: cmd += ['--reversible']
                            rr = subprocess.run(cmd, capture_output=True, text=True, shell=False)
                            output = (rr.stdout or rr.stderr).strip()
                            m = re.search(r'AUTHORIZATION_ID=([A-Za-z0-9]+)', output)
                            if rr.returncode != 0 or 'CHANGE_AUTHORIZATION=ALLOW' not in output or not m:
                                record['decision'] = 'SYSTEM_DENIED'; record['reason'] = output[:1000]
                                append_jsonl(STATE / 'OWNER_APPROVAL_DECISIONS.jsonl', record, threading.Lock())
                                return self.send_json({'ok': False, 'error': 'canonical_authorization_denied', 'decision': record}, 409)
                            record['authorization_id'] = m.group(1)
                            append_jsonl(STATE / 'OWNER_APPROVAL_DECISIONS.jsonl', record, threading.Lock())
                            return self.send_json({'ok': True, 'decision': record})
                    except TimeoutError:
                        return self.send_json({'ok': False, 'error': 'dashboard_mutation_busy', 'message': 'Another Dashboard decision is still being saved. Try again in a moment.'}, 409)
            if path == '/api/recovery':
                try: body = self.read_body(8192)
                except ValueError as exc: return self.send_json({'ok': False, 'error': str(exc)}, 400)
                action = str(body.get('action') or '')
                if action != 'reset_policy_to_observe_only': return self.send_json({'ok': False, 'error': 'invalid_recovery_action'}, 400)
                template = read_json(TEMPLATE)
                if not isinstance(template, dict): return self.send_json({'ok': False, 'error': 'safe_policy_template_invalid'}, 500)
                candidate = json.loads(json.dumps(template))
                candidate['permissions']['preset'] = 'REPORT_ONLY'
                candidate['permissions']['custom_auto_change_risks'] = []
                candidate['permissions']['custom_categories'] = []
                candidate['schedule']['enabled'] = False
                candidate['schedule']['executor_mode'] = 'UNCONFIGURED'
                candidate['schedule']['executor']['command'] = ''
                candidate['schedule']['executor']['arguments'] = []
                temp = STATE / ('.owner-policy-recovery-' + secrets.token_hex(8) + '.json')
                try:
                    with state_exclusive_lock('DASHBOARD_MUTATION.lock'):
                        temp.write_text(json.dumps(candidate, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
                        rr = subprocess.run(policy_tool + ['apply', '--policy-json', str(temp), '--owner-approved', '--approval-source', 'dashboard_local_control'], capture_output=True, text=True, shell=False)
                        if rr.returncode: raise RuntimeError((rr.stderr or rr.stdout).strip())
                        sr = subprocess.run(scheduler_tool + ['remove', '--owner-approved'], capture_output=True, text=True, shell=False)
                        saved = run_json(policy_tool + ['get'])
                        registration = read_json(STATE / 'SCHEDULER_REGISTRATION.json')
                        collect_dashboard_data(project)
                    scheduler_state = str((registration or {}).get('status') or '')
                    if sr.returncode != 0 or (scheduler_state and scheduler_state != 'DISABLED'):
                        return self.send_json({'ok': False, 'error': 'recovery_scheduler_cleanup_failed', 'policy_safe': True, 'message': 'Permissions were reset to Observe only, but PUNTASH QA could not prove that the automatic scan registration was removed. Automatic remediation remains blocked; repair the scheduler before relying on scan timing.', 'policy': saved, 'scheduler_state': scheduler_state}, 409)
                    return self.send_json({'ok': True, 'message': 'Permission settings were reset to Observe only and automatic scan registration was removed.', 'policy': saved})
                except Exception as exc:
                    return self.send_json({'ok': False, 'error': 'recovery_failed', 'message': str(exc)}, 409)
                finally:
                    try: temp.unlink()
                    except Exception: pass
            if path != '/api/policy': return self.send_json({'ok': False, 'error': 'not_found'}, 404)
            try: candidate = self.read_body(MAX_BODY)
            except ValueError as exc: return self.send_json({'ok': False, 'error': str(exc)}, 400 if str(exc) == 'invalid_json' else 413)
            temp = STATE / ('.owner-policy-candidate-' + secrets.token_hex(8) + '.json')
            try:
                with state_exclusive_lock('DASHBOARD_MUTATION.lock'):
                    temp.write_text(json.dumps(candidate, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
                    r = subprocess.run(policy_tool + ['apply', '--policy-json', str(temp), '--owner-approved', '--approval-source', 'dashboard_local_control'], capture_output=True, text=True, shell=False)
                    if r.returncode: raise RuntimeError((r.stderr or r.stdout).strip())
                    op = 'apply' if candidate.get('schedule', {}).get('enabled') else 'remove'
                    sr = subprocess.run(scheduler_tool + [op, '--owner-approved'], capture_output=True, text=True, shell=False)
                    saved = run_json(policy_tool + ['get']); sched = scheduler_projection()
                    collect_dashboard_data(project)
                return self.send_json({'ok': True, 'policy': saved, 'scheduler': sched.get('data'), 'scheduler_apply_ok': sr.returncode in (0, 7), 'scheduler_message': (sr.stdout or sr.stderr).strip()})
            except Exception as exc:
                return self.send_json({'ok': False, 'error': 'policy_update_rejected', 'message': str(exc)}, 400)
            finally:
                try: temp.unlink()
                except Exception: pass

    srv = ThreadingHTTPServer(('127.0.0.1', a.port), H); port = srv.server_address[1]; srv.timeout = 1
    print(f'DASHBOARD_CONTROL_URL=http://127.0.0.1:{port}/', flush=True); print('DASHBOARD_CONTROL_BIND=127.0.0.1', flush=True)
    collect_dashboard_data(project)
    if not a.no_browser: webbrowser.open(f'http://127.0.0.1:{port}/#token={token}')
    try:
        while not stop.is_set() and time.monotonic() - last[0] < a.idle_minutes * 60:
            srv.handle_request()
    finally:
        srv.server_close(); print('DASHBOARD_CONTROL_STOPPED=1', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
