# Kestrel Charging governance series: transcripts

Narrated transcripts of the five videos in this folder, one week at Kestrel Charging told through Tyk API
Governance on Kubernetes. Timestamps are minutes and seconds from the start of each video, measured against
the narration in the recorded audio. "On screen" lines are text shown in the video but not read word for word.
The narration is synthetic (macOS text-to-speech). A subtitle file (.srt) with the same name sits beside each
video for players and video platforms that load captions.

## Part 1 · Setting the standard

**01-monday-setting-the-standard.mp4** · 05:50 · Monday

**[00:00] On screen:** Monday, 09:10 · Kestrel Charging  
Setting the standard. How Rob turns a wiki page into a check the cluster runs on every API.

**[00:00]**  
Monday morning at Kestrel Charging.

**[00:05] On screen, the problem:** Every new API waits for one person to review it by hand: two hours each, six in the queue. The standards live on a wiki page nobody reads before they deploy.  
**What this part shows:** Rob turns the standard into code, and the cluster checks every API against it, automatically, on every change.

**[00:05]**  
The problem: every new API waits for one person to review it by hand, and the standards live on a wiki page nobody reads before they deploy. This part shows Rob turning the standard into code, so the cluster checks every API against it on every change.

**[00:22] On screen:** Every new API waits for one person. Rob reviews each API by hand. The standards live on a wiki page nobody reads before they deploy.

**[00:22]**  
This is Kestrel Charging, a fictional network of electric vehicle chargers. Right now every new API waits for Rob, the platform lead, to review it by hand: about two hours each, six in the queue. The standards live on a wiki page that nobody reads before they deploy. In this series we replace that queue with Tyk API Governance, running entirely through the Tyk Operator on Kubernetes.

**[00:48] On screen:** A document can't stop a deploy.

**[00:48]**  
Why it matters. In March, an API went live without authentication. A bot scraped it and took a system down for forty minutes. Rob wrote that lesson down afterwards, but a document cannot stop a deploy.

**[01:02] On screen:** Rob sets the rules. Ines follows them.

**[01:02]**  
Two people carry the story. Ines is a backend engineer on the payments squad. She has to ship the Kestrel Payments API by Friday, because a partner with nine hundred vans launches on Monday. Rob owns the cluster and the standards. Watch how the work passes between them: Rob sets the rules, Ines follows them, and when a rule turns out to be wrong, Rob changes the rule, not her API.

**[01:27] See the APIs in the cluster**  
Kestrel's APIs are Kubernetes resources. Each one is a Tyk OAS API definition. The Tyk Operator watches them and keeps the Tyk Dashboard in sync, and the Dashboard configures the gateways.

**[01:41] Read the governance column**  
The last column, preflight status, is the governance verdict for each API. Right now every API says skipped, because no standard exists yet. Nothing is checking these APIs, including the one Ines pushed this morning.

**[01:57] Look at Ines's API**  
Here is her API definition. The Tyk section at the bottom configures the gateway: a listen path and an upstream address. There is no authentication and no rate limit. That is exactly the mistake from March, and nobody has noticed.

**[02:16] Check the Dashboard**  
The Tyk Dashboard agrees. Its Governance Overview shows three APIs: none compliant, none non-compliant. Everything is not applicable, because there is nothing to be compliant with yet.

**[02:29] On screen:** Monday, 09:30 · Rob Whitfield, API platform lead  
Rob writes the standard as code, once, and lets the platform check every API for him.

**[02:29]**  
Half past nine. Rob.

**[02:34] Rob writes the standard as code**  
Rob's hands on the keyboard. He writes the standard as a Tyk ruleset, which is a Kubernetes resource. A ruleset is a named list of rules that APIs must follow. Because it is a manifest, it lives in Git and gets reviewed like any other change.

**[02:50] Start from a template**  
He doesn't write the rules from scratch. This ruleset extends the OWASP API Security ruleset, a widely used set of API security checks, and includes all of them.

**[03:02] Scope it by category**  
It is bound to a category, payments, rather than to Ines's API by name. Every API tagged payments is checked, including the two her squad will ship next quarter.

**[03:14] Choose what happens on failure**  
The action says what happens when an API breaks an error-level rule. Warn means the developer is told, in the Dashboard and in the terminal when they deploy. Nothing is blocked. We'll see the stricter option on Thursday.

**[03:28] Apply the ruleset**  
Rob applies it, exactly the way he deploys anything else on the cluster.

**[03:34] Confirm the Operator synced it**  
The Tyk Operator created the ruleset in the Dashboard and wrote the Dashboard's identifier back onto the resource. The sync status is Successful.

