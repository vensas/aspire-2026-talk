#!/usr/bin/env bash
# Deploys the app to a Multipass VM using Kamal.
# Run from the repository root after 2-build-push.sh.
#
# Steps:
#   setup   — one-time: install Docker, configure registry, boot proxy + accessories
#   deploy  — subsequent: deploy a new image version (default)
#   all     — setup + deploy in one go (first time only)
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

# ── Resolve structural variables ──────────────────────────────────────────────
# Kamal only interpolates env.secret values inside containers — server IPs,
# registry host, and SSH key in the YAML itself must be literals.
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

# Kamal is installed via homebrew ruby gems — may not be on PATH
KAMAL="$(command -v kamal 2>/dev/null || echo /opt/homebrew/lib/ruby/gems/4.0.0/bin/kamal)"

cd "$OUTPUT"
CONFIG="-c config/deploy.resolved.yml"

COMMAND="${1:-deploy}"

case "$COMMAND" in
  setup)
    # ── Step 1: install Docker on the VM ─────────────────────────────────────
    echo "=== [1/4] Bootstrapping server (installs Docker) ==="
    "$KAMAL" server bootstrap $CONFIG

    # ── Step 2: configure insecure registry, restart Docker ──────────────────
    echo "=== [2/4] Configuring insecure registry on VM ==="
    # Kamal installs Docker but our registry is plain HTTP — Docker must be
    # told to allow it before any pull can succeed.
    multipass exec "${VM_NAME:-kamal-demo}" -- bash -c "
      echo '{\"insecure-registries\":[\"$REGISTRY_HOST\"]}' | sudo tee /etc/docker/daemon.json > /dev/null
      sudo systemctl restart docker
      sleep 2
    "

    # ── Step 3: boot Kamal proxy ──────────────────────────────────────────────
    echo "=== [3/4] Booting Kamal proxy ==="
    "$KAMAL" proxy boot $CONFIG

    # ── Step 4: start accessories (postgres, rabbitmq) ────────────────────────
    echo "=== [4/4] Starting accessories ==="
    "$KAMAL" accessory boot all $CONFIG
    ;;

  deploy)
    # Image was already pushed by 2-build-push.sh — skip the build/push phase.
    echo "=== Deploying ==="
    "$KAMAL" deploy --skip-push $CONFIG
    echo ""
    echo "=== URLs ==="
    echo "  API / backend:  http://$SERVER_IP"
    echo "  Frontend:       http://$SERVER_IP:3000"
    echo "  Health check:   http://$SERVER_IP/health"
    ;;

  all)
    "$0" setup && "$0" deploy
    ;;

  *)
    echo "Usage: $0 [setup|deploy|all]" >&2
    echo "  setup   — first-time: install Docker, configure registry, boot proxy + accessories" >&2
    echo "  deploy  — deploy the pre-pushed image (default)" >&2
    echo "  all     — setup + deploy (first time)" >&2
    exit 1
    ;;
esac
