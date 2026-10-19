#!/usr/bin/env bash
# Shows rulesets and the compliance status of every categorised OAS API.
set -euo pipefail
source "$(dirname "$0")/env.sh"
echo "== Rulesets"
dash GET "/api/rulesets?p=-1" | jq -r '.rulesets[] | "  \(.name) [\(.ruleset_id)] active=\(.active) action=\(.action) categories=\(.categories)"'
echo "== Compliance by API"
dash GET "/api/apis?p=-1" | jq -r '.apis[] | select(.api_definition.is_oas==true) | "\(.api_definition.api_id)\t\(.api_definition.name)"' \
| while IFS=$'\t' read -r id name; do
  cats="$(dash GET "/api/apis/oas/$id/categories" | jq -c '.categories // []')"
  [[ "$cats" == "[]" ]] && continue
  dash GET "/api/governance/apis/$id/compliance" | jq -r --arg n "$name" --arg c "$cats" '
    "  \($n) \($c): \(.overall_status)" + (.rulesets | map("\n      - \(.ruleset_name): \(.compliance // .status) errors=\(.error_count) warnings=\(.warn_count) score=\(.compliance_level // "n/a")") | join(""))'
done
