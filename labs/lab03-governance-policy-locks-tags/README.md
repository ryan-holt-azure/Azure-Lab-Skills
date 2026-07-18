# Lab 03 — Governance: Management Groups, Policy, Tags, Locks

**Domain:** Identity & Governance (20–25%) · **Week:** 1 · **Cost:** ~$0 (a couple
cents for one storage account created briefly)

## Objectives (exam skills covered)

Configure management groups · Implement and manage Azure Policy · Apply and manage
tags on resources · Configure resource locks · Manage resource groups and
subscriptions

## Build

### 3.1 — Elevate access (hidden prerequisite)
- Entra ID → **Properties** → scroll to **Access management for Azure resources**
  → toggle **Yes** → Save. Sign out and back in.
- This grants **User Access Administrator** at the root scope so management groups
  can be created. **Turn it back to No when the lab is done** — standing root
  access is a real security finding.

### 3.2 — Create a management group
- Search → **Management groups** → **+ Create** → ID `mg-lab` (permanent — cannot
  be changed later, unlike display name), display name `Lab Management Group`.
- `mg-lab` → **Subscriptions** → **+ Add** → select your subscription → Save.
  This is the shelf above the subscription — policy and RBAC assigned here rain
  down on every subscription added under it.

### 3.3 — Assign a Policy that DENIES
- Search → **Policy** → **Assignments** → **Assign policy**.
- Scope: `mg-lab` (or your subscription). Policy definition: built-in
  **Allowed locations**. Parameters: Allowed locations = **East US only**.
  Non-compliance message: a short note. Review + create.
- **Wait 10–15 minutes** — policy assignment is not instant.

### 3.4 — Watch it deny you
```bash
az group create -n rg-lab03 -l eastus

# try to put a resource in the wrong region:
az storage account create -n stlab03ryan$RANDOM \
  -g rg-lab03 -l westus2 --sku Standard_LRS
# -> rejected: RequestDisallowedByPolicy

# now the right region:
az storage account create -n stlab03ryan$RANDOM \
  -g rg-lab03 -l eastus --sku Standard_LRS
# -> succeeds
```
You are the Owner with every permission and it still says no — that's the
difference between RBAC (who may act) and Policy (what may exist). Note: the
built-in **Allowed locations** policy excludes resource groups by design; a
separate policy, **Allowed locations for resource groups**, restricts RG
placement.

### 3.5 — Tags, and forcing them with policy
- `rg-lab03` → **Tags** → `CostCenter` = `IT-Lab` → Apply.
- Open the storage account you just made → **Tags** — it's empty. **Tags do not
  inherit.**
- Policy → Assign policy → **Inherit a tag from the resource group** → Parameter
  Tag Name = `CostCenter`.
- Remediation tab → tick **Create a Managed Identity** (System assigned,
  East US) → Create. (Effect = Modify, so it needs an identity to act.)
- Policy → **Remediation** → select the assignment → **Remediate** → re-check the
  storage account's Tags.

### 3.6 — Locks: tape over the delete button
- `rg-lab03` → **Locks** → **+ Add** → name `lock-nodelete`, type **Delete** → OK.
  ```bash
  az group delete -n rg-lab03 --yes
  # -> fails: scope is locked
  ```
  You are the Owner and still can't delete it. Locks beat permissions.
- Change to **ReadOnly** → try to create anything in the RG. Also blocked.
  ReadOnly can break operations that need write to their own plane, like listing
  storage account keys.
- **Remove the lock before cleanup**, or cleanup fails.

## Exam facts

- Policy effects hierarchy: Deny, Audit, Append, Modify, DeployIfNotExists.
  **Modify** and **DeployIfNotExists** require a managed identity; **Deny** and
  **Audit** do not.
- Tags do **not** inherit by default (policy can force it). Tag names are
  case-insensitive; values are case-sensitive.
- Two lock types only: **CanNotDelete** and **ReadOnly**. Locks **inherit
  downward** to child resources and apply to everyone, including Owners. Removing
  a lock requires `Microsoft.Authorization/locks/delete` (Owner or User Access
  Administrator).
- Management group IDs are permanent; display names can be renamed anytime.
- Policy assignment and dynamic evaluation are **not instant** — allow 10–15
  minutes before assuming something is broken.

## Pro / interview talking point

Policy stops the action without touching anyone's identity — RBAC alone couldn't
have prevented the westus2 deploy without removing your own access. Tags-by-policy
is FinOps plumbing: it's how a cost center actually stays attributable at scale
instead of becoming an unowned line item on the bill.

## Job posting relevance

Policy-enforced governance is the direct answer to the HIPAA/Sophos posting's
"organizational security standards" and "security hardening" lines — a
Deny policy is a technical control that prevents non-compliant infrastructure
from ever existing, not just documentation saying it shouldn't. Resource locks
answer a different real fear at both posting types: an MSP or IT team managing
someone else's production environment needs a guardrail against the accidental
`az group delete` that ends a career.

## Cleanup

Remove the lock → delete both policy assignments (Policy → Assignments → … →
Delete) → `az group delete -n rg-lab03 --yes --no-wait` → remove the subscription
from `mg-lab`, delete `mg-lab`, and **turn elevated access back to No**. A leftover
Deny policy will silently break later labs.
