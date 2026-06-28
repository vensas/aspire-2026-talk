#!/usr/bin/env bash
# Deploys the generated Helm chart to the current kubectl context.
# Run from the repository root after 3-build.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELM="$ROOT/deploy/output/helm"

if [[ ! -d "$HELM" ]]; then
  echo "No Helm output found at $HELM — run 1-publish.sh first." >&2
  exit 1
fi

# Override defaults — edit or pass via environment
REGISTRY="${REGISTRY:-localhost}"
SERVER_IMAGE="${SERVER_IMAGE:-$REGISTRY/server:latest}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-$REGISTRY/frontend:latest}"
COOKIE_SENSOR_IMAGE="${COOKIE_SENSOR_IMAGE:-$REGISTRY/cookie-sensor:latest}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
RABBITMQ_PASSWORD="${RABBITMQ_PASSWORD:-rabbitmq}"
COOKIE_JAR_CAPACITY="${COOKIE_JAR_CAPACITY:-100}"

helm upgrade --install cookiejar "$HELM" \
  --namespace cookiejar \
  --create-namespace \
  --set parameters.server.server_image="$SERVER_IMAGE" \
  --set parameters.frontend.frontend_image="$FRONTEND_IMAGE" \
  --set parameters.cookie_sensor.cookie_sensor_image="$COOKIE_SENSOR_IMAGE" \
  --set secrets.postgres.postgres_password="$POSTGRES_PASSWORD" \
  --set secrets.messaging.rabbitmq_password="$RABBITMQ_PASSWORD" \
  --set secrets.cookie_sensor.rabbitmq_password="$RABBITMQ_PASSWORD" \
  --set secrets.server.postgres_password="$POSTGRES_PASSWORD" \
  --set secrets.server.rabbitmq_password="$RABBITMQ_PASSWORD" \
  --set config.server.cookie_jar_capacity="$COOKIE_JAR_CAPACITY"
