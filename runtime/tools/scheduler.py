#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path


SECRET_LIKE_EXTERNAL = re.compile(r'gh[op]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----')

def validate_external_id(value):
    value = str(value or '').strip()
    if not value or len(value) > 512:
        raise RuntimeError('A bounded external-id is required.')
    if '\r' in value or '\n' in value or SECRET_LIKE_EXTERNAL.search(value):
        raise RuntimeError('external-id contains disallowed control/secret-like content.')
    return value

def now():
    return datetime.now(timezone.utc).astimezone().isoformat()


def atomic_json_write(path: Path, value: dict):
    tmp = path.with_name(path.name + f'.tmp.{os.getpid()}.{__import__("time").time_ns()}')
    data = json.dumps(value, indent=2) + '\n'
    try:
        with tmp.open('w', encoding='utf-8', newline='\n') as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    finally:
        try:
            tmp.unlink(missing_ok=True)
        except OSError:
            pass


def schedule_signature(schedule: dict) -> str:
    material = {
        'enabled': bool(schedule.get('enabled')),
        'frequency': schedule.get('frequency'),
        'local_time': schedule.get('local_time'),
        'days_of_week': schedule.get('days_of_week', []),
        'timezone_mode': schedule.get('timezone_mode'),
        'executor_mode': schedule.get('executor_mode'),
    }
    raw = json.dumps(material, sort_keys=True, separators=(',', ':')).encode()
    return hashlib.sha256(raw).hexdigest()[:20]


def resolve_executor(command: str, project: Path):
    command = str(command or '').strip()
    if not command:
        return None
    found = shutil.which(command)
    if found:
        return str(Path(found).resolve())
    candidate = Path(command).expanduser()
    if not candidate.is_absolute():
        candidate = project / candidate
    return str(candidate.resolve()) if candidate.is_file() else None


def load_registration(path: Path):
    if not path.exists():
        return None
    try:
        value = json.loads(path.read_text(encoding='utf-8-sig'))
        return value if isinstance(value, dict) else None
    except Exception:
        return {'status': 'REGISTRATION_STATE_INVALID', 'message': 'Scheduler registration state is invalid JSON.'}


