# Scenario 2 — The Compliance Audit Finding

## Business context

A healthcare-adjacent company (HIPAA applies) is going through an annual
third-party security audit. The auditor's preliminary report lands on your
desk two weeks before the final review.

## What gets reported

**Not this:** "Configure storage account network rules and enable diagnostic
logging."

**This:** An email from the compliance officer, subject line **"Urgent —
audit findings, need remediation plan by Friday"**, with three bullet points
pasted from the auditor's report:
- *"Storage account `stclinicaldata01` allows access from all networks."*
- *"RDP (3389) is open to the internet on `vm-billing01`."*
- *"No diagnostic logging configured on production resources — unable to
  verify who accessed what, when."*

## Business consequence if unresolved

This is "database exposed → risk, compliance, potential fines" directly. In
a HIPAA context specifically, an open storage account holding clinical data
and no access logging isn't a technical footnote in the audit report — it's
the finding that determines whether the audit passes, and repeat findings
put contracts and licensure at risk.

## Investigation

Three findings, three fixes — work them in order of actual risk, not the
order they were listed:

1. **Storage account public access** (highest risk — data exposure). Confirm
   in the portal: Networking blade shows "Allow access from all networks."
   Confirm what's actually reachable: try accessing a blob anonymously from
   outside any allowed network.
2. **Open RDP** (second-highest — this is the "open port" category of boring
   misconfiguration that's behind most real breaches, not a sophisticated
   attack). Confirm the NSG rule allowing 3389 from `Any` source.
3. **No logging** (lower immediate risk, but it's *why the first two weren't
   caught sooner* — the actual root cause behind all three findings existing
   at once).

## Root cause

Not three unrelated mistakes — one pattern: resources were provisioned
quickly to meet a deadline, with security hardening treated as a "later"
task that never got scheduled, and no logging existed to catch the gap in
the meantime. The audit is the first time anyone found out.

## Resolution

1. **Storage account** (Lab 05): restrict network access to the specific
   VNet (service endpoint) plus any legitimate named IPs; confirm anonymous
   access now fails, confirm the application/service that legitimately needs
   access still works.
2. **RDP exposure** (Lab 13): remove the NSG rule allowing 3389 from the
   internet. Deploy **Bastion** for administrative access instead — no
   public IP on the VM at all going forward.
3. **Logging** (Lab 16): enable diagnostic settings on the affected
   resources, routed to a Log Analytics workspace. Write and save one KQL
   query per resource type that answers "who accessed this and when" —
   that's the specific artifact the auditor will ask for next time.

## Prevention / hardening

This is the part that actually satisfies an auditor — not just "we fixed
the three items," but "here's what stops this from recurring":

- **Azure Policy** (Lab 03): assign a Deny policy for public network access
  on storage accounts, and an Audit policy flagging any NSG rule allowing
  management ports from `Any` source, at the management group level so it
  applies to every future resource automatically.
- **Remediation task** for any existing non-compliant resources found by
  the policy scan — proof the fix isn't just the three items the auditor
  happened to catch.
- Document the fix and the policy in one place — this is the artifact for
  the compliance officer, not just a closed ticket.

## Skills drawn from

| Lab | What it contributed |
|---|---|
| Lab 05 (Storage firewall) | Locking down the exposed storage account |
| Lab 13 (NSG / Bastion) | Removing public RDP, replacing with Bastion |
| Lab 16 (Monitor/Logs) | Enabling logging, writing the audit-answering KQL query |
| Lab 03 (Policy) | The preventive fix — Deny/Audit policy so this can't recur silently |

## Interview framing (problem → action → result)

*"An audit flagged an exposed storage account, open RDP, and missing
logging on a HIPAA-relevant environment. I remediated all three within the
week — network-restricted the storage account, replaced open RDP with
Bastion, and enabled diagnostic logging — then assigned an Azure Policy
initiative so the same class of finding gets caught automatically on any
future resource, not just re-discovered at the next annual audit."*
