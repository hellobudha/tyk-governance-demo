#!/usr/bin/env bash
# Shared environment for the Tyk Governance demo scripts.
# Reads the Dashboard admin user's API key from the tyk-demo bootstrap context.
TYK_DEMO_DIR="${TYK_DEMO_DIR:-$HOME/projects/tyk-demo}"
export TYK_DASHBOARD_URL="${TYK_DASHBOARD_URL:-http://tyk-dashboard.localhost:3000}"
export TYK_DASHBOARD_TOKEN="${TYK_DASHBOARD_TOKEN:-$(cat "$TYK_DEMO_DIR/.context-data/1_dashboard-user_1_api-key" 2>/dev/null || true)}"
if [[ -z "$TYK_DASHBOARD_TOKEN" ]]; then
  echo "ERROR: could not read the Dashboard API key from $TYK_DEMO_DIR/.context-data. Is tyk-demo bootstrapped?" >&2
  exit 1
fi
DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dash() { # dash METHOD PATH [curl args...]
  local method="$1" path="$2"; shift 2
  curl -sS -X "$method" "$TYK_DASHBOARD_URL$path" -H "Authorization: $TYK_DASHBOARD_TOKEN" "$@"
}
api_id_by_name() { # api_id_by_name "OAS HTTPbin"
  dash GET "/api/apis?p=-1" | jq -r --arg n "$1" '.apis[] | select(.api_definition.name==$n) | .api_definition.api_id' | head -1
}
ruleset_id_by_name() {
  dash GET "/api/rulesets?p=-1" | jq -r --arg n "$1" '.rulesets[] | select(.name==$n) | .ruleset_id' | head -1
}
