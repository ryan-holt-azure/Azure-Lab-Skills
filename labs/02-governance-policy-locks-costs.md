# Lab 02 — Governance: Management Groups, Policy, Tags, Locks and Costs

> **Scenario:** Before the network goes in, HLG's CFO and CISO set three rules. **(1)** Azure is used only in the four regions where HLG operates. **(2)** Every resource is charged to a cost center. **(3)** Nobody can accidentally delete the hub network. Finance also wants to be warned before the monthly bill surprises anyone.
>
> **Time:** ~3 h · **Cost:** < $0.50 · **Prereqs:** Lab 00 (Lab 01 for groups used in budgets/alerts is optional)

## What you'll build

```
Tenant Root Group
└── mg-hlg  (Halsted Logistics)                ← Allowed locations · Tagging standard initiative
    ├── mg-hlg-platform                        (empty: where identity/connectivity subs would live)
    ├── mg-hlg-landingzones                    ← Allowed VM sizes
    │   └── <your subscription>
    │       ├── rg-hlg-onprem-chi  rg-hlg-hub-eus  rg-hlg-spoke-weu  rg-hlg-spoke-sea
    │       └── rg-hlg-mgmt-eus    rg-hlg-data-eus rg-hlg-apps       rg-hlg-sandbox  ← exemption
    └── mg-hlg-sandbox
Budgets: subscription $50 + rg-hlg-hub-eus $20 · Action group: ag-hlg-finance
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Configure management groups | Task 1 |
| Manage subscriptions | Task 2 |
| Manage resource groups | Task 3 |
| Apply and manage tags on resources | Task 3 |
| Implement and manage Azure Policy | Task 4 |
| Configure resource locks | Task 5 |
| Manage costs by using alerts, budgets, and Azure Advisor recommendations | Task 6 |

---

## Task 1 — Build the management group hierarchy

**Why it matters:** Management groups (MGs) let you apply policy and RBAC once and have every subscription underneath inherit it.

1. Portal → **Management groups**. The first time, you may see **Start using management groups**. That creates the **Tenant Root Group**.
2. **+ Create**: ID `mg-hlg`, display name `Halsted Logistics`.
3. Open `mg-hlg` → **+ Create** three children: `mg-hlg-platform`, `mg-hlg-landingzones`, `mg-hlg-sandbox`.
4. Open `mg-hlg-landingzones` → **+ Add subscription** → select your subscription.
5. Open **Management groups** again and expand the tree.

> [!TIP]
> **🎯 EXAM TIP — Management group facts:**
> - Up to **10,000** MGs per directory, and the tree supports **six levels of depth** (not counting the root or the subscription level).
> - Each MG and each subscription has **exactly one parent**.
> - The **Tenant Root Group** can't be moved or deleted. Its ID is the tenant ID.
> - Moving a subscription needs write access on the subscription (for example **Owner**) **and** on the target parent MG (for example **Management Group Contributor**).
> - Policy and RBAC assigned to an MG **inherit down** to every child MG, subscription, resource group and resource.

> [!TIP]
> **🎯 EXAM TIP — Elevate access.** By default, not even a Global Administrator can see every subscription or the root MG. In **Entra ID → Properties → Access management for Azure resources = Yes**, a Global Administrator grants themselves **User Access Administrator at root scope (`/`)**. Turn it off when done.

> 📸 **Checkpoint 02-01** — The expanded MG tree with your subscription under `mg-hlg-landingzones`. Blur the subscription ID and tenant ID. → `screenshots/lab-02/02-01-mg-hierarchy.png`

<details><summary>CLI equivalent</summary>

```bash
az account management-group create --name mg-hlg --display-name "Halsted Logistics"
for c in platform landingzones sandbox; do
  az account management-group create --name mg-hlg-$c --display-name "HLG $c" --parent mg-hlg
