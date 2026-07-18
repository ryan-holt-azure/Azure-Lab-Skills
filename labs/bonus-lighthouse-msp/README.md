# Bonus Lab — Azure Lighthouse (MSP Multi-Customer Administration)

**Not an AZ-104 exam objective.** This lab is included specifically because a real
job posting listed *"prior experience handling multiple customers at an IT
consultancy or MSP"* as a requirement, and Azure Lighthouse is the direct,
Azure-native answer to that. It doesn't appear on the exam — don't study it as
exam content, but do build it as portfolio content.

**Cost:** ~$0. Lighthouse is a delegation/RBAC construct — no compute, no
storage. Any cost comes only from whatever test resources exist in the customer
subscription being delegated.

## Objectives (not exam-mapped — job-posting-mapped)

Configure cross-tenant delegated resource management so a "managing tenant" can
administer resources that live in a separate "customer tenant," without a guest
account or a shared password in the customer's directory.

## Prerequisite: you need two tenants

Lighthouse delegates *from* a customer tenant *to* a managing tenant — one
tenant alone can't demonstrate it. If a second real customer tenant isn't
available:

- Create a **second Entra ID tenant for free** (Entra ID → Manage tenants →
  Create) to play the role of "Customer A." This costs nothing — tenants
  themselves are free, same as the primary lab tenant from Lab 0's setup.
- Alternatively, if a colleague or friend has their own tenant and is willing to
  test this with you, that's a more realistic rehearsal — but not required.

## Build

1. **In the customer tenant** (the second one, or your simulated "Customer A"):
   sign in as an Owner/admin of a subscription there.
2. Get Microsoft's public **Lighthouse sample ARM template** (search
   `Azure Lighthouse` on the Azure Quickstart Templates gallery, or use the
   portal's built-in **"Service providers" → "Delegate a subscription"** flow,
   which walks through the same thing without hand-authoring the template).
3. Fill in the delegation: which **role** to grant (start with **Reader**, then
   try **Contributor** once the mechanism is confirmed working), at what
   **scope** (a single resource group is safer to test with than a whole
   subscription), and which **user or group in your managing tenant** receives
   it.
4. **Deploy the delegation** in the customer tenant. This registers the
   delegation — the customer's resources stay in the customer's tenant; nothing
   moves.
5. **Switch to your managing tenant.** Go to **Azure Lighthouse → My customers**
   — the customer tenant/subscription should now appear, without ever signing
   into it directly.
6. From the managing tenant, **manage a resource in the delegated resource
   group** (view it, check its IAM blade, or — if Contributor was granted —
   make a small change) to confirm the delegation actually works end to end.
7. Read (don't need to fully build) **Azure Lighthouse → My customers → Offers**
   — this is how a real MSP practice formalizes delegated management at scale
   via Marketplace "Managed Service" offers, instead of one-off manual
   delegations per customer.
8. **Remove the delegation** from the customer side when done (My customers →
   remove delegation) — same "clean up after yourself" discipline as every
   other lab.

## Real-world facts (not exam facts — there is no exam here)

- Lighthouse delegates access via **Azure Delegated Resource Management**. The
  customer remains the owner of their own tenant and subscription; the managing
  tenant gets *only* the RBAC roles explicitly delegated, at the scope
  explicitly delegated — and the customer can revoke it at any time.
- Delegated access appears under **My customers** in the managing tenant — no
  guest account, no password, no separate login into the customer's directory
  is ever needed.
- Real MSPs combine Lighthouse with **Azure Policy/Initiatives** (Lab 03) to
  apply one governance baseline across every delegated customer subscription
  from a single control plane — the same governance building blocks from Lab 03,
  just applied across tenant boundaries instead of within one.

## Pro / MSP talking point — be honest about what this proves

*"I've built and torn down the actual delegation mechanism MSPs use to manage
customer Azure resources without shared credentials or guest accounts, and I can
speak concretely to how governance baselines apply across multiple delegated
customer subscriptions from one pane."*

Say it that way, not as years of real client-facing MSP history — this lab
proves hands-on fluency with the *mechanism*, which is genuinely useful and
honest, but it isn't a substitute for real client experience if an interviewer
asks directly. Frame it as what it is.

## Job posting relevance

Already the point of this whole lab, but stated plainly: the alternative to
Lighthouse is shared credentials or standing guest accounts across customer
tenants — exactly the "over-broad admin" and "old access keys" categories of
boring misconfiguration that cause real breaches. This lab is the MSP
posting's headline requirement solved the way a real consultancy actually
solves it, not worked around with a shared password spreadsheet.

## Cleanup

- Remove the Lighthouse delegation from the customer tenant.
- Delete any test resources created in the customer subscription/resource group
  used for the demonstration.
- If a second tenant was created solely for this lab and isn't needed going
  forward, it can be left alone (tenants are free) or deleted via Entra ID →
  Manage tenants, at your discretion.
