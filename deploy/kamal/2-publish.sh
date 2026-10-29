#!/usr/bin/env bash
# Generates Kamal deployment artifacts with Vensas.Aspire.Hosting.Kamal.
# Run from the repository root after 1-setup-vm.sh.
set -euo pipefail
source "$(dirname "$0")/_common.sh"

if [[ -z "$VM_IP" ]]; then
  echo "VM '$VM_NAME' not found — run 1-setup-vm.sh first." >&2
  exit 1
fi

echo "Generating Kamal artifacts (server: $VM_IP, registry: $REGISTRY_HOST)..."
# Parameters__rabbitmq-password is required because aspire publish is non-interactive.
# It never lands in the output: .kamal/secrets references $RABBITMQ_PASSWORD instead.
env "Parameters__rabbitmq-password=placeholder" \
  PUBLISH_TARGET=kamal \
  KAMAL_SERVER="$VM_IP" \
  KAMAL_REGISTRY="$REGISTRY_HOST" \
  aspire publish \
  --apphost "$ROOT/src/CookieJar.AppHost/CookieJar.AppHost.csproj" \
  --output-path "$OUTPUT"

echo ""
echo "Artifacts written to: $OUTPUT"
echo "  config/deploy.yml, config/deploy.<app>.yml, .kamal/secrets, Dockerfile.server"
echo ""
echo "Next: ./deploy/kamal/3-build-push.sh"