done
az account management-group subscription add --name mg-hlg-landingzones --subscription "$(az account show --query id -o tsv)"
az account management-group show --name mg-hlg --expand --recurse -o jsonc
```
</details>

---

## Task 2 — Manage the subscription

1. **Subscriptions** → your subscription → **Overview** → **Rename** it to `HLG-Lab-Sub01`. (Only the display name changes; the ID never does.)
2. **Settings → Resource providers**: filter `Microsoft.App`. If it's *NotRegistered*, select **Register**.
3. **Settings → Usage + quotas**: filter **Total Regional vCPUs** across your four regions.
4. **Access control (IAM)** → **Role assignments**: note your Owner assignment and where it's inherited from.
5. **Overview → Change directory** and **Transfer billing ownership**: open them, read the warnings, and **cancel**. Don't run either.

> [!CAUTION]
> **⚠️ EXAM TRAP — Changing a subscription's directory (tenant)** removes **all Azure RBAC role assignments** and custom role definitions, and managed identities need re-creating. Resources keep running. Transferring **billing ownership** (who pays) is a different operation and doesn't touch RBAC.

> [!TIP]
> **🎯 EXAM TIP — Subscription boundaries.** A subscription is a **billing** boundary and an **access/management** boundary. It trusts exactly one Entra tenant. Quotas and limits apply per subscription per region.

> 📸 **Checkpoint 02-02** — Resource providers filtered to Microsoft.App, plus Usage + quotas. → `screenshots/lab-02/02-02-subscription-settings.png`

---

## Task 3 — Resource groups and tags

### 3a. Create the HLG resource groups
Create one in the portal to learn the form: **Resource groups → + Create** → name `rg-hlg-sandbox`, region **East US**, and on the **Tags** tab: `Project=az104-hybrid`, `Company=Halsted Logistics`, `CostCenter=CC-1001`, `Environment=lab`, `Owner=<you>`.

Create the rest in Cloud Shell:
```bash
OWNER="your-alias"   # change me
declare -A RG=( [rg-hlg-onprem-chi]=northcentralus [rg-hlg-hub-eus]=eastus [rg-hlg-spoke-weu]=westeurope
                [rg-hlg-spoke-sea]=southeastasia [rg-hlg-mgmt-eus]=eastus [rg-hlg-data-eus]=eastus [rg-hlg-apps]=eastus )
for n in "${!RG[@]}"; do
  az group create -n "$n" -l "${RG[$n]}" -o none \
    --tags Project=az104-hybrid "Company=Halsted Logistics" CostCenter=CC-1001 Environment=lab Owner="$OWNER" \
    && echo "created $n"
