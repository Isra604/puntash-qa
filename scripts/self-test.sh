#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ echo "FAIL: $1" >&2; exit 1; }
pass(){ echo "PASS: $1"; }
[[ "$(find "$ROOT/runtime/gates" -maxdepth 1 -type f -name 'GATE-*.md' | wc -l | tr -d ' ')" == "25" ]] || fail 'exactly 25 gates'
pass 'exactly 25 gates'
for i in $(seq -w 1 25); do [[ -f "$ROOT/runtime/gates/GATE-$i.md" ]] || fail "missing GATE-$i"; done
pass 'gate numbering 01-25'
for f in "$ROOT/scripts/install.sh" "$ROOT/scripts/verify-install.sh" "$ROOT/runtime/tools/qa-doctor.sh" "$ROOT/runtime/tools/dashboard-refresh.sh" "$ROOT/scripts/self-test.sh"; do bash -n "$f" || fail "bash syntax $f"; done
pass 'bash syntax'
[[ -f "$ROOT/runtime/START_HERE.md" && -f "$ROOT/docs/PRODUCT_ROADMAP.md" ]] || fail 'Easy Start/roadmap files'
pass 'Easy Start/roadmap files'
if git -C "$ROOT" grep -n -E 'gh[op]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----' -- ':!scripts/self-test.sh' ':!scripts/self-test.ps1' >/tmp/qa-secret-hits.$$ 2>/dev/null; then cat /tmp/qa-secret-hits.$$; rm -f /tmp/qa-secret-hits.$$; fail 'common secret signature found'; fi
rm -f /tmp/qa-secret-hits.$$ || true
pass 'no common secret signatures'
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
bash "$ROOT/runtime/tools/qa-doctor.sh" "$ROOT" "$TMP/doctor" >/dev/null
[[ -s "$TMP/doctor/QA_DOCTOR.json" && -s "$TMP/doctor/QA_DOCTOR.md" ]] || fail 'QA Doctor output'
pass 'QA Doctor output'

for f in "$ROOT/runtime/dashboard/index.html" "$ROOT/runtime/dashboard/data.js" "$ROOT/runtime/templates/DASHBOARD_RUN.json" "$ROOT/runtime/tools/dashboard-refresh.sh" "$ROOT/docs/DASHBOARD.md"; do [[ -f "$f" ]] || fail "missing dashboard asset $f"; done
grep -q 'Local only · no telemetry' "$ROOT/runtime/dashboard/index.html" || fail 'dashboard privacy label'
grep -q '25 gate map' "$ROOT/runtime/dashboard/index.html" || fail 'dashboard gate map'
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
