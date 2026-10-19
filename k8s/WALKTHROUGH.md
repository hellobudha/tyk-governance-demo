# Tyk Governance on Kubernetes: end-to-end demo walkthrough (Tyk Operator 1.5)

A presenter script for the API Governance capability in Tyk Dashboard 5.15.0, driven entirely through
Tyk Operator 1.5.0 (23 September 2026). Everything in it was run and verified on a kind cluster on
1 October 2026 with Dashboard v5.15.0, Gateway v5.15.0, Operator v1.5.0 and the tyk-stack chart 5.4.1.

Runtime: about 15 minutes for the core story (Acts 1 to 6), 20 to 25 minutes with the optional acts.

It is the same week at Kestrel Charging as the Docker walkthrough in the parent folder. What changes is where
the work happens: Rob and Ines never create anything in the Dashboard UI. Rulesets and APIs are YAML in a repo,
`kubectl apply` is the deployment, the Operator keeps the Dashboard in sync, and the Dashboard is where
everyone reads the result.

---

## Part 1. The story and the context

### One week at Kestrel Charging

**Kestrel Charging** is a fictional EV charging network with about 2,400 charge points across the UK. Its APIs
run on Kubernetes and are managed as code: every API is a `TykOasApiDefinition`, reconciled into Tyk by the
Operator. Two people carry the story.

| Who | Role in the story |
|---|---|
| **Ines Ferreira**, backend engineer, Payments squad | Has to ship the **Kestrel Payments API** by Friday. Northline Fleet, a partner running 900 vans, launches pay-from-your-own-app charging on Monday and their integration depends on it. Her PR merged on Monday morning and CI applied the manifest to the cluster. |
| **Rob Whitfield**, API platform lead | Owns the cluster and the standards. Reviews every new API by hand: about two hours each, six in the queue, Ines's is number four. In March an internal tariff API went live keyless, a price-comparison bot scraped it and took the upstream down for 40 minutes on a Saturday. Since then Rob has a standards page in Confluence. Nobody reads it before they `kubectl apply`. |
| **Northline Fleet** | The partner. Their driver app will call the Payments API. They never appear on screen; they are the deadline. |

The arc, day by day:

- **Monday** (Acts 0 to 2): Rob stops reviewing by hand. He commits two `TykRuleset` manifests: the OWASP
  template, and the two rules the March incident taught him.
- **Tuesday** (Acts 3 to 5): Ines finds out what is wrong, in the Dashboard and in `kubectl describe`, with the
  fix next to each failure. Her next `kubectl apply` prints a preflight warning. One finding is the environment's
  fault, not hers, so Rob changes one line of YAML instead of her API.
- **Wednesday** (Act 6): Ines adds the same check to the pull-request pipeline, so the verdict arrives before
  anything touches the cluster.
- **Thursday** (Acts 7 and 8, optional): Rob previews a design standard, then switches the payments baseline to
  `action: block`. A bad rollback is refused by the API server itself.
- **Friday** (Close): the Payments API is compliant, Northline is on track, Rob's review took zero hours.

### What Governance is in 5.15, and what the Operator adds

- A **universal API governance hub built into Tyk Dashboard**. No separate product, no agent, no extra install.
  It is a licence claim (`governance` scope) that your account team enables per organisation. Without it every
  governance endpoint returns `403`, and the Operator records every preflight as `skipped`.
- **Rulesets** are Spectral-format, executed by **Vacuum**, a Go engine that is fully Spectral-compatible. Existing
  Spectral rulesets import as-is, in the UI, through the API, or as a `TykRuleset` manifest.
- Rulesets are **scoped through API Categories**. On Kubernetes a category is one line in the manifest:
  `spec.categories: [payments]`. Governance is opt-in: no categories, no evaluation.
- Rules check the **OpenAPI document and the Tyk gateway configuration** (`x-tyk-api-gateway`). That is the part
  no generic linter can reach, and the part that hurt Kestrel in March.
