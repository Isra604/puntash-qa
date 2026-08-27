#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ echo "FAIL: $1" >&2; exit 1; }
pass(){ echo "PASS: $1"; }
[[ "$(find "$ROOT/runtime/gates" -maxdepth 1 -type f -name 'GATE-*.md' | wc -l | tr -d ' ')" == "25" ]] || fail 'exactly 25 gates'
pass 'exactly 25 gates'
for i in $(seq -w 1 25); do [[ -f "$ROOT/runtime/gates/GATE-$i.md" ]] || fail "missing GATE-$i"; done
pass 'gate numbering 01-25'
[[ "$(find "$ROOT/runtime/gates/lenses" -maxdepth 1 -type f -name 'LENS-*.md' | wc -l | tr -d ' ')" == "9" ]] || fail 'exactly 9 reliability lenses'
for i in $(seq -f "%02g" 1 9); do [[ -f "$ROOT/runtime/gates/lenses/LENS-$i.md" ]] || fail "missing LENS-$i"; done
[[ -f "$ROOT/runtime/gates/reliability.yaml" ]] || fail 'missing reliability policy'
grep -q 'required_lens_count: 9' "$ROOT/runtime/gates/reliability.yaml" || fail 'reliability policy lens count'
grep -q 'decisive_automated_test_pass_requires_test_trustworthiness_evaluation: true' "$ROOT/runtime/gates/reliability.yaml" || fail 'test trustworthiness policy'
grep -q 'coverage_percentage_is_never_behavioral_proof: true' "$ROOT/runtime/gates/reliability.yaml" || fail 'coverage-only prohibition'
[[ "$(grep -l 'v2 cross-cutting reliability obligations' "$ROOT"/runtime/gates/GATE-*.md | wc -l | tr -d ' ')" == "25" ]] || fail 'all gates v2 reliability obligations'
pass '9 reliability lenses and policy contract'
TERMS_VERSION="$(tr -d '\r\n' < "$ROOT/TERMS_VERSION")"
grep -q "terms_version: $TERMS_VERSION" "$ROOT/runtime/config/default.yaml" || fail 'default.yaml Terms version consistency'
if [[ "$(tr -d '\r\n' < "$ROOT/VERSION")" == "2.1.0" ]]; then grep -q 'authority_source: state/OWNER_POLICY.json' "$ROOT/runtime/config/default.yaml" || fail 'OWNER_POLICY authority source'; grep -q 'legacy_allowed_modes_are_not_authority: true' "$ROOT/runtime/config/default.yaml" || fail 'legacy remediation authority disabled'; fi
pass 'config authority/Terms consistency'
for f in "$ROOT/scripts/install.sh" "$ROOT/scripts/verify-install.sh" "$ROOT/runtime/tools/qa-doctor.sh" "$ROOT/runtime/tools/dashboard-refresh.sh" "$ROOT/runtime/tools/validate-run.sh" "$ROOT/runtime/tools/policy-manager.sh" "$ROOT/runtime/tools/scheduler.sh" "$ROOT/runtime/tools/scheduled-run.sh" "$ROOT/runtime/tools/authorize-change.sh" "$ROOT/runtime/tools/open-dashboard.sh" "$ROOT/scripts/self-test.sh"; do bash -n "$f" || fail "bash syntax $f"; done
pass 'bash syntax'
[[ -f "$ROOT/runtime/START_HERE.md" && -f "$ROOT/docs/PRODUCT_ROADMAP.md" ]] || fail 'Easy Start/roadmap files'
pass 'Easy Start/roadmap files'
if [[ "$(tr -d '\r\n' < "$ROOT/VERSION")" == "2.1.0" ]]; then
  for f in runtime/templates/OWNER_POLICY.json runtime/templates/PERMISSION_POLICY.json runtime/templates/SCHEDULED_QA.md runtime/tools/policy-manager.py runtime/tools/authorize-change.py runtime/tools/prepare-scheduler-for-rollback.ps1 runtime/tools/scheduler.py runtime/tools/scheduled-run.py runtime/tools/dashboard-control.py runtime/tools/open-dashboard.sh scripts/v2.1-control-red-team.py scripts/v2.1-upgrade-red-team.ps1; do [[ -f "$ROOT/$f" ]] || fail "missing v2.1 asset $f"; done
  cmp -s "$ROOT/runtime/config/permission-policy.json" "$ROOT/runtime/templates/PERMISSION_POLICY.json" || fail 'permission policy compatibility copy mismatch'
  cmp -s "$ROOT/runtime/prompts/SCHEDULED_QA.md" "$ROOT/runtime/templates/SCHEDULED_QA.md" || fail 'scheduled prompt compatibility copy mismatch'
  grep -q 'authorize-change' "$ROOT/runtime/AGENT_INSTRUCTIONS.md" || fail 'agent mechanical authorization contract'
  grep -q 'Agent permissions' "$ROOT/runtime/dashboard/index.html" || fail 'dashboard agent permissions card'
  grep -q 'Scheduled QA' "$ROOT/runtime/dashboard/index.html" || fail 'dashboard scheduled QA card'
  pass 'v2.1 control-center asset contract'
