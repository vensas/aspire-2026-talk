#!/usr/bin/env bash
# Removes the Helm release and deletes the namespace, then optionally stops minikube.
# Run from the repository root.
set -euo pipefail

echo "Uninstalling Helm release 'cookiejar'..."
helm uninstall cookiejar --namespace cookiejar 2>/dev/null || echo "  (release not found — skipping)"

echo "Deleting namespace 'cookiejar'..."
kubectl delete namespace cookiejar 2>/dev/null || echo "  (namespace not found — skipping)"

echo ""
read -r -p "Stop minikube as well? [y/N] " STOP_MINIKUBE
if [[ "$STOP_MINIKUBE" =~ ^[Yy]$ ]]; then
  echo "Stopping minikube..."
  minikube stop
fi

echo "Done."
