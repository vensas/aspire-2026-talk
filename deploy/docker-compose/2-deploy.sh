#!/usr/bin/env bash
# Starts the Docker Compose stack from the generated artifacts.
# Run from the repository root after 1-publish.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="$ROOT/deploy/output/docker-compose"
COMPOSE="$OUTPUT/docker-compose.yaml"

if [[ ! -f "$COMPOSE" ]]; then
  echo "No Docker Compose output found at $OUTPUT — run 1-publish.sh first." >&2
  exit 1
fi

docker compose -f "$COMPOSE" up --build "$@"
