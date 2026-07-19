# Scenario 1 — The Site Goes Down During a Sale

## Business context

A mid-size retailer runs its ordering site on two web VMs behind a Standard
Load Balancer (built in Lab 15). It's the first hour of a major promotional
sale — traffic is high, and every minute of downtime is lost revenue at the
worst possible time.

## What gets reported

**Not this:** "The NIC-level NSG is blocking the health probe port."

**This:** A Slack message from the marketing lead: *"Customers are saying the
checkout page won't load. Sale just went live 20 minutes ago. Is something
broken?"* Then, three minutes later, a second message: *"This is costing us
money every minute — how long until it's fixed?"*

## Business consequence if unresolved

Lost revenue during the highest-traffic window of the quarter, plus a hit to
customer trust that outlasts the outage itself — the exact "website goes
down → lost revenue, trust, customers" pattern.

## Investigation

1. **Confirm the symptom first.** Hit the site yourself. Confirm it's actually
   down (not a marketing-side caching issue or a single user's problem).
2. **Check the Load Balancer's backend health** (Lab 15). One or both backend
   VMs show unhealthy in the health probe status.
3. **Don't assume the app crashed — check the network path first**, since
   that's faster to rule in/out than debugging application code under
   pressure. Use **Effective security rules** (Lab 13) on the affected VM's
   NIC to see the merged NSG result.
4. Find it: a rule was added *that morning* — "Deny all inbound except
   management IPs," added as a well-intentioned hardening pass — and it
   accidentally blocks the Load Balancer's health probe source
   (`AzureLoadBalancer` service tag), not just external traffic.
5. Confirm with **IP Flow Verify** (Lab 17): test the probe port from the
   Load Balancer's perspective, confirm it's the specific rule blocking it,
   not something else.

## Root cause

A security-hardening change was made without checking its effect on
infrastructure the change author didn't know depended on that traffic path —
a **process gap**, not a knowledge gap. The engineer who made the change knew
NSGs; they didn't know the Load Balancer's probe traffic needed an explicit
allow for the `AzureLoadBalancer` tag.

## Resolution

1. Add an inbound allow rule for the `AzureLoadBalancer` service tag on the
   affected NSG, at a priority that doesn't conflict with the new hardening
   rule's intent.
2. Confirm in the portal: backend health flips back to healthy within the
   probe interval.
3. Confirm from outside: the checkout page loads again. Reply to the Slack
   thread with the actual resolution time, not just "fixed."

## Prevention / hardening

- Any NSG change touching a subnet with a Load Balancer backend gets a
  **documented pre-change checklist** item: "does this rule allow the
  `AzureLoadBalancer` tag and any other required platform traffic?"
- Add a **metric alert** (Lab 16) on Load Balancer health probe status
  specifically, routed to the existing `ag-email-ryan` action group — so this
  is caught by monitoring within a minute of it happening, not by a customer
  complaint 20 minutes later.
- If change volume justifies it, this is the argument for the CI/CD pipeline
  pattern from the Cloud Engineer repo: NSG changes as code, reviewed in a
  pull request, instead of a portal click nobody else saw.

## Skills drawn from

| Lab | What it contributed |
|---|---|
| Lab 15 (Load Balancer) | Recognizing and confirming the health-probe symptom |
| Lab 13 (NSG / Effective rules) | Finding the actual blocking rule |
| Lab 17 (Network Watcher) | Confirming the diagnosis with IP Flow Verify |
| Lab 16 (Monitor/Alerts) | The preventive fix — alerting before customers notice |

## Interview framing (problem → action → result)

*"During a peak sales event, our checkout site went down. I traced it in
under ten minutes to a same-day NSG hardening change that had accidentally
blocked our Load Balancer's health probe traffic — not an application bug.
I restored service by allowing the correct service tag, then added a
dedicated health-probe alert so any future recurrence gets caught by
monitoring instead of a customer complaint."*
