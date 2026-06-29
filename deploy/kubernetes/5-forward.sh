#!/usr/bin/env bash
# Port-forwards the frontend service to localhost:8080.
# Run from the repository root after 4-deploy.sh.
set -euo pipefail

PORT="${PORT:-8080}"

echo "Forwarding http://localhost:$PORT → frontend-service:3000 (Ctrl+C to stop)"
kubectl port-forward -n cookiejar svc/frontend-service "$PORT:3000"
