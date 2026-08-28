#!/usr/bin/env python3
import json, os, shutil, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def ok(cond,name):
    if not cond: raise AssertionError('V21_TARGET_SCOPE_FAIL='+name)
    print('V21_TARGET_SCOPE_PASS='+name)

def run(cmd, expect=None):
    r=subprocess.run(cmd,capture_output=True,text=True)
    if expect is not None and r.returncode!=expect:
        raise AssertionError(f'command rc={r.returncode} expected={expect}\nOUT={r.stdout}\nERR={r.stderr}')
    return r

def main():
  with tempfile.TemporaryDirectory(prefix='qa-v21-target-scope-') as td:
    project=Path(td)/'project';install=project/'.comprehensive-qa';project.mkdir();shutil.copytree(ROOT/'runtime',install)
    state=install/'state';state.mkdir(exist_ok=True)
    pm=[sys.executable,str(install/'tools/policy-manager.py')]
    auth=[sys.executable,str(install/'tools/authorize-change.py')]
    cand=Path(td)/'policy.json';base=json.loads(run(pm+['get'],0).stdout);base['permissions']['preset']='SAFE_FIXES';cand.write_text(json.dumps(base),encoding='utf-8')
    run(pm+['apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'],0)
    def call(targets, category='documentation'):
        cmd=auth+['--risk','LOW','--category',category,'--finding-id','F-TARGET','--change-summary','target-scope red team','--evidence-ref','evidence/target.txt']
        for t in targets: cmd += ['--target-path',t]
        cmd += ['--expected-behavior-proven','--reversible']
        return run(cmd)
    good=call(['docs/allowed.md']);ok(good.returncode==0,'safe_project_relative_target_allowed')
    hist=[json.loads(x) for x in (state/'CHANGE_AUTHORIZATION_HISTORY.jsonl').read_text(encoding='utf-8-sig').splitlines() if x.strip()];ok(hist[-1].get('target_paths')==['docs/allowed.md'],'authorization_history_records_exact_target_scope')
    cases={
      'missing_target':[],
      'traversal':['src/../.env'],
      'absolute_windows':['C:/temp/file.txt'],
      'absolute_unix':['/tmp/file.txt'],
      'qa_authority':['.comprehensive-qa/state/OWNER_POLICY.json'],
      'git_metadata':['.git/config'],
      'github_workflow':['.github/workflows/qa.yml'],
      'env_file':['.env.production'],
      'secrets_prefix':['secrets/private.key'],
      'credentials_prefix':['credentials/token.txt'],
      'credential_basename':['config/credentials.json'],
      'private_key_suffix':['config/private.pem'],
      'duplicate_targets':['docs/a.md','docs/a.md'],
      'leading_space':[' docs/a.md'],
      'trailing_space':['docs/a.md '],
      'empty_segment':['docs//a.md'],
      'trailing_slash':['docs/a.md/'],
      'trailing_dot':['docs/a.'],
      'ntfs_ads':['docs/a.txt:stream'],
      'windows_device':['docs/CON.txt'],
    }
    for name,targets in cases.items():ok(call(targets).returncode!=0,name+'_rejected')
    # Existing symlink/junction/reparse ancestors must fail closed where supported.
    outside=Path(td)/'outside';outside.mkdir();src=project/'src';src.mkdir()
    link=src/'external'
    try:
        link.symlink_to(outside,target_is_directory=True)
        ok(call(['src/external/file.py'],category='source_code').returncode!=0,'symlink_target_rejected')
    except (OSError,NotImplementedError):
        if os.name=='nt':
            jr=subprocess.run(['cmd','/c','mklink','/J',str(link),str(outside)],capture_output=True,text=True)
            if jr.returncode==0 and link.exists():
                ok(call(['src/external/file.py'],category='source_code').returncode!=0,'junction_target_rejected')
            else:
                print('V21_TARGET_SCOPE_SKIP=symlink_or_junction_creation_not_available')
        else:
            print('V21_TARGET_SCOPE_SKIP=symlink_creation_not_available')
    # Existing hardlinks must not be auto-remediation targets because mutation can affect another path.
    original=project/'src'/'hard-original.txt';alias=project/'src'/'hard-alias.txt';original.write_text('x',encoding='utf-8')
    try:
        os.link(original,alias)
        ok(call(['src/hard-alias.txt'],category='source_code').returncode!=0,'hardlink_target_rejected')
    except (OSError,NotImplementedError):
        print('V21_TARGET_SCOPE_SKIP=hardlink_creation_not_available')
    # Existing directories are not exact-file scopes.
    (project/'docs').mkdir(exist_ok=True)
    ok(call(['docs'],category='documentation').returncode!=0,'directory_target_rejected')
    # Canonical permission policy may not silently lose a boundary or gain an auto category.
    perm_path=install/'config/permission-policy.json';original=json.loads(perm_path.read_text(encoding='utf-8-sig'))
    tampered=json.loads(json.dumps(original));tampered['hard_boundaries'].remove('credentials');perm_path.write_text(json.dumps(tampered),encoding='utf-8')
    ok(call(['docs/after-boundary-removal.md']).returncode!=0,'permission_policy_boundary_removal_fails_closed')
    perm_path.write_text(json.dumps(original),encoding='utf-8')
    tampered=json.loads(json.dumps(original));tampered['auto_change_categories'].append('production');perm_path.write_text(json.dumps(tampered),encoding='utf-8')
    ok(call(['docs/after-category-injection.md']).returncode!=0,'permission_policy_auto_category_injection_fails_closed')
    perm_path.write_text(json.dumps(original),encoding='utf-8')
    tampered=json.loads(json.dumps(original));tampered['protected_path_prefixes'].remove('.git');perm_path.write_text(json.dumps(tampered),encoding='utf-8')
    ok(call(['docs/after-protected-prefix-removal.md']).returncode!=0,'permission_policy_protected_prefix_removal_fails_closed')
    perm_path.write_text(json.dumps(original),encoding='utf-8')
    tampered=json.loads(json.dumps(original));tampered['protected_path_name_prefixes']=[];perm_path.write_text(json.dumps(tampered),encoding='utf-8')
    ok(call(['docs/after-env-prefix-removal.md']).returncode!=0,'permission_policy_env_prefix_removal_fails_closed')
  print('V21_TARGET_SCOPE_RESULT=PASS')
  return 0
if __name__=='__main__':
  try: raise SystemExit(main())
  except Exception as e: print(str(e),file=sys.stderr);raise
