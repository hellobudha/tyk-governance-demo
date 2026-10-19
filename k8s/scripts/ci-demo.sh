#!/usr/bin/env bash
# The pull-request check, unchanged from the Docker version: scripts/governance-check.sh from the Tyk
# docs, pointed at the in-cluster Dashboard. Runs Monday's spec (fails) and Tuesday's (passes).
source "$(dirname "$0")/env.sh"
export TYK_DASHBOARD_TOKEN="$(dashboard_token)"
set +e
for spec in payments-api.json payments-api-fixed.json; do
  echo
  echo "################  governance-check.sh apis/$spec --categories payments --strictness ${STRICTNESS:-standard}  ################"
  out="$(mktemp)"
  "$DEMO_DIR/scripts/governance-check.sh" "$DEMO_DIR/apis/$spec" --categories payments --api-id kestrel-payments-api --strictness "${STRICTNESS:-standard}" > "$out" 2>&1
  rc=$?
  awk '/^Totals across/{exit} {print}' "$out" | jq -r '
      "rulesets: " + ([.rulesets[] | "\(.name) (action=\(.action)) errors=\(.error_count) warns=\(.warn_count)"] | join(" | ")),
      (.issues[] | select(.severity=="error") | "  ERROR  \(.rule_id)  at \(.path)\n         fix: \(.how_to_fix[0:140])")' 2>/dev/null || cat "$out"
  grep -E '^(Totals|Counting|Result)' "$out"
  echo ">>> exit code: $rc  ($( [[ $rc -eq 0 ]] && echo "pipeline continues" || echo "pipeline FAILS" ))"
  rm -f "$out"
done
