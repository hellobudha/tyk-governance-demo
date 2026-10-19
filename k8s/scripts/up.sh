#!/usr/bin/env bash
# Brings up the whole demo: kind cluster, cert-manager, Redis + Postgres, and the tyk-stack chart
# (Dashboard 5.15 + Gateway 5.15 + Operator 1.5). Idempotent; safe to re-run.
# Licence: set TYK_LICENCE, or it is read from ~/projects/tyk-demo/.env (DASHBOARD_LICENCE).
set -euo pipefail
source "$(dirname "$0")/env.sh"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.19.1}"
TYK_STACK_CHART_VERSION="${TYK_STACK_CHART_VERSION:-5.4.1}"

LICENCE="${TYK_LICENCE:-$(grep '^DASHBOARD_LICENCE=' "$HOME/projects/tyk-demo/.env" 2>/dev/null | cut -d= -f2- | tr -d '"')}"
[[ -z "$LICENCE" ]] && { echo "ERROR: no licence. Export TYK_LICENCE or keep DASHBOARD_LICENCE in ~/projects/tyk-demo/.env" >&2; exit 1; }
SCOPE="$(python3 -c "import base64,json,sys;p=sys.argv[1].split('.')[1];p+='='*(-len(p)%4);print(json.loads(base64.urlsafe_b64decode(p)).get('scope',''))" "$LICENCE")"
echo "== Licence scope: $SCOPE"
[[ "$SCOPE" == *governance* ]] || echo "   WARNING: scope has no 'governance' claim; every governance endpoint will return 403"

echo "== 1. kind cluster '$KIND_CLUSTER' (Dashboard -> localhost:3100, Gateway -> localhost:8180)"
if kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER"; then echo "   exists"; else kind create cluster --config "$K8S_DIR/kind-config.yaml"; fi

echo "== 2. cert-manager $CERT_MANAGER_VERSION (the Operator's admission webhook needs a certificate)"
kubectl --context "$KUBE_CONTEXT" apply -f "https://github.com/cert-manager/cert-manager/releases/download/$CERT_MANAGER_VERSION/cert-manager.yaml" >/dev/null
kubectl --context "$KUBE_CONTEXT" -n cert-manager wait --for=condition=Available deploy --all --timeout=240s

echo "== 3. Redis and PostgreSQL"
kubectl --context "$KUBE_CONTEXT" apply -f "$K8S_DIR/manifests/00-datastores.yaml" >/dev/null
k wait --for=condition=Available deploy/tyk-redis deploy/tyk-postgres --timeout=240s

echo "== 4. tyk-stack $TYK_STACK_CHART_VERSION: Dashboard, Gateway, Operator (bootstrap creates org, admin user, operator secret)"
helm repo add tyk-helm https://helm.tyk.io/public/helm/charts/ >/dev/null 2>&1 || true
helm repo update >/dev/null
helm --kube-context "$KUBE_CONTEXT" upgrade --install tyk-stack tyk-helm/tyk-stack --version "$TYK_STACK_CHART_VERSION" \
  -n "$NS" -f "$K8S_DIR/values.yaml" \
  --set global.license.dashboard="$LICENCE" --set global.license.operator="$LICENCE"
# No --wait: the chart's post-install bootstrap job creates the Operator's secret, and Helm runs
# post-install hooks only after --wait is satisfied, which the Operator cannot be without the secret.
echo "   waiting for the bootstrap job to create secret/tyk-operator-conf..."
for i in $(seq 1 90); do k get secret tyk-operator-conf >/dev/null 2>&1 && break; sleep 3; done
k get secret tyk-operator-conf >/dev/null
# The Operator reads the secret as environment variables at start. On a reinstall the pod can start
# before the bootstrap job rewrites the secret, so restart it once the secret is in place.
k rollout restart deploy/tyk-stack-tyk-operator-controller-manager >/dev/null
k rollout status deploy/dashboard-tyk-stack-tyk-dashboard --timeout=600s
k rollout status deploy/gateway-tyk-stack-tyk-gateway --timeout=600s
k rollout status deploy/tyk-stack-tyk-operator-controller-manager --timeout=600s

echo "== 5. Pin NodePorts so the kind port mappings line up"
k patch svc dashboard-svc-tyk-stack-tyk-dashboard --type json -p '[{"op":"replace","path":"/spec/ports/0/nodePort","value":30300}]' >/dev/null
k patch svc gateway-svc-tyk-stack-tyk-gateway   --type json -p '[{"op":"replace","path":"/spec/ports/0/nodePort","value":30808}]' >/dev/null

echo "== 6. Waiting for the Dashboard on $TYK_DASHBOARD_URL"
for i in $(seq 1 60); do curl -sf -o /dev/null "$TYK_DASHBOARD_URL/hello" && break; sleep 2; done
code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: $(dashboard_token)" "$TYK_DASHBOARD_URL/api/rulesets")"
echo "   GET /api/rulesets -> $code (200 = governance enabled, 403 = licence lacks the claim)"
k get pods
cat <<MSG

Ready.
  Dashboard : $TYK_DASHBOARD_URL
  Login     : $(awk '/^  adminUser:/{f=1} f&&/email:/{print $2; exit}' "$K8S_DIR/values.yaml") / $(k get secret tyk-dashboard-login-details -o jsonpath='{.data.adminUserPassword}' | base64 -d)
  Gateway   : $TYK_GATEWAY_URL
  Operator  : $(k get deploy tyk-stack-tyk-operator-controller-manager -o jsonpath='{.spec.template.spec.containers[?(@.name=="manager")].image}')
Next: ./scripts/seed.sh   (Monday morning: the internal estate and Ines's first push, no rulesets yet)
MSG
