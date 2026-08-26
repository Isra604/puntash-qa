#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then echo "Usage: $0 /path/to/project" >&2; exit 2; fi
PROJECT="$(cd "$1" && pwd)"
DEST="$PROJECT/.comprehensive-qa"
for f in AGENT_INSTRUCTIONS.md config/default.yaml profile/PROJECT_QA_PROFILE.md state/FINDING_LEDGER.jsonl INSTALLATION.json LICENSE TERMS_OF_USE.md DISCLAIMER.md DATA_RESPONSIBILITY_NOTICE.md HUMAN_ACCEPTANCE.md TERMS_VERSION LEGAL_MANIFEST.json NOTICE CREDITS.md state/HUMAN_ACCEPTANCE_RECEIPT.json state/FIRST_RUN_ATTRIBUTION_PENDING.txt; do
  [[ -e "$DEST/$f" ]] || { echo "Missing: $DEST/$f" >&2; exit 1; }
done
for i in $(seq -w 1 25); do
  [[ -e "$DEST/gates/GATE-$i.md" ]] || { echo "Missing GATE-$i" >&2; exit 1; }
done
echo "PASS: Comprehensive QA runtime verified at $DEST"
echo "PASS: 25 gate definitions present"
