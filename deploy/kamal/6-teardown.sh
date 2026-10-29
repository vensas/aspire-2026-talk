#!/usr/bin/env bash
# Removes the Kamal deployment from the server and optionally destroys the Multipass VM.
# Run from the repository root.
set -euo pipefail
source "$(dirname "$0")/_common.sh"

if [[ -f "$OUTPUT/config/deploy.yml" && -n "$VM_IP" ]]; then
  cd "$OUTPUT"
  # Secondary apps first — the primary config also removes proxy and accessories
  for (( i=${#APPS[@]}-1; i>=0; i-- )); do
    echo "Removing ${APPS[$i]}..."
    "$KAMAL" remove --confirmed -c "$(config_for "${APPS[$i]}")" 2>/dev/null || echo "  (not deployed — skipping)"
  done
  cd "$ROOT"
else
  echo "No Kamal output or VM found — skipping remote teardown."
fi

echo ""
read -r -p "Destroy Multipass VM '$VM_NAME'? [y/N] " DESTROY_VM
if [[ "$DESTROY_VM" =~ ^[Yy]$ ]]; then
  echo "Stopping and deleting VM '$VM_NAME'..."
  multipass stop "$VM_NAME" 2>/dev/null || true
  multipass delete "$VM_NAME" 2>/dev/null || true
  multipass purge
fi

echo ""
read -r -p "Remove local container registry? [y/N] " REMOVE_REGISTRY
if [[ "$REMOVE_REGISTRY" =~ ^[Yy]$ ]]; then
  echo "Removing local registry container..."
  docker rm -f local-registry 2>/dev/null || echo "  (not running — skipping)"
fi

echo "Done."
