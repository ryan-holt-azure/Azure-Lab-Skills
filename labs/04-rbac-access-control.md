# Lab 04 — Role-Based Access Control Across Scopes

> **Scenario:** The foundation is live, and HLG's teams want in. Auditors need to see everything and change nothing. Chicago's network team owns the hub and on-prem networks. EU Operations runs its own spoke. APAC Operations may restart servers but must not touch the network. Analysts read shipment data but must never see storage keys. And the Northbridge contractor gets read-only access to the EU spoke. You'll implement least privilege at every scope and prove it by signing in as each person.
>
> **Time:** ~2.5 h · **Cost:** $0 (VMs from Lab 03 running ≈ $1/day) · **Prereqs:** Labs 01–03

## The access plan

| Principal | Role | Scope | Why |
|---|---|---|---|
| `grp-hlg-auditors` | Reader | **Management group** `mg-hlg` | See every current and future subscription |
| `grp-hlg-network-ops` | Network Contributor | **RG** `rg-hlg-hub-eus`, `rg-hlg-onprem-chi` | Manage networks, nothing else |
| `grp-hlg-eu-ops` | Contributor | **RG** `rg-hlg-spoke-weu` | Full control of their spoke, no role assignments |
| `grp-hlg-apac-ops` | Virtual Machine Contributor | **RG** `rg-hlg-spoke-sea` | Operate VMs, not networks |
| `grp-hlg-data-analysts` | Storage Blob Data Reader + Reader | **Resource** `sthlgdata…` | Read blobs, see the account, no keys |
| `grp-hlg-eu-partners` (guest) | Reader | **RG** `rg-hlg-spoke-weu` | Contractor visibility |
| `grp-hlg-it-admins` | Role Based Access Control Administrator, *with condition* | **Subscription** | Delegate access management without handing out Owner |
| You (`labadmin`) | Storage Blob Data Contributor | **Resource** `sthlgdata…` | Owner isn't enough for blob data (Task 4) |

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Manage built-in Azure roles | Tasks 1, 5, 8 |
| Assign roles at different scopes | Tasks 2–5 |
| Interpret access assignments | Tasks 6, 7 |

---

## Task 1 — Read built-in role definitions

1. Subscription → **Access control (IAM)** → **Roles**. Search for and open each of these, then select **View → Permissions** and **JSON**:
   - **Owner**, **Contributor**, **Reader**
   - **User Access Administrator**, **Role Based Access Control Administrator**
   - **Virtual Machine Contributor**, **Network Contributor**
   - **Storage Account Contributor**, **Storage Blob Data Reader**
2. For each, note **Actions**, **NotActions**, **DataActions** in your notes. Compare Contributor's `NotActions` with Owner's.
3. CLI view:
   ```bash
   az role definition list --name "Virtual Machine Contributor" --query "[0].permissions[0]" -o jsonc
   az role definition list --name "Storage Blob Data Reader"   --query "[0].permissions[0].dataActions"
   ```

> [!TIP]
> **🎯 EXAM TIP — The four fundamental roles:**
> - **Owner:** everything, including assigning roles.
> - **Contributor:** everything **except** granting access (`Microsoft.Authorization/*/Write`/`Delete` are in NotActions), so it also **can't manage locks**.
> - **Reader:** view everything on the control plane. No data access, no keys.
> - **User Access Administrator:** manage access only, no resources.
>
> Newer: **Role Based Access Control Administrator** manages role assignments and can be **constrained with conditions** (which roles, which principal types). That's the least-privilege answer when a question says "delegate access management without full Owner rights".

> [!CAUTION]
> **⚠️ EXAM TRAP — Control plane vs data plane.** `Actions` manage the resource through Azure Resource Manager. `DataActions` act on the **data inside** it (blobs, queue messages, Key Vault secrets). **Owner/Contributor have no DataActions**, but they can call `listKeys`, so they reach data **through access keys**. Storage Account Contributor can too. A "can't see keys but can read blobs" requirement means **Storage Blob Data Reader** and no key-listing role.

---

## Task 2 — Assign at management group scope

1. **Management groups** → `mg-hlg` → **Access control (IAM)** → **+ Add → Add role assignment**.
2. Role **Reader** → Members: **User, group, or service principal** → `grp-hlg-auditors`.
3. If your tenant has P2, you'll see an **Assignment type** tab (*Eligible* / *Active*, which is PIM). Choose **Active**, **Permanent**.
4. **Review + assign**.

