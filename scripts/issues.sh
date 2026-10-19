#!/usr/bin/env bash
# Lists the governance issues recorded against an API. Usage: issues.sh "Kestrel Payments API" [error|warn|info]
set -euo pipefail
source "$(dirname "$0")/env.sh"
id="$(api_id_by_name "${1:-Kestrel Payments API}")"
sev="${2:-}"
dash GET "/api/governance/evaluation-details/$id?p=-1${sev:+&severity=$sev}" \
| jq -r '.violations[]? // .issues[]? // .[]? | select(type=="object") | "\(.severity // .severity_label)\t\(.ruleset_id)\t\(.rule_id // .rule)\t\(.path // .location // "")\t\(.message // "")"' 2>/dev/null \
|| dash GET "/api/governance/evaluation-details/$id?p=-1${sev:+&severity=$sev}" | jq .