- **Severity drives compliance**: one Error-level finding makes an API Non-compliant.
- **Three actions.** `none` is visibility only. `warn` is the Dashboard's Deployment Warning; in the cluster it
  also makes `kubectl apply` print a preflight warning. `block` exists only in the Operator: the admission webhook
  denies a `TykOasApiDefinition` create or update that has Error-level findings. The Dashboard stores a `block`
  ruleset as `warn`, so the UI and the CI check behave the same as before.
- **Same engine everywhere.** The webhook, the reconciler, the CI script and the Dashboard all call the same
  evaluation. The Operator resolves the matching rulesets to explicit IDs and calls the sandbox endpoint.
- Tyk OAS APIs only at launch. The Operator governs `TykOasApiDefinition` only.

### What changed since last year (say this if anyone remembers the 2025 preview)

The 2025 "Governance Hub" (standalone dashboard + agents, multi-gateway discovery) was a proof of concept with two
customers. The learning was that a second product outside the workflow kills adoption. It was deprecated and
governance was rebuilt natively into the Dashboard, and now into the Operator, which is where Kestrel's workflow
already lives.

### Talking points from the internal Release 1 showcase (August 2026)

- The problem: manual governance built for dozens of APIs does not scale to hundreds or thousands.
  Northwestern Mutual: 500+ APIs governed by a 3 to 4 person team. RBFCU: 2+ hours per API review,
  3 to 4 reviews a week. About 20% of deployments need rework because of late policy violations.
- Customer quotes: "Telling someone no isn't helpful. It needs to be no, and here's what to do instead."
  (NextEra). "Everything as code. Via Tyk Operator, I want warnings or errors before deploying an API." (Liebherr).
  The Liebherr quote is this demo.
- Three pillars: **Centralised Standards**, **Shift-Left Quality Gates**, **Compliance Visibility**.
- The workflow: **Define** → **Evaluate** → **See** → **Act**.
- The three shifts: standards on paper → enforced before production; governance as a bottleneck →
  a development accelerator; compliance as an audit event → a continuous state.
- Roadmap (customer-feedback driven, not committed): compliance reporting and scoring, notifications and
  webhooks, RBAC expansion, hard-block option in the UI, GraphQL and MCP governance.
- Top questions: not a separate product; Spectral rules import as-is; runs async; identical on Tyk Cloud and
  self-managed; the Operator needs cert-manager for the webhook certificate; `block` is Operator-only.

### Sources

- Docs: https://tyk.io/docs/tyk-governance/overview and https://tyk.io/docs/tyk-governance/tyk-operator
  (Governance via Tyk Operator: `TykRuleset` fields, webhook behaviour, status fields, events).
- Operator 1.5.0 release notes: https://tyk.io/docs/developer-support/release-notes/operator
- tyk-stack chart: https://tyk.io/docs/product-stack/tyk-charts/tyk-stack-chart
- Internal: "Showcase Tyk-API-Governance 2026" deck, Governance PRD R1 (Confluence, EN space).

---

## Part 2. Environment preparation (before you hit record)

### Prerequisites

- Docker Desktop running, plus `kind`, `kubectl`, `helm`, `curl`, `jq`.
- A Tyk licence whose scope includes `governance`. `scripts/up.sh` reads `DASHBOARD_LICENCE` from
  `~/projects/tyk-demo/.env` unless `TYK_LICENCE` is exported, and uses the same key for the Operator.
- Ports 3100 and 8180 free on the host. tyk-demo can stay up on 3000 and 8080.

### Bring the stack up

```bash
cd ~/projects/tyk-governance-demo/k8s
./scripts/up.sh
```

What it does, in order: creates the `kestrel` kind cluster; installs cert-manager v1.19.1; applies Redis and
PostgreSQL; installs `tyk-helm/tyk-stack` 5.4.1 with Dashboard 5.15.0, Gateway 5.15.0 and Operator 1.5.0;
waits for the chart's bootstrap job to create the org, the admin user and the `tyk-operator-conf` secret;
pins the NodePorts; confirms `GET /api/rulesets` returns `200`. First run is 3 to 5 minutes, mostly image pulls.

