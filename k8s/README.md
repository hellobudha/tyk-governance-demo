# Tyk Governance demo on Kubernetes (Tyk Operator 1.5)

The same Kestrel Charging story as the Docker version in the parent folder, run the way Kestrel's platform
team would actually run it: every API and every governance ruleset is a Kubernetes manifest, applied with
`kubectl`, reconciled into Tyk Dashboard 5.15 by **Tyk Operator 1.5.0**. The Operator adds the one thing the
Dashboard deliberately does not do: a hard block, at `kubectl apply` time, through an admission webhook.

See [WALKTHROUGH.md](WALKTHROUGH.md) for the presenter script. Verified end to end on 1 October 2026.

## What runs

Everything lives in one `kind` cluster called `kestrel`, namespace `tyk`:

| Component | How | Why |
|---|---|---|
| Tyk Dashboard 5.15.0, Tyk Gateway 5.15.0, Tyk Operator 1.5.0 | `tyk-helm/tyk-stack` chart 5.4.1 with [values.yaml](values.yaml) | One chart, one release. Its bootstrap job creates the org, the admin user and the Operator's credentials secret. Pump and Portal are off. |
| Redis 7, PostgreSQL 16 | [manifests/00-datastores.yaml](manifests/00-datastores.yaml), plain Deployments; Postgres on a 1Gi PersistentVolumeClaim | Lean, and the org, admin user and Operator credentials survive a Docker Desktop restart. |
| cert-manager v1.19.1 | upstream release manifest | The Operator's admission webhook needs a serving certificate. |
| Dashboard on http://localhost:3100, Gateway on http://localhost:8180 | kind port mappings to pinned NodePorts | Coexists with tyk-demo, which owns 3000 and 8080. |

## Layout

| Path | Purpose |
|---|---|
| `kind-config.yaml` | One-node kind cluster with the two host port mappings. |
| `values.yaml` | Chart values: images pinned to 5.15.0 / 1.5.0, Operator on, Pump off, webhook `governanceFailurePolicy: Fail`. Licence keys are passed on the command line, never stored here. |
| `manifests/00-datastores.yaml` | Namespace, Redis, PostgreSQL (with a PersistentVolumeClaim). |
| `manifests/10-internal-apis.yaml` | Kestrel's existing estate: Tariffs API and Charge Points API, category `internal`, as `TykOasApiDefinition` + ConfigMap. |
| `manifests/11-kestrel-payments-api.yaml` | Ines's API, category `payments`. The OAS comes from a revisioned ConfigMap created from `../apis/*.json`. |
| `manifests/20-payments-security-baseline.yaml` | Rob's `TykRuleset` from the OWASP template, `action: warn`, inline `ruleset.raw`. |
| `manifests/21-kestrel-platform-standards.yaml` | Rob's house rules as a `TykRuleset` with `ruleset.objRef` pointing at a ConfigMap built from `../rulesets/kestrel-platform-standards.json`. `action: none`. |
| `manifests/22-payments-security-baseline-tuned.yaml` | Same ruleset, https-servers rule downgraded to `warn`. |
| `manifests/23-payments-security-baseline-block.yaml` | Same ruleset with `action: block`. |
| `manifests/24-design-standards.yaml` | Rob's Thursday preview: OpenAPI Best Practices template, category `internal`, `action: none`. |
| `scripts/up.sh` / `down.sh` | Create or delete the whole thing. |
| `scripts/seed.sh` | Monday morning: internal APIs plus Ines's first push. `--with-rulesets` to start at Act 3. |
| `scripts/ines-push.sh monday\|gateway-fixed\|fixed` | Publish a spec revision: new ConfigMap, update the `TykOasApiDefinition`, go through the webhook. |
| `scripts/rob-tune.sh [--revert]` | Apply the tuned ruleset. |
| `scripts/block-demo.sh [--revert]` | Switch to `action: block` and attempt a bad rollback. |
| `scripts/ci-demo.sh` | The unchanged `../scripts/governance-check.sh` from the Tyk docs, against the in-cluster Dashboard. |
| `scripts/status.sh` | `kubectl get` for rulesets and APIs (with `PREFLIGHTSTATUS`) plus the Dashboard's compliance view. |
| `scripts/reset.sh` | Delete the demo objects; the Operator removes them from the Dashboard. |

