#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import sys
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

SECRET = re.compile(r'gh[op]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----')
APPROVAL_SOURCES = {'dashboard_local_control', 'agent_owner_conversation', 'installer_optional_setup', 'manual_cli'}
VALID_FREQUENCIES = {'DAILY', 'WEEKDAYS', 'WEEKLY'}
VALID_EXECUTOR_MODES = {'UNCONFIGURED', 'LOCAL_COMMAND', 'AGENT_MANAGED'}
VALID_WEEKDAYS = {'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'}


def now() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat()


def require_dict(value, name: str, errors: list[str]):
    if not isinstance(value, dict):
        errors.append(f'{name} must be an object')
        return {}
    return value


def require_string_list(value, name: str, errors: list[str], max_items: int = 64):
    if not isinstance(value, list):
        errors.append(f'{name} must be an array')
        return []
    if len(value) > max_items:
        errors.append(f'{name} exceeds {max_items} entries')
    if any(not isinstance(item, str) for item in value):
        errors.append(f'{name} entries must be strings')
    return value


def bounded_int(value, name: str, minimum: int, maximum: int, errors: list[str]):
    if isinstance(value, bool) or not isinstance(value, int):
        errors.append(f'{name} must be an integer')
        return
    if not minimum <= value <= maximum:
        errors.append(f'{name} must be between {minimum} and {maximum}')



def reject_unknown_keys(obj: dict, allowed: set[str], name: str, errors: list[str]):
    unknown = sorted(set(obj) - allowed)
    if unknown:
        errors.append(f"{name} contains unknown fields: {', '.join(unknown)}")


