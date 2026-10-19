#!/usr/bin/env bash
# Customises the OWASP-based "Payments Security Baseline": downgrades the HTTPS-servers rule to Warn
# (TLS terminates at the edge in this environment, and the Dashboard adds the gateway's http:// URL
# to every API's servers list). Demonstrates that editing a ruleset re-evaluates every API in scope.
# Use --revert to restore the untouched template definition.
set -euo pipefail
source "$(dirname "$0")/env.sh"
id="$(ruleset_id_by_name "Payments Security Baseline")"
[[ -z "$id" ]] && { echo "Payments Security Baseline not found (create it in the UI or run setup.sh --with-owasp)." >&2; exit 1; }
current="$(dash GET "/api/rulesets/$id")"
if [[ "${1:-}" == "--revert" ]]; then
  def='{"extends":[["spectral:owasp","all"]]}'
else
  def='{"extends":[["spectral:owasp","all"]],"rules":{"owasp-security-hosts-https-oas3":"warn"}}'
fi
echo "$current" | jq --arg def "$def" '{name, description, active, action, resource_type, categories, definition: $def}' \
  | dash PUT "/api/rulesets/$id" -H "Content-Type: application/json" -d @- | jq -c '{name, action, categories}'
echo "== Applied rule severity now:"; dash GET "/api/rulesets/$id" | jq -c '.applied_rules[] | select(.id=="owasp-security-hosts-https-oas3") | {id, severity}'
echo "== Waiting for background re-evaluation of every payments API..."; sleep 3
"$DEMO_DIR/scripts/status.sh"
