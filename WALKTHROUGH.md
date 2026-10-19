# Tyk Governance: end-to-end demo walkthrough (Tyk 5.15)

A presenter script for recording or presenting the API Governance capability that shipped inside
Tyk Dashboard 5.15.0 (1 September 2026) and Tyk Operator 1.5.0 (23 September 2026).
Everything in it was run and verified on tyk-demo with Dashboard v5.15.0 on 28 September 2026.

Runtime: about 15 minutes for the core story (Acts 1 to 6), 20 to 25 minutes with the optional acts.

---

## Part 1. The story and the context

### One week at Kestrel Charging

The demo follows one week at **Kestrel Charging**, a fictional EV charging network with about 2,400 charge
points across the UK. Two people carry the story.

| Who | Role in the story |
|---|---|
| **Ines Ferreira**, backend engineer, Payments squad | Has to ship the **Kestrel Payments API** by Friday. Northline Fleet, a partner running 900 vans, launches pay-from-your-own-app charging on Monday and their integration depends on it. She imported the first version into Tyk on Monday morning. |
| **Rob Whitfield**, API platform lead | Reviews every new API by hand: about two hours each, six in the queue, Ines's is number four. In March an internal tariff API was left keyless, a price-comparison bot scraped it and took the upstream down for 40 minutes on a Saturday. Since then Rob has a standards page in Confluence. Nobody reads it before they ship. |
| **Northline Fleet** | The partner. Their driver app will call the Payments API. They never appear on screen; they are the deadline. |

The arc, day by day:

- **Monday** (Acts 0 to 2): Rob stops reviewing by hand and defines the standard once, from the OWASP template
  and from the two rules the March incident taught him.
- **Tuesday** (Acts 3 to 5): Ines finds out what is wrong with her API and how to fix it, without a review
  meeting. One finding is the environment's fault, not hers, so Rob tunes the standard rather than the API.
- **Wednesday** (Act 6): Ines puts the same check in her pull-request pipeline so the next change never reaches
  Rob's queue broken.
- **Thursday** (Acts 7 and 8, optional): Rob previews a design standard on the internal APIs and hard-blocks
  the Kubernetes-managed ones through Tyk Operator.
- **Friday** (Close): the Payments API is compliant, Northline is on track, and Rob's review took zero hours.

### What Governance is in 5.15

- A **universal API governance hub built into Tyk Dashboard**. No separate product, no agent, no extra install.
  It is a licence claim (`governance` scope) that your account team enables per organisation.
  Without it, every governance endpoint returns `403`.
- **Rulesets** are Spectral-format (the de-facto API linting standard) executed by **Vacuum**, a Go engine
  that is fully Spectral-compatible and much faster on large specs. Existing Spectral rulesets import as-is.
- Rulesets are **scoped through API Categories**. Tag an API `payments` and every active ruleset linked to
  `payments` evaluates it, automatically, in the background, whenever the API or the ruleset changes.
- Rules check the **OpenAPI document and the Tyk gateway configuration** (`x-tyk-api-gateway`): auth,
  rate limits, upstream settings. That is the part no generic linter can reach.
- **Severity drives compliance**: one Error-level finding makes an API Non-compliant. Warn and Info are advisory.
- **Advisory by design in the UI**: a per-ruleset *Deployment Warning* shows a soft warning when a
  non-compliant API is saved. It never blocks. Tyk Operator is the exception: `action: block` rejects the
  manifest at `kubectl apply` time through an admission webhook.
- Same engine everywhere: Dashboard UI, CI/CD pipeline (`/api/evaluations/sandbox/oas`), Tyk Operator.
- Tyk OAS APIs only at launch. MCP and GraphQL governance are on the roadmap.

### What changed since last year (say this if anyone remembers the 2025 preview)

