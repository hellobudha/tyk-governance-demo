#!/usr/bin/env bash
# Prepares tyk-demo for the Governance walkthrough:
#   1. tags existing Tyk OAS APIs with the "internal" category
#   2. imports the deliberately non-compliant "Kestrel Payments API" and tags it "payments"
#   3. creates the custom "Kestrel Platform Standards" ruleset (visibility only) for payments + internal
# Modes:
#   ./setup.sh                 categories + payments API + custom Kestrel ruleset (default)
#   ./setup.sh --no-rulesets   categories + payments API only; you create every ruleset live in the UI
#   ./setup.sh --with-owasp    also creates "Payments Security Baseline" from the OWASP template
#                              (Deployment Warning ON) via the API instead of creating it live
set -euo pipefail
source "$(dirname "$0")/env.sh"

echo "== 1. Tag existing OAS APIs with the 'internal' category"
for name in "OAS HTTPbin" "JWT-RSA" "Strict Routes" "Multiple Listen Paths"; do
  id="$(api_id_by_name "$name")"
  if [[ -z "$id" ]]; then echo "   skip: $name not found"; continue; fi
  dash PUT "/api/apis/oas/$id/categories" -H "Content-Type: application/json" -d '{"categories":["internal"]}' >/dev/null
  echo "   $name ($id) -> internal"
done

echo "== 2. Import the Kestrel Payments API (non-compliant) and tag it 'payments'"
if [[ -n "$(api_id_by_name "Kestrel Payments API")" ]]; then
  echo "   already exists, skipping import"
else
  dash POST "/api/apis/oas" -H "Content-Type: application/json" --data-binary "@$DEMO_DIR/apis/payments-api.json" | jq -c .
fi
PAY_ID="$(api_id_by_name "Kestrel Payments API")"
dash PUT "/api/apis/oas/$PAY_ID/categories" -H "Content-Type: application/json" -d '{"categories":["payments"]}' >/dev/null
echo "   Kestrel Payments API ($PAY_ID) -> payments"

echo "== Categories now defined:"
dash GET "/api/apis/categories" | jq -c .

if [[ "${1:-}" == "--no-rulesets" ]]; then
  echo "== --no-rulesets: skipping ruleset creation. Create them live under Governance > Rulesets."
  exit 0
fi

echo "== 3. Create the custom 'Kestrel Platform Standards' ruleset (action: none = visibility only)"
if [[ -n "$(ruleset_id_by_name "Kestrel Platform Standards")" ]]; then
  echo "   already exists, skipping"
else
  jq -n --arg def "$(jq -c . "$DEMO_DIR/rulesets/kestrel-platform-standards.json")" '{
    name: "Kestrel Platform Standards",
    description: "Kestrel Charging platform standards: authentication and upstream rate limiting on every API, operationIds, descriptions, ownership and semantic versions.",
    active: true, resource_type: "oas-api", action: "none",
    categories: ["payments","internal"], definition: $def }' \
  | dash POST "/api/rulesets" -H "Content-Type: application/json" -d @- | jq -c .
fi

if [[ "${1:-}" == "--with-owasp" ]]; then
  echo "== 4. Create 'Payments Security Baseline' from the OWASP API Security template (action: warn = Deployment Warning ON)"
  if [[ -n "$(ruleset_id_by_name "Payments Security Baseline")" ]]; then
    echo "   already exists, skipping"
  else
    TEMPLATE_DEF="$(dash GET "/api/rulesets?is_template=true&p=-1" | jq -r '.rulesets[] | select(.ruleset_id=="spectral-owasp") | .definition')"
    jq -n --arg def "$TEMPLATE_DEF" '{
      name: "Payments Security Baseline",
      description: "OWASP API Security Top 10 baseline for every payments API. Created from the OWASP API Security template.",
      active: true, resource_type: "oas-api", action: "warn",
      categories: ["payments"], definition: $def }' \
    | dash POST "/api/rulesets" -H "Content-Type: application/json" -d @- | jq -c .
  fi
fi

echo "== Waiting a few seconds for background evaluation..."
sleep 4
"$DEMO_DIR/scripts/status.sh"