Do not add `--wait` to the Helm install. The bootstrap job that creates the Operator's secret is a post-install
hook, and Helm runs post-install hooks only after `--wait` is satisfied, which the Operator cannot be without
the secret.

### Seed Monday morning

```bash
./scripts/seed.sh
```

Applies the two internal APIs (Tariffs, Charge Points, category `internal`) and Ines's first push of the
Kestrel Payments API (category `payments`). No rulesets exist, so Rob creates them live in Acts 1 and 2.
To skip straight to Act 3: `./scripts/seed.sh --with-rulesets`.

### Have these open

- Browser tab 1: http://localhost:3100 logged in as `rob.whitfield@kestrelcharging.example` (password in
  `values.yaml`). You play both Rob and Ines from this login; say whose hands are on the keyboard.
- Terminal 1, "Rob": `cd ~/projects/tyk-governance-demo/k8s`, with `manifests/` visible in an editor.
- Terminal 2, "Ines": same directory, with `../apis/payments-api.json` open in the editor.
- Browser tab 2: https://tyk.io/docs/tyk-governance/tyk-operator for the docs moment.

### The cast of objects

| Thing | Role in the story |
|---|---|
| `TykOasApiDefinition/kestrel-payments-api` (category `payments`) | Ines's API. The OAS is in ConfigMap `kestrel-payments-api-<rev>`; each push is a new revision. Monday's spec: keyless, no rate limit, integer IDs, no operationIds, `http://` server. |
| `TykOasApiDefinition/kestrel-tariffs-api`, `.../kestrel-charge-points-api` (category `internal`) | The estate Rob's team already manages. Tariffs is the March API: authenticated now, upstream rate limit still missing. Charge Points has no operationIds. |
| `TykRuleset/payments-security-baseline` | Rob, Act 1. OWASP API Security template as inline `ruleset.raw`, `action: warn`, categories `[payments]`. |
| `TykRuleset/kestrel-platform-standards` | Rob, Act 2. House rules via `ruleset.objRef` to a ConfigMap built from `rulesets/kestrel-platform-standards.json`. `action: none`, categories `[payments, internal]`. |
| `apis/payments-api-gateway-fixed.json` | Ines's first fix: authentication and upstream rate limit in `x-tyk-api-gateway`, nothing else. |
| `apis/payments-api-fixed.json` | Ines's full fix. Passes every Error rule. |

---

## Part 3. The demo, act by act

Timings are a guide. Lines in *italics* are suggested narration. Command output below is what the cluster
printed on 1 October 2026; your IDs and timestamps will differ.

### Act 0. Monday, 09:10. Set the scene (1 min)

Terminal 1:

```bash
kubectl -n tyk get tykoasapidefinitions
```

```
NAME                        LISTENPATH        ENABLED   SYNCSTATUS   CATEGORIES     PREFLIGHTSTATUS
kestrel-charge-points-api   /charge-points/   true      Successful   ["internal"]   skipped
kestrel-payments-api        /payments/        true      Successful   ["payments"]   skipped
kestrel-tariffs-api         /tariffs/         true      Successful   ["internal"]   skipped
```

*"This is Kestrel Charging. Their APIs are Kubernetes manifests, and the Tyk Operator keeps the Dashboard in
sync with the cluster. It's Monday. Ines on the Payments squad merged the Kestrel Payments API half an hour ago
and CI applied it. Northline Fleet, 900 vans, launches pay-from-their-own-app charging next Monday, and this API
is what their app will call. Ines needs it in production by Friday."*

*"Rob runs the platform. Every new API goes through him: two hours a review, six in the queue, Ines is number
four. Since March, when a keyless tariff API got scraped and took the upstream down for 40 minutes, Rob has a
standards page in Confluence. Nobody reads it before they apply."*

Point at the `PREFLIGHTSTATUS` column: `skipped`, because there are no rulesets. Open the Dashboard **APIs**
list: the Governance Overview strip shows every API as N/A.

*"Let's give Rob a way to define the standard once, as code, and have every apply checked against it."*

### Act 1. Monday, 09:30. Rob commits the standard (3 min)

*"Rob's terminal."* Show `manifests/20-payments-security-baseline.yaml`:

