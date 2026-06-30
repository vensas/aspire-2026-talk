#!/usr/bin/env bash
# Builds the server and frontend images and pushes them to the local registry.
# Run from the repository root after 1-publish.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SECRETS="$ROOT/deploy/output/kamal/.kamal/secrets"

if [[ ! -f "$SECRETS" ]]; then
  echo "No .kamal/secrets found — copy secrets.example and fill it in first." >&2
  echo "  cp deploy/output/kamal/.kamal/secrets.example $SECRETS" >&2
  exit 1
fi

# Load REGISTRY_HOST from secrets (ignore lines without = and comment lines)
REGISTRY_HOST="$(grep '^REGISTRY_HOST=' "$SECRETS" | cut -d= -f2-)"
if [[ -z "$REGISTRY_HOST" ]]; then
  echo "REGISTRY_HOST is not set in .kamal/secrets." >&2
  exit 1
fi

echo "Registry: $REGISTRY_HOST"

# ── .NET server ───────────────────────────────────────────────────────────────
echo "Building server image..."
dotnet publish "$ROOT/src/CookieJar.Server/CookieJar.Server.csproj" \
  /t:PublishContainer \
  -p ContainerRepository=cookiejar \
  -p ContainerImageTag=latest

# Kamal tags images by git commit SHA — push both that tag and :latest.
GIT_SHA="$(git -C "$ROOT" rev-parse HEAD)"
# Kamal requires a 'service' label matching the service name in deploy.yml.
# The .NET SDK container build doesn't add it, so we add it in a thin layer.
echo "Adding Kamal service label..."
printf 'FROM localhost/cookiejar:latest\nLABEL service=cookiejar\n' | \
  podman build --quiet -t localhost/cookiejar:latest -f - .

echo "Pushing to $REGISTRY_HOST (SHA: ${GIT_SHA:0:12})..."
# --tls-verify=false is required for plain-HTTP local registries.
podman push --tls-verify=false \
  "localhost/cookiejar:latest" \
  "$REGISTRY_HOST/cookiejar:$GIT_SHA"
podman push --tls-verify=false \
  "localhost/cookiejar:latest" \
  "$REGISTRY_HOST/cookiejar:latest"

# ── React frontend (nginx) ────────────────────────────────────────────────────
echo "Building frontend image..."
podman build --quiet -t localhost/cookiejar-frontend:latest "$ROOT/src/frontend"

echo "Pushing frontend to $REGISTRY_HOST..."
podman push --tls-verify=false \
  "localhost/cookiejar-frontend:latest" \
  "$REGISTRY_HOST/cookiejar-frontend:latest"

# ── Python cookie-sensor ──────────────────────────────────────────────────────
echo "Building cookie-sensor image..."
podman build --quiet -t localhost/cookiejar-cookie-sensor:latest "$ROOT/src/cookie-sensor"

echo "Pushing cookie-sensor to $REGISTRY_HOST..."
podman push --tls-verify=false \
  "localhost/cookiejar-cookie-sensor:latest" \
  "$REGISTRY_HOST/cookiejar-cookie-sensor:latest"

echo "Done. Images pushed:"
echo "  $REGISTRY_HOST/cookiejar:$GIT_SHA  (Kamal deploy tag)"
echo "  $REGISTRY_HOST/cookiejar:latest"
echo "  $REGISTRY_HOST/cookiejar-frontend:latest"
echo "  $REGISTRY_HOST/cookiejar-cookie-sensor:latest"
echo "Next: ./deploy/kamal/4-setup.sh   (first time)"
echo "       ./deploy/kamal/5-deploy.sh  (subsequent deploys)"
