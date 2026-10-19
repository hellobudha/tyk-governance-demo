#!/usr/bin/env bash
# "Ines ships the fix from the repo": replaces the saved Kestrel Payments API with the remediated
# definition (apis/payments-api-fixed.json) through the Dashboard API, then shows the new compliance status.
# Use --revert to put the non-compliant version back.
set -euo pipefail
source "$(dirname "$0")/env.sh"
spec="payments-api-fixed.json"; [[ "${1:-}" == "--revert" ]] && spec="payments-api.json"
id="$(api_id_by_name "Kestrel Payments API")"
[[ -z "$id" ]] && { echo "Kestrel Payments API not found. Run setup.sh first." >&2; exit 1; }
echo "== PUT /api/apis/oas/$id  <- apis/$spec"
dash PUT "/api/apis/oas/$id" -H "Content-Type: application/json" --data-binary "@$DEMO_DIR/apis/$spec" | jq -c .
echo "== Waiting for background re-evaluation..."; sleep 3
dash GET "/api/governance/apis/$id/compliance" | jq -r '"  overall: \(.overall_status)", (.rulesets[] | "    - \(.ruleset_name): \(.compliance // .status) errors=\(.error_count) warnings=\(.warn_count) score=\(.compliance_level // "n/a")")'