def latest_history_entry(history: Path):
    if not history.exists():
        return None
    lines=[line for line in history.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    if not lines:
        return None
    return json.loads(lines[-1])


def verify_current_integrity(policy_path: Path, history_path: Path, policy: dict):
    configured=policy.get('configured')
    revision=policy.get('policy_revision')
    approval=policy.get('approval',{})
    if configured is False:
        if revision != 0 or approval.get('approved_by_human') is not False:
            raise ValueError('unconfigured OWNER_POLICY has inconsistent revision/approval state')
        return
    if configured is not True:
        raise ValueError('configured must be boolean')
    if approval.get('approved_by_human') is not True:
        raise ValueError('configured OWNER_POLICY lacks human approval')
    entry=latest_history_entry(history_path)
    if not isinstance(entry,dict):
        raise ValueError('configured OWNER_POLICY is missing authorization history')
    if entry.get('revision') != revision:
        raise ValueError('OWNER_POLICY revision does not match latest audit entry')
    actual=hashlib.sha256(policy_path.read_bytes()).hexdigest()
    if str(entry.get('new_hash','')).lower() != actual.lower():
        raise ValueError('OWNER_POLICY hash does not match latest audit entry')


def validate_permission_policy(perm: dict):
    errors = []
    if not isinstance(perm, dict):
        raise ValueError('permission policy must be an object')
    reject_unknown_keys(perm, {'schema_version','model','change_risks','presets','auto_change_categories','hard_boundaries','rules'}, 'permission policy', errors)
    for key in ('presets', 'auto_change_categories', 'hard_boundaries'):
        if key not in perm:
            errors.append(f'permission policy missing {key}')
    presets=perm.get('presets')
    if not isinstance(presets, dict):
        errors.append('permission policy presets must be an object')
        presets={}
    required={'REPORT_ONLY','SAFE_FIXES','ACTIVE_REMEDIATION','CUSTOM'}
    if set(presets) != required:
        errors.append('permission policy presets must exactly define REPORT_ONLY, SAFE_FIXES, ACTIVE_REMEDIATION, CUSTOM')
    auto=require_string_list(perm.get('auto_change_categories'), 'permission policy auto_change_categories', errors, 128)
    hard=require_string_list(perm.get('hard_boundaries'), 'permission policy hard_boundaries', errors, 128)
    if len(set(auto)) != len(auto): errors.append('permission policy auto_change_categories contains duplicates')
    if len(set(hard)) != len(hard): errors.append('permission policy hard_boundaries contains duplicates')
    if set(auto) & set(hard): errors.append('permission policy auto-change categories overlap hard boundaries')
    expected={'REPORT_ONLY':set(),'SAFE_FIXES':{'LOW'},'ACTIVE_REMEDIATION':{'LOW','MEDIUM'},'CUSTOM':set()}
    for name,want in expected.items():
        value=presets.get(name,{}) if isinstance(presets,dict) else {}
        risks=value.get('auto_change_risks',[]) if isinstance(value,dict) else []
        if set(risks)!=want: errors.append(f'permission policy {name} auto_change_risks violates canonical ceiling')
    rules=perm.get('rules',{})
    for key in ('agent_may_never_self_elevate','owner_approval_required_for_policy_mutation','hard_boundaries_override_all_presets','unknown_change_risk_requires_approval','ambiguous_expected_behavior_requires_approval','all_automatic_changes_must_be_reversible','automatic_change_requires_finding_evidence_and_authorization_id'):
        if rules.get(key) is not True: errors.append(f'permission policy safety rule must be true: {key}')
    if errors:
        raise ValueError('; '.join(errors))


def validate(policy: dict, perm: dict):
    errors: list[str] = []
    if not isinstance(policy, dict):
        raise ValueError('OWNER_POLICY must be an object')
    if policy.get('schema_version') != 1:
        errors.append('schema_version must equal 1')
    reject_unknown_keys(policy, {'schema_version','configured','configured_at','configured_via','permissions','schedule','approval','policy_revision'}, 'OWNER_POLICY', errors)
    if not isinstance(policy.get('configured'), bool): errors.append('configured must be boolean')
    if isinstance(policy.get('policy_revision'), bool) or not isinstance(policy.get('policy_revision'), int) or policy.get('policy_revision',-1) < 0: errors.append('policy_revision must be a non-negative integer')
    if policy.get('configured_at') is not None and not isinstance(policy.get('configured_at'), str): errors.append('configured_at must be null or string')
    if policy.get('configured_via') not in APPROVAL_SOURCES | {'UNCONFIGURED'}: errors.append('configured_via is invalid')

    permissions = require_dict(policy.get('permissions'), 'permissions', errors)
    reject_unknown_keys(permissions, {'preset','custom_auto_change_risks','custom_categories','notes'}, 'permissions', errors)
    if not isinstance(permissions.get('notes',''), str) or len(str(permissions.get('notes',''))) > 2000: errors.append('permissions.notes must be a string <= 2000 characters')
    preset = permissions.get('preset')
    presets = set(perm.get('presets', {}))
    if preset not in presets:
        errors.append('invalid permissions preset')

    custom_risks = require_string_list(permissions.get('custom_auto_change_risks', []), 'permissions.custom_auto_change_risks', errors, 2)
    for risk in custom_risks:
        if risk not in {'LOW', 'MEDIUM'}:
            errors.append(f'custom auto-change risk not allowed: {risk}')
    if len(set(custom_risks)) != len(custom_risks):
        errors.append('permissions.custom_auto_change_risks contains duplicates')

    allowed_categories = set(perm.get('auto_change_categories', []))
    hard_boundaries = set(perm.get('hard_boundaries', []))
    custom_categories = require_string_list(permissions.get('custom_categories', []), 'permissions.custom_categories', errors, len(allowed_categories) or 64)
    for category in custom_categories:
        if category not in allowed_categories:
            errors.append(f'custom category not allowed: {category}')
        if category in hard_boundaries:
            errors.append(f'hard boundary cannot be auto-authorized: {category}')
    if len(set(custom_categories)) != len(custom_categories):
        errors.append('permissions.custom_categories contains duplicates')

    schedule = require_dict(policy.get('schedule'), 'schedule', errors)
    reject_unknown_keys(schedule, {'enabled','frequency','local_time','days_of_week','executor_mode','executor','timezone_mode'}, 'schedule', errors)
    if not isinstance(schedule.get('enabled'), bool):
        errors.append('schedule.enabled must be boolean')
    if schedule.get('frequency') not in VALID_FREQUENCIES:
        errors.append('unsupported schedule frequency')
    if not re.fullmatch(r'(?:[01]\d|2[0-3]):[0-5]\d', str(schedule.get('local_time', ''))):
        errors.append('schedule.local_time must be HH:mm')
    if schedule.get('timezone_mode') != 'LOCAL':
        errors.append('schedule.timezone_mode must equal LOCAL')

    days = require_string_list(schedule.get('days_of_week', []), 'schedule.days_of_week', errors, 7)
    if any(day not in VALID_WEEKDAYS for day in days):
        errors.append('schedule.days_of_week contains an invalid weekday')
    if len(set(days)) != len(days):
        errors.append('schedule.days_of_week contains duplicates')
    if schedule.get('frequency') == 'WEEKLY' and not days:
        errors.append('WEEKLY schedule requires at least one day_of_week')
    if schedule.get('frequency') != 'WEEKLY' and days:
        errors.append('days_of_week must be empty unless frequency is WEEKLY')

    executor_mode = schedule.get('executor_mode')
    if executor_mode not in VALID_EXECUTOR_MODES:
        errors.append('invalid executor_mode')
    executor = require_dict(schedule.get('executor'), 'schedule.executor', errors)
    reject_unknown_keys(executor, {'command','arguments','timeout_minutes','log_retention_days'}, 'schedule.executor', errors)
    command = executor.get('command', '')
    if not isinstance(command, str):
        errors.append('executor.command must be a string')
        command = ''
    if executor_mode == 'LOCAL_COMMAND' and not command.strip():
        errors.append('LOCAL_COMMAND requires executor.command')
    if len(command) > 4096:
        errors.append('executor.command exceeds 4096 characters')

    arguments = require_string_list(executor.get('arguments', []), 'executor.arguments', errors, 64)
    if any(len(arg) > 4096 for arg in arguments if isinstance(arg, str)):
        errors.append('executor argument exceeds 4096 characters')

    bounded_int(executor.get('timeout_minutes', 240), 'executor.timeout_minutes', 1, 1440, errors)
    bounded_int(executor.get('log_retention_days', 30), 'executor.log_retention_days', 1, 365, errors)

    approval=require_dict(policy.get('approval'), 'approval', errors)
    reject_unknown_keys(approval, {'approved_by_human','approved_at','source'}, 'approval', errors)
    if not isinstance(approval.get('approved_by_human'), bool): errors.append('approval.approved_by_human must be boolean')
    if approval.get('approved_at') is not None and not isinstance(approval.get('approved_at'), str): errors.append('approval.approved_at must be null or string')
    if approval.get('source') not in APPROVAL_SOURCES | {'UNCONFIGURED'}: errors.append('approval.source is invalid')
    if policy.get('configured') is False:
        if policy.get('policy_revision') != 0 or approval.get('approved_by_human') is not False or policy.get('configured_via') != 'UNCONFIGURED': errors.append('unconfigured policy must remain revision 0 with no human approval')
    elif policy.get('configured') is True:
        if policy.get('policy_revision',0) < 1 or approval.get('approved_by_human') is not True: errors.append('configured policy requires revision >=1 and human approval')
        if policy.get('configured_via') != approval.get('source'): errors.append('configured_via must match approval.source')

    serialized = json.dumps(policy, ensure_ascii=False, separators=(',', ':'))
    if SECRET.search(serialized):
        errors.append('OWNER_POLICY must not contain credentials/tokens/private keys')
    if len(serialized.encode('utf-8')) > 65536:
        errors.append('OWNER_POLICY exceeds 65536 bytes')

    if errors:
        raise ValueError('; '.join(errors))


@contextmanager
def policy_lock(state: Path):
    path = state / 'OWNER_POLICY.lock'
    handle = path.open('a+b')
    try:
        if os.name == 'nt':
            import msvcrt
            handle.seek(0, os.SEEK_END)
            if handle.tell() == 0:
                handle.write(b'0')
                handle.flush()
            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_LOCK, 1)
        else:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        yield
    finally:
        try:
            handle.seek(0)
            if os.name == 'nt':
                import msvcrt
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        finally:
            handle.close()


