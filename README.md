# Tyk Governance demo (Tyk Dashboard 5.15)

Working demo of the API Governance capability that shipped **inside Tyk Dashboard 5.15.0** (1 September 2026)
and Tyk Operator 1.5.0 (23 September 2026). It runs on top of the standard `tyk-demo` stack.

> Do **not** use `./up.sh governance` in tyk-demo. That folder is the deprecated 2025 standalone
> "Governance Hub" proof of concept (tykio/governance-api v0.2.0). Governance now lives in the Dashboard.

See [WALKTHROUGH.md](WALKTHROUGH.md) for the full presenter script.

There is also a **Kubernetes version** driven entirely through Tyk Operator 1.5 in [k8s/](k8s/README.md):
same story, same acts, rulesets and APIs as manifests, plus the Operator-only hard block at `kubectl apply` time.

## The story

The demo follows one week at **Kestrel Charging**, a fictional EV charging network with about 2,400 charge
points across the UK.

- **Ines Ferreira**, backend engineer on the Payments squad, has to ship the **Kestrel Payments API** by Friday.
  Northline Fleet, a partner running 900 vans, is launching pay-from-your-own-app charging on Monday and
  their integration depends on it.
- **Rob Whitfield**, API platform lead, reviews every new API by hand. About two hours each, six in the queue.
  Since the March incident (an unauthenticated internal tariff API scraped by a price-comparison bot, upstream
  down for 40 minutes) he has a standards page in Confluence that nobody reads before they ship.

Rob defines the standard once (Acts 1 and 2). Ines finds out what is wrong and how to fix it without a review
meeting (Acts 3 and 4). Rob tunes the standard instead of the API (Act 5). Ines puts the same check in her
pull-request pipeline so the next change never reaches Rob's queue broken (Act 6). Friday ships.

## Layout

| Path | Purpose |
|---|---|
| `apis/payments-api.json` | Deliberately **non-compliant** Tyk OAS API ("Kestrel Payments API"): keyless, no rate limit, integer IDs, no operationIds, http server URL. |
| `apis/payments-api-fixed.json` | The same API after Ines's remediation. Passes every Error-level rule in both rulesets. |
| `rulesets/kestrel-platform-standards.json` | Rob's house rules. Custom Spectral-format ruleset that checks the **Tyk gateway configuration** (`x-tyk-api-gateway`) as well as the OpenAPI document. |
| `scripts/setup.sh` | Prepares tyk-demo: tags 4 existing OAS APIs `internal`, imports the payments API tagged `payments`, creates the custom ruleset. `--with-owasp` also creates the OWASP-based ruleset via API. |
| `scripts/status.sh` | Rulesets + compliance status per categorised API (uses the Governance API). |
| `scripts/issues.sh` | Lists recorded issues for an API, optionally filtered by severity. |
| `scripts/remediate.sh` | "Ines pushes the fix from the repo": replaces the saved API with the fixed spec. `--revert` undoes it. |
| `scripts/tune-ruleset.sh` | "Rob tunes the rule": downgrades the OWASP https-servers rule to Warn. `--revert` undoes it. |
| `scripts/ci-demo.sh` | Runs the CI/CD check against the bad and the fixed spec and shows the exit codes. |
| `scripts/governance-check.sh` | The reference pipeline script from the Tyk docs, unchanged. |
| `scripts/reset.sh` | Deletes everything the demo created so it can be recorded again. |
| `scripts/env.sh` | Reads the Dashboard URL and admin API key from `~/projects/tyk-demo/.context-data`. |

## Prerequisites

- `tyk-demo` running with `DASHBOARD_VERSION=v5.15.0` and a Dashboard licence whose `scope` includes `governance`
  (check with `GET /api/rulesets`: 200 means enabled, 403 means the licence claim is missing).
- `curl` and `jq`.

## Quick start

```bash
cd ~/projects/tyk-governance-demo
./scripts/setup.sh            # environment ready for the live walkthrough
./scripts/status.sh           # what governance currently thinks
./scripts/ci-demo.sh          # pipeline check: bad spec fails (exit 2), fixed spec passes (exit 0)
./scripts/reset.sh            # back to a clean slate
```

Dashboard: http://tyk-dashboard.localhost:3000 (credentials in `tyk-demo/.context-data/1_dashboard-user_1_*`).
Governance UI: **Governance > Rulesets** at http://tyk-dashboard.localhost:3000/governance/rulesets
