#!/usr/bin/env bash
# Generates a Helm chart from the Aspire AppHost.
# Run from the repository root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/deploy/output/helm"

echo "Generating Helm chart..."
aspire publish \
  --project "$ROOT/src/CookieJar.AppHost/CookieJar.AppHost.csproj" \
  --output-format helm \
  --output-path "$OUTPUT"

echo ""
echo "Artifacts written to: $OUTPUT"
echo "To install:"
echo "  helm upgrade --install cookiejar $OUTPUT --namespace cookiejar --create-namespace"
