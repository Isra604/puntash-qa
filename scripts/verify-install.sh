#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then echo "Usage: $0 /path/to/project" >&2; exit 2; fi
PROJECT="$(cd "$1" && pwd)"
DEST="$PROJECT/.comprehensive-qa"
for f in AGENT_INSTRUCTIONS.md START_HERE.md OPEN_DASHBOARD.cmd dashboard/index.html dashboard/data.js templates/DASHBOARD_RUN.json tools/dashboard-refresh.ps1 tools/dashboard-refresh.sh tools/open-dashboard.ps1 agent-guides/GENERIC.md config/default.yaml profile/PROJECT_QA_PROFILE.md state/FINDING_LEDGER.jsonl INSTALLATION.json LICENSE TERMS_OF_USE.md DISCLAIMER.md DATA_RESPONSIBILITY_NOTICE.md HUMAN_ACCEPTANCE.md TERMS_VERSION LEGAL_MANIFEST.json NOTICE CREDITS.md state/HUMAN_ACCEPTANCE_RECEIPT.json tools/check-update.ps1 tools/update.ps1 tools/rollback.ps1 tools/qa-doctor.ps1 tools/qa-doctor.sh config/update.json; do
  [[ -e "$DEST/$f" ]] || { echo "Missing: $DEST/$f" >&2; exit 1; }
done
if [[ ! -e "$DEST/state/FIRST_RUN_ATTRIBUTION_PENDING.txt" && ! -e "$DEST/state/ATTRIBUTION_SHOWN.txt" ]]; then
  echo "Missing first-run attribution state" >&2
  exit 1
fi
for i in $(seq -w 1 25); do
  [[ -e "$DEST/gates/GATE-$i.md" ]] || { echo "Missing GATE-$i" >&2; exit 1; }
done
echo "PASS: Comprehensive QA runtime verified at $DEST"
echo "PASS: 25 gate definitions present"