> [!TIP]
> **🎯 EXAM TIP — Assignment = principal + role definition + scope.** Scopes form a hierarchy: **management group → subscription → resource group → resource**. Assignments **inherit down**. You can't remove an inherited permission at a lower scope; you'd use a deny assignment, which you can't create directly (Blueprints, managed applications and deployment stacks create them). Roles are **additive**: a user's effective access is the union of every assignment.

---

## Task 3 — Assign at resource group scope

Do the first two in the portal (RG → **Access control (IAM)** → Add role assignment), then run the script for the rest and compare:

| RG | Role | Group |
|---|---|---|
| `rg-hlg-hub-eus` | Network Contributor | `grp-hlg-network-ops` |
| `rg-hlg-spoke-sea` | Virtual Machine Contributor | `grp-hlg-apac-ops` |

```bash
bash rbac/assign-hlg-roles.sh     # adds the remaining rows from the access plan (idempotent)
az role assignment list --resource-group rg-hlg-spoke-weu -o table
```

> [!TIP]
> **🎯 EXAM TIP — Assign to groups, not users.** It's easier to audit, survives staff changes, and keeps you under the limit of **4,000 role assignments per subscription**. Role changes can take **up to ~10 minutes** to apply. Sign out and back in if a test fails right after assigning.

---

## Task 4 — Assign at resource scope and see the data-plane split

1. As **`labadmin`** (Owner), open the `sthlgdata…` storage account → **Storage browser** → **Blob containers** → `manifests`. Upload any small file using the **Authentication method** toggle:
   - **Microsoft Entra user account** → *"You do not have permissions to list the data using your user account"*. Owner has no DataActions.
   - Switch to **Access key** → it works, because Owner can list keys.
2. Fix it the right way: storage account → **Access control (IAM)** → add **Storage Blob Data Contributor** for yourself, at **this resource**. Wait a couple of minutes and retry with Entra auth.
3. Confirm the analyst assignments the script made at this resource: `grp-hlg-data-analysts` has **Storage Blob Data Reader** *and* **Reader**.

> [!CAUTION]
> **⚠️ EXAM TRAP — "User can read blobs with the CLI but can't find the storage account in the portal."** Data roles don't include control-plane read. The portal needs **Reader** (or any role with `Microsoft.Storage/storageAccounts/read`) to show the resource. That's why analysts get both roles.

> 📸 **Checkpoint 04-01** — The Entra-auth error as Owner, then success after the data role. → `screenshots/lab-04/04-01-data-plane.png`

---

## Task 5 — Delegate access management with a condition

1. Subscription → **Access control (IAM)** → **Add role assignment** → **Privileged administrator roles** tab → **Role Based Access Control Administrator**.
2. Members: `grp-hlg-it-admins`.
3. **Conditions** tab → *Allow user to only assign selected roles to selected principals (fewer privileges)* → **Constrain roles**: Reader, Virtual Machine Contributor, Network Contributor. **Principal types**: Users and Groups.
4. Assign. Later, as Priya, try to assign **Owner** to someone (blocked), then **Reader** (allowed).

> [!TIP]
> **🎯 EXAM TIP — Privileged administrator roles** in the portal are Owner, Contributor, User Access Administrator, Role Based Access Control Administrator and a few others. They sit on a separate tab so you choose them deliberately. Conditions on role-assignment roles are how Microsoft expects you to delegate "only these roles to only these people".

> 📸 **Checkpoint 04-02** — The condition editor showing the constrained roles. → `screenshots/lab-04/04-02-rbac-admin-condition.png`

---

## Task 6 — Prove it: sign in as each person

Use a separate InPrivate window per user. First sign-ins need a password change and MFA registration (Lab 01 CA003 plus mandatory Azure MFA).