```yaml
apiVersion: tyk.tyk.io/v1alpha1
kind: TykRuleset
metadata:
  name: payments-security-baseline
  namespace: tyk
spec:
  name: Payments Security Baseline
  active: true
  action: warn
  resourceType: oas-api
  categories: [payments]
  ruleset:
    raw: |
      extends:
        - ["spectral:owasp", "all"]
```

*"A ruleset is a Kubernetes resource. The whole definition is: extend the OWASP ruleset, all rules. It is bound
to the payments category, not to Ines's API, so the two APIs her squad ships next quarter are in scope the moment
they carry the tag. `action: warn` is the Dashboard's Deployment Warning. In the cluster it also means kubectl
tells you at apply time. It never blocks."*

```bash
kubectl -n tyk apply -f manifests/20-payments-security-baseline.yaml
kubectl -n tyk get tykrulesets
```

```
NAME                         NAME                         RULESETID                  ACTIVE   ACTION   SYNCSTATUS
payments-security-baseline   Payments Security Baseline   6abf246a6b059500012c9844   true     warn     Successful
```

*"The Operator created the ruleset in the Dashboard and wrote the Dashboard's ID back into the status."*

Dashboard: **Governance > Rulesets** now lists Payments Security Baseline, category `payments`, Deployment
Warning **Warn**. Open it: Rules overview, 23 rules with severities such as `owasp-no-numeric-ids: error`.

*"Nothing was blocked, no gateway was touched, and Ines's API was re-evaluated in the background the moment the
ruleset landed."*

```bash
kubectl -n tyk get tykoasapidefinition kestrel-payments-api
```

`PREFLIGHTSTATUS` is now `warned`.

### Act 2. Monday, 09:45. Rob writes down the March incident (2 min)

*"OWASP covers the spec. What actually hurt Kestrel in March was gateway configuration: an API published with no
authentication and no rate limit on the upstream. Generic linters can't see that. Tyk can, because the gateway
configuration is part of the Tyk OAS document. So Rob turns the incident review into rules."*

Show one rule in `../rulesets/kestrel-platform-standards.json`:

```json
"kestrel-upstream-rate-limit": {
  "description": "Every API must protect its upstream with a rate limit",
  "severity": "error",
  "given": "$['x-tyk-api-gateway'].upstream",
  "then": { "field": "rateLimit", "function": "truthy" },
  "howToFix": "In the API Designer open Settings > Upstream > Rate Limit and enable it, for example 100 requests per 60 seconds."
}
```

*"Standard Spectral: a JSONPath, a function, a severity, and `howToFix`. Whatever Rob writes there is what Ines
sees next to the failure."*

Show `manifests/21-kestrel-platform-standards.yaml`: `action: none`, categories `[payments, internal]`, and

```yaml
  ruleset:
    objRef:
      kind: ConfigMap
      name: kestrel-platform-standards
      keyName: ruleset.json
```

*"Same JSON file as the Docker demo and the CI check, mounted from a ConfigMap. Rob scopes it to internal too:
he wants to know how the existing estate measures up, without warning anyone yet. `action: none` is visibility
only."*

```bash
kubectl -n tyk apply -f manifests/21-kestrel-platform-standards.yaml
./scripts/status.sh
```

```
== TykOasApiDefinitions
NAME                        CATEGORIES     PREFLIGHTSTATUS
kestrel-charge-points-api   ["internal"]   warned
kestrel-payments-api        ["payments"]   warned
kestrel-tariffs-api         ["internal"]   warned
== Dashboard compliance
  kestrel-charge-points-api ["internal"]: non_compliant
      - Kestrel Platform Standards: non_compliant errors=2 warnings=3 score=62
  kestrel-payments-api ["payments"]: non_compliant
      - Payments Security Baseline: non_compliant errors=20 warnings=12 score=43
      - Kestrel Platform Standards: non_compliant errors=5 warnings=5 score=25
  kestrel-tariffs-api ["internal"]: non_compliant
      - Kestrel Platform Standards: non_compliant errors=1 warnings=1 score=75
```

