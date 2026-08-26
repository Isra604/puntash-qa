#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/project" >&2
  exit 2
fi
PROJECT="$(cd "$1" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="$PROJECT/.comprehensive-qa"
if [[ -e "$DEST" ]]; then
  echo "QA runtime already exists: $DEST" >&2
  exit 3
fi
mkdir -p "$DEST"
cp -R "$PACKAGE_ROOT/runtime/." "$DEST/"
mkdir -p "$DEST/profile" "$DEST/reports" "$DEST/evidence" "$DEST/artifacts" "$DEST/remediation" "$DEST/dispositions" "$DEST/state"
cp "$DEST/templates/PROJECT_QA_PROFILE.md" "$DEST/profile/PROJECT_QA_PROFILE.md"
: > "$DEST/state/FINDING_LEDGER.jsonl"
VERSION="$(tr -d '\r\n' < "$PACKAGE_ROOT/VERSION")"
cat > "$DEST/INSTALLATION.json" <<EOF
{
  "system": "Universal Comprehensive QA Gate System",
  "version": "$VERSION",
  "project_path": "$PROJECT",
  "runtime_path": "$DEST"
}
EOF
echo "Installed Comprehensive QA runtime at: $DEST"
echo "Next: ask your QA agent to read .comprehensive-qa/AGENT_INSTRUCTIONS.md and perform Discovery."
