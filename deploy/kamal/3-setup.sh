#!/usr/bin/env bash
# First-time server setup: installs Docker, configures the insecure registry,
# boots the Kamal proxy, and starts accessories (postgres, rabbitmq).
# Run from the repository root after 2-build-push.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="$ROOT/deploy/output/kamal"

SECRETS="$OUTPUT/.kamal/secrets"
DEPLOY_TEMPLATE="$OUTPUT/config/deploy.yml"

if [[ ! -f "$DEPLOY_TEMPLATE" ]]; then
  echo "No Kamal output found at $OUTPUT/config/deploy.yml — run 1-publish.sh first." >&2
  exit 1
fi

if [[ ! -f "$SECRETS" ]]; then
  echo "No .kamal/secrets file found." >&2
  echo "Run: cp $OUTPUT/.kamal/secrets.example $SECRETS" >&2
  echo "Then fill in your SERVER_IP, REGISTRY_HOST, SSH_USER, SSH_KEY, and passwords." >&2
  exit 1
fi

_secret() { grep "^$1=" "$SECRETS" | head -1 | cut -d= -f2- | sed 's/[[:space:]]*#.*//'; }
SERVER_IP="$(_secret SERVER_IP)"
REGISTRY_HOST="$(_secret REGISTRY_HOST)"
SSH_USER="$(_secret SSH_USER)"
SSH_KEY="$(_secret SSH_KEY)"

for var in SERVER_IP REGISTRY_HOST SSH_USER SSH_KEY; do
  [[ -z "${!var}" ]] && { echo "ERROR: $var not set in $SECRETS" >&2; exit 1; }
done

RESOLVED="$OUTPUT/config/deploy.resolved.yml"
sed \
  -e "s|\${SERVER_IP}|$SERVER_IP|g" \
  -e "s|\${REGISTRY_HOST}|$REGISTRY_HOST|g" \
  -e "s|\${SSH_USER}|$SSH_USER|g" \
  -e "s|\${SSH_KEY}|$SSH_KEY|g" \
  "$DEPLOY_TEMPLATE" > "$RESOLVED"

KAMAL="$(command -v kamal 2>/dev/null || echo /opt/homebrew/lib/ruby/gems/4.0.0/bin/kamal)"
cd "$OUTPUT"
CONFIG="-c config/deploy.resolved.yml"

echo "=== [1/4] Bootstrapping server (installs Docker) ==="
"$KAMAL" server bootstrap $CONFIG

echo "=== [2/4] Configuring insecure registry on VM ==="
multipass exec "${VM_NAME:-kamal-demo}" -- bash -c "
  echo '{\"insecure-registries\":[\"$REGISTRY_HOST\"]}' | sudo tee /etc/docker/daemon.json > /dev/null
  sudo systemctl restart docker
  sleep 2
"

echo "=== [3/4] Booting Kamal proxy ==="
"$KAMAL" proxy boot $CONFIG

echo "=== [4/4] Starting accessories ==="
"$KAMAL" accessory boot all $CONFIG

echo ""
echo "Setup complete. Run ./deploy/kamal/4-deploy.sh to deploy the app."
