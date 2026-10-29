#!/usr/bin/env bash
# Deploys the pre-pushed images to the server — one Kamal app per generated config.
# Run from the repository root after 4-setup.sh (first time) or 3-build-push.sh (subsequent).
set -euo pipefail
source "$(dirname "$0")/_common.sh"
require_output

GIT_SHA="$(git -C "$ROOT" rev-parse HEAD)"
cd "$OUTPUT"

for app in "${APPS[@]}"; do
  echo "=== Deploying $app ==="
  "$KAMAL" deploy --skip-push --version "$GIT_SHA" -c "$(config_for "$app")"
done

echo ""
echo "=== URLs ==="
echo "  Frontend:  http://frontend.$VM_IP.nip.io"
echo "  API:       http://server.$VM_IP.nip.io/scalar"
echo "  Health:    http://server.$VM_IP.nip.io/health"