*"Rob spent fifteen minutes and two commits. He hasn't opened Ines's API once. And he has learned that the
March API still has no upstream rate limit."*

### Act 3. Tuesday, 08:50. Ines finds out (3 min)

*"Tuesday morning. Ines logs in to carry on with the Payments API."*

1. Dashboard **home page**: red banner *"3 APIs are non-compliant..."* with **See Non-Compliant APIs**.
   *"Compliance is a continuous state. Rob changed the rules overnight and the answer was waiting for Ines when
   she logged in. No meeting was booked."*
2. **APIs** list: Governance Overview strip (3 total, 0 compliant, 3 non-compliant), Compliance column.
3. Open **Kestrel Payments API > Governance** tab: **Non-compliant**, 25 Errors, 17 Warnings. Two ruleset
   cards: Kestrel Platform Standards 25/100, Payments Security Baseline 43/100. Issues table with
   **Problem If Not Fixed** and **View Issue**.
4. **View Issue** on `kestrel-auth-configured`: Affected area `authentication`, **HOW TO FIX**: *"In the API
   Designer open Settings > Authentication, switch from Keyless..."*.
   *"Rob's words, from the incident review, next to Ines's failure. No, and here's what to do instead."*
5. *"Ines lives in the terminal, so she also looks there."* Terminal 2:

```bash
kubectl -n tyk describe tykoasapidefinition kestrel-payments-api | sed -n '/Governance Preflight/,/Message/p'
```

```
  Governance Preflight:
    Effective Action:  warn
    Error Count:       23
    Evaluated At:      2026-10-02T03:26:40Z
    Info Count:        3
    Message:           preflight warned: 23 error(s), 17 warning(s) — owasp-integer-format (components.schemas.NewPayment.properties.amount): ...
    Status:            warned
    Warn Count:        17
```

```bash
kubectl -n tyk get events --field-selector involvedObject.name=kestrel-payments-api
```

shows `GovernancePreflightWarned` events, one per evaluation.

*"Twenty-three errors in the cluster, twenty-five in the Dashboard. The Dashboard evaluates the stored API,
and it adds the gateway's own server URLs to it. Keep that in mind; it comes back on Tuesday afternoon."*

### Act 4. Tuesday, 09:15. Ines fixes it, and kubectl warns her (3 min)

*"Two of the errors are gateway settings. Ines fixes them in the Tyk vendor extension of her OpenAPI file,
opens a PR, and CI applies it. In this demo the script plays CI."* Show the diff between
`../apis/payments-api.json` and `../apis/payments-api-gateway-fixed.json`: `server.authentication` and
`upstream.rateLimit` added, nothing else.

```bash
./scripts/ines-push.sh gateway-fixed
```

```
== ConfigMap kestrel-payments-api-fe0b22accc  <- apis/payments-api-gateway-fixed.json
== kubectl apply TykOasApiDefinition kestrel-payments-api -> configmapRef kestrel-payments-api-fe0b22accc
Warning: preflight warned: 20 error(s), 17 warning(s) — owasp-integer-format (components.schemas.NewPayment.properties.amount): schema of type `integer` must specify a format of `int32` or `int64`; ...
tykoasapidefinition.tyk.tyk.io/kestrel-payments-api configured
```

*"That Warning line is the Deployment Warning, in the terminal, at apply time. The apply went through, because
the ruleset says warn. Ines keeps the decision, but she cannot say she didn't know, and neither can Rob."*

*"Each spec revision is its own ConfigMap, the way kustomize's configMapGenerator does it, and the
TykOasApiDefinition is pointed at the new one. That update is what the webhook evaluates."*

Dashboard **Governance** tab, refresh: Kestrel Platform Standards drops from 5 errors to 3 (the three missing
operationIds). *"The two March rules, fixed in one commit."*

*"The rest, uuid IDs, string limits, error responses, operationIds, is OpenAPI work. Ines does it in the same
repo and pushes again."*

```bash
./scripts/ines-push.sh fixed
```

