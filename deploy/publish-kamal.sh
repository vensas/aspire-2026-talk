#!/usr/bin/env bash
# Generates Kamal deployment artifacts via the custom KamalPipelineStep.
# The step runs automatically as part of aspire publish (RequiredBy "publish").
# Run from the repository root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/deploy/output/kamal"

echo "Generating Kamal deployment artifacts..."
aspire publish \
  --project "$ROOT/src/CookieJar.AppHost/CookieJar.AppHost.csproj" \
  --step generate-kamal-config \
  --output-path "$OUTPUT"

echo ""
echo "Artifacts written to: $OUTPUT"
echo ""
echo "Next steps:"
echo "  1. cp $OUTPUT/.kamal/secrets.example $OUTPUT/.kamal/secrets"
echo "  2. Edit .kamal/secrets — fill in registry credentials and passwords"
echo "  3. Edit deploy.yml — update server IP and domain"
echo "  4. cd $OUTPUT && kamal setup && kamal deploy"
