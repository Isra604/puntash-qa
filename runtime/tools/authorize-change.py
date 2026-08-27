#!/usr/bin/env python3
import argparse,json,sys
from pathlib import Path

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--risk',required=True,choices=['LOW','MEDIUM','HIGH','PROTECTED']);ap.add_argument('--category',required=True);ap.add_argument('--expected-behavior-proven',action='store_true');ap.add_argument('--reversible',action='store_true');a=ap.parse_args()
 install=Path(__file__).resolve().parent.parent;state=install/'state';policy_path=state/'OWNER_POLICY.json';perm_path=install/'config'/'permission-policy.json';perm_path=perm_path if perm_path.exists() else install/'templates'/'PERMISSION_POLICY.json'
 if not policy_path.exists():
  print('CHANGE_AUTHORIZATION=DENY REASON=owner_policy_missing');return 10
 p=json.loads(policy_path.read_text(encoding='utf-8-sig'));perm=json.loads(perm_path.read_text(encoding='utf-8-sig'))
 if not p.get('configured') or not p.get('approval',{}).get('approved_by_human'):
  print('CHANGE_AUTHORIZATION=DENY REASON=owner_policy_unconfigured');return 10
 if a.category in set(perm.get('hard_boundaries',[])) or a.risk in {'HIGH','PROTECTED'}:
  print('CHANGE_AUTHORIZATION=DENY REASON=high_or_protected_requires_owner_approval');return 10
 if a.category not in set(perm.get('auto_change_categories',[])):
  print('CHANGE_AUTHORIZATION=DENY REASON=category_not_auto_changeable');return 10
 if not a.expected_behavior_proven:
  print('CHANGE_AUTHORIZATION=DENY REASON=expected_behavior_not_proven');return 10
 preset=p.get('permissions',{}).get('preset','REPORT_ONLY')
 if preset=='CUSTOM':
  risks=set(p['permissions'].get('custom_auto_change_risks',[]));cats=set(p['permissions'].get('custom_categories',[]))
 else:
  risks=set(perm.get('presets',{}).get(preset,{}).get('auto_change_risks',[]));cats=set(perm.get('auto_change_categories',[]))
 if a.risk not in risks or a.category not in cats:
  print(f'CHANGE_AUTHORIZATION=DENY REASON=preset_ceiling PRESET={preset}');return 10
 if preset=='SAFE_FIXES' and not a.reversible:
  print('CHANGE_AUTHORIZATION=DENY REASON=safe_fix_must_be_reversible');return 10
 print(f'CHANGE_AUTHORIZATION=ALLOW PRESET={preset} RISK={a.risk} CATEGORY={a.category}');return 0
if __name__=='__main__':raise SystemExit(main())