```
tykoasapidefinition.tyk.tyk.io/kestrel-payments-api configured
NAME                   ...   CATEGORIES     PREFLIGHTSTATUS
kestrel-payments-api   ...   ["payments"]   passed
{"effectiveAction":"none","message":"preflight passed: 0 error(s), 0 warning(s)","status":"passed"}
```

No warning this time. *"The cluster says passed."* Now the Dashboard **Governance** tab: Kestrel Platform
Standards **Compliant**, 100/100. Payments Security Baseline: 2 errors, both `owasp-security-hosts-https-oas3`,
on `servers.0.url` and `servers.1.url`.

*"Here it is. The Dashboard added `http://gateway-svc-tyk-stack-tyk-gateway.tyk.svc:8080/payments` and
`/payments` to the servers list: the in-cluster gateway address and the relative path. Neither is in Ines's
file. At Kestrel TLS terminates at the edge, so the rule is right in general and wrong for this environment.
Ines messages Rob: 'the https rule is firing on URLs the Dashboard adds, not on anything in my spec.' Rob tunes
the standard, not the API."*

### Act 5. Tuesday, 11:20. Rob changes one line (2 min)

*"Rob's terminal."*

```bash
./scripts/rob-tune.sh
```

The script prints the diff between the two manifests, then applies the tuned one:

```
>       rules:
>         owasp-security-hosts-https-oas3: warn
tykruleset.tyk.tyk.io/payments-security-baseline configured
...
  kestrel-payments-api ["payments"]: compliant
      - Payments Security Baseline: compliant errors=0 warnings=2 score=95
      - Kestrel Platform Standards: compliant errors=0 warnings=0 score=100
```

*"Spectral semantics: extend the template, override one rule's severity. Rob keeps it as a warning rather than
off, because it should still fire when a squad publishes a real http upstream. The Operator updated the ruleset
in the Dashboard, the Dashboard re-evaluated every payments API, and the Operator requeued the matching
TykOasApiDefinitions."*

Dashboard: **Kestrel Payments API > Governance** is **Compliant**, 0 errors, 2 warnings. **APIs** list:
1 compliant, 2 non-compliant. Home banner down to 2.

*"Tuesday lunchtime. Ines's API is compliant. Rob's total time on it: one Slack message and a two-line commit."*

### Act 6. Wednesday. Ines shifts left into the pipeline (3 min)

*"Everything so far happened at apply time or after. Northline will ask for changes after launch, and Ines
wants the verdict in the pull request, before anything touches the cluster. Same rulesets, same engine, one HTTP
call to the Dashboard's sandbox endpoint."*

Show the core of `../scripts/governance-check.sh`, the reference script from the Tyk docs:

```bash
curl -sS -X POST "$TYK_DASHBOARD_URL/api/evaluations/sandbox/oas?categories=payments&api_id=kestrel-payments-api" \
  -H "Authorization: Bearer $TYK_DASHBOARD_TOKEN" -H "Content-Type: application/json" \
  --data-binary @apis/payments-api.json
```

```bash
./scripts/ci-demo.sh
```

Monday's spec: both rulesets resolved from the `payments` category, 22 errors and 18 warnings in total, 17
errors on the gating ruleset, each with `how_to_fix`, `Result: non-compliant.`, **exit code 2, pipeline fails**.
Then `payments-api-fixed.json`: 0 errors, `Result: compliant.`, **exit code 0**.

*"Monday's version would never have reached the cluster. The PR would have failed with the same messages Ines
read on Tuesday, before Rob knew the API existed. And if it had reached the cluster anyway, the webhook would
have said the same thing, because it is the same evaluation."*

Points to make: `--categories payments` tracks whatever Rob links to the category; `--strictness` chooses
errors-only (default), warnings too, or report-only; only rulesets whose action is not `none` gate the build,
matching the Dashboard; nothing is persisted, it is a sandbox call. GitHub Actions, GitLab and Jenkins snippets
are on the docs page CI/CD Governance Checks.

### Act 7 (optional). Thursday. Rob previews a design standard (1 min)

*"With the incident rules in place, Rob wants to raise the bar on the internal estate without surprising four
squads with a new red banner. He previews first."*

