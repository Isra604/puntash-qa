#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/project" >&2
  exit 2
fi
if [[ ! -t 0 || ! -t 1 ]]; then
  echo "Human acceptance required. This installer refuses non-interactive/CI/unattended execution." >&2
  exit 5
fi
PROJECT="$(cd "$1" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="$PROJECT/.comprehensive-qa"
if [[ -e "$DEST" ]]; then
  echo "QA runtime already exists: $DEST. No files were changed. This shell installer does not overwrite an existing runtime." >&2
  exit 3
fi
VERSION="$(tr -d '\r\n' < "$PACKAGE_ROOT/VERSION")"
TERMS_VERSION="$(tr -d '\r\n' < "$PACKAGE_ROOT/TERMS_VERSION")"
LEGAL=(LICENSE TERMS_OF_USE.md DISCLAIMER.md DATA_RESPONSIBILITY_NOTICE.md HUMAN_ACCEPTANCE.md NOTICE CREDITS.md)
for f in "${LEGAL[@]}"; do [[ -f "$PACKAGE_ROOT/$f" ]] || { echo "Missing legal document: $f" >&2; exit 6; }; done

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}' | tr '[:lower:]' '[:upper:]'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}' | tr '[:lower:]' '[:upper:]'
  else echo "SHA-256 utility (sha256sum or shasum) is required." >&2; exit 7
  fi
}

clear 2>/dev/null || true
echo "Universal Comprehensive QA Gate System v$VERSION"
echo "Original creator and project architect: Ofir Israeli"
echo "Terms version: $TERMS_VERSION"
echo "===================================================================="
for f in "${LEGAL[@]}"; do
  echo
  echo "===== $f ====="
  cat "$PACKAGE_ROOT/$f"
done

echo
echo "HUMAN ACCEPTANCE REQUIRED"
echo "An AI agent, automation, bot, CI runner, or unattended script is not authorized by this distribution to accept on your behalf."
read -r -p "Are you a natural person authorized to accept for yourself or the relevant organization/project owner? Type YES: " HUMAN
[[ "$HUMAN" == "YES" ]] || { echo "Installation declined. No files were written to the target project."; exit 4; }
read -r -p "Have you read and do you accept the License, Terms of Use, Disclaimer, Data Responsibility Notice, and Human Acceptance Requirement? Type YES: " TERMS
[[ "$TERMS" == "YES" ]] || { echo "Installation declined. No files were written to the target project."; exit 4; }
read -r -p "Do you accept responsibility for suitability, permissions, backups, legal/compliance obligations, and consequences of use? Type YES: " RISK
[[ "$RISK" == "YES" ]] || { echo "Installation declined. No files were written to the target project."; exit 4; }
read -r -p "Type exactly I ACCEPT to continue: " PHRASE
[[ "$PHRASE" == "I ACCEPT" ]] || { echo "Installation declined. No files were written to the target project."; exit 4; }

ACCEPTED_AT="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
INSTALLATION_ID="$( (command -v uuidgen >/dev/null 2>&1 && uuidgen) || printf '%s-%s' "$(date +%s)" "$$" )"
LOCAL_USER="$(id -un 2>/dev/null || echo unknown)"
LOCAL_HOST="$(hostname 2>/dev/null || echo unknown)"

mkdir -p "$DEST"
cp -R "$PACKAGE_ROOT/runtime/." "$DEST/"
for f in "${LEGAL[@]}" TERMS_VERSION LEGAL_MANIFEST.json; do cp "$PACKAGE_ROOT/$f" "$DEST/$f"; done
mkdir -p "$DEST/profile" "$DEST/reports" "$DEST/evidence" "$DEST/artifacts" "$DEST/remediation" "$DEST/dispositions" "$DEST/state"
cp "$DEST/templates/PROJECT_QA_PROFILE.md" "$DEST/profile/PROJECT_QA_PROFILE.md"
: > "$DEST/state/FINDING_LEDGER.jsonl"
cat > "$DEST/state/FIRST_RUN_ATTRIBUTION_PENDING.txt" <<EOF
Universal Comprehensive QA Gate System v$VERSION
Original creator and project architect: Ofir Israeli
Copyright (c) 2026 Ofir Israeli
Licensed under the MIT License.
EOF

# Escape a few JSON-sensitive characters for local metadata fields.
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
{
  echo '{'
  echo '  "system": "Universal Comprehensive QA Gate System",'
  echo "  \"package_version\": \"$(json_escape "$VERSION")\","
  echo "  \"terms_version\": \"$(json_escape "$TERMS_VERSION")\","
  echo "  \"installation_id\": \"$(json_escape "$INSTALLATION_ID")\","
  echo "  \"accepted_at\": \"$(json_escape "$ACCEPTED_AT")\","
  echo "  \"project_path\": \"$(json_escape "$PROJECT")\","
  echo '  "acceptance_method": "interactive_terminal_human_attestation",'
  echo '  "accepted_by_human_attestation": true,'
  echo '  "acceptance_phrase": "I ACCEPT",'
  echo "  \"local_os_user\": \"$(json_escape "$LOCAL_USER")\","
  echo "  \"local_machine_name\": \"$(json_escape "$LOCAL_HOST")\","
  echo '  "creator": "Ofir Israeli",'
  echo '  "license": "MIT",'
  echo '  "transmitted_by_installer": false,'
  echo '  "legal_document_sha256": {'
  for idx in "${!LEGAL[@]}"; do
    f="${LEGAL[$idx]}"; h="$(hash_file "$PACKAGE_ROOT/$f")"
    if [[ "$idx" -lt $((${#LEGAL[@]}-1)) ]]; then comma=','; else comma=''; fi
    echo "    \"$f\": \"$h\"$comma"
  done
  echo '  }'
  echo '}'
} > "$DEST/state/HUMAN_ACCEPTANCE_RECEIPT.json"

cat > "$DEST/INSTALLATION.json" <<EOF
{
  "system": "Universal Comprehensive QA Gate System",
  "version": "$VERSION",
  "terms_version": "$TERMS_VERSION",
  "project_path": "$(json_escape "$PROJECT")",
  "runtime_path": "$(json_escape "$DEST")",
  "installation_id": "$(json_escape "$INSTALLATION_ID")",
  "human_acceptance_receipt": "state/HUMAN_ACCEPTANCE_RECEIPT.json",
  "author": "Ofir Israeli",
  "license": "MIT"
}
EOF

if [[ -f "$DEST/tools/qa-doctor.sh" ]]; then
  if bash "$DEST/tools/qa-doctor.sh" "$PROJECT" "$DEST/state"; then
    echo "QA Doctor readiness scan completed."
  else
    echo "WARNING: QA Doctor did not complete. Installation remains valid." >&2
  fi
fi

echo "Comprehensive QA Gate System installed successfully."
echo "Created by Ofir Israeli."
echo "Human acceptance recorded for Terms v$TERMS_VERSION."
echo "Installed runtime: $DEST"
echo "Acceptance receipt: $DEST/state/HUMAN_ACCEPTANCE_RECEIPT.json"
echo "Next: ask your QA agent to read .comprehensive-qa/START_HERE.md and .comprehensive-qa/AGENT_INSTRUCTIONS.md and perform Discovery."
