#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-before}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQ="$ROOT/demo-app/requirements-${MODE}.txt"
OUT="$ROOT/sbom/trivy-bom-${MODE}.cdx.json"
TRIVY_IMAGE="${TRIVY_IMAGE:-aquasec/trivy:0.76.1}"

if [[ ! -f "$REQ" ]]; then
  echo "Unknown mode: $MODE" >&2
  exit 2
fi

command -v docker >/dev/null 2>&1 || {
  echo "Docker is required to run the pinned Trivy image" >&2
  exit 3
}

mkdir -p "$ROOT/sbom"
TMP_DIR="$(mktemp -d "$ROOT/.trivy-tmp.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

# Trivy detects the standard Python manifest name reliably. A temporary copy
# keeps the intentionally vulnerable and remediated dependency sets separate.
cp "$REQ" "$TMP_DIR/requirements.txt"

docker run --rm \
  --volume "$TMP_DIR:/workspace:ro" \
  --volume "$ROOT/sbom:/output" \
  "$TRIVY_IMAGE" \
  fs --format cyclonedx \
  --output "/output/$(basename "$OUT")" \
  /workspace

echo "Trivy CycloneDX SBOM written to $OUT"