The 2025 "Governance Hub" (standalone dashboard + agents, multi-gateway discovery, the thing in
`tyk-demo/deployments/governance`) was a proof of concept with two customers. The learning was that a
second product outside the workflow kills adoption, and multi-gateway governance solved a problem our core
customers did not have yet. It was deprecated and governance was rebuilt natively into the Dashboard.

### Talking points from the internal Release 1 showcase (August 2026)

- The problem: manual governance built for dozens of APIs does not scale to hundreds or thousands.
  Northwestern Mutual: 500+ APIs governed by a 3 to 4 person team. RBFCU: 2+ hours per API review,
  3 to 4 reviews a week. About 20% of deployments need rework because of late policy violations.
  (Rob's queue is this problem in miniature.)
- Customer quotes: "Telling someone no isn't helpful. It needs to be no, and here's what to do instead."
  (NextEra). "Everything as code. Via Tyk Operator, I want warnings or errors before deploying an API." (Liebherr).
- Three pillars: **Centralised Standards**, **Shift-Left Quality Gates**, **Compliance Visibility**.
- The workflow: **Define** (templates, import, custom) → **Evaluate** (automatic, background, by category)
  → **See** (Governance tab, portfolio view) → **Act** (fix with guidance, before deployment).
- Value: reduce security and compliance exposure; scale governance without scaling headcount;
  govern what existing tools can't reach (the gateway-config layer); enable AI safely (directional).
- The three shifts: standards on paper → enforced before production; governance as a bottleneck →
  a development accelerator; compliance as an audit event → a continuous state.
- Roadmap (customer-feedback driven, not committed): compliance reporting and scoring (A to AAA grading
  modelled on Northwestern Mutual), notifications and webhooks, RBAC expansion, hard-block option in the UI,
  GraphQL and MCP governance, later shadow-API detection and multi-gateway discovery.
- Top questions you will get: not a separate product; Spectral rules import as-is; runs async so it never
  slows the Dashboard (most APIs evaluate in under a second); identical on Tyk Cloud and self-managed;
  enabled through the account team, not self-serve.

### Sources

- Docs: https://tyk.io/docs/tyk-governance/overview (Quick Start, Rulesets, Ruleset Templates, Scoping,
  Service Compliance, Remediate Issues, CI/CD Governance Checks, Governance via Tyk Operator, Core Concepts)
- Dashboard 5.15.0 release notes: https://tyk.io/docs/developer-support/release-notes/dashboard
- Operator 1.5.0 release notes: https://tyk.io/docs/developer-support/release-notes/operator
- Internal: "Showcase Tyk-API-Governance 2026" deck (Project Team - Governance, Release 4 showcase, August 2026),
  Governance PRD R1 and competitor analysis in Confluence (EN space), Figma prototype
  "Governance-Dashboard" (flows: Ruleset, Compliance visibility, Shift-left warning).
- Slack: #discuss-product-technical and #discuss-product-strategy for questions; Northwestern Mutual asked
  for it to be enabled the week of release; Wolters Kluwer demo prepared by KD (late September 2026).

---

## Part 2. Environment preparation (before you hit record)

### Prerequisites

1. tyk-demo with `DASHBOARD_VERSION=v5.15.0` and `GATEWAY_VERSION=v5.15.0` in `.env`
   (already the case in `~/projects/tyk-demo`).
2. A Dashboard licence whose scope includes `governance`. Check it:

```bash
grep '^DASHBOARD_LICENCE=' ~/projects/tyk-demo/.env | cut -d= -f2 | cut -d. -f2 | base64 -d 2>/dev/null | jq -r .scope
```

