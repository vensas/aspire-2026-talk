#!/usr/bin/env bash
# Fixes known issues in the Aspire-generated Helm output.
# Run from the repository root after 1-publish.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HELM="$ROOT/deploy/output/helm"

if [[ ! -d "$HELM" ]]; then
  echo "No Helm output found at $HELM — run 1-publish.sh first." >&2
  exit 1
fi

echo "Fixing Helm output in $HELM..."

# Kubernetes volume names must match [a-z0-9]([-a-z0-9]*[a-z0-9])? — no dots allowed.
# Aspire generates volume names derived from the AppHost project name, e.g.
# "cookiejar.apphost-<hash>-postgres-data". Replace dots only inside quoted
# name values that follow the AppHost naming pattern.
# Tracked upstream: https://github.com/microsoft/aspire/issues/17169
find "$HELM/templates" -name "statefulset.yaml" -exec \
  sed -i '' 's/\(name: "[a-z0-9-]*\)\.\([a-z0-9][^"]*"\)/\1-\2/g' {} +

echo "Done."
echo "Next: ./deploy/kubernetes/3-build.sh"