**[03:46] See it in the Dashboard**  
In the Dashboard, under Governance, the same ruleset appears with its payments category and the deployment warning switched on. Rob never opened this screen to create it.

**[04:02] Browse the rules**  
Opening it lists every rule the template brought in, each with a severity. Error-level rules decide whether an API is compliant. Warnings are advisory.

**[04:12] Add the lesson from March**  
Now the part generic linters can't do. March's outage was gateway configuration, not API design. Rob writes custom rules in the same format that look inside x-tyk-api-gateway, Tyk's own gateway settings. This one checks the upstream section for a rate limit.

**[04:31] Make it an error**  
At error severity, an API without an upstream rate limit cannot be compliant.

**[04:37] Tell people how to fix it**  
And every rule carries how-to-fix text. That text is what developers will see next to the failure, so the standard arrives with instructions, not just a no.

**[04:48] Wrap the rules in a second ruleset**  
The second ruleset loads those rules from a ConfigMap, so one file serves the cluster, the Dashboard and the pipeline. It covers both payments and internal APIs, and its action is none: report only. Rob wants to see how the existing APIs measure up before he warns anyone.

**[05:07] Apply it and look at the whole estate**  
He applies it, and within seconds every tagged API has been evaluated. All three are non-compliant. Ines's payments API scores twenty-five out of a hundred against Rob's rules, and forty-three against the OWASP baseline.

**[05:22] Notice the March API**  
And Rob learns something he didn't know. The tariffs API from the March incident is authenticated now, but it still has no rate limit on its upstream.

**[05:36] Two rulesets, fifteen minutes**  
Two rulesets, two commits, about fifteen minutes of Rob's time. One warns developers when they deploy. The other only reports. Rob has not opened Ines's API once, and tomorrow morning she will find out on her own.

## Part 2 · Ines finds out

**02-tuesday-ines-finds-out.mp4** · 02:41 · Tuesday

**[00:00] On screen:** Tuesday, 08:50 · Ines Ferreira, backend engineer, Payments squad  
Ines finds out. Rob changed the rules overnight; nobody told her, and nobody needed to.

**[00:00]**  
Tuesday morning. Ines.

**[00:05] On screen, the problem:** Developers usually hear about standards in a review meeting, days after they wrote the code, with no clear path to fixing them.  
**What this part shows:** Ines finds out on her own, in the Dashboard and in the terminal, with the fix written next to every failure.

**[00:05]**  
The problem: developers usually hear about standards in a review meeting, days after they wrote the code. This part shows Ines finding out on her own, with the fix next to every failure.

**[00:17] On screen:** No meeting was booked. Compliance is continuous and visible to everyone. Every failure explains how to fix it.

**[00:17]**  
Tuesday morning. Normally Ines would hear about Rob's standards in a review meeting, days after she wrote the code. Instead the platform worked it out overnight, and the answer is waiting for her, with instructions.

**[00:35] Log in**  
Ines logs in. The home page tells her three APIs are non-compliant, and offers to show them.

**[00:45] See the whole estate**  
The API list now carries a compliance summary for the whole estate: three APIs, none compliant.

**[00:52] Find her API**  
Every API shows its own status, so anyone can see the state of the estate at a glance. Hers is non-compliant.

**[01:10] Open the Governance tab**  
On her API's Governance tab is the verdict: non-compliant, with twenty-five errors and seventeen warnings.

**[01:18] Read the score per ruleset**  
Each ruleset gets its own card with a compliance score. Rob's platform standards give her twenty-five out of a hundred. The OWASP baseline gives her forty-three.

**[01:35] Filter to Rob's rules**  
She filters the list to Rob's rules. Each row names the rule that failed and the problem it causes if it isn't fixed: no authentication, no rate limit, missing operation IDs.

**[01:50] Open one issue**  
Opening an issue shows the rule, the ruleset it came from, and the part of the API it affects.

**[01:58] Read how to fix it**  
And here is how to fix it, in Rob's own words, written yesterday. This is the difference between being told no, and being told what to do instead.

**[02:11] Check from the terminal**  
Ines lives in the terminal, so she checks there too. The same verdict is recorded on the Kubernetes resource itself: status warned, twenty-three errors, and the first few of them inline.

**[02:24] Every check is an event**  
Every evaluation is also recorded as a Kubernetes event, so the alerting and audit tools the team already runs pick it up with no extra work.

**[02:33] On screen:** Twenty-five errors sounds like a bad morning. It is Tuesday, she has until Friday, and every one of them says what to do.

**[02:33]**  
Twenty-five errors sounds like a bad morning. It is Tuesday, she has until Friday, and every one of them tells her what to do.

## Part 3 · The fix, and the handoff

**03-tuesday-the-fix-and-the-handoff.mp4** · 03:41 · Tuesday