def next_revision(old_raw: bytes, history: Path):
    try:
        old = json.loads(old_raw.decode('utf-8-sig'))
        return int(old.get('policy_revision', 0)) + 1, False
    except Exception:
        revision = 1
        if history.exists():
            for line in reversed(history.read_text(encoding='utf-8-sig').splitlines()):
                try:
                    revision = max(revision, int(json.loads(line).get('revision', 0)) + 1)
                    break
                except Exception:
                    continue
        return revision, True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['get', 'apply'])
    parser.add_argument('--policy-json')
    parser.add_argument('--owner-approved', action='store_true')
    parser.add_argument('--approval-source', choices=sorted(APPROVAL_SOURCES))
    args = parser.parse_args()

    install = Path(__file__).resolve().parent.parent
    state = install / 'state'
    state.mkdir(exist_ok=True)
    policy_path = state / 'OWNER_POLICY.json'
    template_path = install / 'templates' / 'OWNER_POLICY.json'
    permission_path = install / 'config' / 'permission-policy.json'
    if not permission_path.exists():
        permission_path = install / 'templates' / 'PERMISSION_POLICY.json'
    perm = json.loads(permission_path.read_text(encoding='utf-8-sig'))
    validate_permission_policy(perm)

    if not policy_path.exists():
        policy_path.write_bytes(template_path.read_bytes())

    if args.operation == 'get':
        raw = policy_path.read_text(encoding='utf-8-sig')
        current = json.loads(raw)
        validate(current, perm)
        verify_current_integrity(policy_path, state / 'OWNER_POLICY_HISTORY.jsonl', current)
        print(json.dumps(current, indent=2, ensure_ascii=False))
        return 0

    if not args.owner_approved:
        raise ValueError('Policy mutation requires explicit human owner approval.')
    if not args.approval_source:
        raise ValueError('approval-source required')
    if not args.policy_json:
        raise ValueError('policy-json required')

    candidate_path = Path(args.policy_json)
    candidate = json.loads(candidate_path.read_text(encoding='utf-8-sig'))
    validate(candidate, perm)

    history_path = state / 'OWNER_POLICY_HISTORY.jsonl'
    with policy_lock(state):
        old_bytes = policy_path.read_bytes()
        recovery_reason = None
        try:
            old_policy=json.loads(old_bytes.decode('utf-8-sig'));validate(old_policy,perm);verify_current_integrity(policy_path,history_path,old_policy)
        except Exception as exc:
            recovery_reason=str(exc)
        revision, recovery = next_revision(old_bytes, history_path)
        last=latest_history_entry(history_path)
        if isinstance(last,dict) and isinstance(last.get('revision'),int): revision=max(revision,last['revision']+1)
        recovery = bool(recovery or recovery_reason)
        candidate['configured'] = True
        candidate['configured_at'] = now()
        candidate['configured_via'] = args.approval_source
        candidate['policy_revision'] = revision
        candidate['approval'] = {
            'approved_by_human': True,
            'approved_at': now(),
            'source': args.approval_source,
        }
        validate(candidate, perm)
        new_bytes = (json.dumps(candidate, indent=2, ensure_ascii=False) + '\n').encode('utf-8')
        temp_path = policy_path.with_name(f'.OWNER_POLICY.{uuid.uuid4().hex}.tmp')
        try:
            temp_path.write_bytes(new_bytes)
            os.replace(temp_path, policy_path)
        finally:
            try:
                temp_path.unlink()
            except FileNotFoundError:
                pass

        history = {
            'changed_at': now(),
            'revision': revision,
            'source': args.approval_source,
            'owner_approved': True,
            'old_hash': hashlib.sha256(old_bytes).hexdigest(),
            'new_hash': hashlib.sha256(new_bytes).hexdigest(),
            'preset': candidate['permissions']['preset'],
            'schedule_enabled': bool(candidate['schedule']['enabled']),
            'executor_mode': candidate['schedule']['executor_mode'],
            'recovery_from_invalid_policy': recovery,
            'recovery_reason': recovery_reason,
        }
        with history_path.open('a', encoding='utf-8') as handle:
            handle.write(json.dumps(history, separators=(',', ':')) + '\n')

    print(f"OWNER_POLICY_APPLIED=1 REVISION={revision} PRESET={candidate['permissions']['preset']} SCHEDULE={candidate['schedule']['enabled']}")
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print('OWNER_POLICY_ERROR=' + str(exc), file=sys.stderr)
        raise SystemExit(1)
