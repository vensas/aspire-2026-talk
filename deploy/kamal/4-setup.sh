#!/usr/bin/env bash
# First-time server setup: installs Docker, configures the insecure registry,
# boots the Kamal proxy, and starts the accessories (postgres, messaging).
# Run from the repository root after 3-build-push.sh.
set -euo pipefail
source "$(dirname "$0")/_common.sh"
require_output
cd "$OUTPUT"

echo "=== [1/4] Bootstrapping server (installs Docker) ==="
"$KAMAL" server bootstrap

echo "=== [2/4] Configuring insecure registry on VM ==="
multipass exec "$VM_NAME" -- bash -c "
  echo '{\"insecure-registries\":[\"$REGISTRY_HOST\"]}' | sudo tee /etc/docker/daemon.json > /dev/null
  sudo systemctl restart docker
  sleep 2
"

echo "=== [3/4] Booting Kamal proxy ==="
"$KAMAL" proxy boot

echo "=== [4/4] Starting accessories (owned by the primary app config) ==="
"$KAMAL" accessory boot all

echo ""
echo "Setup complete. Run ./deploy/kamal/5-deploy.sh to deploy the apps."