| Sign in as | Try | Expected |
|---|---|---|
| **Wei Ling** (APAC ops) | Resource groups list | Only `rg-hlg-spoke-sea` |
| | `vm-hlg-sea-app01` → **Restart** | ✅ Works |
| | `nsg-snet-app-sea` → add an inbound rule | ❌ *does not have authorization to perform action 'Microsoft.Network/networkSecurityGroups/securityRules/write'* |
| **Grace** (auditor) | Resource groups list | All `rg-hlg-*` |
| | Any VM → **Stop** | ❌ |
| | `sthlgdata…` → **Access keys** | ❌ Reader can't list keys |
| **Elena** (analyst) | `sthlgdata…` → Storage browser → manifests (Entra auth) | ✅ Lists and downloads |
| | Upload a file | ❌ Data Reader only |
| | **Access keys** | ❌ |
| **Northbridge guest** | Portal → **Switch directory** to HLG → Resource groups | Only `rg-hlg-spoke-weu`, read-only |
| **Priya** (IT admin) | Subscription IAM → assign **Owner** to Tom | ❌ Blocked by condition |
| | Assign **Reader** on `rg-hlg-sandbox` to Tom | ✅ |

> [!TIP]
> **🎯 EXAM TIP — Virtual Machine Contributor** can manage VMs (create, resize, start, stop, attach disks, **run commands**) and has `join` actions to connect a NIC to an existing subnet. It can't manage the VNet, NSG or storage account those depend on, and it **doesn't grant sign-in** to the OS. For Entra-ID-based sign-in to a VM, assign **Virtual Machine User Login** or **Virtual Machine Administrator Login**.

> 📸 **Checkpoint 04-03** — Wei Ling's NSG authorization error, plus the successful restart. → `screenshots/lab-04/04-03-least-privilege.png`

---

## Task 7 — Interpret access assignments

### 7a. Check access
1. `rg-hlg-spoke-sea` → **Access control (IAM)** → **Check access** → search **Wei Ling**. You see **Virtual Machine Contributor**, granted through `grp-hlg-apac-ops`. Check access includes assignments that reach a user through group membership.
2. **Role assignments** tab: read the **Scope** column. *This resource* means direct; *Subscription (Inherited)* / *Management group (Inherited)* means from above. Grace's Reader shows as inherited from `mg-hlg`.
3. **Deny assignments** tab: empty. Note why (Task 2 tip).
4. **View my access** as `labadmin`.
5. CLI, including group membership:
   ```bash
   az role assignment list --assignee weiling.tan@<tenant>.onmicrosoft.com --all --include-inherited --include-groups -o table
   ```

