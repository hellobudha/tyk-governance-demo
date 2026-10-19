#!/usr/bin/env bash
# "Rob commits a one-line change to the ruleset": the OWASP https-servers rule becomes a warning.
# --revert restores the untouched template. Either way the Operator updates the Dashboard ruleset,
# which re-evaluates every payments API, and requeues the matching TykOasApiDefinitions.
set -euo pipefail
source "$(dirname "$0")/env.sh"
f="22-payments-security-baseline-tuned.yaml"; [[ "${1:-}" == "--revert" ]] && f="20-payments-security-baseline.yaml"
echo "== kubectl apply -f manifests/$f"
diff <(sed -n '/^spec:/,$p' "$K8S_DIR/manifests/20-payments-security-baseline.yaml") <(sed -n '/^spec:/,$p' "$K8S_DIR/manifests/$f") || true
k apply -f "$K8S_DIR/manifests/$f"
echo "== Waiting for re-evaluation..."; sleep 6
"$K8S_DIR/scripts/status.sh"
