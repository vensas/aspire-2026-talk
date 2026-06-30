#!/usr/bin/env bash
# One-time setup: generate a dedicated SSH key, launch a Multipass VM,
# and configure it for Kamal. Run from the repository root.
set -euo pipefail

VM_NAME="${VM_NAME:-kamal-demo}"
REGISTRY_PORT="${REGISTRY_PORT:-5001}"
SSH_KEY="$HOME/.ssh/kamal-multipass"

# ── 1. Generate a dedicated SSH key for this demo ────────────────────────────
if [[ -f "$SSH_KEY" ]]; then
  echo "SSH key already exists at $SSH_KEY — skipping."
else
  echo "Generating dedicated SSH key at $SSH_KEY..."
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "kamal-multipass-demo"
fi

# ── 2. Start a local container registry on the host ──────────────────────────
# The VM will pull images from it via the host's Multipass bridge IP.
if docker inspect local-registry &>/dev/null 2>&1; then
  echo "Local registry already running."
else
  echo "Starting local container registry on port $REGISTRY_PORT..."
  docker run -d -p "$REGISTRY_PORT:5000" --name local-registry --restart=always registry:2
fi

# ── 3. Launch the VM ──────────────────────────────────────────────────────────
if multipass info "$VM_NAME" &>/dev/null 2>&1; then
  echo "VM '$VM_NAME' already exists — skipping launch."
  multipass start "$VM_NAME" 2>/dev/null || true
else
  echo "Launching VM '$VM_NAME' (2 CPUs, 4 GB RAM, 20 GB disk)..."
  multipass launch --name "$VM_NAME" --cpus 2 --memory 4G --disk 20G
fi

# ── 4. Install the dedicated public key into the VM ──────────────────────────
echo "Installing SSH public key into VM..."
PUB_KEY="$(cat "${SSH_KEY}.pub")"
multipass exec "$VM_NAME" -- bash -c "
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  grep -qxF '$PUB_KEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$PUB_KEY' >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
"

# ── 5. Allow insecure access to the host's local registry from inside the VM ─
VM_IP="$(multipass info "$VM_NAME" | awk '/IPv4/ { print $2 }')"
# Derive host bridge IP: last octet → 1 (e.g. 192.168.64.5 → 192.168.64.1)
HOST_IP="${VM_IP%.*}.1"
REGISTRY_HOST="$HOST_IP:$REGISTRY_PORT"

echo "Host IP on Multipass bridge: $HOST_IP"

multipass exec "$VM_NAME" -- bash -c "
  sudo mkdir -p /etc/docker
  echo '{\"insecure-registries\":[\"$REGISTRY_HOST\"]}' | sudo tee /etc/docker/daemon.json > /dev/null
"

# ── 6. Print summary ──────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────"
echo "VM '$VM_NAME' ready."
echo ""
echo "  VM IP:        $VM_IP"
echo "  Host IP:      $HOST_IP"
echo "  Registry:     $REGISTRY_HOST"
echo "  SSH key:      $SSH_KEY"
echo ""
echo "Next steps:"
echo ""
echo "  1. Generate Kamal artifacts:"
echo "       ./deploy/kamal/2-publish.sh"
echo ""
echo "  2. Copy and fill in secrets:"
echo "       cp deploy/output/kamal/.kamal/secrets.example deploy/output/kamal/.kamal/secrets"
echo ""
echo "     Set these values:"
echo "       SERVER_IP=$VM_IP"
echo "       REGISTRY_HOST=$REGISTRY_HOST"
echo "       SSH_KEY=$SSH_KEY"
echo "       ConnectionStrings__cookiejardb=Host=$VM_IP;Port=5432;Database=cookiejardb;Username=app;Password=yourpassword"
echo "       ConnectionStrings__messaging=amqp://app:yourpassword@$VM_IP:5672"
echo "       POSTGRES_PASSWORD=yourpassword"
echo "       RABBITMQ_DEFAULT_PASS=yourpassword"
echo "────────────────────────────────────────────────"
