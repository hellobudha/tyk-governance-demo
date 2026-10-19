#!/usr/bin/env bash
# Act 8: Rob switches the payments baseline to action: block, then someone tries to roll the
# payments API back to Monday's keyless spec. The admission webhook denies the apply.
# --revert puts the ruleset back to warn.
set -euo pipefail
source "$(dirname "$0")/env.sh"
if [[ "${1:-}" == "--revert" ]]; then k apply -f "$K8S_DIR/manifests/22-payments-security-baseline-tuned.yaml"; exit 0; fi
echo "== Rob: action warn -> block"
k apply -f "$K8S_DIR/manifests/23-payments-security-baseline-block.yaml"
k get tykruleset payments-security-baseline
sleep 3
echo
echo "== Someone pushes Monday's spec again (a bad rollback)..."
"$K8S_DIR/scripts/ines-push.sh" monday || true
echo
echo "== Current state of the API in the cluster (unchanged):"
k get tykoasapidefinition kestrel-payments-api -o jsonpath='{.spec.tykOAS.configmapRef.name}{"\n"}'