## Recorded walkthrough

[videos/](videos/) holds five narrated videos, one per part of the week, recorded against this cluster:

| File | Part |
|---|---|
| `01-monday-setting-the-standard.mp4` | The problem, the cast, and Rob committing both rulesets |
| `02-tuesday-ines-finds-out.mp4` | Ines sees the verdict and the fix for every failure |
| `03-tuesday-the-fix-and-the-handoff.mp4` | Two pushes with preflight warnings, one bad rule handed back to Rob |
| `04-wednesday-the-check-moves-into-the-pull-request.mp4` | The same check in CI, with exit codes |
| `05-thursday-friday-the-hard-block-and-the-week-in-review.mp4` | `action: block`, and the week in review |

Each opens with the day and what the part is about, keeps a running timer, and explains every step in a
footer below the screen. [recording/](recording/README.md) re-creates them.

## Prerequisites

- Docker Desktop, `kind`, `kubectl`, `helm`, `curl`, `jq`.
- A Tyk licence whose scope includes `governance`. `up.sh` reads `DASHBOARD_LICENCE` from
  `~/projects/tyk-demo/.env` unless `TYK_LICENCE` is set. The same key is used for the Operator, as tyk-demo does.

## Quick start

```bash
cd ~/projects/tyk-governance-demo/k8s
./scripts/up.sh                  # 3 to 5 minutes the first time (image pulls)
./scripts/seed.sh                # Monday: APIs in, no rulesets yet
./scripts/status.sh              # PREFLIGHTSTATUS skipped everywhere
kubectl -n tyk apply -f manifests/20-payments-security-baseline.yaml   # Act 1
kubectl -n tyk apply -f manifests/21-kestrel-platform-standards.yaml   # Act 2
./scripts/ines-push.sh gateway-fixed   # Act 4: kubectl prints the preflight warning
./scripts/ines-push.sh fixed
./scripts/rob-tune.sh                  # Act 5
./scripts/ci-demo.sh                   # Act 6
./scripts/block-demo.sh                # Act 8: the webhook denies the rollback
./scripts/block-demo.sh --revert
./scripts/reset.sh && ./scripts/seed.sh   # back to Monday
./scripts/down.sh                         # delete the cluster
```

Dashboard login: `rob.whitfield@kestrelcharging.example`, password in `values.yaml` (also in the
`tyk-dashboard-login-details` secret).

If Docker Desktop or the kind node restarts, the stack comes back on its own. Postgres and Redis both keep their
data on volumes; Redis matters because the Dashboard keeps user API key sessions there, and an empty Redis turns
every API key, the Operator's included, into a 401. If the Operator ever logs `HTTP 401` after a reinstall, it started before the bootstrap job rewrote
`tyk-operator-conf`: `kubectl -n tyk rollout restart deploy/tyk-stack-tyk-operator-controller-manager`
(`up.sh` does this automatically).

## Two things to know before presenting

- **Why ConfigMaps are revisioned.** The Operator's webhook validates `TykOasApiDefinition` create and update
  requests, not ConfigMap edits. If the OAS were edited in place, the reconciler would sync it without an
  admission decision. Each spec revision therefore gets its own ConfigMap (`kestrel-payments-api-<sha>`), and the
  `TykOasApiDefinition` is pointed at it, which is exactly what kustomize's `configMapGenerator` produces. A denied
  apply leaves the previous revision in place.
- **Cluster counts differ from Dashboard counts, on purpose.** The preflight evaluates the manifest as written.
  The Dashboard evaluates the stored API, to which it adds the gateway's own server URLs
  (`http://gateway-svc-...:8080/payments` and `/payments`). Those two `http://` entries are two extra
  `owasp-security-hosts-https-oas3` errors in the Dashboard. The story uses that: Rob tunes the rule in Act 5.
