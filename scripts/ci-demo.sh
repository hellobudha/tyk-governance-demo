#!/usr/bin/env bash
# Runs the CI/CD governance check against the non-compliant and the fixed Payments API specs,
# exactly as a GitHub Actions / GitLab / Jenkins step would. Set STRICTNESS=strict|standard|permissive.
source "$(dirname "$0")/env.sh"
set +e
for spec in payments-api.json payments-api-fixed.json; do
  echo
  echo "################  governance-check.sh apis/$spec --categories payments --strictness ${STRICTNESS:-standard}  ################"
  out="$(mktemp)"
  "$DEMO_DIR/scripts/governance-check.sh" "$DEMO_DIR/apis/$spec" --categories payments --api-id kestrel-payments-api --strictness "${STRICTNESS:-standard}" > "$out" 2>&1
  rc=$?
  # the script prints the JSON report first, then 3 summary lines
  awk '/^Totals across/{exit} {print}' "$out" | jq -r '
      "rulesets: " + ([.rulesets[] | "\(.name) (action=\(.action)) errors=\(.error_count) warns=\(.warn_count)"] | join(" | ")),
      (.issues[] | select(.severity=="error") | "  ERROR  \(.rule_id)  at \(.path)\n         fix: \(.how_to_fix[0:140])")' 2>/dev/null || cat "$out"
  grep -E '^(Totals|Counting|Result)' "$out"
  echo ">>> exit code: $rc  ($( [[ $rc -eq 0 ]] && echo "pipeline continues" || echo "pipeline FAILS" ))"
  rm -f "$out"
done