**[00:00] On screen:** Tuesday, 09:15 · Ines Ferreira, backend engineer, Payments squad  
The fix, and the handoff. Ines fixes her API; one bad rule goes back to Rob.

**[00:00]**  
Quarter past nine. Ines.

**[00:05] On screen, the problem:** A developer only learns that a change broke the standards after it has shipped. And a rule that is wrong for the environment creates noise until someone owns it.  
**What this part shows:** Ines is told on every push, before the change lands. The one wrong rule goes back to Rob, who changes the rule, not her API.

**[00:05]**  
The problem: a developer only learns a change broke the standards after it has shipped, and a rule that is wrong for the environment creates noise until someone owns it. This part shows Ines being told on every push, and one wrong rule going back to Rob.

**[00:21] On screen:** Fix the API. Then fix the rule. The cluster tells Ines how she is doing on every push. When one rule is wrong for Kestrel, the problem goes back to Rob.

**[00:21]**  
Quarter past nine. Watch the handoff in this part. Ines fixes her API, and the cluster tells her how she is doing on every push. Then one rule turns out to be wrong for Kestrel's environment, and Rob changes the rule rather than asking Ines to work around it.

**[00:38] Fix the gateway settings**  
Two of the errors are gateway settings. In the Tyk section of her file, Ines turns on token authentication and adds a rate limit of a hundred requests a minute on the upstream. Nothing else changes yet.

**[00:51] Push the change**  
She pushes the change. Normally her pipeline applies it; here a small script plays that part. Each version of the spec goes into its own ConfigMap, and the API resource is pointed at the new one. That update is what the Operator checks.

**[01:07] Read the warning**  
Look at the warning line. The Tyk Operator evaluated the change before Kubernetes stored it, and printed the result straight into her terminal: twenty errors left. The change still went through, because Rob's ruleset says warn, not block.

**[01:26] Watch the score move**  
In the Dashboard, Rob's platform standards have dropped from five violations to three. Only the missing operation IDs remain.

**[01:36] Fix the OpenAPI document**  
The rest of the fixes live in the OpenAPI document itself. Every operation gets an operation ID,

**[01:43] Fix the OpenAPI document**  
payment IDs become random UUIDs instead of guessable numbers, and every string and error response gets proper limits and schemas.

**[01:52] Push again**  
She pushes again. No warning this time, and the preflight status is passed.

**[02:01] One ruleset still complains**  
Rob's standards now score a hundred. But the OWASP baseline still reports two errors.

**[02:11] Find the cause**  
Both come from the same rule: server URLs must use HTTPS. They point at addresses the Dashboard adds by itself, the gateway's internal address and a relative path. Neither of them is in Ines's file.

**[02:25] On screen:** "The HTTPS rule is firing on URLs the Dashboard adds, not on anything in my spec." (Ines Ferreira)  
At Kestrel, TLS ends at the network edge. The rule is right in general, and wrong for this environment.

**[02:25]**  
At Kestrel, TLS ends at the network edge, so this rule is right in general and wrong for this environment. Ines sends Rob a message. This is the handoff: the problem moves from the person following the rules to the person who owns them.

**[02:40] On screen:** Tuesday, 11:20 · Rob Whitfield, API platform lead  
Rob tunes the standard, not the API. Two lines of YAML, and every payments API is re-checked.

**[02:40]**  
Twenty past eleven. Rob.

**[02:46] Rob overrides one rule**  
Rob's hands on the keyboard. Two lines override that one rule from error to warning. Every other OWASP rule is untouched. He keeps it as a warning rather than switching it off, so it still shows if a team ever publishes a real HTTP address.

**[03:02] Apply the change**  
He applies it. The Operator updates the ruleset in the Dashboard, the Dashboard re-checks every payments API, and the Operator refreshes their status.

**[03:12] Read the result**  
The payments API is now compliant against both rulesets.

**[03:20] Ines checks her API**  
Ines refreshes her Governance tab: compliant, zero errors.

**[03:29] Look across the estate**  
Across the estate, one API is compliant and the two internal ones are Rob's backlog. It is Tuesday lunchtime. Ines's API cost Rob one message and a two-line commit, and nobody booked a meeting.

## Part 4 · The check moves into the pull request

**04-wednesday-the-check-moves-into-the-pull-request.mp4** · 01:26 · Wednesday

**[00:00] On screen:** Wednesday, 10:00 · Ines Ferreira, backend engineer, Payments squad  
The check moves into the pull request. Same rules, same engine, before anything reaches the cluster.

**[00:00]**  
Wednesday. Ines.

