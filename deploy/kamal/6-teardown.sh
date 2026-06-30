#!/usr/bin/env bash
# Removes the Kamal deployment from the server and optionally destroys the Multipass VM.
# Run from the repository root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="$ROOT/deploy/output/kamal"
VM_NAME="${VM_NAME:-kamal-demo}"

KAMAL="$(command -v kamal 2>/dev/null || echo /opt/homebrew/lib/ruby/gems/4.0.0/bin/kamal)"

if [[ -f "$OUTPUT/config/deploy.yml" && -f "$OUTPUT/.kamal/secrets" ]]; then
  echo "Removing Kamal deployment from server..."
  cd "$OUTPUT"
  "$KAMAL" remove --confirmed 2>/dev/null || echo "  (nothing deployed — skipping)"
  cd "$ROOT"
else
  echo "No Kamal output or secrets found — skipping remote teardown."
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
