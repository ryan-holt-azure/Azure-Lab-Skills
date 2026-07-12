# Lab 04 — Cost Control: Action Groups, Budgets, Advisor

**Domain:** Identity & Governance (20–25%) · **Week:** 1 · **Cost:** ~$0

This lab protects the other seventeen. Do it before building a single VM.

## Objectives (exam skills covered)

Manage costs by using alerts, budgets, and Azure Advisor recommendations

## Build

### 4.1 — Build the action group first
- Search → **Monitor** → **Alerts** → **Action groups** → **+ Create**.
- Basics: resource group `rg-lab04` (create it), action group name
  `ag-email-ryan`, **display name capped at 12 characters** (it's the alert
  sender name).
- Notifications: type = Email, name `EmailMe`, tick Email, enter your address →
  OK → Review + create. Check inbox for the confirmation email.
- An action group is the "who do we call" list — budget alerts, CPU alerts,
  backup failures, autoscale events all route through the same object. Build
  once, reuse everywhere (Lab 16 reuses this exact group).

### 4.2 — The budget that guards the credit
- Search → **Cost Management + Billing** → your subscription → **Budgets** →
  **+ Add**.
- Scope: subscription. Name `budget-lab-50`. Reset period: Monthly. Amount: `50`.
- Alert conditions: add rows for **Actual 50%**, **Actual 80%**, **Actual 100%**,
  and **Forecasted 100%**. Actual = already spent; Forecasted = predicted to
  spend — Forecasted is the one that warns before the money is gone.
- Alert recipients: your email. Action groups: `ag-email-ryan` → Create.

### 4.3 — Cost analysis: find what's eating you
- Cost Management → **Cost analysis**. Group by **Service name**, then
  **Resource group**. Granularity: **Daily**.
- Check this every session — if a number surprises you, something was left
  running (usually Bastion or an un-deallocated VM).

### 4.4 — Azure Advisor: the free consultant
- Search → **Advisor** → **Overview**. Click through all five tabs: Cost,
  Security, Reliability, Operational Excellence, Performance.
- Open any recommendation, read the impact, practice the **Dismiss** and
  **Postpone** workflow.

## Exam facts

- **Budgets alert only — they never stop spending.** Nothing in Azure
  automatically caps subscription spend, except a spending limit on free/credit
  accounts. If a question offers "the budget will prevent overspending," that's
  the wrong answer.
- Advisor's five pillars: Cost, Security, Reliability, Operational Excellence,
  Performance. Advisor pulls its Security findings from Microsoft Defender for
  Cloud.

## Pro / interview talking point

This is the guardrail protecting the study credit itself — and the identical move
to make on day one of any real subscription inherited at a new job: open Advisor,
read Security and Cost, bring three findings to the first team meeting. Costs
twenty minutes, looks like a wizard in week one.

## Cleanup

Keep `ag-email-ryan` and the budget running for the rest of the 30-day window —
this lab's resources are meant to persist and protect the others. Only
`rg-lab04` itself (if anything test-only landed in it) needs deleting at the very
end of the study window.
