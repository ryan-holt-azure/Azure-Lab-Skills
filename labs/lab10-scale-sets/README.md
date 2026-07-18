# Lab 10 — Scale Sets

**Domain:** Compute (20–25%) · **Week:** 2 · **Cost:** low — 2 small instances,
short-lived

## Objectives (exam skills covered)

Deploy and configure virtual machine scale sets

## Build

1. Create a **Flexible VMSS**, 2 instances, spread across **zones 1–2**.
2. Configure an **autoscale rule**: add an instance when CPU > 70% (stress the
   VMs with a CPU load loop to trigger it for real), scale in when CPU < 30%.
3. Watch **one full autoscale cycle** — don't just configure the rule and move
   on; observe the scale-out actually happen, then the scale-in, including the
   cool-down period between events.
4. Review the **upgrade policy** options (Manual / Automatic / Rolling).

## Exam facts

- **Uniform** = identical instances, the classic/original model. **Flexible** =
  mixed sizes, spot + standard mixed, and is the modern default choice.
- Autoscale needs **min / max / default** instance counts configured; scale-out
  and scale-in rules are configured as a pair.
- Zonal spreading is decided at **creation**.

## Pro / interview talking point

Autoscale math — cool-down periods, flapping (rapid scale-out/scale-in
oscillation) — is a favorite real-world gotcha that only shows up if a full
cycle is actually watched, not just configured. That's the difference between
"I set up autoscale" and "I understand autoscale."

## Job posting relevance

Honest note: neither researched posting names autoscaling directly — both are
infrastructure/security generalist roles, not high-scale application hosting.
This lab still matters for general cloud engineering credibility and for the
"infrastructure modernization" language both postings use, but it's not a
line-item match the way Labs 04, 06, or 13 are. Don't force this one in an
interview if it doesn't come up naturally.

## Cleanup

```bash
az group delete -n rg-lab10 --yes --no-wait
```
