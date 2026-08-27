#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v python3 >/dev/null 2>&1 && python3 -c 'import sys' >/dev/null 2>&1; then exec python3 "$ROOT/scheduler.py" "$@"; fi
echo "Python 3 is required for local scheduler management on this platform." >&2
exit 2
