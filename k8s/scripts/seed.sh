#!/usr/bin/env bash
# Monday morning at Kestrel: the two internal APIs the platform team already manages, and Ines's
# first push of the Kestrel Payments API. No rulesets exist yet; Rob creates them live in Act 1 and 2.
#   ./seed.sh                 APIs only (default)
#   ./seed.sh --with-rulesets also applies both TykRulesets, so you can start at Act 3
set -euo pipefail
source "$(dirname "$0")/env.sh"
echo "== Rob's ruleset file as a ConfigMap (rulesets/kestrel-platform-standards.json -> ruleset.json)"
k create configmap kestrel-platform-standards --from-file=ruleset.json="$DEMO_DIR/rulesets/kestrel-platform-standards.json" \
  --dry-run=client -o yaml | k label --local -f - demo=kestrel-governance -o yaml | k apply -f - >/dev/null
echo "== Internal estate: Tariffs API and Charge Points API, category 'internal'"
k apply -f "$K8S_DIR/manifests/10-internal-apis.yaml"
echo "== Ines's first push: Kestrel Payments API (Monday's spec), category 'payments'"
"$K8S_DIR/scripts/ines-push.sh" monday
if [[ "${1:-}" == "--with-rulesets" ]]; then
  echo "== Rulesets (normally created live in Acts 1 and 2)"
  k apply -f "$K8S_DIR/manifests/20-payments-security-baseline.yaml"
  k apply -f "$K8S_DIR/manifests/21-kestrel-platform-standards.yaml"
  sleep 5
fi
"$K8S_DIR/scripts/status.sh"