def read_validated_policy(policy_tool: list[str]):
    result = subprocess.run(policy_tool + ['get'], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError((result.stderr or result.stdout).strip() or 'OWNER_POLICY validation failed')
    return json.loads(result.stdout)


@contextmanager
def crontab_lock():
    import fcntl
    lock_path = Path.home() / '.comprehensive-qa-crontab.lock'
    handle = lock_path.open('a+')
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        yield
    finally:
        fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        handle.close()


def crontab_get():
    result = subprocess.run(['crontab', '-l'], capture_output=True, text=True)
    if result.returncode == 0:
        return result.stdout
    message = (result.stderr or result.stdout or '').strip().lower()
    if result.returncode == 1 and (not message or 'no crontab for' in message):
        return ''
    raise RuntimeError((result.stderr or result.stdout).strip() or f'crontab -l failed with {result.returncode}')


def remove_entry(text: str, marker: str):
    lines = text.splitlines()
    output = []
    skipping = False
    for line in lines:
        if line.strip() == f'# BEGIN {marker}':
            skipping = True
            continue
        if line.strip() == f'# END {marker}':
            skipping = False
            continue
        if not skipping:
            output.append(line)
    return '\n'.join(output).rstrip() + ('\n' if output else '')


def local_entry_exists(marker: str):
    if not shutil.which('crontab'):
        return False, 'crontab_unavailable'
    try:
        return f'# BEGIN {marker}' in crontab_get(), None
    except Exception as exc:
        return False, str(exc)


def remove_local_entry(marker: str):
    if not shutil.which('crontab'):
        return False
    with crontab_lock():
        current = crontab_get()
        if f'# BEGIN {marker}' not in current:
            return False
        updated = remove_entry(current, marker)
        subprocess.run(['crontab', '-'], input=updated, text=True, check=True)
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['status', 'apply', 'remove', 'mark-agent-managed', 'confirm-agent-managed-disabled'])
    parser.add_argument('--owner-approved', action='store_true')
    parser.add_argument('--external-id', default='')
    args = parser.parse_args()

    install = Path(__file__).resolve().parent.parent
    project = install.parent
    state = install / 'state'
    state.mkdir(exist_ok=True)
    registration_path = state / 'SCHEDULER_REGISTRATION.json'
    marker = 'COMPREHENSIVE-QA-' + hashlib.sha256(str(project).encode()).hexdigest()[:12]
    policy_tool = [sys.executable, str(install / 'tools' / 'policy-manager.py')]

    def save(status, message, **extra):
        platform = extra.pop('platform', 'unix-cron')
        record = {
            'updated_at': now(),
            'status': status,
            'message': message,
            'task_name': marker,
            'platform': platform,
        }
        record.update(extra)
        atomic_json_write(registration_path, record)
        return record

    if args.operation == 'status':
        registration = load_registration(registration_path)
        effective = dict(registration or {})
        exists = False
        cron_error = None
        try:
            policy = read_validated_policy(policy_tool)
            schedule = policy.get('schedule', {})
            signature = schedule_signature(schedule)
            external_id = str((registration or {}).get('external_id', '')).strip()
            local_probe_required = schedule.get('executor_mode') == 'LOCAL_COMMAND' or ((registration or {}).get('status') == 'ACTIVE' and (registration or {}).get('platform') == 'unix-cron')
            if local_probe_required:
                exists, cron_error = local_entry_exists(marker)
            if external_id:
                if not schedule.get('enabled') or schedule.get('executor_mode') != 'AGENT_MANAGED':
                    effective.update(status='NEEDS_PLATFORM_DEACTIVATION', message='External AI/platform schedule must be disabled.', external_id=external_id)
                elif (registration or {}).get('status') == 'AGENT_MANAGED_ACTIVE' and (registration or {}).get('schedule_signature') != signature:
                    effective.update(status='NEEDS_PLATFORM_UPDATE', message='External AI/platform schedule no longer matches owner policy.', external_id=external_id, schedule_signature=signature)
            if exists and (not schedule.get('enabled') or schedule.get('executor_mode') != 'LOCAL_COMMAND'):
                effective.update(status='STALE_LOCAL_REGISTRATION', message='A local cron entry exists but current owner policy does not authorize LOCAL_COMMAND scheduling.')
            elif schedule.get('enabled') and schedule.get('executor_mode') == 'LOCAL_COMMAND' and not exists and not cron_error and (registration or {}).get('status') == 'ACTIVE':
                effective.update(status='MISSING_LOCAL_REGISTRATION', message='Owner policy expects local scheduling but the cron entry is missing.')
        except Exception as exc:
            effective.update(status='POLICY_INVALID', message=str(exc))
        if cron_error:
            effective.update(status='SCHEDULER_STATUS_ERROR', message=cron_error)
        print(json.dumps({'task_name': marker, 'registered': exists, 'registration': effective or None}, indent=2))
        return 0

    if not args.owner_approved:
        raise RuntimeError('Scheduler mutation requires explicit human owner approval.')

    previous = load_registration(registration_path) or {}
    previous_external = str(previous.get('external_id', '')).strip()

    if args.operation == 'confirm-agent-managed-disabled':
        if not previous_external:
            save('DISABLED', 'No external AI/platform schedule is recorded as active.')
            print('SCHEDULER_AGENT_MANAGED=DISABLED')
            return 0
        external_id = validate_external_id(args.external_id)
        if external_id != previous_external:
            raise RuntimeError('external-id does not match the recorded external schedule.')
        save('DISABLED', 'External AI/platform schedule deactivation confirmed by the agent.', platform='agent-managed', deactivated_external_id=previous_external)
        print('SCHEDULER_AGENT_MANAGED=DISABLED')
        return 0

    if args.operation == 'remove':
        try:
            remove_local_entry(marker)
        except Exception as exc:
            save('BLOCKED', 'Could not remove local cron schedule.', error=str(exc))
            raise
        if previous_external:
            save('NEEDS_PLATFORM_DEACTIVATION', 'Local schedule is disabled; external AI/platform schedule still requires deactivation.', platform='agent-managed', external_id=previous_external)
            print('SCHEDULER_NEEDS_PLATFORM_DEACTIVATION=1')
            return 0
        save('DISABLED', 'Local OS schedule removed by owner.')
        print('SCHEDULER_REMOVED=' + marker)
        return 0

    policy = read_validated_policy(policy_tool)
    if not policy.get('configured') or not policy.get('approval', {}).get('approved_by_human'):
        raise RuntimeError('OWNER_POLICY is not human-approved/configured.')
    schedule = policy['schedule']
    signature = schedule_signature(schedule)

    if args.operation == 'mark-agent-managed':
        if not schedule.get('enabled') or schedule.get('executor_mode') != 'AGENT_MANAGED':
            raise RuntimeError('Policy is not enabled for AGENT_MANAGED scheduling.')
        external_id = validate_external_id(args.external_id)
        remove_local_entry(marker)
        save('AGENT_MANAGED_ACTIVE', 'External AI/platform scheduler marked active.', platform='agent-managed', external_id=external_id, frequency=schedule.get('frequency'), local_time=schedule.get('local_time'), days_of_week=schedule.get('days_of_week', []), schedule_signature=signature, policy_revision=policy.get('policy_revision'))
        print('SCHEDULER_AGENT_MANAGED=ACTIVE')
        return 0

    if not schedule.get('enabled'):
        raise RuntimeError('Schedule is disabled in OWNER_POLICY.')

    mode = schedule.get('executor_mode')
    if previous_external and mode != 'AGENT_MANAGED':
        remove_local_entry(marker)
        save('NEEDS_PLATFORM_DEACTIVATION', 'External AI/platform schedule must be disabled before another scheduler mode can become active.', platform='agent-managed', external_id=previous_external, pending_executor_mode=mode)
        print('SCHEDULER_NEEDS_PLATFORM_DEACTIVATION=1')
        return 0

    if mode == 'UNCONFIGURED':
        remove_local_entry(marker)
        save('NEEDS_EXECUTOR', 'Schedule intent exists but no executor is configured.')
        print('SCHEDULER_NEEDS_EXECUTOR=1')
        return 7

    if mode == 'AGENT_MANAGED':
        remove_local_entry(marker)
        if previous_external:
            if previous.get('status') == 'AGENT_MANAGED_ACTIVE' and previous.get('schedule_signature') == signature:
                save('AGENT_MANAGED_ACTIVE', 'External AI/platform scheduler remains aligned with owner policy.', platform='agent-managed', external_id=previous_external, frequency=schedule.get('frequency'), local_time=schedule.get('local_time'), days_of_week=schedule.get('days_of_week', []), schedule_signature=signature, policy_revision=policy.get('policy_revision'))
                print('SCHEDULER_AGENT_MANAGED=ACTIVE')
            else:
                save('NEEDS_PLATFORM_UPDATE', 'External AI/platform scheduler must be updated to match the owner policy.', platform='agent-managed', external_id=previous_external, frequency=schedule.get('frequency'), local_time=schedule.get('local_time'), days_of_week=schedule.get('days_of_week', []), schedule_signature=signature, policy_revision=policy.get('policy_revision'))
                print('SCHEDULER_NEEDS_PLATFORM_UPDATE=1')
        else:
            save('NEEDS_PLATFORM_ACTIVATION', 'Schedule must be activated by the AI platform scheduler.', platform='agent-managed', frequency=schedule.get('frequency'), local_time=schedule.get('local_time'), days_of_week=schedule.get('days_of_week', []), schedule_signature=signature, policy_revision=policy.get('policy_revision'))
            print('SCHEDULER_NEEDS_PLATFORM_ACTIVATION=1')
        return 0

    if mode != 'LOCAL_COMMAND':
        raise RuntimeError('Unsupported executor mode.')

    resolved_executor = resolve_executor(schedule.get('executor', {}).get('command', ''), project)
    if not resolved_executor:
        remove_local_entry(marker)
        save('NEEDS_EXECUTOR', 'Configured local executor cannot be resolved.')
        print('SCHEDULER_NEEDS_EXECUTOR=1')
        return 7
    if not shutil.which('crontab'):
        save('BLOCKED', 'crontab is unavailable on this system.')
        print('SCHEDULER_CRONTAB_UNAVAILABLE=1')
        return 7

    hour, minute = map(int, schedule['local_time'].split(':'))
    frequency = schedule['frequency']
    day_of_week = '*'
    if frequency == 'WEEKDAYS':
        day_of_week = '1-5'
    elif frequency == 'WEEKLY':
        mapping = {'Sunday': '0', 'Monday': '1', 'Tuesday': '2', 'Wednesday': '3', 'Thursday': '4', 'Friday': '5', 'Saturday': '6'}
        day_of_week = ','.join(mapping[day] for day in schedule['days_of_week'])

    runner = install / 'tools' / 'scheduled-run.py'
    cron_command = f'{shlex.quote(sys.executable)} {shlex.quote(str(runner))}'
    cron_line = f'{minute} {hour} * * {day_of_week} {cron_command}'
    with crontab_lock():
        current = crontab_get()
        updated = remove_entry(current, marker) + f'# BEGIN {marker}\n{cron_line}\n# END {marker}\n'
        subprocess.run(['crontab', '-'], input=updated, text=True, check=True)

    save('ACTIVE', 'Local cron scheduled QA registered.', frequency=frequency, local_time=schedule.get('local_time'), days_of_week=schedule.get('days_of_week', []), executor_mode='LOCAL_COMMAND', resolved_executor=resolved_executor, schedule_signature=signature, policy_revision=policy.get('policy_revision'))
    print(f'SCHEDULER_ACTIVE={marker} TIME={schedule.get("local_time")} FREQUENCY={frequency}')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:
        print('SCHEDULER_ERROR=' + str(exc), file=sys.stderr)
        raise SystemExit(1)
