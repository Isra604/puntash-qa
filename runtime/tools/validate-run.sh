#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then echo "Usage: $0 <run.json>" >&2; exit 2; fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY=""
if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1 && python -c 'import sys;raise SystemExit(0 if sys.version_info.major>=3 else 1)' >/dev/null 2>&1; then PY=python
else echo "Python 3 is required for structured run validation on this platform." >&2; exit 2
fi
exec "$PY" "$ROOT/validate-run.py" "$1"