fi
if git -C "$ROOT" grep -n -E 'gh[op]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----' -- ':!scripts/self-test.sh' ':!scripts/self-test.ps1' >/tmp/qa-secret-hits.$$ 2>/dev/null; then cat /tmp/qa-secret-hits.$$; rm -f /tmp/qa-secret-hits.$$; fail 'common secret signature found'; fi
rm -f /tmp/qa-secret-hits.$$ || true
pass 'no common secret signatures'
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
bash "$ROOT/runtime/tools/qa-doctor.sh" "$ROOT" "$TMP/doctor" >/dev/null
[[ -s "$TMP/doctor/QA_DOCTOR.json" && -s "$TMP/doctor/QA_DOCTOR.md" ]] || fail 'QA Doctor output'
pass 'QA Doctor output'
grep -q '"doctor_version": "2.0"' "$TMP/doctor/QA_DOCTOR.json" || fail 'QA Doctor v2 version'
[[ "$(grep -c '"LENS-0[1-9]_' "$TMP/doctor/QA_DOCTOR.json")" == "9" ]] || fail 'QA Doctor 9 reliability hints'
pass 'QA Doctor v2 reliability hints'

for f in "$ROOT/runtime/dashboard/index.html" "$ROOT/runtime/dashboard/data.js" "$ROOT/runtime/templates/DASHBOARD_RUN.json" "$ROOT/runtime/tools/dashboard-refresh.sh" "$ROOT/docs/DASHBOARD.md"; do [[ -f "$f" ]] || fail "missing dashboard asset $f"; done
grep -q 'Local only · no telemetry' "$ROOT/runtime/dashboard/index.html" || fail 'dashboard privacy label'
grep -q '25 gate map' "$ROOT/runtime/dashboard/index.html" || fail 'dashboard gate map'
grep -q 'Reliability assurance' "$ROOT/runtime/dashboard/index.html" || fail 'dashboard reliability assurance'
grep -q '9 cross-cutting lenses' "$ROOT/runtime/dashboard/index.html" || fail 'dashboard lens strip'
pass 'dashboard local UI contract'
DASHROOT="$TMP/dashproject"; mkdir -p "$DASHROOT/.comprehensive-qa"; cp -R "$ROOT/runtime/." "$DASHROOT/.comprehensive-qa/"; printf '{"version":"%s"}\n' "$(tr -d '\r\n' < "$ROOT/VERSION")" > "$DASHROOT/.comprehensive-qa/INSTALLATION.json"; mkdir -p "$DASHROOT/.comprehensive-qa/reports/dashboard"
printf '%s\n' '{"schema_version":1,"run_id":"RUN-SHELL-1","project":{"name":"Demo","branch":"main","head":"abc"},"completed_at":"2026-08-26T10:00:00Z","summary":{"pass":20,"fail":2,"blocked":1,"not_run":1,"not_applicable":1},"findings_summary":{"open":3},"gates":[],"findings":[],"changes":{}}' > "$DASHROOT/.comprehensive-qa/reports/dashboard/RUN-SHELL-1.json"
set +e
bash "$DASHROOT/.comprehensive-qa/tools/dashboard-refresh.sh" "$DASHROOT" >/dev/null 2>&1
DASH_RC=$?
set -e
if [[ "$DASH_RC" == "0" ]]; then
  grep -q 'RUN-SHELL-1' "$DASHROOT/.comprehensive-qa/dashboard/data.js" || fail 'dashboard history shell output'
  pass 'dashboard refresh and history'
elif [[ "$DASH_RC" == "2" && "${OS:-}" == "Windows_NT" ]]; then
  pass 'dashboard refresh dependency reported cleanly on Windows Git Bash'
else
  fail "dashboard refresh shell exit $DASH_RC"
fi
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then
  python3 - "$ROOT" "$TMP" <<'PY'
import json,subprocess,sys
from pathlib import Path
root=Path(sys.argv[1]); tmp=Path(sys.argv[2])
gates=[{"gate":i,"status":"PASS","assurance":"STRONG","summary":"self","evidence_freshness":"CURRENT","evidence_refs":[f"evidence/GATE-{i:02d}.txt"],"lens_impact_reviewed":False,"lens_exception_lenses":[],"lens_exception_rationale":""} for i in range(1,26)]
lenses=[{"lens":i,"status":"PASS","assurance":"STRONG","applicability_rationale":"self","applicability_evidence":["profile/PROJECT_QA_PROFILE.md"],"evidence_freshness":"CURRENT","evidence_refs":[f"evidence/LENS-{i:02d}.txt"]} for i in range(1,10)]
base={"schema_version":2,"run_id":"SELF","project":{"name":"self"},"completed_at":"2026-08-26T10:00:00Z","summary":{"pass":25,"fail":0,"blocked":0,"not_run":0,"not_applicable":0},"evidence_assurance":{"overall":"STRONG"},"gates":gates,"lenses":lenses,"test_trustworthiness":{"applicable":True,"status":"PASS","assurance":"STRONG","evidence_freshness":"CURRENT","evidence_refs":["evidence/LENS-01/test-trust.txt"],"decisive_suites":["critical"]},"findings":[],"changes":{}}
def run(obj,name,expect):
 p=tmp/name;p.write_text(json.dumps(obj),encoding="utf-8")
 rc=subprocess.run([sys.executable,str(root/'runtime/tools/validate-run.py'),str(p)],stdout=subprocess.DEVNULL).returncode
 if (rc==0)!=expect: raise SystemExit(f"validator case {name} rc={rc}")
run(base,"valid-v2.json",True)
bad=json.loads(json.dumps(base));bad["gates"][0]["assurance"]="WEAK";run(bad,"bad-weak.json",False)
bad=json.loads(json.dumps(base));bad["lenses"][1]["status"]="BLOCKED";bad["lenses"][1]["reason"]="missing tool";run(bad,"bad-g25.json",False)
bad=json.loads(json.dumps(base));bad["lenses"]=bad["lenses"][:-1];run(bad,"bad-lens-count.json",False)
PY
  pass 'run validator PASS ceilings and 25+9 completeness'
  python3 "$ROOT/scripts/v2-red-team.py" >/dev/null || fail 'v2 red-team suite'
  pass 'v2 red-team false-PASS attacks'
  if [[ "$(tr -d '\r\n' < "$ROOT/VERSION")" == "2.1.0" ]]; then
    python3 "$ROOT/scripts/v2.1-control-red-team.py" >/dev/null || fail 'v2.1 control red-team suite'
    python3 "$ROOT/scripts/v2.1-policy-fuzz-red-team.py" >/dev/null || fail 'v2.1 policy fuzz red-team suite'
    python3 "$ROOT/scripts/v2.1-runtime-red-team.py" >/dev/null || fail 'v2.1 runtime lifecycle red-team suite'
    pass 'v2.1 control/permission/runtime red-team'
    if [[ "${OS:-}" != "Windows_NT" ]]; then
      python3 "$ROOT/scripts/v2.1-unix-scheduler-red-team.py" >/dev/null || fail 'v2.1 unix scheduler red-team suite'
      pass 'v2.1 unix scheduler red-team'
    fi
  fi
else
  echo 'SKIP: Python 3 unavailable for shell run-validator contract test'
fi
mkdir -p "$TMP/project"
set +e
bash "$ROOT/scripts/install.sh" "$TMP/project" </dev/null >/tmp/qa-install-out.$$ 2>&1
RC=$?
set -e
[[ "$RC" == "5" ]] || { cat /tmp/qa-install-out.$$; fail "noninteractive installer refusal expected exit 5 got $RC"; }
[[ ! -e "$TMP/project/.comprehensive-qa" ]] || fail 'noninteractive installer wrote target files'
rm -f /tmp/qa-install-out.$$
pass 'human acceptance cannot be bypassed by noninteractive shell install'
echo 'SELF_TEST_RESULT=PASS'