Show `manifests/24-design-standards.yaml`: the **OpenAPI Best Practices** template (`spectral:oas`,
`recommended`), category `internal`, `action: none`. Commit and apply it like the others:

```bash
kubectl -n tyk apply -f manifests/24-design-standards.yaml
```

Then Dashboard: **Kestrel Payments API > Governance > Test ruleset**, select **Design Standards** (it is not
linked to `payments`), **Run**.

*"A dry run. The panel runs any ruleset against this API, even one that isn't linked to it. Results are not
stored and the compliance status does not change, so Rob can talk the findings through with the squad before
anything turns red."*

### Act 8. Thursday. Rob turns on the hard block (2 min)

*"This is the one place where governance can say no outright. Rob changes one word."* Show
`manifests/23-payments-security-baseline-block.yaml`: identical to the tuned ruleset, `action: block`.

```bash
./scripts/block-demo.sh
```

```
== Rob: action warn -> block
tykruleset.tyk.tyk.io/payments-security-baseline configured
NAME                         ...   ACTIVE   ACTION   SYNCSTATUS
payments-security-baseline   ...   true     block    Successful

== Someone pushes Monday's spec again (a bad rollback)...
== ConfigMap kestrel-payments-api-c306704ccc  <- apis/payments-api.json
== kubectl apply TykOasApiDefinition kestrel-payments-api -> configmapRef kestrel-payments-api-c306704ccc
Error from server (Forbidden): ... admission webhook "vtykoasapidefinition.kb.io" denied the request:
governance preflight blocked this API (22 error(s)):
  - owasp-integer-format (components.schemas.NewPayment.properties.amount): schema of type `integer` must specify a format of `int32` or `int64`
  - owasp-integer-format (components.schemas.Payment.properties.amount): ...
  - owasp-integer-format (components.schemas.Payment.properties.id): ...
  - owasp-integer-format (paths./payments/{paymentId}.get.parameters.0.schema): ...
  - owasp-integer-limit (components.schemas.NewPayment.properties.amount): ...
Fix the violations or relax the ruleset action; the full violation list is available on the Dashboard.
>>> The cluster refused the change. The API keeps its previous revision.
```

*"The API server refused the apply. The object was never written to etcd, the Operator never saw it, the
Dashboard never saw it. The API is still on Tuesday's revision. Five violations are shown inline; the full list
is in the Dashboard."*

```bash
kubectl -n tyk get tykoasapidefinition kestrel-payments-api -o jsonpath='{.spec.tykOAS.configmapRef.name}'
```

Dashboard **Governance > Rulesets**: the ruleset still shows Deployment Warning **Warn**. *"Block is stored as
warn in the Dashboard, so the UI and the CI check behave exactly as before. Only the cluster blocks."*

Put it back to warn for the next take: `./scripts/block-demo.sh --revert`.

### Close. Friday (1 min)

Dashboard **APIs** list with the Governance Overview strip, and Terminal 1:

```bash
kubectl -n tyk get tykrulesets,tykoasapidefinitions
```

*"Friday. The Kestrel Payments API is compliant and Northline's launch is on track. Rob spent fifteen minutes
on Monday and one commit on Tuesday, and never reviewed the API. The two internal APIs still on the banner are
his backlog, and for the first time it's a number on the home page instead of a feeling."*

*"Three shifts. Standards on paper become standards enforced before production. Governance stops being the
bottleneck and becomes the thing that tells developers what to do instead. And compliance stops being a yearly
audit and becomes a number you can read any time. Same rules, same verdict, whether the check runs in the
Dashboard, in your pipeline, or in your cluster at apply time."*

---

## Part 4. Reset between takes

```bash
./scripts/reset.sh      # deletes the TykRulesets, TykOasApiDefinitions and ConfigMaps; the Operator removes them from the Dashboard
./scripts/seed.sh       # Monday again
```

To rewind only part of the story: `./scripts/ines-push.sh monday` (if the ruleset is not on `block`),
`./scripts/rob-tune.sh --revert`, `./scripts/block-demo.sh --revert`. `./scripts/down.sh` deletes the cluster.

