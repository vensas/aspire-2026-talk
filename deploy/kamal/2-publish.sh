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

# ── Seed secrets file with demo defaults ─────────────────────────────────────
SECRETS="$OUTPUT/.kamal/secrets"
VM_NAME="${VM_NAME:-kamal-demo}"
REGISTRY_PORT="${REGISTRY_PORT:-5001}"

VM_IP="$(multipass info "$VM_NAME" 2>/dev/null | awk '/IPv4/ { print $2 }')"
HOST_IP="${VM_IP%.*}.1"
REGISTRY_HOST="$HOST_IP:$REGISTRY_PORT"

cat > "$SECRETS" <<EOF
# .kamal/secrets — demo defaults, do not commit to version control.

SERVER_IP=$VM_IP
SSH_USER=ubuntu
SSH_KEY=~/.ssh/kamal-multipass
REGISTRY_HOST=$REGISTRY_HOST
REGISTRY_USERNAME=unused
REGISTRY_PASSWORD=unused
ConnectionStrings__cookiejardb=Host=cookiejar-db;Port=5432;Database=cookiejardb;Username=postgres;Password=cookiejar
ConnectionStrings__messaging=amqp://guest:cookiejar@cookiejar-mq:5672
CookieJar__Capacity=100
POSTGRES_PASSWORD=cookiejar
RABBITMQ_DEFAULT_PASS=cookiejar
EOF

echo "Secrets written to: $SECRETS"
echo "  SERVER_IP=$VM_IP  REGISTRY_HOST=$REGISTRY_HOST"
echo ""
echo "Next: ./deploy/kamal/3-build-push.sh"
