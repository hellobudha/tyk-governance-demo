#!/usr/bin/env bash
# Removes every demo object from the cluster. The Operator deletes the matching rulesets and APIs
# from the Dashboard. The stack itself stays up; use down.sh to delete the cluster.
set -euo pipefail
source "$(dirname "$0")/env.sh"
echo "== Deleting TykRulesets"; k delete tykrulesets -l demo=kestrel-governance --ignore-not-found
echo "== Deleting TykOasApiDefinitions"; k delete tykoasapidefinitions -l demo=kestrel-governance --ignore-not-found
echo "== Deleting ConfigMaps"; k delete configmaps -l demo=kestrel-governance --ignore-not-found
echo "== Done."
