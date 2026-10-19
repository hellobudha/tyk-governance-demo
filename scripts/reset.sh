#!/usr/bin/env bash
# Removes everything setup.sh (and the live demo) created, so the walkthrough can be recorded again.
set -euo pipefail
source "$(dirname "$0")/env.sh"
echo "== Deleting demo rulesets"
# "Acme Platform Standards" is the pre-rename name; kept so an old seed still cleans up.
for name in "Payments Security Baseline" "Kestrel Platform Standards" "Design Standards" "OpenAPI Design Standards" "Acme Platform Standards"; do
  id="$(ruleset_id_by_name "$name")"
  [[ -z "$id" ]] && continue
  dash DELETE "/api/rulesets/$id" >/dev/null && echo "   deleted $name ($id)"
done
echo "== Deleting the Kestrel Payments API"
for name in "Kestrel Payments API" "Acme Payments API"; do
  id="$(api_id_by_name "$name")"
  if [[ -n "$id" ]]; then dash DELETE "/api/apis/oas/$id" | jq -c . && echo "   deleted $name"; fi
done
echo "== Removing the 'internal' category from demo APIs"
for name in "OAS HTTPbin" "JWT-RSA" "Strict Routes" "Multiple Listen Paths"; do
  id="$(api_id_by_name "$name")"
  [[ -z "$id" ]] && continue
  dash PUT "/api/apis/oas/$id/categories" -H "Content-Type: application/json" -d '{"categories":[]}' >/dev/null && echo "   $name cleared"
done
echo "== Done. Categories left:"; dash GET "/api/apis/categories" | jq -c .
