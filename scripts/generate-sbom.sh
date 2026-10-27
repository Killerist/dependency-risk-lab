#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-before}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQ="$ROOT/demo-app/requirements-${MODE}.txt"
OUT="$ROOT/sbom/bom-${MODE}.json"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if [[ ! -f "$REQ" ]]; then
  echo "Unknown mode: $MODE" >&2
  exit 2
fi

mkdir -p "$ROOT/sbom"
"$PYTHON_BIN" -m cyclonedx_py requirements "$REQ" --output-format JSON --output-file "$OUT"
echo "SBOM written to $OUT"