3. Stack running: `cd ~/projects/tyk-demo && ./up.sh`. Confirm governance answers:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: $(cat ~/projects/tyk-demo/.context-data/1_dashboard-user_1_api-key)" http://tyk-dashboard.localhost:3000/api/rulesets
```

   `200` means enabled. `403` means the licence claim is missing.

### Seed the demo

```bash
cd ~/projects/tyk-governance-demo
./scripts/reset.sh          # clean slate (safe to run on a fresh environment)
./scripts/setup.sh --no-rulesets
```

`--no-rulesets` tags four existing OAS APIs (`OAS HTTPbin`, `JWT-RSA`, `Strict Routes`, `Multiple Listen
Paths`) with the category `internal` (these play Kestrel's existing internal APIs) and imports Ines's
deliberately broken **Kestrel Payments API** tagged `payments`. No rulesets exist yet, so Rob creates them
live. If you prefer to skip the ruleset wizard, run `./scripts/setup.sh --with-owasp` instead and start at Act 3.

Why categories first: the Dashboard rejects a ruleset that references a category no API carries yet.

### Have these open

- Browser tab 1: http://tyk-dashboard.localhost:3000 logged in as the admin user
  (credentials in `~/projects/tyk-demo/.context-data/1_dashboard-user_1_email` and `..._password`).
  You play both Rob and Ines from this one login; say whose hands are on the keyboard when it changes.
- Browser tab 2: https://tyk.io/docs/tyk-governance/overview (for the Operator YAML and the docs moment).
- Terminal in `~/projects/tyk-governance-demo` with `apis/payments-api.json` and
  `rulesets/kestrel-platform-standards.json` visible in an editor.
- Optional: the "Showcase Tyk-API-Governance 2026" deck for the opening and closing slides.

### The cast of objects

| Thing | Role in the story |
|---|---|
| **Kestrel Payments API** (`/payments/`, category `payments`) | Ines's API, as imported on Monday morning. Keyless, no rate limit, integer IDs, no operationIds, `http://` server. Three operations: list payments, create a payment for a charging session, get a payment. |
| **Payments Security Baseline** | Rob creates it live from the **OWASP API Security** template, Deployment Warning **on**, scoped to `payments`. |
| **Kestrel Platform Standards** | Rob's house rules, imported from `rulesets/kestrel-platform-standards.json`. The two Error rules about authentication and the two about upstream rate limiting are the March incident written down. Also operationIds, descriptions, ownership, semver. Scoped to `payments` and `internal`. |
| **Design Standards** (optional) | Rob creates it from the **OpenAPI Best Practices** template, scoped to `internal`, to show portfolio-wide visibility. |
| `apis/payments-api-fixed.json` | The spec Ines pushes from her repo on Tuesday afternoon. Passes every Error rule. |

---

## Part 3. The demo, act by act

Timings are a guide. Lines in *italics* are suggested narration. Each act opens with where we are in the week.

### Act 0. Monday, 09:10. Set the scene (1 min)

Open the Dashboard home page and the API list (**APIs**).

*"This is Kestrel Charging's Tyk Dashboard: 60-odd APIs, 2,400 charge points behind them. It's Monday.
Ines on the Payments squad imported the Kestrel Payments API half an hour ago. Northline Fleet, 900 vans,
launches pay-from-their-own-app charging next Monday, and this API is what their app will call. Ines needs it
in production by Friday."*

*"Rob runs the API platform. Every new API goes through him: two hours a review, six in the queue, Ines is
number four. Since March, when a keyless tariff API got scraped and took the upstream down for 40 minutes,
Rob has a standards page in Confluence. Today the only thing between Ines's API and production is whether
Rob gets to it, and whether she read that page."*

Point at the API list: there is no compliance information yet. Find Kestrel Payments API in the list.

*"Let's give Rob a way to define the standard once, and have every API checked against it, continuously."*

### Act 1. Monday, 09:30. Rob defines the standard from a template (3 min)

*"Rob's hands on the keyboard."*

1. Left navigation: **Governance > Rulesets** (URL `/governance/rulesets`). Empty state.
2. Click **Create New Ruleset**. The three-step wizard opens.
3. **Step 1, Define basic information**
   - Name: `Payments Security Baseline`
   - Description: `OWASP API Security Top 10 baseline for every payments API.`
   - **Link ruleset to APIs > Category**: pick `payments (1 API)`.
     *"Rob doesn't pick Ines's API. He picks the payments category. Every API that carries the tag is in
     scope automatically, including the two the Payments squad will ship next quarter."*
   - **Deployment warning**: switch on **Activate deployment warning**.
     *"Off by default. On means Ines gets a warning at save time. It never blocks her."*
   - **Continue**.