**[00:05] On screen, the problem:** Even a warning at apply time arrives after the code is merged.  
**What this part shows:** The same governance check runs in the pull request, with exit codes the pipeline understands, so a bad spec never reaches the cluster.

**[00:05]**  
The problem: even a warning at apply time arrives after the code is merged. This part shows the same check running in the pull request, with exit codes the pipeline understands.

**[00:17] On screen:** Fail the build, not the deploy. Even a warning at apply time arrives after the code is merged. Ines wants the answer in the pull request.

**[00:17]**  
Wednesday. Even a warning at apply time arrives after the code is merged. Ines wants the answer in the pull request, before anything reaches the cluster.

**[00:27] One API call**  
She adds this script, taken from the Tyk documentation, to her pipeline. It sends the spec to the Dashboard's sandbox endpoint and asks for a verdict against the payments rules. Nothing is saved or deployed.

**[00:41] Exit codes the pipeline understands**  
If any gating rule fails, the script exits with code two, which fails the build. Warnings on their own let it pass.

**[00:50] Run it against Monday's spec**  
Here it runs against Monday's version of her spec. It finds the same errors Ines read on Tuesday, each with its fix, and exits with code two. The pull request would have failed before Rob even knew the API existed.

**[01:04] Run it against the fixed spec**  
And against the fixed version: zero errors, exit code zero. The pipeline carries on.

**[01:11] On screen:** Same rules, same verdict, wherever you ask.  
In the pull request · at kubectl apply · in the Tyk Dashboard

**[01:11]**  
The pull request, the cluster and the Dashboard all use the same rules and the same engine. The answer is the same wherever you ask, and that is what makes it safe to move the check earlier.

## Part 5 · The hard block, and the week in review

**05-thursday-friday-the-hard-block-and-the-week-in-review.mp4** · 02:27 · Thursday

**[00:00] On screen:** Thursday, 14:00 · Rob Whitfield, API platform lead  
The hard block, and the week in review. The one place governance can say no outright.

**[00:00]**  
Thursday afternoon. Rob.

**[00:05] On screen, the problem:** Warnings can be ignored. Some standards must never be broken in production.  
**What this part shows:** With action set to block, the Kubernetes API server itself refuses a change that breaks the rules. Then, on Friday, the week in review.

**[00:05]**  
The problem: warnings can be ignored, and some standards must never be broken in production. This part shows the Kubernetes API server itself refusing a change that breaks the rules, and then the week in review.

**[00:19] On screen:** Some rules must never be broken. Warnings can be ignored. With action: block, the Kubernetes API server itself rejects a change that breaks the rules.

**[00:19]**  
Thursday. Warnings can be ignored, and some standards must never be broken in production. This is the one place where governance can say no outright, and it is a capability only the Tyk Operator has.

**[00:32] Change one word**  
For the payments category, Rob decides that warnings aren't enough. He changes one word in the ruleset: the action becomes block.

**[00:41] Apply it, then try a bad rollback**  
He applies it. Then someone tries a bad rollback: pushing Monday's insecure version of the payments spec again.

**[00:49] Kubernetes says no**  
The Kubernetes API server refused the change. The Tyk Operator's admission webhook checked it, found twenty-two errors, and denied the request, listing the first five. The insecure version was never stored, so it never reached the Dashboard or the gateways.

**[01:06] Nothing changed**  
The payments API is still running Tuesday's compliant version.

**[01:14] The Dashboard is unchanged**  
In the Dashboard the ruleset still shows warn. Blocking is something only the cluster does, so the Dashboard and the pipeline behave exactly as before.

**[01:25] Back to warn for now**  
Rob sets it back to warn for now.

**[01:28] On screen:** Friday, 09:00 · Kestrel Charging  
The week in review. Ready for Monday's launch.

**[01:28]**  
Friday morning.

**[01:34] On screen:** Ready for Monday's launch. The Kestrel Payments API is compliant and the partner launch is on track. Rob never reviewed it by hand.

**[01:34]**  
Friday. The Kestrel Payments API is compliant and the partner launch is on track. Rob never reviewed it by hand.

**[01:42] Everything is code**  
Everything lives in the cluster as code: the rulesets, the APIs, and a governance status on each one.

**[01:54] Everything is visible**  
And the Dashboard turns the estate's compliance into a number anyone can read.

**[02:00] On screen:** Rob set the rules. Ines followed them. The cluster kept score.

**[02:00]**  
The week in review. Monday, Rob defined the standard once, as code. Tuesday, Ines found out on her own, fixed her API with the instructions in front of her, and handed one bad rule back to Rob, who fixed the rule. Wednesday, the same check moved into the pull request. Thursday, the rules that matter most became impossible to break. And on Friday, compliance is a number on a screen instead of a queue on Rob's desk.
