# Scenario 4 — The Surprise Cloud Bill

## Business context

A small company's leadership approved a $5,000/month Azure budget for the
current project. It's the end of the month.

## What gets reported

**Not this:** "Identify and remediate cost anomalies in the subscription."

**This:** An email from the owner, forwarded from finance, subject line
**"Why is this bill $14,000??"** — with the invoice attached and no other
context. Nobody on the technical team flagged it before the invoice arrived.

## Business consequence if unresolved

This is "cloud costs double → money wasted every month," except it's worse
than double, and it happened *silently* — nobody found out until the bill
posted. Beyond the immediate money, this is exactly the kind of surprise
that makes leadership stop trusting the cloud team's estimates, which makes
the *next* project's budget conversation much harder.

## Investigation

1. **Cost Analysis first** (Lab 04): group by **Resource group**, then
   **Service name**, granularity **Daily** — don't guess, look at where the
   money actually went and when it started climbing.
2. Find the pattern: spend was flat and on-budget for three weeks, then
   roughly doubled starting a specific date. That date matters more than
   the total — it points at *what changed*, not just *that something's
   expensive*.
3. Cross-reference that date against what was deployed. Likely candidates,
   in order of how often this actually happens: a **VM left running**
   that should have been deallocated (a dev/test box, or — ironically — a
   **Bastion instance** left deployed after a lab or troubleshooting
   session, which bills continuously whether it's used or not), an
   **oversized VM SKU** picked for a "quick test" and never resized down,
   or a **duplicate resource** created by a second engineer who didn't know
   one already existed.
4. Confirm: check the resource's creation date against the spend inflection
   point. They match.

## Root cause

No **budget alert** existed to catch this before the invoice did — the
$5,000 budget was a number in an approval email, not a technical control
that actually notified anyone. The overspend itself was an honest mistake
(forgetting to deallocate something); the reason it went unnoticed for
three weeks is a process gap.

## Resolution

1. **Stop the bleeding first**: deallocate or delete the offending
   resource immediately (matching the exact "deallocate when done, every
   time" discipline this whole lab portfolio has practiced from Lab 0
   onward).
2. **Right-size** anything legitimately still needed but oversized.
3. Pull the exact numbers from Cost Analysis — what it was costing per day,
   how many days it ran unnecessarily — so the response to leadership is a
   specific dollar figure and a specific fix, not "we're looking into it."

## Prevention / hardening

This is the part that actually rebuilds trust with leadership, not just
fixes this month's bill:

- **Budget with real alert thresholds** (Lab 04): 50%, 80%, 100% actual,
  plus a **Forecasted 100%** alert — the one that would have caught this
  *before* the invoice, not after.
- **Tagging standard** (Lab 03) applied to every resource — `Owner`,
  `Project`, `Environment` — so if this happens again, Cost Analysis can
  be filtered straight to who's responsible instead of hunting through
  every resource group.
- A **weekly Cost Analysis check** as a standing habit, not just a reaction
  to a bad invoice — the same "check this every session" discipline from
  Lab 04, applied at team scale.

## Skills drawn from

| Lab | What it contributed |
|---|---|
| Lab 04 (Cost/Budgets/Advisor) | Diagnosing the spend pattern, the preventive alert fix |
| Lab 03 (Tags/Policy) | Tagging standard so cost is attributable next time |
| Credit-protection discipline (repo-wide) | Recognizing the "forgot to deallocate" pattern immediately, because it's the exact mistake this whole portfolio's rules exist to prevent |

## Interview framing (problem → action → result)

*"A project's Azure spend came in almost 3x over budget with zero warning
before the invoice. I used Cost Analysis to trace it to a single
oversized resource left running for three weeks, shut it down, and
quantified the exact overspend for leadership. More importantly, I
implemented budget alerts with a forecasted-spend threshold and a
tagging standard, so the next anomaly gets caught by monitoring within
days, not discovered on an invoice a month later."*
