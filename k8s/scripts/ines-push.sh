#!/usr/bin/env bash
# "Ines merges a PR and CI applies it": publishes a revision of the payments spec to the cluster.
#   ./ines-push.sh monday          apis/payments-api.json               (keyless, no rate limit, ...)
#   ./ines-push.sh gateway-fixed   apis/payments-api-gateway-fixed.json (auth + upstream rate limit only)
#   ./ines-push.sh fixed           apis/payments-api-fixed.json         (everything)
# Each revision is its own ConfigMap (kestrel-payments-api-<rev>, like a kustomize configMapGenerator),
# and the TykOasApiDefinition is pointed at it. That update is what the Operator's governance
# webhook evaluates: it can print a warning, or deny the change outright under action: block.
set -euo pipefail
source "$(dirname "$0")/env.sh"
case "${1:-}" in
  monday)        f="payments-api.json" ;;
  gateway-fixed) f="payments-api-gateway-fixed.json" ;;
  fixed)         f="payments-api-fixed.json" ;;
  *) echo "usage: $0 monday|gateway-fixed|fixed" >&2; exit 2 ;;
esac
rev="$(spec_rev "$DEMO_DIR/apis/$f")"
cm="kestrel-payments-api-$rev"
echo "== ConfigMap $cm  <- apis/$f"
k create configmap "$cm" --from-file=payments-api.json="$DEMO_DIR/apis/$f" --dry-run=client -o yaml \
  | k label --local -f - demo=kestrel-governance squad=payments -o yaml | k apply -f - >/dev/null
echo "== kubectl apply TykOasApiDefinition kestrel-payments-api -> configmapRef $cm"
set +e
sed "s/kestrel-payments-api-REV/$cm/" "$K8S_DIR/manifests/11-kestrel-payments-api.yaml" | k apply -f -
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  echo ">>> The cluster refused the change. The API keeps its previous revision."
  k delete configmap "$cm" --ignore-not-found >/dev/null
  exit $rc
fi
echo "== Waiting for the Operator to sync and evaluate..."
for i in $(seq 1 30); do
  s="$(k get tykoasapidefinition kestrel-payments-api -o jsonpath='{.status.latestTransaction.status}{" "}{.status.governancePreflight.status}' 2>/dev/null)"
  [[ "$s" == Successful* && "$s" != *" " ]] && break; sleep 2
done
k get tykoasapidefinition kestrel-payments-api
k get tykoasapidefinition kestrel-payments-api -o jsonpath='{.status.governancePreflight}' | jq -c 'del(.sourceHash)' 2>/dev/null || true