done
```

> [!TIP]
> **🎯 EXAM TIP — Resource group facts:**
> - A resource group's **location** only stores its metadata. Its resources can be in **any region**.
> - Resource groups **can't be renamed** or nested. A resource belongs to exactly one resource group.
> - Deleting a resource group deletes **everything in it**.
> - Moving resources between RGs or subscriptions **changes their resource IDs**. Both source and target RGs are **locked for writes during the move** (up to about 4 hours). The resource **doesn't change region**.

### 3b. Move a resource between resource groups
1. Create a throwaway storage account in the sandbox:
   ```bash
   SBX=sthlgsbx$RANDOM; az storage account create -g rg-hlg-sandbox -n $SBX -l eastus --sku Standard_LRS -o none; echo $SBX
   ```
2. Portal → the storage account → **Overview** → **Move** → **Move to another resource group** → target `rg-hlg-mgmt-eus`. Watch the **validation** step, then confirm.
3. Compare the **Resource ID** before and after (Properties blade). Then move it **back** to `rg-hlg-sandbox`. You'll use it in Task 5.

### 3c. Manage tags
1. **Portal, single resource:** storage account → **Tags** → add `DataClassification=Internal`.
2. **Portal, at scale:** **Resource groups** → select all `rg-hlg-*` → **Assign tags** → `Region-Owner=IT-Chicago` → Save.
3. **CLI, merge vs replace:**
   ```bash
   ID=$(az group show -n rg-hlg-sandbox --query id -o tsv)
   az tag update --resource-id $ID --operation Merge   --tags Purpose=experiments   # adds
   az tag list   --resource-id $ID -o jsonc
   az tag update --resource-id $ID --operation Delete  --tags Purpose=experiments   # removes that tag
   ```
   (`--operation Replace` would wipe every other tag. Don't run it on these RGs; the tag policy you add next would complain.)
4. Remove `Region-Owner` from the RGs (portal multi-select → Assign tags → delete the row).

> [!CAUTION]
> **⚠️ EXAM TRAP — Tags are NOT inherited.** A tag on a resource group doesn't automatically appear on its resources. Use **Azure Policy** (*Inherit a tag from the resource group*, Task 4) or the **Cost Management tag inheritance** setting (which affects cost records only, not the resources).

> [!TIP]
> **🎯 EXAM TIP — Tag limits:** up to **50** tag name/value pairs per resource, resource group or subscription. Tag names are case-insensitive for operations. Not every resource type supports tags. Tagging a resource needs write access to it (or the **Tag Contributor** role, which can tag without other write access).

> 📸 **Checkpoint 02-03** — Resource groups list showing the tag columns. Use **Manage view → Edit columns** to add tags. → `screenshots/lab-02/02-03-rg-tags.png`

---

## Task 4 — Azure Policy

### 4a. Allowed locations at the top management group
1. **Policy** → **Assignments** → **Assign policy**.
2. **Scope:** `mg-hlg`. **Policy definition:** *Allowed locations*. **Assignment name:** `HLG - Allowed locations`.
3. **Parameters:** East US, North Central US, West Europe, Southeast Asia.
4. **Non-compliance messages:** `HLG policy: deploy only to approved regions. See Lab 02.`
5. **Review + create**. Repeat for *Allowed locations for resource groups* with the same regions.
6. Wait about 10 minutes, then test:
   ```bash
   az group create -n rg-hlg-test-brazil -l brazilsouth --tags CostCenter=CC-1001
   az storage account create -g rg-hlg-sandbox -n sthlgbr$RANDOM -l brazilsouth --sku Standard_LRS
   ```
   Both fail with `RequestDisallowedByPolicy` and your non-compliance message.

> [!CAUTION]
> **⚠️ EXAM TRAP — "Allowed locations" doesn't cover resource groups.** The built-in *Allowed locations* policy excludes resource groups and `global` resources. To restrict where RGs are created you need *Allowed locations for resource groups* as well. Exam questions love the RG that was created in a forbidden region anyway.

### 4b. Prove a Deny, then fix the side effects with Modify
1. Assign the built-in **Require a tag on resource groups** at `mg-hlg`, tag name `CostCenter`. Name it `HLG - TEMP require CostCenter`.
2. After a few minutes: `az group create -n rg-hlg-untagged -l eastus` → **denied**. 📸
3. Think about what else this would block. Azure creates resource groups on your behalf: **NetworkWatcherRG** when you create your first VNet in a region, **AzureBackupRG_\<region\>_1** for VM backup snapshots, **DefaultResourceGroup-\<region\>** for some monitoring features. None of them carry your tag, so all would be denied.
4. Delete the TEMP assignment.
5. Build an **initiative**: **Policy → Definitions → + Initiative definition**
   - Location: `mg-hlg`. Name `HLG - Tagging standard`. Category: create `HLG`.
   - Policies: **Require a tag on resource groups**, **Add a tag to resource groups**, **Inherit a tag from the resource group if missing**.
   - Initiative parameters: `tagName` (default `CostCenter`) and `defaultTagValue` (default `CC-1001`). Map each policy's parameters to them.
6. Assign the initiative at `mg-hlg`. On the **Remediation** tab: **Create a Managed Identity** (system-assigned, East US) and **Create a remediation task** for the *Inherit* policy.
7. Test again: `az group create -n rg-hlg-untagged -l eastus` now **succeeds**, and the RG has `CostCenter=CC-1001`. Then `az network nsg create -g rg-hlg-sandbox -n nsg-hlg-tagtest` → its tags include CostCenter, copied from the RG. Delete `rg-hlg-untagged` and keep the NSG; Lab 03 uses it.

> [!TIP]
> **🎯 EXAM TIP — Effect evaluation order.** Azure Policy evaluates **Disabled → Append/Modify → Deny → Audit**, then **AuditIfNotExists/DeployIfNotExists** after the resource is created. That's why step 7 succeeded: *Add a tag* (Modify) inserted the tag **before** *Require a tag* (Deny) checked for it.

> [!TIP]
> **🎯 EXAM TIP — Managed identity and remediation.** **Modify** and **DeployIfNotExists** need a **managed identity** on the assignment, with the roles listed in the definition's `roleDefinitionIds`. New and updated resources are handled at request time. **Existing** non-compliant resources are only fixed by a **remediation task**.

> [!TIP]
> **🎯 EXAM TIP — When does it apply?** A new assignment takes effect within minutes (allow up to ~30). Compliance results appear after an evaluation cycle: about 30 minutes after assignment, then every 24 hours, or on demand with `az policy state trigger-scan`. **Deny never deletes existing resources.** They just show as non-compliant.

### 4c. Allowed VM sizes and an exemption
1. Assign *Allowed virtual machine size SKUs* at **`mg-hlg-landingzones`**, name `HLG - Allowed VM sizes (cost control)`:
   `Standard_B1s, Standard_B1ms, Standard_B2s, Standard_B2ms, Standard_B2als_v2, Standard_B2as_v2, Standard_B2ats_v2, Standard_D2s_v5, Standard_D2as_v5`
2. **Exemption:** open that assignment → **Create exemption** → scope `rg-hlg-sandbox` → category **Waiver** → expiration date 30 days from now → description `Sandbox may test larger SKUs`.

> [!TIP]
> **🎯 EXAM TIP — Exclusions vs exemptions.** An **exclusion** is set on the assignment and permanently skips a child scope. An **exemption** is a separate object with a **category** (*Waiver* or *Mitigated*), an optional **expiry**, and can target specific policies inside an initiative. Exempted resources show as *Exempt* in compliance, not as missing.

### 4d. Compliance and a custom definition
1. **Policy → Compliance**. Select the tagging initiative and find any non-compliant resources. Older resources need the remediation task, or `az policy state trigger-scan --resource-group rg-hlg-sandbox`.
2. Open [`policy/custom-allowed-environment-tag.json`](../policy/custom-allowed-environment-tag.json) and answer:
   - What happens to an RG with **no** Environment tag? (Hint: the `exists` condition.)
   - What happens to an RG tagged `Environment=Prod`? (Hint: is `notIn` case-sensitive for this value?)
   - How would you make it audit-only without editing the definition?
3. Optional: create it (**Definitions → + Policy definition**, paste the `properties` content) and assign it in **Audit** at `mg-hlg`.

<details><summary>Answers</summary>

- No tag: the `exists: true` condition is false, so `allOf` is false. **Not affected.**
- `Prod`: string comparisons in policy conditions are case-insensitive, so `Prod` matches `prod` and the RG is allowed.
- Assign it with the `effect` parameter set to `Audit`. The definition exposes the effect as a parameter for exactly this reason.
</details>

> 📸 **Checkpoint 02-04** — (a) the RequestDisallowedByPolicy error, (b) the initiative assignment's compliance page, (c) `rg-hlg-untagged` auto-tagged by Modify. → `screenshots/lab-02/02-04-policy-*.png`

<details><summary>CLI path for this whole task</summary>

[`policy/deploy-hlg-policies.sh`](../policy/deploy-hlg-policies.sh) builds the same assignments and initiative, looking up built-in definitions by display name.
</details>

---

## Task 5 — Resource locks

1. Sandbox storage account (`sthlgsbx…`) → **Locks** → **+ Add**: name `lock-readonly-demo`, type **Read-only**.
2. Try each of these and note what happens:
   - **Access keys** → *Show* → fails. Listing keys is a **POST** (`listKeys`), and Read-only blocks it.
   - **Configuration** → change the TLS version → fails (write).
   - Open **Storage browser** with *Access key* authentication → fails (needs keys). Switch to *Microsoft Entra user account* → data-plane access still depends on your data role.
3. Change the lock to **Delete** (CanNotDelete). Now try `az group delete -n rg-hlg-sandbox` → fails with `ScopeLocked`. The lock on one resource protects the whole group from deletion.
4. Remove the lock and delete the sandbox storage account.

> [!TIP]
> **🎯 EXAM TIP — Lock types:**
> - **CanNotDelete (Delete):** read and modify allowed, delete blocked.
> - **ReadOnly:** read allowed. **All writes and deletes blocked**, including **POST** operations: listing storage keys, starting/restarting/stopping VMs, some portal blades that call POST.
> - Locks **inherit** from subscription → RG → resource. The most restrictive applies.
> - Only roles with `Microsoft.Authorization/locks/*` (**Owner**, **User Access Administrator**) can create or delete locks. **Contributor can't.**
> - Locks apply to the **management (control) plane** only. A ReadOnly lock doesn't stop someone with a SAS token or data role from writing blobs.

> [!CAUTION]
> **⚠️ EXAM TRAP — ReadOnly lock on a VM's resource group** stops anyone from **starting or restarting** the VM (POST actions), even Owners, until the lock is removed. A ReadOnly lock is almost never what you want on running workloads.

> [!NOTE]
> In Lab 03 you'll add a **CanNotDelete** lock to `vnet-hlg-hub-eus` once it exists. You lock the VNet resource rather than the whole RG, so you can still delete Bastion and the VPN gateways from the hub RG to save money.

> 📸 **Checkpoint 02-05** — The *Access keys* error caused by the ReadOnly lock. → `screenshots/lab-02/02-05-readonly-lock.png`

---

## Task 6 — Costs: budgets, alerts, Advisor

### 6a. Action group for finance
**Monitor → Alerts → Action groups → + Create**: RG `rg-hlg-mgmt-eus`, name `ag-hlg-finance`, display `HLG Finance`. Notification: **Email** to your address. Create, then **Test action group** → select *Budget* sample.

### 6b. Budgets
1. Open `budget-hlg-safety-net` (Lab 00) → **Edit** → add the action group `ag-hlg-finance` to the 90% condition.
2. **Create a resource-group budget:** **Cost Management → Budgets** → scope `rg-hlg-hub-eus` → `budget-hlg-hub` → **$20/month** → alerts at **Actual 80%** and **Forecasted 100%** → action group `ag-hlg-finance`. The hub will hold Bastion and the VPN gateways, your biggest costs.
3. **Cost alerts → + Add → Anomaly alert** at subscription scope → email yourself.

### 6c. Cost analysis
1. **Cost analysis** → view **Cost by resource**, then **Daily costs**. Group by **Resource group**, then **Tag: CostCenter**.
2. **Cost Management → Settings → Tag inheritance** → turn it on, so subscription/RG tags are applied to usage records even when a resource lacks the tag.
3. **Download** the view as CSV. You'll compare it with the Lab 16 teardown.

### 6d. Azure Advisor
1. **Advisor → Recommendations**: open the **Cost**, **Security**, **Reliability**, **Operational excellence** and **Performance** tabs. A new subscription may have few cost items. Come back after Lab 08.
2. **Advisor score**: note how it's calculated per category.
3. **Configuration**: scope to your subscription. Under **VM/VMSS right sizing**, set the CPU threshold to **5%** and the lookback to **7 days**.
4. **Alerts (Advisor) → + New Advisor alert**: category **Cost**, action group `ag-hlg-finance`.
5. Pick any recommendation and practise **Postpone** and **Dismiss**.

> [!TIP]
> **🎯 EXAM TIP — Which cost tool?**
> - **Budget:** "Warn me when spend crosses X." Actual or forecasted thresholds, email and/or action group. Scopes: management group, subscription, resource group (and billing scopes). Never stops resources by itself.
> - **Cost alerts:** budget alerts, **anomaly** alerts, credit alerts and department spending quotas (EA).
> - **Advisor:** "What should I change?" Right-size or shut down underused VMs, reserved instance and savings plan purchases, unused public IPs. Recommendations are free, refresh periodically, and can be exported or turned into Advisor alerts.
> - **Cost analysis:** "Where did the money go?" Group by RG, service, tag, location.

> 📸 **Checkpoint 02-06** — Both budgets, plus the Advisor configuration page. → `screenshots/lab-02/02-06-budgets-advisor.png`

---

## Break-fix challenges

1. A colleague deploys a VM in `rg-hlg-spoke-sea` with size `Standard_D4s_v5` and gets an error. Find the exact policy assignment that denied it using the **Activity log**, without guessing.
2. You need `rg-hlg-sandbox` deleted, but `az group delete` says `ScopeLocked` and you can't see a lock on the RG. Where else can the lock be?
3. A storage account in `rg-hlg-data-eus` has no `CostCenter` tag even though the RG does. Get it tagged without editing the storage account directly.

<details><summary>Fixes</summary>

1. **Activity log** → filter *Status = Failed* → open the operation → JSON → `policyAssignmentName` / `policyDefinitionDisplayName` under `RequestDisallowedByPolicy`. (`az monitor activity-log list --status Failed --resource-group rg-hlg-spoke-sea`)
2. On the **subscription** (inherited down) or on **any resource inside** the RG. Check subscription → Locks and every resource's Locks blade, or `az lock list --resource-group rg-hlg-sandbox`.
3. **Policy → Remediation** → create a remediation task for *Inherit a tag from the resource group if missing* scoped to the RG. The assignment's managed identity applies the tag.
</details>

---

## Knowledge check

1. You must ensure that all resource groups are created only in East US, while resources inside them may be in East US or West US. Which two built-in policies do you assign?
2. Users report they can't start a VM in an RG. You find a ReadOnly lock on the RG. Who can remove it: Contributor, Owner, or User Access Administrator?
3. A budget fires at 100% actual. What happens to running resources?
4. An initiative contains a Modify policy. Assignment fails with a message about a missing identity. What's missing?
5. You moved a storage account to a new subscription. What changed: region, resource ID, data, or access keys?

<details><summary>Answers</summary>

1. *Allowed locations for resource groups* = East US, and *Allowed locations* = East US + West US.
2. **Owner** or **User Access Administrator**. Contributor lacks `Microsoft.Authorization/locks/*`.
3. Nothing. Budgets alert only (unless an action group runs automation).
4. A **managed identity** on the assignment (system- or user-assigned) with the roles the definition requires.
5. Only the **resource ID**. The region, data and keys are unchanged.
</details>

---

## Clean up

Keep the MGs, policies, RGs, budgets and action group; every later lab relies on them. Delete only the sandbox storage account (Task 5) and `rg-hlg-untagged`.

> [!WARNING]
> **💲 COST.** Nothing in this lab bills meaningfully. Your budgets will start warning you as Labs 06–07 add Bastion and VPN gateways.

## 📣 Document it

```bash
git add notes/lab-02.md screenshots/lab-02 && git commit -m "Lab 02: MG hierarchy, Azure Policy (deny/modify/exemption), tags, locks, budgets, Advisor"
```

**LinkedIn post template:**
> Lab 02 of my AZ-104 hybrid build: governance before infrastructure.
>
> 🏛️ Management group hierarchy with the subscription in a landing-zones group
> 🌍 Allowed-locations policy, and the trap: it doesn't cover resource groups, so you need a second policy
> 🏷️ A tagging initiative where a Modify policy auto-tags resource groups Azure creates for you (NetworkWatcherRG, backup RGs), so the Deny policy never blocks them. Policy effect order: Modify runs before Deny.
> 🔒 ReadOnly vs CanNotDelete locks, and why ReadOnly blocks listing storage keys and starting VMs
> 💰 Subscription + resource group budgets, anomaly alerts, Advisor right-sizing config
>
> #Azure #AZ104 #AzurePolicy #CloudGovernance #FinOps #LearningInPublic
