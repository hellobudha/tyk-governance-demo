#!/usr/bin/env bash
# governance-check.sh - evaluate an OAS file against Tyk Governance rulesets from CI.
# Reference script from https://tyk.io/docs/tyk-governance/cicd-checks
#
# Usage:
#   ./governance-check.sh <spec-file> (--categories a,b | --ruleset-ids a,b) [--api-id id] [--api-name name] [--strictness strict|standard|permissive]
#
# Requires: curl, jq
# Env vars: TYK_DASHBOARD_URL, TYK_DASHBOARD_TOKEN
#
# --strictness (default: standard)
#   strict:      fail the build on any Error or Warn severity issue
#   standard:    fail the build only on Error severity issues (matches the Dashboard's own compliance definition)
#   permissive:  never fail on severity, just report. The check still fails if it couldn't run at all
#                (bad response, or the response was truncated)
#
# Only rulesets whose action is not "none" count toward the pass/fail decision:
# action: "none" means visibility-only in the Dashboard too (no Deployment Warning),
# so a violation on one of those rulesets is reported but never fails the build,
# regardless of strictness.
set -euo pipefail
SPEC_FILE="${1:?Usage: $0 <spec-file> (--categories a,b | --ruleset-ids a,b) [--api-id id] [--api-name name] [--strictness strict|standard|permissive]}"
shift
CATEGORIES=""
RULESET_IDS=""
API_ID=""
API_NAME=""
STRICTNESS="standard"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --categories) CATEGORIES="$2"; shift 2 ;;
    --ruleset-ids) RULESET_IDS="$2"; shift 2 ;;
    --api-id) API_ID="$2"; shift 2 ;;
    --api-name) API_NAME="$2"; shift 2 ;;
    --strictness) STRICTNESS="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done
: "${TYK_DASHBOARD_URL:?Set TYK_DASHBOARD_URL}"
: "${TYK_DASHBOARD_TOKEN:?Set TYK_DASHBOARD_TOKEN}"
if [[ -z "$CATEGORIES" && -z "$RULESET_IDS" ]]; then
  echo "Provide either --categories or --ruleset-ids" >&2
  exit 2
fi
if [[ -n "$CATEGORIES" && -n "$RULESET_IDS" ]]; then
  echo "Provide either --categories or --ruleset-ids, not both" >&2
  exit 2
fi
case "$SPEC_FILE" in
  *.yaml|*.yml) CONTENT_TYPE="application/yaml" ;;
  *.json) CONTENT_TYPE="application/json" ;;
  *) echo "Unrecognized file extension on $SPEC_FILE (expected .yaml, .yml or .json)" >&2; exit 2 ;;
esac
QUERY="categories=${CATEGORIES}"
[[ -n "$RULESET_IDS" ]] && QUERY="ruleset_ids=${RULESET_IDS}"
[[ -n "$API_ID" ]] && QUERY="${QUERY}&api_id=${API_ID}"
[[ -n "$API_NAME" ]] && QUERY="${QUERY}&api_name=${API_NAME}"
RESP="$(curl -sS -X POST \
  "${TYK_DASHBOARD_URL}/api/evaluations/sandbox/oas?${QUERY}" \
  -H "Authorization: Bearer ${TYK_DASHBOARD_TOKEN}" \
  -H "Content-Type: ${CONTENT_TYPE}" \
  --data-binary "@${SPEC_FILE}")"
if ! echo "$RESP" | jq -e '.rulesets' >/dev/null 2>&1; then
  echo "Unexpected response from Tyk Dashboard:" >&2
  echo "$RESP" >&2
  exit 2
fi
echo "$RESP" | jq .
ERROR_FIELD="$(echo "$RESP" | jq -r '.error')"
TRUNCATED="$(echo "$RESP" | jq -r '.truncated')"
if [[ "$ERROR_FIELD" != "null" || "$TRUNCATED" == "true" ]]; then
  echo "Evaluation returned an error, or the response was truncated. Treating this as a failed check regardless of strictness." >&2
  exit 2
fi
TOTAL_ERRORS="$(echo "$RESP" | jq -r '.error_count')"
TOTAL_WARNS="$(echo "$RESP" | jq -r '.warn_count')"
# Only rulesets with action != "none" gate the build; see the note at the top of this file.
GATING_ERRORS="$(echo "$RESP" | jq -r '[.rulesets[] | select(.action != "none") | .error_count] | add // 0')"
GATING_WARNS="$(echo "$RESP" | jq -r '[.rulesets[] | select(.action != "none") | .warn_count] | add // 0')"
echo "Totals across all rulesets: ${TOTAL_ERRORS} error(s), ${TOTAL_WARNS} warning(s)."
echo "Counting only rulesets with action != none: ${GATING_ERRORS} error(s), ${GATING_WARNS} warning(s)."
if [[ "$GATING_ERRORS" -gt 0 ]]; then
  RESULT_CODE=2
  echo "Result: non-compliant."
elif [[ "$GATING_WARNS" -gt 0 ]]; then
  RESULT_CODE=1
  echo "Result: compliant, with warnings."
else
  RESULT_CODE=0
  echo "Result: compliant."
fi
case "$STRICTNESS" in
  strict)     exit "$RESULT_CODE" ;;
  standard)   [[ "$RESULT_CODE" -eq 2 ]] && exit 2 || exit 0 ;;
  permissive) exit 0 ;;
  *) echo "Unknown --strictness value: $STRICTNESS (expected strict, standard, or permissive)" >&2; exit 2 ;;
esac
