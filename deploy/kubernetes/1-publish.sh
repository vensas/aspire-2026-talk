#!/usr/bin/env bash
# Generates a Helm chart from the Aspire AppHost.
# Run from the repository root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="$ROOT/deploy/output/helm"

echo "Cleaning previous Helm artifacts..."
rm -rf "$OUTPUT"

echo "Generating Helm chart..."
PUBLISH_TARGET=kubernetes aspire publish \
  --apphost "$ROOT/src/CookieJar.AppHost/CookieJar.AppHost.csproj" \
  --output-path "$OUTPUT"

echo ""
echo "Artifacts written to: $OUTPUT"
echo "Next: ./deploy/kubernetes/2-fix.sh"
