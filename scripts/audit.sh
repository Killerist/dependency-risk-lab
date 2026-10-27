#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-before}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQ="$ROOT/demo-app/requirements-${MODE}.txt"
OUT="$ROOT/evidence/audit-${MODE}.json"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if [[ ! -f "$REQ" ]]; then
  echo "Unknown mode: $MODE" >&2
  exit 2
fi

mkdir -p "$ROOT/evidence"
TMP_OUT="$(mktemp "$ROOT/evidence/.audit-${MODE}.XXXXXX.json")"
trap 'rm -f "$TMP_OUT"' EXIT

# pip-audit returns a non-zero status when vulnerabilities are found.
set +e
"$PYTHON_BIN" -m pip_audit --requirement "$REQ" --no-deps --disable-pip --format json --output "$TMP_OUT"
STATUS=$?
set -e

if [[ ! -s "$TMP_OUT" ]]; then
  echo "Audit did not produce a result" >&2
  exit "${STATUS:-4}"
fi

mv "$TMP_OUT" "$OUT"
echo "Audit evidence written to $OUT (scanner status: $STATUS)"

if [[ "$STATUS" -gt 1 ]]; then
  echo "Scanner failed with status $STATUS" >&2
  exit "$STATUS"
fi

if [[ "${FAIL_ON_FINDINGS:-0}" == "1" && "$STATUS" -ne 0 ]]; then
  echo "Known vulnerabilities found; failing because FAIL_ON_FINDINGS=1" >&2
  exit "$STATUS"
fi

