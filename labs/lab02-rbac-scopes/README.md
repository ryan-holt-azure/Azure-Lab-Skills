# Lab 02 — RBAC: Roles, Scopes, Custom Roles

**Domain:** Identity & Governance (20–25%) · **Week:** 1 · **Cost:** ~$0

## Objectives (exam skills covered)

Manage built-in Azure roles · Assign roles at different scopes · Interpret access
assignments

## Build

### 2.1 — Build the sandbox
```bash
az group create -n rg-lab02 -l eastus
```

### 2.2 — Grant Reader at SUBSCRIPTION scope
- Search → **Subscriptions** → your subscription → **Access control (IAM)** →
  **+ Add** → **Add role assignment**.
- Role: **Reader**. Member: Test Nurse One (from Lab 01). Review + assign.
- She can now read every resource group and resource under this subscription,
  including ones that don't exist yet — permissions flow downhill.

### 2.3 — Grant Contributor at RESOURCE GROUP scope
- Resource groups → `rg-lab02` → **IAM** → **+ Add** → **Add role assignment**.
- Role: **Contributor**. Member: Test Nurse One. Review + assign.
- She's now Reader across the whole subscription AND Contributor in one RG.
  **Azure adds permissions together — it never subtracts.** There is no "deny"
  role.

### 2.4 — Read the access (the forensic move)
- `rg-lab02` → **IAM** → **Check access** tab → search Test Nurse One → click her.
- Look at the **Scope** column: one assignment says *This resource*, the other
  says *Inherited (from the subscription)*. This blade answers "why can this
  person see that?" in thirty seconds.

### 2.5 — Try to edit a built-in role (you can't)
- Subscription → **IAM** → **Roles** tab → find **Contributor** → try to edit.
  Azure won't let you — built-in roles belong to Microsoft.
- Click **…** on Contributor's row → **Clone**.
- Basics: name `Contributor No Network`, baseline = start from role Contributor.
- Permissions → **+ Exclude permissions** → search `Microsoft.Network` → tick the
  Write actions → Add.
- JSON tab shows:
  ```json
  "actions": [ "*" ],
  "notActions": [ "Microsoft.Network/*/write" ]
  ```
  Excluded permissions land in `notActions` — a subtraction from *this role's*
  grant, not a deny.
- Review + create (propagation takes ~1 minute).

### 2.6 — Assign it and watch the trap spring
- `rg-lab02` → IAM → assign `Contributor No Network` to Test Nurse One.
- Sign in as her (private window) → try to create a VNet in `rg-lab02`. **It still
  works** — because her original plain Contributor assignment from 2.3 is still
  there, and Azure adds grants. `notActions` cannot block a permission handed out
  by a *different* assignment.
- Remove the plain Contributor assignment from 2.3 → try the VNet again as her.
  **Now it's denied.** Try creating a storage account → works fine.

## Exam facts

- Roles inherit **down** scope: management group → subscription → resource group
  → resource.
- There is no "deny" in a role definition. `notActions` subtracts from `actions`
  within the same role — it does not block grants from other assignments.
- **Owner** = Contributor + the ability to grant roles to others. **User Access
  Administrator** = can grant roles but can't build resources.
- You cannot modify built-in roles — clone to a custom role. Custom roles need at
  least one assignable scope.
- Entra directory roles ≠ Azure RBAC roles — know which system a question is in.
- The only true blockers to accumulated grants: Azure Policy, resource locks, and
  Deny Assignments (which you can't create by hand).

## Pro / interview talking point

Least privilege is the first thing auditors check in healthcare and regulated
environments. "Check access" is the forensic tool you reach for the day someone
asks "why does this person have access to that?" — knowing it exists, and having
broken/fixed the NotActions trap yourself, is a stronger answer than reciting the
rule.

## Cleanup

```bash
az group delete -n rg-lab02 --yes --no-wait
```
Also remove the subscription-scope Reader assignment (Subscription → IAM → Role
assignments → select → Remove). Stale role assignments are how companies fail
audits.
