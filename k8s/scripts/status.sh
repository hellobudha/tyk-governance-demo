#!/usr/bin/env bash
# What the cluster thinks (kubectl) and what the Dashboard thinks (Governance API) about every demo API.
set -euo pipefail
source "$(dirname "$0")/env.sh"
echo "== TykRulesets"; k get tykrulesets 2>/dev/null || echo "   none"
echo "== TykOasApiDefinitions (PREFLIGHTSTATUS: passed | warned | blocked | error | skipped)"; k get tykoasapidefinitions
echo "== Dashboard compliance"
for cr in $(k get tykoasapidefinitions -o name); do
  name="$(k get "$cr" -o jsonpath='{.metadata.name}')"
  id="$(k get "$cr" -o jsonpath='{.status.id}')"
  [[ -z "$id" ]] && continue
  cats="$(k get "$cr" -o jsonpath='{.spec.categories}')"
  dash GET "/api/governance/apis/$id/compliance" | jq -r --arg n "$name" --arg c "$cats" '
    "  \($n) \($c): \(.overall_status // "n/a")" + ((.rulesets // []) | map("\n      - \(.ruleset_name): \(.compliance // .status) errors=\(.error_count) warnings=\(.warn_count) score=\(.compliance_level // "n/a")") | join(""))' 2>/dev/null \
    || echo "  $name: no compliance record yet"
done
