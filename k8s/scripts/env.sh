#!/usr/bin/env bash
# Shared environment for the Kubernetes version of the Kestrel governance demo.
KIND_CLUSTER="${KIND_CLUSTER:-kestrel}"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-$KIND_CLUSTER}"
NS="${NS:-tyk}"
K8S_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEMO_DIR="$(cd "$K8S_DIR/.." && pwd)"
export TYK_DASHBOARD_URL="${TYK_DASHBOARD_URL:-http://localhost:3100}"
export TYK_GATEWAY_URL="${TYK_GATEWAY_URL:-http://localhost:8180}"
k() { kubectl --context "$KUBE_CONTEXT" -n "$NS" "$@"; }
# The Dashboard API key the chart's bootstrap job wrote for the Operator. Scripts reuse it.
dashboard_token() { k get secret tyk-operator-conf -o jsonpath='{.data.TYK_AUTH}' 2>/dev/null | base64 -d; }
dash() { # dash METHOD PATH [curl args...]
  local method="$1" path="$2"; shift 2
  curl -sS -X "$method" "$TYK_DASHBOARD_URL$path" -H "Authorization: $(dashboard_token)" "$@"
}
api_id_by_name() { dash GET "/api/apis?p=-1" | jq -r --arg n "$1" '.apis[] | select(.api_definition.name==$n) | .api_definition.api_id' | head -1; }
spec_rev() { shasum -a 256 "$1" | cut -c1-10; }   # revision suffix for the payments ConfigMap
