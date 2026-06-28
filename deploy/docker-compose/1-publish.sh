#!/usr/bin/env bash
# Generates Docker Compose artifacts from the Aspire AppHost.
# Run from the repository root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="$ROOT/deploy/output/docker-compose"

echo "Cleaning previous Docker Compose artifacts..."
rm -rf "$OUTPUT"

echo "Generating Docker Compose artifacts..."
PUBLISH_TARGET=docker-compose aspire publish \
  --apphost "$ROOT/src/CookieJar.AppHost/CookieJar.AppHost.csproj" \
  --output-path "$OUTPUT"

cp "$ROOT/deploy/.env.template" "$OUTPUT/.env"

echo ""
echo "Artifacts written to: $OUTPUT"
echo "Next: ./deploy/docker-compose/2-deploy.sh"