4. **Step 2, Choose a starting point**: **Start from a template**. **Continue**.
   *"Two templates ship today: OWASP API Security and OpenAPI Best Practices. Or bring your own Spectral ruleset."*
5. **Step 3, Select a template**: click the **OWASP API Security** card. The **Template definition** editor
   shows `{"extends": [["spectral:owasp", "all"]]}`.
   *"That's the whole definition: extend the OWASP ruleset, all rules. Rob can override any rule's severity
   or add his own right here. He'll need to on Tuesday."*
6. Click **Save and activate**.
7. You land on the ruleset detail page: **Basic information** (category `payments`, Deployment warning
   **On**, Status **Active**), **Rules overview** (23 rules with severities such as
   `owasp-no-numeric-ids: error`, `owasp-define-error-responses-401: warn`), and the **Test ruleset** panel.

*"Evaluation of Ines's API already started in the background. Nothing was blocked, no gateway was touched.
Evaluation runs on the control plane only."*

### Act 2. Monday, 09:45. Rob writes down the March incident (2 min)

*"OWASP covers the spec. But what actually hurt Kestrel in March wasn't in the spec. It was gateway
configuration: an API published with no authentication and no rate limit on the upstream. Generic linters
can't see that. Tyk can, because the gateway configuration is part of the Tyk OAS document. So Rob turns the
incident review into two rules."*

1. Show `rulesets/kestrel-platform-standards.json` in the editor. Walk through one rule:

```json
"kestrel-upstream-rate-limit": {
  "description": "Every API must protect its upstream with a rate limit",
  "severity": "error",
  "given": "$['x-tyk-api-gateway'].upstream",
  "then": { "field": "rateLimit", "function": "truthy" },
  "howToFix": "In the API Designer open Settings > Upstream > Rate Limit and enable it, for example 100 requests per 60 seconds."
}
```

   *"Standard Spectral: given a JSONPath, then a function, a severity, and, importantly, `howToFix`.
   Whatever Rob writes there is what Ines sees next to the failure. This is the Confluence page, moved to the
   one place people will actually read it."*

   Point at `kestrel-auth-configured` too: its message says keyless APIs are not allowed "since the March
   tariff-API incident".

2. **Governance > Rulesets > Create New Ruleset**
   - Name `Kestrel Platform Standards`, categories `payments` **and** `internal`, Deployment warning off.
   - **Start from your own definition** > **Import from file** > `rulesets/kestrel-platform-standards.json`
     (or paste it). **Save and activate**.

   Or from the terminal (same result):

```bash
./scripts/setup.sh        # creates the Kestrel ruleset via POST /api/rulesets if it does not exist
```

   *"Rob scopes it to internal as well as payments. He wants to know how the existing estate measures up,
   without warning anyone yet. That's what Deployment warning off means: visibility only."*

3. Back on **Governance > Rulesets**: two rulesets, columns Status, Name, Category, Deployment Warning
   (`Warn` vs `Don't warn`), Last Updated.

*"Rob spent fifteen minutes. He hasn't opened Ines's API once."*

### Act 3. Tuesday, 08:50. Ines finds out (3 min)

*"Tuesday morning. Ines logs in to carry on with the Payments API."*

1. **Home page**: a red banner: *"5 APIs are non-compliant. Review affected APIs and check the Governance
   tab for issue details and remediation options."* with **See Non-Compliant APIs**.
   *"Compliance is a continuous state, not an audit event. Rob changed the rules overnight, and the answer was
   waiting for Ines when she logged in. No meeting was booked."*
