#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="${1:-$(pwd)}"
PYTHON="$(command -v python3 || command -v python || true)"
[[ -n "$PYTHON" ]] || { echo '{"ok":false,"algorithm":"PUNTASH_SOURCE_V1","reason":"Python 3 is required to calculate a non-Git project snapshot."}'; exit 2; }
exec "$PYTHON" "$SCRIPT_DIR/project-fingerprint.py" "$PROJECT"
