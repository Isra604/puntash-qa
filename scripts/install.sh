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
VERSION="$(tr -d '\r\n' < "$PACKAGE_ROOT/VERSION")"
echo "Installing Universal Comprehensive QA Gate System v$VERSION"
echo "Original creator and project architect: Ofir Israeli"
echo "Copyright (c) 2026 Ofir Israeli | MIT License"
echo
if [[ -e "$DEST" ]]; then
  echo "QA runtime already exists: $DEST" >&2
  exit 3
fi
mkdir -p "$DEST"
cp -R "$PACKAGE_ROOT/runtime/." "$DEST/"
cp "$PACKAGE_ROOT/LICENSE" "$PACKAGE_ROOT/NOTICE" "$PACKAGE_ROOT/CREDITS.md" "$DEST/"
mkdir -p "$DEST/profile" "$DEST/reports" "$DEST/evidence" "$DEST/artifacts" "$DEST/remediation" "$DEST/dispositions" "$DEST/state"
cp "$DEST/templates/PROJECT_QA_PROFILE.md" "$DEST/profile/PROJECT_QA_PROFILE.md"
: > "$DEST/state/FINDING_LEDGER.jsonl"
cat > "$DEST/state/FIRST_RUN_ATTRIBUTION_PENDING.txt" <<EOF
Universal Comprehensive QA Gate System v$VERSION
Original creator and project architect: Ofir Israeli
Copyright (c) 2026 Ofir Israeli
Licensed under the MIT License.
EOF
cat > "$DEST/INSTALLATION.json" <<EOF
{
  "system": "Universal Comprehensive QA Gate System",
  "version": "$VERSION",
  "project_path": "$PROJECT",
  "runtime_path": "$DEST",
  "author": "Ofir Israeli",
  "creator_role": "Original creator and project architect",
  "license": "MIT",
  "copyright": "Copyright (c) 2026 Ofir Israeli"
}
EOF
echo "Comprehensive QA Gate System installed successfully."
echo "Created by Ofir Israeli."
echo "Installed runtime: $DEST"
echo "Next: ask your QA agent to read .comprehensive-qa/AGENT_INSTRUCTIONS.md and perform Discovery."