2. **APIs** list: the new **Governance Overview** strip (Total APIs, Compliant, Non-compliant, N/A), a
   **Compliance** filter and a **Compliance** column. Filter by **Non-compliant**.
   *"Her API, and four of Rob's internal ones. N/A means the API carries no category linked to an active
   ruleset. Governance is opt-in by category."*
3. Open **Kestrel Payments API**. Click the **Governance** tab (last tab, badged New!).
   - **Governance status** banner: **Non-compliant**, 24 Errors, 17 Warnings.
   - **Rulesets associated with this API**: one card per ruleset with violations, warnings and a
     **Compliance level** score (Kestrel Platform Standards 25/100, Payments Security Baseline 43/100).
   - **Issues for this API**: pills **All Issues / Errors / Warnings**, filter by ruleset and severity,
     table with Ruleset, Rule Violated, Severity, **Problem If Not Fixed**, **View Issue**.
   *"Twenty-four errors sounds bad. It is Tuesday morning and she has until Friday. What matters is whether
   each one tells her what to do."*
4. Click **View Issue** on `kestrel-auth-configured`. The **Issue details** modal shows Rule, Ruleset,
   Severity, Description, **Affected area** (`authentication`) and **HOW TO FIX**:
   *"In the API Designer open Settings > Authentication, switch from Keyless to an authentication method..."*
   *"Rob's words, from the incident review, next to Ines's failure. No, and here's what to do instead."*
5. Optionally click **View Issue** on `owasp-no-numeric-ids` to show an OWASP remediation
   ("use type string with uuid format instead of type integer").
   *"That one matters for Northline: sequential integer payment IDs are how you enumerate someone else's
   payments."*

### Act 4. Tuesday, 09:15. Ines fixes it, and meets the Deployment Warning (3 min)

