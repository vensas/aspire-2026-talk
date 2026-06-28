#!/usr/bin/env bash
# Generates Kamal deployment artifacts via the custom KamalPipelineStep.
# Run from the repository root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="$ROOT/deploy/output/kamal"

echo "Generating Kamal deployment artifacts..."
# Parameters__rabbitmq-password is required because it is declared as a secret
# parameter with no default (AddParameter("rabbitmq-password", secret: true)).
# aspire publish is non-interactive and will error without a value. The actual
# secret is replaced before real deployment via .kamal/secrets.
env "Parameters__rabbitmq-password=placeholder" PUBLISH_TARGET=kamal \
  aspire publish \
  --apphost "$ROOT/src/CookieJar.AppHost/CookieJar.AppHost.csproj" \
  --output-path "$OUTPUT"

echo ""
echo "Artifacts written to: $OUTPUT"
echo ""
echo "Next steps:"
echo "  1. cp $OUTPUT/.kamal/secrets.example $OUTPUT/.kamal/secrets"
echo "  2. Edit .kamal/secrets — fill in registry credentials and passwords"
echo "  3. Edit deploy.yml — update server IP and domain"
echo "  4. cd $OUTPUT && kamal setup && kamal deploy"
