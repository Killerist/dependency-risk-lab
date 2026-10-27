#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-after}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SBOM="${SBOM_FILE:-$ROOT/sbom/trivy-bom-${MODE}.cdx.json}"
DTRACK_URL="${DTRACK_URL:-http://localhost:8080}"
DTRACK_PROJECT_NAME="${DTRACK_PROJECT_NAME:-dependency-risk-lab}"
DTRACK_PROJECT_VERSION="${DTRACK_PROJECT_VERSION:-$MODE}"

if [[ -z "${DTRACK_API_KEY:-}" ]]; then
  echo "DTRACK_API_KEY is required" >&2
  exit 2
fi

if [[ ! -f "$SBOM" ]]; then
  echo "SBOM not found: $SBOM" >&2
  echo "Run ./scripts/generate-trivy-sbom.sh $MODE first" >&2
  exit 3
fi

curl --fail-with-body --silent --show-error \
  --request POST \
  --header "X-Api-Key: $DTRACK_API_KEY" \
  --form "autoCreate=true" \
  --form "projectName=$DTRACK_PROJECT_NAME" \
  --form "projectVersion=$DTRACK_PROJECT_VERSION" \
  --form "bom=@$SBOM" \
  "${DTRACK_URL%/}/api/v1/bom"

printf '\nSBOM submitted to Dependency-Track: %s:%s\n' \
  "$DTRACK_PROJECT_NAME" "$DTRACK_PROJECT_VERSION"
