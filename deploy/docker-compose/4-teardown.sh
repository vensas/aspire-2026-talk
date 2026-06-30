#!/usr/bin/env bash
# Stops and removes the Docker Compose stack, including volumes.
# Run from the repository root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="$ROOT/deploy/output/docker-compose"
COMPOSE="$OUTPUT/docker-compose.yaml"

if [[ ! -f "$COMPOSE" ]]; then
  echo "No Docker Compose output found at $OUTPUT — nothing to tear down." >&2
  exit 0
fi

echo "Stopping and removing Docker Compose stack (including volumes)..."
docker compose -f "$COMPOSE" down --volumes --remove-orphans

# Remove any orphaned cookiejar volumes left behind by interrupted runs.
# RabbitMQ's .erlang.cookie gets bad permissions if a volume is reused after
# a non-clean shutdown, so we always wipe them here.
ORPHANS=$(docker volume ls -q | grep '^docker-compose_cookiejar\.' || true)
if [[ -n "$ORPHANS" ]]; then
  echo "Removing orphaned volumes: $ORPHANS"
  echo "$ORPHANS" | xargs docker volume rm
fi

echo "Done."
