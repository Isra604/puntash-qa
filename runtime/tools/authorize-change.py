#!/usr/bin/env python3
import argparse
import json
import os
import stat
import subprocess
import sys
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath


def now():
    return datetime.now(timezone.utc).astimezone().isoformat()


@contextmanager
def audit_lock(state: Path):
    path = state / 'CHANGE_AUTHORIZATION.lock'
    handle = path.open('a+b')
    try:
        if os.name == 'nt':
            import msvcrt
            handle.seek(0, os.SEEK_END)
            if handle.tell() == 0:
                handle.write(b'0'); handle.flush()
            handle.seek(0); msvcrt.locking(handle.fileno(), msvcrt.LK_LOCK, 1)
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


def has_reparse_or_symlink(path: Path) -> bool:
    try:
        if path.is_symlink():
            return True
        st = path.lstat()
        attrs = getattr(st, 'st_file_attributes', 0)
        reparse_flag = getattr(stat, 'FILE_ATTRIBUTE_REPARSE_POINT', 0x400)
        if attrs & reparse_flag:
            return True
        isjunction = getattr(os.path, 'isjunction', None)
        if isjunction and isjunction(path):
            return True
    except FileNotFoundError:
        return False
    except OSError:
        return True
    return False


def normalize_target(raw: str, project: Path, perm: dict) -> tuple[str|None, str|None]:
    value = str(raw or '').replace('\\','/')
    if value != value.strip(): return None, 'target_path_whitespace_ambiguous'
    if not value or len(value) > 2048 or any(ord(ch) < 32 for ch in value):
        return None, 'target_path_invalid'
    if value.startswith('/') or (len(value) >= 2 and value[1] == ':' and value[0].isalpha()):
        return None, 'target_path_absolute_forbidden'
    raw_parts=value.split('/')
    if any(part=='' for part in raw_parts): return None, 'target_path_empty_segment_forbidden'
    pp = PurePosixPath(value)
    if '..' in pp.parts or '.' in pp.parts or not pp.parts:
        return None, 'target_path_traversal_forbidden'
    normalized = '/'.join(pp.parts)
    reserved={'con','prn','aux','nul',*[f'com{i}' for i in range(1,10)],*[f'lpt{i}' for i in range(1,10)]}
    for part in pp.parts:
        low=part.lower()
        stem=low.split('.',1)[0]
        if part.endswith((' ','.')) or ':' in part or stem in reserved:
            return None, 'target_path_platform_alias_forbidden'
    parts_lower = [x.lower() for x in pp.parts]
    prefixes = {str(x).lower() for x in perm.get('protected_path_prefixes', [])}
    basenames = {str(x).lower() for x in perm.get('protected_path_basenames', [])}
    suffixes = tuple(str(x).lower() for x in perm.get('protected_path_suffixes', []))
    name_prefixes = tuple(str(x).lower() for x in perm.get('protected_path_name_prefixes', []))
    if parts_lower and parts_lower[0] in prefixes:
        return None, 'target_path_protected_prefix'
    base = parts_lower[-1]
    if base in basenames or (name_prefixes and any(base.startswith(x) for x in name_prefixes)) or (suffixes and base.endswith(suffixes)):
        return None, 'target_path_protected_name'
    # Existing symlink/junction/reparse ancestors are never auto-remediation targets.
    cur = project
    if has_reparse_or_symlink(cur):
        return None, 'project_root_reparse_requires_owner_approval'
    for part in pp.parts:
        cur = cur / part
        if cur.exists() or cur.is_symlink():
            if has_reparse_or_symlink(cur):
                return None, 'target_path_reparse_or_symlink_forbidden'
    target=project/Path(*pp.parts)
    if target.exists():
        if target.is_dir(): return None, 'target_path_directory_forbidden'
        try:
            if target.stat().st_nlink > 1: return None, 'target_path_hardlink_forbidden'
        except OSError:
            return None, 'target_path_link_state_unverifiable'
    try:
        project_abs = project.resolve()
        candidate_abs = (project / Path(*pp.parts)).resolve(strict=False)
        candidate_abs.relative_to(project_abs)
    except Exception:
        return None, 'target_path_escape_forbidden'
    return normalized, None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--risk', required=True, choices=['LOW', 'MEDIUM', 'HIGH', 'PROTECTED'])
    parser.add_argument('--category', required=True)
    parser.add_argument('--finding-id', required=True)
    parser.add_argument('--change-summary', required=True)
    parser.add_argument('--evidence-ref', action='append', default=[])
    parser.add_argument('--target-path', action='append', default=[])
    parser.add_argument('--expected-behavior-proven', action='store_true')
    parser.add_argument('--reversible', action='store_true')
    args = parser.parse_args()

    install = Path(__file__).resolve().parent.parent
    project = install.parent
    state = install / 'state'; state.mkdir(exist_ok=True)
    perm_path = install / 'config' / 'permission-policy.json'
    if not perm_path.exists(): perm_path = install / 'templates' / 'PERMISSION_POLICY.json'
    policy_tool = [sys.executable, str(install / 'tools' / 'policy-manager.py'), 'get']
    authorization_id = uuid.uuid4().hex
    decision = 'DENY'; reason = 'internal_error'; preset = 'UNKNOWN'; revision = None; target_paths=[]

    def finish(code: int):
        record = {
            'authorization_id': authorization_id,
            'decided_at': now(),
            'decision': decision,
            'reason': reason,
            'policy_revision': revision,
            'preset': preset,
            'risk': args.risk,
            'category': args.category,
            'finding_id': args.finding_id,
            'change_summary': args.change_summary,
            'evidence_refs': args.evidence_ref,
            'target_paths': target_paths,
            'expected_behavior_proven': bool(args.expected_behavior_proven),
            'reversible': bool(args.reversible),
        }
        with audit_lock(state):
            with (state / 'CHANGE_AUTHORIZATION_HISTORY.jsonl').open('a', encoding='utf-8') as handle:
                handle.write(json.dumps(record, separators=(',', ':')) + '\n')
        print(f'CHANGE_AUTHORIZATION={decision} REASON={reason} AUTHORIZATION_ID={authorization_id} PRESET={preset} RISK={args.risk} CATEGORY={args.category}')
        return code

    if not args.finding_id.strip() or len(args.finding_id) > 128:
        reason = 'finding_id_invalid'; return finish(10)
    if not args.change_summary.strip() or len(args.change_summary) > 1000:
        reason = 'change_summary_invalid'; return finish(10)
    if not args.evidence_ref or len(args.evidence_ref) > 16 or any(not ref.strip() or len(ref) > 2048 for ref in args.evidence_ref):
        reason = 'evidence_refs_required_or_invalid'; return finish(10)
    if not args.target_path or len(args.target_path) > 32:
        reason = 'target_paths_required_or_invalid'; return finish(10)

    try:
        policy_result = subprocess.run(policy_tool, capture_output=True, text=True)
        if policy_result.returncode:
            reason = 'owner_policy_invalid'; return finish(10)
        policy = json.loads(policy_result.stdout)
        perm = json.loads(perm_path.read_text(encoding='utf-8-sig'))
    except Exception:
        reason = 'owner_policy_or_permission_policy_invalid'; return finish(10)

    revision = policy.get('policy_revision')
    preset = policy.get('permissions', {}).get('preset', 'REPORT_ONLY')
    normalized=[]
    for raw in args.target_path:
        norm, issue = normalize_target(raw, project, perm)
        if issue:
            target_paths = normalized
            reason = issue; return finish(10)
        normalized.append(norm)
    if len(set(normalized)) != len(normalized):
        target_paths = normalized; reason='target_paths_duplicate'; return finish(10)
    target_paths = normalized

    if not policy.get('configured') or policy.get('approval', {}).get('approved_by_human') is not True:
        reason = 'owner_policy_unconfigured'; return finish(10)
    if args.category in set(perm.get('hard_boundaries', [])) or args.risk in {'HIGH', 'PROTECTED'}:
        reason = 'high_or_protected_requires_owner_approval'; return finish(10)
    if args.category not in set(perm.get('auto_change_categories', [])):
        reason = 'category_not_auto_changeable'; return finish(10)
    if not args.expected_behavior_proven:
        reason = 'expected_behavior_not_proven'; return finish(10)
    if not args.reversible:
        reason = 'automatic_change_must_be_reversible'; return finish(10)

    if preset == 'CUSTOM':
        risks = set(policy['permissions'].get('custom_auto_change_risks', []))
        categories = set(policy['permissions'].get('custom_categories', []))
    else:
        risks = set(perm.get('presets', {}).get(preset, {}).get('auto_change_risks', []))
        categories = set(perm.get('auto_change_categories', []))
    if args.risk not in risks or args.category not in categories:
        reason = 'preset_ceiling'; return finish(10)

    decision = 'ALLOW'; reason = 'within_owner_policy_ceiling'
    return finish(0)


if __name__ == '__main__':
    raise SystemExit(main())
