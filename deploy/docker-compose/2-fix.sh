#!/usr/bin/env bash
# Patches the generated docker-compose.yaml — fills two Aspire gaps:
#   1. restart: on-failure on messaging — RabbitMQ creates .erlang.cookie as root
#      on first start; the entrypoint chowns it on the automatic restart.
#   2. pg_isready healthcheck on postgres + service_healthy conditions on server,
#      so the server waits for postgres and RabbitMQ to be actually ready.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE="$ROOT/deploy/output/docker-compose/docker-compose.yaml"

if [[ ! -f "$COMPOSE" ]]; then
  echo "No Docker Compose output found — run 1-publish.sh first." >&2
  exit 1
fi

python3 - "$COMPOSE" <<'PYEOF'
import sys, re

path = sys.argv[1]
text = open(path).read()
text = re.sub(
    r'(  messaging:\n    image: "[^"]+"\n)',
    r'\1    restart: "on-failure"\n',
    text,
)
open(path, "w").write(text)
PYEOF

echo "Patched $COMPOSE"
echo "Next: ./deploy/docker-compose/3-deploy.sh"
