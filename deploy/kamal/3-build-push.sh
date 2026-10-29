#!/usr/bin/env bash
# Builds all app images from the generated Kamal configs and pushes them to the local registry.
# Kamal can build images itself, but needs docker buildx — this demo runs on Podman.
# Run from the repository root after 2-publish.sh.
set -euo pipefail
source "$(dirname "$0")/_common.sh"
require_output

GIT_SHA="$(git -C "$ROOT" rev-parse HEAD)"
cd "$OUTPUT"

for app in "${APPS[@]}"; do
  config="$(config_for "$app")"
  # Read dockerfile + context straight from the generated deploy.yml (paths are relative to $OUTPUT)
  dockerfile="$(awk '/^builder:/{b=1} b && /dockerfile:/{print $2; exit}' "$config")"
  context="$(awk '/^builder:/{b=1} b && /context:/{print $2; exit}' "$config")"
  image="$REGISTRY_HOST/$(awk '/^image:/{print $2; exit}' "$config")"

  echo "=== $app: $dockerfile ($context) → $image:${GIT_SHA:0:12}"
  # Kamal requires a 'service' label matching the service name in deploy.yml
  podman build --quiet --platform linux/arm64 --label "service=$app" \
    -f "$dockerfile" -t "$image:$GIT_SHA" "$context"
  # --tls-verify=false is required for plain-HTTP local registries
  podman push --quiet --tls-verify=false "$image:$GIT_SHA"
done

echo ""
echo "Next: ./deploy/kamal/4-setup.sh   (first time)"
echo "      ./deploy/kamal/5-deploy.sh  (subsequent deploys)"