### 7b. Interpret a role definition
Read [`rbac/interpret-me.role.json`](../rbac/interpret-me.role.json) (don't create it) and answer:

1. Can a user with only this role create a **VPN gateway**?
2. Can they **read** public IP addresses? **Create** one?
3. They also hold **Network Contributor** at the same scope. Can they now create a VPN gateway?
4. Can they read blob data?
5. Can they assign roles to others?
6. At which scopes can this role be assigned?

<details><summary>Answers</summary>

1. **No.** `Microsoft.Network/virtualNetworkGateways/*` is in NotActions.
2. **Read: yes** (`Microsoft.Network/*` includes read; only write/delete are excluded). **Create: no.**
3. **Yes.** NotActions is **not a deny**. It only subtracts from *this* role. Network Contributor grants it.
4. **No.** No DataActions.
5. **No.** No `Microsoft.Authorization/roleAssignments/write`.
6. The subscription in `AssignableScopes` **and anything below it** (RGs, resources).
</details>

### 7c. Optional: create a custom role
Create **HLG VM Operator** from [`rbac/hlg-vm-operator.role.json`](../rbac/hlg-vm-operator.role.json) (replace `<SUBSCRIPTION-ID>`): `az role definition create --role-definition @rbac/hlg-vm-operator.role.json`. Assign it to Tom on `rg-hlg-spoke-sea` and confirm he can restart but not resize.

> [!TIP]
> **🎯 EXAM TIP — Custom roles:** JSON with `Actions`, `NotActions`, `DataActions`, `NotDataActions`, `AssignableScopes`. Up to 5,000 per tenant. A custom role that includes **DataActions can't be assigned at management group scope**. Start from a built-in role (**Clone a role** in the portal) rather than from scratch.

> 📸 **Checkpoint 04-04** — Check access for Wei Ling, plus the role assignments list with inherited scopes visible. → `screenshots/lab-04/04-04-check-access.png`

---

## Task 8 — Entra roles vs Azure roles

1. **Microsoft Entra ID** → **Roles and administrators** → **Helpdesk Administrator** → **+ Add assignments** → **Tom Brennan**.
2. As Tom: Entra admin center → reset Lotte's password ✅. Azure portal → **Subscriptions** → nothing.
3. As `labadmin`, look at **Entra ID → Properties → Access management for Azure resources**. That's the elevate-access switch from Lab 02. Leave it **No**.

> [!TIP]
> **🎯 EXAM TIP — Two separate RBAC systems.**
>
> | | Microsoft Entra roles | Azure roles (RBAC) |
> |---|---|---|
> | Manage | Users, groups, apps, licenses, directory settings | Azure resources |
> | Scope | Tenant, or **administrative unit** | Management group, subscription, RG, resource |
> | Examples | Global Administrator, User Administrator, Helpdesk Administrator, Guest Inviter | Owner, Contributor, Reader, VM Contributor |
> | Where | Entra ID → Roles and administrators | Any scope → Access control (IAM) |
>
> The only bridge is **elevate access** (Global Administrator → User Access Administrator at `/`). Classic subscription administrators (Co-Administrator) are retired, so on a current exam the answer is always Azure RBAC.

---

## Break-fix challenges

1. Arjun (APAC ops) says *"I can restart vm-hlg-sea-app01 but I can't connect to it with Bastion."* What role is missing? (Lab 06 deploys Bastion. Come back to this then.)
2. Elena can list blobs with `az storage blob list --auth-mode login` but sees **nothing** in the portal's Storage accounts list. Diagnose.
3. Priya tries to give Marcus **User Access Administrator** on `rg-hlg-hub-eus` and gets blocked. Is that a bug?

<details><summary>Fixes</summary>

1. Bastion needs **Reader** on the **VM**, on the **NIC** with the VM's private IP, on the **Bastion resource**, and (when Bastion is in a peered VNet, as here) on the **target VM's virtual network**, plus OS credentials. VM Contributor covers the VM and NIC reads. Add **Reader** on `bas-hlg-hub-eus` and on `vnet-hlg-spoke-sea`.
2. She has a data role but no control-plane read on the account. Add **Reader** at the storage account scope. (If you ran the script, she has it; remove it to reproduce.)
3. Not a bug. The condition on her RBAC Administrator assignment only allows Reader, VM Contributor and Network Contributor.
</details>

---

## Knowledge check

1. You need a team to restart VMs in one RG but not delete them, with the least administrative effort. Built-in or custom role?
2. A user has **Contributor** on a subscription and **Reader** on one RG inside it. What can they do in that RG?
3. Which role lets someone read Key Vault secrets' *values* using Azure RBAC: Key Vault Reader or Key Vault Secrets User?
4. Auditors must automatically see all future subscriptions. Where do you assign Reader?
5. You want to give a user permission to manage role assignments, but only to assign Reader. Which role and feature?

<details><summary>Answers</summary>

1. No built-in role does exactly *start/restart without delete* (VM Contributor can delete). Create a **custom role** (like HLG VM Operator), or accept VM Contributor if delete is tolerable.
2. Everything Contributor allows. Roles are additive, and Reader doesn't restrict Contributor.
3. **Key Vault Secrets User.** Key Vault Reader reads metadata only, not secret values.
4. At a **management group** above the subscriptions (here `mg-hlg`).
5. **Role Based Access Control Administrator** with a **condition** constraining the assignable roles to Reader.
</details>

---

## Clean up

Keep all assignments; later labs and the capstone use them. Remove Tom's Helpdesk Administrator role if you like.

## 📣 Document it

```bash
git add rbac notes/lab-04.md screenshots/lab-04 && git commit -m "Lab 04: least-privilege RBAC at MG/sub/RG/resource scopes, conditions, data-plane roles"
```

**LinkedIn post template:**
> Lab 04 of my AZ-104 hybrid build: least-privilege access for 5 teams across 4 scopes, verified by signing in as each person.
>
> 🔑 Auditors: Reader at the management group, so future subscriptions are covered automatically
> 🌐 Network team: Network Contributor on hub and on-prem RGs only
> 🖥️ APAC ops: VM Contributor. They can restart servers but got an authorization error touching an NSG.
> 📦 Analysts: Storage Blob Data Reader plus Reader at resource scope. They can read shipment files but never see keys.
> 🧑‍💼 IT admins: RBAC Administrator with a condition that only allows assigning 3 low-risk roles
>
> The one that surprised me: as subscription Owner I couldn't read blobs with Entra auth. Owner has no data-plane permissions, only the ability to list keys.
> #Azure #AZ104 #RBAC #ZeroTrust #LearningInPublic