1. Still on Kestrel Payments API, click **Edit**, then immediately **Save API** without changing anything.
   Because Payments Security Baseline has the Deployment Warning on and the API has Error-level findings,
   the warning dialog appears: *"This API does not fully meet the compliance requirements. Please review the
   issues for each rule and make the necessary updates before deploying... If you choose to deploy now, the API
   will be saved and deployed with a Non-Compliant status."* with two choices: **Save Anyway** or
   **View Compliance Issues**. Choose **View Compliance Issues** (the save is cancelled, you stay in edit mode,
   and the Governance tab shows a live pre-save check: *"Showing results from your last compliance check on
   unsaved changes"*).
   *"Advisory by design. Ines keeps the decision. If the Northline deadline forced her to ship on Thursday
   with two warnings left, she could. But she cannot claim she didn't know, and neither can Rob."*
2. Fix the two gateway-level issues in the API Designer (**Settings** tab, still in edit mode):
   - **Server > Authentication**: switch the toggle on and pick **Auth Token** as the method.
   - **Upstream > Rate limiting**: switch the toggle on, `100` requests per `60` seconds.
   - **Save API**. The warning appears again (OWASP errors remain). Click **Save Anyway**.
   *"The two March rules, fixed in ninety seconds, in the Designer, because the fix text told her exactly
   which settings page to open."*
3. **Governance** tab, within a second: Kestrel Platform Standards drops from 5 errors to 3 (the three
   missing operationIds). The banner error count drops accordingly.
   *"That is the shift-left loop: fix, save, re-evaluated in under a second, no ticket, no review meeting."*
4. *"The rest of the fixes (uuid IDs, string limits, error responses, operationIds) live in the OpenAPI
   document. Ines fixes them in the payments-api repo and pushes."* Apply the fixed definition:
   - UI: **Actions > Update API OAS > Import from File** and pick `apis/payments-api-fixed.json`, or
   - Terminal:

```bash
./scripts/remediate.sh      # PUT /api/apis/oas/kestrel-payments-api with the fixed spec, then prints compliance
```

5. Refresh the **Governance** tab: **Kestrel Platform Standards: Compliant** (0 errors, score 100). Payments
   Security Baseline still shows 1 error: `owasp-security-hosts-https-oas3` on the `servers` entry the
   Dashboard added for the gateway.
   *"One left, and it isn't Ines's. The Dashboard adds the gateway's own `http://tyk-gateway.localhost:8080`
   URL to the servers list, and at Kestrel TLS terminates at the edge. The rule is right in general and wrong
   for this environment. Ines messages Rob: 'the https rule is firing on the gateway URL you add, not on
   anything in my spec.' So Rob tunes the standard, not the API."*

### Act 5. Tuesday, 11:20. Rob tunes the standard, everything re-evaluates (2 min)

*"Rob's hands on the keyboard again."*

1. **Governance > Rulesets > Payments Security Baseline > Edit Ruleset > Raw definition** tab.
   Replace the definition with:

```json
{
  "extends": [["spectral:owasp", "all"]],
  "rules": {
    "owasp-security-hosts-https-oas3": "warn"
  }
}
```

   *"Spectral semantics: extend the template, override one rule's severity. Every other OWASP rule is
   untouched. Rob keeps it as a warning rather than switching it off, because it should still fire when a
   squad publishes a real http:// upstream."*
   Save. Or from the terminal: `./scripts/tune-ruleset.sh` (and `--revert` to undo).
2. **Rules overview** now shows that rule as `warn`.
3. Open Kestrel Payments API > **Governance**: **Compliant**, 0 errors, a couple of warnings.
   *"Editing a ruleset re-evaluates every API in its categories, in the background. Same thing happens the
   other way: promote a rule from Warn to Error and yesterday's compliant APIs show up on tomorrow's banner."*
4. **APIs** list: Kestrel Payments API now **Compliant**; the home banner count drops to 4.
   *"Tuesday lunchtime. Ines's API is compliant. Rob's total time on it: one Slack message and one edit."*

### Act 6. Wednesday. Ines shifts left into the pipeline (3 min)

*"Wednesday. Ines is thinking about next time. Northline will ask for changes after launch, and the two
APIs her squad ships next quarter shouldn't go through Tuesday morning again. She wants the answer in the pull
request, before the spec is ever imported. Same rulesets, same engine, one HTTP call."*

1. Show `scripts/governance-check.sh` (the reference script from the docs). The core is one request:

```bash
curl -sS -X POST "$TYK_DASHBOARD_URL/api/evaluations/sandbox/oas?categories=payments&api_id=kestrel-payments-api" \
  -H "Authorization: Bearer $TYK_DASHBOARD_TOKEN" -H "Content-Type: application/json" \
  --data-binary @apis/payments-api.json
```

2. Run the pipeline demo:

```bash
./scripts/ci-demo.sh
```

   Output, first for Monday's spec: both rulesets resolved from the `payments` category, 23 errors,
   each with `how_to_fix`, `Result: non-compliant.`, **exit code 2, pipeline fails**.
   Then for `payments-api-fixed.json`: 0 errors, `Result: compliant.`, **exit code 0**.
   *"Monday's version would never have reached Tyk. The PR would have failed with the same 23 messages Ines
   read on Tuesday, before Rob knew the API existed."*

3. Points to make:
   - `--categories payments` means the pipeline tracks whatever Rob currently links to the category;
     `--ruleset-ids` pins an explicit set.
   - `--strictness strict|standard|permissive`: fail on warnings too, fail on errors only (default, matches
     the Dashboard's definition), or report only while rolling out. Try `STRICTNESS=strict ./scripts/ci-demo.sh`.
   - Only rulesets whose action is not `none` gate the build. A visibility-only ruleset (Deployment Warning
     off) is reported but never fails the pipeline, matching what the Dashboard does.
   - HTTP status is `200` even for violations; the verdict is in the body. The script handles that.
   - Nothing is imported or persisted. It is a sandbox call.
   - Drop-in snippets for GitHub Actions, GitLab CI and Jenkins are in the docs page CI/CD Governance Checks.

```yaml
- name: Governance check
  env:
    TYK_DASHBOARD_URL: ${{ secrets.TYK_DASHBOARD_URL }}
    TYK_DASHBOARD_TOKEN: ${{ secrets.TYK_DASHBOARD_TOKEN }}
  run: ./scripts/governance-check.sh openapi.yaml --categories payments --api-id kestrel-payments-api
```

### Act 7 (optional). Thursday. Rob previews a design standard with the test sandbox (1 min)

*"Thursday. With the incident rules in place, Rob wants to raise the bar on the internal estate, but he's
not going to surprise four squads with a new red banner. He previews first."*

1. **Governance > Rulesets > Create New Ruleset**: `Design Standards`, category `internal`, template
   **OpenAPI Best Practices**, **Save and activate**. The four `internal` APIs are now evaluated by two rulesets.
2. On Kestrel Payments API > **Governance** tab, scroll to **Test ruleset**, select **Design Standards**
   (not linked to `payments`) and **Run**.
   *"A dry run. Results are not stored and do not change the compliance status. This is how Rob shows the
   Payments squad what a standard would say before they opt in, and how he iterates on a ruleset before
   activating it."*
3. The same panel exists on the ruleset detail page (select an API, **Run**).

### Act 8 (optional, talk track or live if you have a cluster). Thursday. GitOps with Tyk Operator (2 min)

*"Rob's own platform team manages the internal APIs as Kubernetes manifests. Governance is code for them too,
and this is the one place where Rob can hard-block: nothing keyless gets applied to the cluster, ever again."*
Tyk Operator 1.5.0 adds the `TykRuleset` CRD:

```yaml
apiVersion: tyk.tyk.io/v1alpha1
kind: TykRuleset
metadata:
  name: payments-ruleset
  namespace: tyk
spec:
  name: Payments Ruleset
  active: true
  action: block          # none | warn | block (block is Operator-only, stored as warn in Dashboard)
  resourceType: oas-api
  categories: [payments]
  ruleset:
    raw: |
      extends: ["spectral:oas"]
      rules:
        operation-operationId:
          severity: error
```

`kubectl apply` of a `TykOasApiDefinition` with `spec.categories: [payments]` is evaluated by the admission
webhook. With `block` and Error-level findings the apply is denied and the object is never saved:

```
Error from server (Forbidden): admission webhook "vtykoasapidefinition.kb.io" denied the request:
governance preflight blocked this API (2 error(s)):
* operation-operationId (error): Every operation must have an operationId
```

Otherwise the API is admitted, with `status.governancePreflight` (`passed | warned | blocked | skipped`) and
a `PREFLIGHTSTATUS` column on `kubectl get tykoasapidefinitions`. Apply order on a fresh org: the
categorised API before the ruleset that references its category. Full detail: docs page
"Governance via Tyk Operator".

### Close. Friday (1 min)

Back on the API list with the Governance Overview strip.

*"Friday. The Kestrel Payments API is compliant and Northline's launch is on track. Rob spent fifteen minutes
on Monday and one edit on Tuesday, and never reviewed the API. The four internal APIs still on the banner are
his backlog, and for the first time it's a number on the home page instead of a feeling."*

*"Three shifts. Standards on paper become standards enforced before production. Governance stops being the
bottleneck and becomes the thing that tells developers what to do instead. And compliance stops being a
yearly audit and becomes a number you can read any time, in seconds. Same rules, same verdict, whether the
check runs in the Dashboard, in your pipeline, or in your cluster."*

Roadmap teaser: compliance reporting and scoring, notifications, MCP and GraphQL governance.

---

## Part 4. Reset between takes

```bash
./scripts/reset.sh                 # deletes the three rulesets, the Kestrel Payments API and the category tags
./scripts/setup.sh --no-rulesets   # ready for Act 1 again
```

To rewind only part of the story: `./scripts/remediate.sh --revert` (Monday's broken API back),
`./scripts/tune-ruleset.sh --revert` (OWASP https rule back to error).

Known quirk (5.15.0): ruleset deletion is a soft delete. If you create a ruleset through the API with a custom
`ruleset_id`, delete it, and create another one with the same `ruleset_id`, the Governance tab lists that
ruleset twice and double-counts its errors. The scripts therefore let the Dashboard assign ruleset IDs.
Creating rulesets in the UI never hits this.

---

## Part 5. Appendix

### A. Governance API cheat sheet (Dashboard API, header `Authorization: <user API key>`)

| Call | Purpose |
|---|---|
| `GET /api/rulesets?p=-1` | List rulesets (add `is_template=true` for the shipped templates: `spectral-owasp`, `spectral-oas`) |
| `POST /api/rulesets` | Create. Body: `name`, `ruleset_id` (optional stable id), `description`, `active`, `resource_type` (`oas-api`), `action` (`none`/`warn` = Deployment Warning), `categories` (must already exist), `definition` (Spectral ruleset as a JSON **string**) |
| `PUT /api/rulesets/{id}` and `DELETE` | Update (re-evaluates every API in scope) and soft delete |
| `GET /api/rulesets/{id}` | Includes `applied_rules` after resolving `extends` |
| `GET /api/apis/categories` | Categories with counts |
| `PUT /api/apis/oas/{apiId}/categories` `{"categories":["payments"]}` | Tag an OAS API (triggers evaluation) |
| `GET /api/apis?p=-1&include_stats=true` | API list with `compliance_status` per API and org `stats` (total, compliant, non_compliant, unassessed, total_issues) |
| `GET /api/governance/apis/{apiId}/compliance` | Overall status plus per-ruleset counts and `compliance_level` (0 to 100) |
| `GET /api/governance/evaluation-details/{apiId}?p=-1&severity=error` | Recorded issues with `path`, `message`, `how_to_fix` |
| `POST /api/evaluations/sandbox` `{"ruleset_ids":[...],"api_ids":[...]}` | Dry run saved rulesets against saved APIs (what the Test panels call) |
| `POST /api/evaluations/sandbox/oas?categories=..&api_id=..` (body = OAS file) | CI/CD check of a spec that is not imported. Max 20 rulesets, issues capped at 1,000 (`truncated`) |

### B. Anatomy of a rule

```yaml
rules:
  hosts-must-use-https:
    description: All server URLs MUST use the https protocol
    severity: error            # error | warn | info | hint (default warn)
    given: $.servers[*].url    # JSONPath into the Tyk OAS document, x-tyk-api-gateway included
    then:
      function: pattern        # truthy, falsy, pattern, enumeration, length, schema, ...
      functionOptions:
        match: "^https://"
    howToFix: "Update server URLs in your API definition to use the https scheme."
```

Override a rule from an extended template with the shorthand `"rules": {"<rule-id>": "warn"}` or
disable it with `"off"`.

### C. Why is my API not being evaluated?

1. Is the ruleset **Active** (not a draft)?
2. Do the categories match exactly (`payments` is not `Payments`)?
3. Has the API been saved since the category or ruleset was added?
4. Give background evaluation a few seconds (up to about 10 for 1,000+ endpoint specs).
5. Does your user have Read or Write on the **Rulesets Governance** permission group? Deny hides the feature.
6. `403` on every governance endpoint means the licence lacks the `governance` scope.

### D. Numbers worth quoting

- Evaluation cost is driven by endpoint count, not rules: 0 to 100 endpoints under 1 second, 1,000+ up to
  about 10 seconds; each extra rule adds about 0.5 ms.
- Internal benchmark (Tomas, August 2026): all 11 FDX v6.5 APIs evaluate in under 45 ms each, even the
  265 KB core spec.
- In this demo: the 23-rule OWASP template plus the 8-rule Kestrel ruleset evaluate the payments API in
  about 10 ms (`elapsed_ms` in the sandbox response).