Observed on 1 October 2026: the kind node image was Kubernetes v1.37.0, one minor above the Operator's stated
compatibility range (1.28 to 1.36). Everything worked. Pin an older `kindest/node` image in `kind-config.yaml` if
you want to stay inside the range.

---

## Part 5. Appendix

### A. kubectl cheat sheet

| Command | Shows |
|---|---|
| `kubectl -n tyk get tykrulesets` | `RULESETID` (Dashboard id), `ACTIVE`, `ACTION`, `SYNCSTATUS` |
| `kubectl -n tyk get tykoasapidefinitions` | `CATEGORIES` and `PREFLIGHTSTATUS` (`passed`, `warned`, `blocked`, `error`, `skipped`) |
| `kubectl -n tyk describe tykoasapidefinition <name>` | `Governance Preflight` block: status, effective action, counts, evaluated at, message with up to 5 errors |
| `kubectl -n tyk get events --field-selector involvedObject.name=<name>` | `GovernancePreflightPassed` / `Warned` / `Blocked` / `Error` events |
| `kubectl -n tyk get tykoasapidefinition <name> -o jsonpath='{.status.governancePreflight}'` | The raw status, including `sourceHash` (hash-gated re-evaluation) |

### B. TykRuleset fields

`spec.name`, `spec.description`, `spec.active`, `spec.action` (`none` default, `warn`, `block`),
`spec.resourceType: oas-api`, `spec.categories` (must already exist on at least one API when the ruleset is
created), `spec.ruleset.raw` (inline Spectral YAML or JSON) or `spec.ruleset.objRef` (`kind: ConfigMap|Secret`,
`name`, `keyName`), exactly one of the two. Optional `spec.contextRef` selects an `OperatorContext`; omitted
here, so the Operator uses the credentials from `tyk-operator-conf`.

### C. How the Operator decides

1. No `spec.categories` on the `TykOasApiDefinition`: `skipped`, no Dashboard call.
2. No active `TykRuleset` for `oas-api` in the namespace whose categories intersect: `skipped`.
3. Otherwise the Operator resolves the matching rulesets to IDs and calls the Dashboard's sandbox evaluation.
   Effective action is the strictest action among rulesets with Error-level findings: `block` > `warn` > `none`.
   A `block` ruleset with only warnings does not block.
4. The webhook runs on `TykOasApiDefinition` create and update. The reconciler runs the same evaluation and
   records `status.governancePreflight` and an Event, but never withholds the Dashboard sync.
5. `webhooks.governanceFailurePolicy` (chart value) decides what happens when the preflight cannot run. This demo
   uses `Fail`. The default `Ignore` admits the object and records the real state on the next reconcile.

### D. Why is my API not being evaluated?

0. `SYNCSTATUS` `Failed` with `HTTP 401` on every API means the Operator started before the bootstrap job wrote
   `tyk-operator-conf` (it reads the secret as environment variables). Restart it:
   `kubectl -n tyk rollout restart deploy/tyk-stack-tyk-operator-controller-manager`.
1. Does the `TykOasApiDefinition` carry a category, spelt exactly as the ruleset's (`payments`, not `Payments`)?
2. Is there an active `TykRuleset` in the **same namespace** with that category?
3. `kubectl get tykruleset`: is `SYNCSTATUS` `Successful` and `RULESETID` set? `Failed` with no id usually means
   the Dashboard returned `403` (licence without the `governance` scope) or the category did not exist yet.
4. Is the webhook healthy? `kubectl -n tyk get certificate`, and the Operator pod logs.
5. Edits made in the Dashboard UI are not written back to the manifests, and they do not trigger an Operator
   re-evaluation. The repo is the source of truth; change the YAML.

### E. Numbers worth quoting

- Evaluation cost is driven by endpoint count, not rules: 0 to 100 endpoints under 1 second; each extra rule
  about 0.5 ms. In this demo a push is evaluated and synced within a few seconds end to end.
- Monday's spec: 23 errors in the cluster preflight, 25 in the Dashboard (two added `http://` server URLs),
  22 in the CI check after Rob's tuning.
