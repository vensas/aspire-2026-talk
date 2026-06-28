#!/usr/bin/env bash
# Builds all container images and loads them into the local minikube cluster.
# Run from the repository root after 2-fix.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELM="$ROOT/deploy/output/helm"

if [[ ! -d "$HELM" ]]; then
  echo "No Helm output found at $HELM — run 1-publish.sh first." >&2
  exit 1
fi

echo "Building server image..."
dotnet publish "$ROOT/src/CookieJar.Server/CookieJar.Server.csproj" \
  /t:PublishContainer \
  -p ContainerRepository=server \
  -p ContainerImageTag=latest \
  --no-restore -q

echo "Building cookie-sensor image..."
podman build -q \
  -t localhost/cookie-sensor:latest \
  -f "$HELM/cookie-sensor.Dockerfile" \
  "$ROOT/src/cookie-sensor"

echo "Building frontend image..."
podman build -q \
  -t localhost/frontend:latest \
  "$ROOT/src/frontend"

echo "Loading images into minikube..."
podman save localhost/server:latest        | minikube image load --overwrite=true - &
podman save localhost/cookie-sensor:latest | minikube image load --overwrite=true - &
podman save localhost/frontend:latest      | minikube image load --overwrite=true - &
wait

echo "Done. Images in minikube:"
minikube image ls | grep "^localhost/"
echo "Next: ./deploy/kubernetes/4-deploy.sh"
