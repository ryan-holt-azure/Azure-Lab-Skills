# AZ-104 Exam Tips Cram Sheet

Generated from the 🎯 EXAM TIP and ⚠️ EXAM TRAP callouts in every lab by `scripts/build-cram-sheet.py`. Don't edit this file directly: edit the lab and re-run the script.

**145 tips** across 16 labs.

How to use it: read one lab's section, cover the detail, and explain each tip out loud. If you can't, go back to that lab's task.

## Contents

- [Lab 00 — Setup, Tooling and a Cost Safety Net](#lab-00--setup-tooling-and-a-cost-safety-net) (7)
- [Lab 01 — Halsted Staff Identities, Licensing, Guests, SSPR and Conditional Access](#lab-01--halsted-staff-identities-licensing-guests-sspr-and-conditional-access) (13)
- [Lab 02 — Governance: Management Groups, Policy, Tags, Locks and Costs](#lab-02--governance-management-groups-policy-tags-locks-and-costs) (15)
- [Lab 03 — Infrastructure as Code: Deploy the Hybrid Foundation with Bicep and ARM](#lab-03--infrastructure-as-code-deploy-the-hybrid-foundation-with-bicep-and-arm) (9)
- [Lab 04 — Role-Based Access Control Across Scopes](#lab-04--role-based-access-control-across-scopes) (9)
- [Lab 05 — Virtual Networks, Peering, Public IPs, User-Defined Routes and Troubleshooting](#lab-05--virtual-networks-peering-public-ips-user-defined-routes-and-troubleshooting) (10)
- [Lab 06 — Secure Access: NSGs, ASGs, Bastion, Service Endpoints and Private Endpoints](#lab-06--secure-access-nsgs-asgs-bastion-service-endpoints-and-private-endpoints) (9)
- [Lab 07 — Hybrid Connectivity: Chicago HQ to Azure over Site-to-Site VPN](#lab-07--hybrid-connectivity-chicago-hq-to-azure-over-site-to-site-vpn) (7)
- [Lab 08 — Virtual Machines: Create, Encrypt, Resize, Disks, Availability and Moves](#lab-08--virtual-machines-create-encrypt-resize-disks-availability-and-moves) (6)
- [Lab 09 — Scale Sets, Load Balancers and Azure DNS](#lab-09--scale-sets-load-balancers-and-azure-dns) (9)
- [Lab 10 — Storage Accounts: Redundancy, Encryption, Keys, SAS, Firewalls and Identity-Based Azure Files](#lab-10--storage-accounts-redundancy-encryption-keys-sas-firewalls-and-identity-based-azure-files) (9)
- [Lab 11 — Blob and Files Data Management: Tiers, Versioning, Soft Delete, Lifecycle, Replication, AzCopy](#lab-11--blob-and-files-data-management-tiers-versioning-soft-delete-lifecycle-replication-azcopy) (10)
- [Lab 12 — Containers: Azure Container Registry, Container Instances and Container Apps](#lab-12--containers-azure-container-registry-container-instances-and-container-apps) (7)
- [Lab 13 — Azure App Service: Plans, Scaling, Slots, Networking, TLS, Custom Domains and Backup](#lab-13--azure-app-service-plans-scaling-slots-networking-tls-custom-domains-and-backup) (8)
- [Lab 14 — Monitor and Maintain: Metrics, Logs, KQL, Alerts, Insights and Connection Monitor](#lab-14--monitor-and-maintain-metrics-logs-kql-alerts-insights-and-connection-monitor) (8)
- [Lab 15 — Backup and Disaster Recovery: Recovery Services Vault, Backup Vault and Site Recovery](#lab-15--backup-and-disaster-recovery-recovery-services-vault-backup-vault-and-site-recovery) (9)

## Lab 00 — Setup, Tooling and a Cost Safety Net

Source: [`labs/00-setup-and-safety-net.md`](../labs/00-setup-and-safety-net.md)

**🎯 EXAM TIP — Spending limits.** Only credit-based offers (Free Trial, Visual Studio/MSDN credits) have a **spending limit** that suspends resources when the credit runs out. Pay-As-You-Go has no spending limit. A **budget** never stops resources; it only alerts you (Lab 02).

**🎯 EXAM TIP — Entra roles vs Azure roles.** *Global Administrator* is an **Entra ID role**: it manages the directory (users, groups, licenses). It grants **no** access to Azure resources by itself. *Owner* is an **Azure RBAC role** on a scope (management group, subscription, resource group, resource). Expect questions that hinge on this split. (A Global Admin *can* elevate to User Access Administrator at root scope "/"; see Lab 04.)

**🎯 EXAM TIP — What needs P1/P2.** Dynamic groups, group-based licensing, Conditional Access and SSPR **writeback** need **P1** (or a bundle such as Microsoft 365 E3/Business Premium). **P2** adds Identity Protection (risk-based policies) and **PIM**. Entra ID Free gives you users, groups, basic SSO and security defaults.

**🎯 EXAM TIP — Cloud Shell facts.** Cloud Shell runs in a Microsoft-managed container. Files persist only in the **Azure Files share** it mounts as `clouddrive` (plus your `$HOME` image stored in that share). Sessions time out after about 20 minutes without interaction. Bash and PowerShell share the same storage. You can also run Cloud Shell **ephemerally** with no storage account, but then nothing persists.

**🎯 EXAM TIP — Resource providers.** Each Azure service is delivered by a **resource provider** (`Microsoft.Compute`, `Microsoft.Network`, …). A subscription must be **registered** for a provider before you can deploy that resource type. Register in the portal (**Subscription → Resource providers → Register**), with `az provider register -n Microsoft.X`, or `Register-AzResourceProvider -ProviderNamespace Microsoft.X`. Registering needs a role with `*/register/action`, such as Contributor or Owner at subscription scope.

**🎯 EXAM TIP — Quotas are per region and per VM family.** A quota error for *Standard DSv5 Family vCPUs* in East US says nothing about West Europe or B-series. Requests go through **Quotas** (or a support request for some types).

**⚠️ EXAM TRAP — Budgets don't stop spending.** A budget alert sends email (and can trigger an action group) when spend crosses a threshold. It does **not** stop or delete anything unless you wire an action group to automation that does. Cost data also lags by several hours, so a budget can't catch a spike in real time.

## Lab 01 — Halsted Staff Identities, Licensing, Guests, SSPR and Conditional Access

Source: [`labs/01-identities-and-conditional-access.md`](../labs/01-identities-and-conditional-access.md)

**🎯 EXAM TIP — Break-glass accounts** are cloud-only (no dependency on on-prem sync), hold Global Administrator, are **excluded from Conditional Access policies** that could lock you out, and are monitored (sign-in alerts). Mandatory Azure MFA still applies to them, which is why Microsoft recommends passkeys or certificate-based auth for these accounts.

**🎯 EXAM TIP — Usage location** is required before a license can be assigned to a user, because license availability depends on country. Missing usage location is the classic reason a group-based license assignment shows an error for one user (you'll reproduce this in Task 5).

**🎯 EXAM TIP — Create vs invite.** *Create new user* makes an internal member account in your tenant. *Invite external user* creates a B2B **guest** that authenticates with its home identity provider (Task 6). The exam often gives a partner scenario and asks which one to use.

**🎯 EXAM TIP — Bulk operations** in the portal cover **create, invite, delete, download users** and **import/remove group members** from CSV. Results are downloadable per operation. With PowerShell, the current module is **Microsoft Graph PowerShell** (`New-MgUser`, `New-MgGroup`). The old AzureAD and MSOnline modules are retired, so treat them as wrong answers on newer questions.

**🎯 EXAM TIP — Deleted users are soft-deleted for 30 days** and can be restored with their properties and memberships. After 30 days (or after **Delete permanently**) they're gone. A restored user keeps the same object ID.

**⚠️ EXAM TRAP — Synced users.** For users synced from on-premises AD (Entra Connect / Cloud Sync), most properties are **read-only in Entra ID**. You change them on-premises and they sync up. If a question says "users are synchronized from AD DS" and asks where to change a job title, the answer is on-premises AD, not the portal.

**🎯 EXAM TIP — Group types and membership.**
- **Security** groups grant access (RBAC, apps, licenses). **Microsoft 365** groups add a shared mailbox, calendar, SharePoint site and Teams.
- Membership: **Assigned**, **Dynamic User**, **Dynamic Device**. Dynamic **device** membership is available for **security groups only**, not Microsoft 365 groups.
- You **can't manually add** members to a dynamic group. Change the user's attributes or the rule.
- Dynamic membership requires **Entra ID P1** (or P2).
- "**Microsoft Entra roles can be assigned to the group**" must be chosen **at creation** and can't be changed later. Role-assignable groups can't be dynamic.

**⚠️ EXAM TRAP — Changing a group from Assigned to Dynamic** removes all its manually added members. Members are recalculated from the rule. The exam likes asking what happens to existing members.

**🎯 EXAM TIP — Group-based licensing:**
- Requires **P1** (or a bundle that includes it) to *use* the feature.
- Users inherit licenses from groups; removing a user from the group removes the inherited license.
- **Nested groups aren't supported**: only direct members of the licensed group get the license.
- Failure reasons you should recognize: **usage location missing**, **not enough licenses**, **conflicting service plans**.
- A user can have the same license **directly and inherited**. Removing one path leaves the other.

**🎯 EXAM TIP — External users:**
- Guests are **B2B collaboration** users. They sign in with their own Entra ID, Microsoft account, Google or email one-time passcode. You never manage their password.
- Who can invite is controlled by **Guest invite settings**. The **Guest Inviter** role allows inviting when invites are restricted to admins.
- **Allow/deny domain lists** live under *Collaboration restrictions*. **Cross-tenant access settings** control B2B with specific Entra organizations (inbound/outbound, trust MFA from the partner).
- Guests can be added to groups and granted Azure RBAC roles like any user.
- You can **convert an external user to an internal user** (keeps the object ID and access), or change a guest's **User type** to Member.

**🎯 EXAM TIP — SSPR facts:**
- Scope: **None / Selected (one group) / All**.
- **Administrators are always enabled** for SSPR with a stricter **two-gate** policy (two methods, no security questions). Your scoping doesn't apply to them.
- Required methods: **1 or 2**.
- **Password writeback** (reset in the cloud, written to on-prem AD) needs Entra Connect or Cloud Sync and **P1**.
- SSPR for cloud users needs P1/P2 or a Microsoft 365 business plan. Free tenants get self-service password **change** only.

**🎯 EXAM TIP — Security defaults and Conditional Access are mutually exclusive.** Security defaults are free baseline MFA for everyone. Conditional Access (P1) replaces them with targeted policies.

**⚠️ LOCKOUT TRAP.** Always exclude a break-glass account before turning a policy **On**, and start risky policies in **Report-only**. A policy that blocks "All users / All resources" without an exclusion locks out everyone, including you.

## Lab 02 — Governance: Management Groups, Policy, Tags, Locks and Costs

Source: [`labs/02-governance-policy-locks-costs.md`](../labs/02-governance-policy-locks-costs.md)

**🎯 EXAM TIP — Management group facts:**
- Up to **10,000** MGs per directory, and the tree supports **six levels of depth** (not counting the root or the subscription level).
- Each MG and each subscription has **exactly one parent**.
- The **Tenant Root Group** can't be moved or deleted. Its ID is the tenant ID.
- Moving a subscription needs write access on the subscription (for example **Owner**) **and** on the target parent MG (for example **Management Group Contributor**).
- Policy and RBAC assigned to an MG **inherit down** to every child MG, subscription, resource group and resource.

**🎯 EXAM TIP — Elevate access.** By default, not even a Global Administrator can see every subscription or the root MG. In **Entra ID → Properties → Access management for Azure resources = Yes**, a Global Administrator grants themselves **User Access Administrator at root scope (`/`)**. Turn it off when done.

**⚠️ EXAM TRAP — Changing a subscription's directory (tenant)** removes **all Azure RBAC role assignments** and custom role definitions, and managed identities need re-creating. Resources keep running. Transferring **billing ownership** (who pays) is a different operation and doesn't touch RBAC.

**🎯 EXAM TIP — Subscription boundaries.** A subscription is a **billing** boundary and an **access/management** boundary. It trusts exactly one Entra tenant. Quotas and limits apply per subscription per region.

**🎯 EXAM TIP — Resource group facts:**
- A resource group's **location** only stores its metadata. Its resources can be in **any region**.
- Resource groups **can't be renamed** or nested. A resource belongs to exactly one resource group.
- Deleting a resource group deletes **everything in it**.
- Moving resources between RGs or subscriptions **changes their resource IDs**. Both source and target RGs are **locked for writes during the move** (up to about 4 hours). The resource **doesn't change region**.

**⚠️ EXAM TRAP — Tags are NOT inherited.** A tag on a resource group doesn't automatically appear on its resources. Use **Azure Policy** (*Inherit a tag from the resource group*, Task 4) or the **Cost Management tag inheritance** setting (which affects cost records only, not the resources).

**🎯 EXAM TIP — Tag limits:** up to **50** tag name/value pairs per resource, resource group or subscription. Tag names are case-insensitive for operations. Not every resource type supports tags. Tagging a resource needs write access to it (or the **Tag Contributor** role, which can tag without other write access).

**⚠️ EXAM TRAP — "Allowed locations" doesn't cover resource groups.** The built-in *Allowed locations* policy excludes resource groups and `global` resources. To restrict where RGs are created you need *Allowed locations for resource groups* as well. Exam questions love the RG that was created in a forbidden region anyway.

**🎯 EXAM TIP — Effect evaluation order.** Azure Policy evaluates **Disabled → Append/Modify → Deny → Audit**, then **AuditIfNotExists/DeployIfNotExists** after the resource is created. That's why step 7 succeeded: *Add a tag* (Modify) inserted the tag **before** *Require a tag* (Deny) checked for it.

**🎯 EXAM TIP — Managed identity and remediation.** **Modify** and **DeployIfNotExists** need a **managed identity** on the assignment, with the roles listed in the definition's `roleDefinitionIds`. New and updated resources are handled at request time. **Existing** non-compliant resources are only fixed by a **remediation task**.

**🎯 EXAM TIP — When does it apply?** A new assignment takes effect within minutes (allow up to ~30). Compliance results appear after an evaluation cycle: about 30 minutes after assignment, then every 24 hours, or on demand with `az policy state trigger-scan`. **Deny never deletes existing resources.** They just show as non-compliant.

**🎯 EXAM TIP — Exclusions vs exemptions.** An **exclusion** is set on the assignment and permanently skips a child scope. An **exemption** is a separate object with a **category** (*Waiver* or *Mitigated*), an optional **expiry**, and can target specific policies inside an initiative. Exempted resources show as *Exempt* in compliance, not as missing.

**🎯 EXAM TIP — Lock types:**
- **CanNotDelete (Delete):** read and modify allowed, delete blocked.
- **ReadOnly:** read allowed. **All writes and deletes blocked**, including **POST** operations: listing storage keys, starting/restarting/stopping VMs, some portal blades that call POST.
- Locks **inherit** from subscription → RG → resource. The most restrictive applies.
- Only roles with `Microsoft.Authorization/locks/*` (**Owner**, **User Access Administrator**) can create or delete locks. **Contributor can't.**
- Locks apply to the **management (control) plane** only. A ReadOnly lock doesn't stop someone with a SAS token or data role from writing blobs.

**⚠️ EXAM TRAP — ReadOnly lock on a VM's resource group** stops anyone from **starting or restarting** the VM (POST actions), even Owners, until the lock is removed. A ReadOnly lock is almost never what you want on running workloads.

**🎯 EXAM TIP — Which cost tool?**
- **Budget:** "Warn me when spend crosses X." Actual or forecasted thresholds, email and/or action group. Scopes: management group, subscription, resource group (and billing scopes). Never stops resources by itself.
- **Cost alerts:** budget alerts, **anomaly** alerts, credit alerts and department spending quotas (EA).
- **Advisor:** "What should I change?" Right-size or shut down underused VMs, reserved instance and savings plan purchases, unused public IPs. Recommendations are free, refresh periodically, and can be exported or turned into Advisor alerts.
- **Cost analysis:** "Where did the money go?" Group by RG, service, tag, location.

## Lab 03 — Infrastructure as Code: Deploy the Hybrid Foundation with Bicep and ARM

Source: [`labs/03-iac-bicep-arm-foundation.md`](../labs/03-iac-bicep-arm-foundation.md)

**🎯 EXAM TIP — ARM template anatomy.** `$schema`, `contentVersion`, `parameters`, `variables`, `functions`, `resources`, `outputs`. Only **`$schema`, `contentVersion` and `resources`** are required. Bicep compiles to exactly this. Bicep loops (`for`) become ARM **`copy`** blocks; Bicep symbolic references become `resourceId()`/`reference()` calls and implicit `dependsOn`.

**🎯 EXAM TIP — Bicep vocabulary you'll be asked to read:** `param`, `var`, `resource <symbol> '<type>@<apiVersion>'`, `module`, `output`, `existing`, `parent:`, `scope:`, `if (...)`, `[for x in y: {...}]`, decorators `@description`, `@allowed`, `@minLength/@maxLength`, `@minValue/@maxValue`, `@secure`. In parameter files: `.bicepparam` with `using './main.bicep'`, or the older JSON `*.parameters.json`.

**🎯 EXAM TIP — Deployment scopes and commands.**

| Scope | Azure CLI | PowerShell |
|---|---|---|
| Resource group | `az deployment group create` | `New-AzResourceGroupDeployment` |
| Subscription | `az deployment sub create` (needs `--location`) | `New-AzSubscriptionDeployment` (alias `New-AzDeployment`) |
| Management group | `az deployment mg create` | `New-AzManagementGroupDeployment` |
| Tenant | `az deployment tenant create` | `New-AzTenantDeployment` |

Subscription, MG and tenant deployments need a **location** because the deployment metadata has to be stored somewhere. `what-if` exists at every scope. PowerShell's equivalent is `-WhatIf` or `Get-AzResourceGroupDeploymentWhatIfResult`.

**🎯 EXAM TIP — Lock the resource, not always the RG.** A CanNotDelete lock on the hub **RG** would also stop you deleting Bastion and the VPN gateways later. Locking the VNet resource protects what matters and leaves the rest manageable.

**🎯 EXAM TIP — Run Command** executes a script inside a VM through the **VM agent**. No inbound ports, public IP or Bastion are needed. It needs `Microsoft.Compute/virtualMachines/runCommand/action` (Virtual Machine Contributor has it). Remember it as the fix when a question says "you can't RDP/SSH but need to run a command."

**⚠️ DRIFT TRAP (exam and real life) — Incremental mode still overwrites what's in the template.** Incremental mode leaves resources that **aren't** in the template alone. Resources that **are** in the template get exactly the properties written there. Here the subnets are an inline array on the VNet, so redeploying `main.bicep` after you've (say) associated a route table in the portal **removes that association**. The rule for the rest of the series: after Lab 05, either codify portal changes in the Bicep first, or don't redeploy `main.bicep`.

**🎯 EXAM TIP — Template functions to recognize:** `resourceGroup().location`, `subscription().subscriptionId`, `uniqueString(...)` (deterministic 13-character hash, which is why the account name is the same on every redeploy), `concat`/`format`, `resourceId(type, name)`, `reference(resourceId, apiVersion)` (runtime properties), `parameters()`, `variables()`, `copyIndex()`.

**🎯 EXAM TIP — Deployment modes.**
- **Incremental** (default): adds and updates resources in the template and leaves others untouched.
- **Complete**: also **deletes** resources in the RG that aren't in the template. Only for **resource-group** scope deployments. Locked resources make it fail.
- **Deployment stacks** are the modern way to manage "delete what's no longer declared", with deny settings that block out-of-band changes.

**🎯 EXAM TIP — Export facts:**
- **Export from RG/resource** captures current state. Limit **200 resources**; some types can't be exported; **secrets aren't included**; the result often needs clean-up before it redeploys.
- **Export from deployment history** gives the original template and parameters.
- `az bicep decompile` is **best effort**: review the warnings.
- Portal paths: resource/RG → **Automation → Export template**, and RG → **Settings → Deployments** → deployment → **Template**.

## Lab 04 — Role-Based Access Control Across Scopes

Source: [`labs/04-rbac-access-control.md`](../labs/04-rbac-access-control.md)

**🎯 EXAM TIP — The four fundamental roles:**
- **Owner:** everything, including assigning roles.
- **Contributor:** everything **except** granting access (`Microsoft.Authorization/*/Write`/`Delete` are in NotActions), so it also **can't manage locks**.
- **Reader:** view everything on the control plane. No data access, no keys.
- **User Access Administrator:** manage access only, no resources.

Newer: **Role Based Access Control Administrator** manages role assignments and can be **constrained with conditions** (which roles, which principal types). That's the least-privilege answer when a question says "delegate access management without full Owner rights".

**⚠️ EXAM TRAP — Control plane vs data plane.** `Actions` manage the resource through Azure Resource Manager. `DataActions` act on the **data inside** it (blobs, queue messages, Key Vault secrets). **Owner/Contributor have no DataActions**, but they can call `listKeys`, so they reach data **through access keys**. Storage Account Contributor can too. A "can't see keys but can read blobs" requirement means **Storage Blob Data Reader** and no key-listing role.

**🎯 EXAM TIP — Assignment = principal + role definition + scope.** Scopes form a hierarchy: **management group → subscription → resource group → resource**. Assignments **inherit down**. You can't remove an inherited permission at a lower scope; you'd use a deny assignment, which you can't create directly (Blueprints, managed applications and deployment stacks create them). Roles are **additive**: a user's effective access is the union of every assignment.

**🎯 EXAM TIP — Assign to groups, not users.** It's easier to audit, survives staff changes, and keeps you under the limit of **4,000 role assignments per subscription**. Role changes can take **up to ~10 minutes** to apply. Sign out and back in if a test fails right after assigning.

**⚠️ EXAM TRAP — "User can read blobs with the CLI but can't find the storage account in the portal."** Data roles don't include control-plane read. The portal needs **Reader** (or any role with `Microsoft.Storage/storageAccounts/read`) to show the resource. That's why analysts get both roles.

**🎯 EXAM TIP — Privileged administrator roles** in the portal are Owner, Contributor, User Access Administrator, Role Based Access Control Administrator and a few others. They sit on a separate tab so you choose them deliberately. Conditions on role-assignment roles are how Microsoft expects you to delegate "only these roles to only these people".

**🎯 EXAM TIP — Virtual Machine Contributor** can manage VMs (create, resize, start, stop, attach disks, **run commands**) and has `join` actions to connect a NIC to an existing subnet. It can't manage the VNet, NSG or storage account those depend on, and it **doesn't grant sign-in** to the OS. For Entra-ID-based sign-in to a VM, assign **Virtual Machine User Login** or **Virtual Machine Administrator Login**.

**🎯 EXAM TIP — Custom roles:** JSON with `Actions`, `NotActions`, `DataActions`, `NotDataActions`, `AssignableScopes`. Up to 5,000 per tenant. A custom role that includes **DataActions can't be assigned at management group scope**. Start from a built-in role (**Clone a role** in the portal) rather than from scratch.

**🎯 EXAM TIP — Two separate RBAC systems.**

| | Microsoft Entra roles | Azure roles (RBAC) |
|---|---|---|
| Manage | Users, groups, apps, licenses, directory settings | Azure resources |
| Scope | Tenant, or **administrative unit** | Management group, subscription, RG, resource |
| Examples | Global Administrator, User Administrator, Helpdesk Administrator, Guest Inviter | Owner, Contributor, Reader, VM Contributor |
| Where | Entra ID → Roles and administrators | Any scope → Access control (IAM) |

The only bridge is **elevate access** (Global Administrator → User Access Administrator at `/`). Classic subscription administrators (Co-Administrator) are retired, so on a current exam the answer is always Azure RBAC.

## Lab 05 — Virtual Networks, Peering, Public IPs, User-Defined Routes and Troubleshooting

Source: [`labs/05-vnets-peering-routing.md`](../labs/05-vnets-peering-routing.md)

**🎯 EXAM TIP — Subnet arithmetic.** Azure reserves **5 IPs per subnet**: `.0` network, `.1` default gateway, `.2` and `.3` Azure DNS, and the last address (broadcast). A /24 gives 251 usable addresses, a /29 (the smallest IPv4 subnet) gives 3. Questions ask "how many VMs fit" or "what's the smallest subnet for N VMs".

**🎯 EXAM TIP — VNet facts:**
- A VNet lives in **one region and one subscription**. Subnets can't span VNets.
- Peered VNets must have **non-overlapping** address spaces.
- You **can** add or resize address space on a peered VNet without removing the peering, then **sync** the peering.
- You can remove an address range only if no subnet uses it.
- Changing a VNet's **custom DNS servers** only reaches existing VMs after they renew DHCP or restart.

**🎯 EXAM TIP — Peering facts:**
- **Non-transitive.** A↔B and B↔C doesn't give A↔C. Fix it with direct peering, an **NVA/Azure Firewall in the hub plus UDRs** (this lab), or **Virtual WAN**.
- **Global peering** (cross-region) works like regional peering, including gateway transit. Data transfer is billed in both directions.
- Peering status: **Initiated** means only one side exists, **Connected** means both. **Disconnected** means one side was deleted, so delete and recreate the remaining side.
- Peering works across subscriptions, and across tenants with the right permissions.

**🎯 EXAM TIP — Public IP facts:**
- **Basic SKU public IPs were retired on 30 Sept 2025.** **Standard** is the default: always **static**, **closed to inbound by default** (an NSG must allow traffic), zone-redundant or zonal, and required by Standard Load Balancer, NAT gateway, Bastion and AZ VPN gateways.
- **Routing preference** (*Microsoft network* vs *Internet*) and **zone** are chosen at creation and can't be changed.
- **Global tier** is for the cross-region load balancer.
- You can attach a public IP to a NIC IP configuration, LB frontend, NAT gateway, VPN gateway, Bastion, Application Gateway or Azure Firewall. Detach it before deleting.
- SKUs must match: a Standard LB needs Standard public IPs.

**🎯 EXAM TIP — Which route wins?** First **longest prefix match** (a /24 beats a /16 regardless of source). On a tie: **user-defined route > BGP route > system route**. A route table must be in the **same region and subscription** as the VNet. One subnet can have one route table; one route table can serve many subnets.

**🎯 EXAM TIP — Next hop types:** *Virtual network gateway*, *Virtual network*, *Internet*, *Virtual appliance* (needs an IP), **None** (drops traffic, a "black hole"). For an NVA, IP forwarding must be on **in Azure (the NIC)** and **in the guest OS**. The receiving spoke's peering must **allow forwarded traffic** (set in the Bicep), because the packets originate outside the hub.

**⚠️ EXAM TRAP — Propagate gateway routes = No** stops routes learned from a VPN/ExpressRoute gateway (BGP) reaching that subnet. It's used to force traffic through a firewall instead of straight to on-prem. A question that says "on-prem routes disappeared after a route table was attached" is pointing at this setting.

**🎯 EXAM TIP — Match the Network Watcher tool to the question:**

| Question says… | Tool |
|---|---|
| "Is traffic allowed or denied by an NSG, and by which rule?" | **IP flow verify** / **NSG diagnostics** |
| "Where does traffic from this VM to X go?" | **Next hop** (or the NIC's **Effective routes**) |
| "Test TCP connectivity VM → VM/FQDN/IP and show hops and latency" | **Connection troubleshoot** (one-off) |
| "Continuously monitor connectivity and alert" | **Connection monitor** (Lab 14) |
| "Capture packets" | **Packet capture** (needs the agent extension) |
| "Why is my S2S VPN down?" | **VPN troubleshoot** (Lab 07) |
| "Log all flows through the VNet" | **VNet flow logs** + Traffic analytics (Lab 14) |
| "Diagram my network" | **Topology** |

**🎯 EXAM TIP — Explicit outbound methods:** **NAT gateway** (recommended), **Load Balancer outbound rules**, a **public IP on the NIC**, or routing through **Azure Firewall/NVA**. A NAT gateway associates with one or more subnets **in a single VNet**, uses Standard public IPs or prefixes (up to 16 IPs), and **takes precedence over other outbound methods** for those subnets. Inbound connections to a VM's own public IP still work.

**⚠️ EXAM TRAP — "VMs in a new VNet can't download updates, but VMs in the old VNet can."** The new VNet's subnets are private by default. The fix is an explicit outbound method, not an NSG rule (NSG outbound to Internet is allowed by default).

## Lab 06 — Secure Access: NSGs, ASGs, Bastion, Service Endpoints and Private Endpoints

Source: [`labs/06-secure-access-nsg-bastion-endpoints.md`](../labs/06-secure-access-nsg-bastion-endpoints.md)

**🎯 EXAM TIP — Bastion SKUs:**

| | Developer | Basic | Standard | Premium |
|---|---|---|---|---|
| Cost | Free (shared infra, select regions) | Hourly | Hourly | Hourly |
| `AzureBastionSubnet` + public IP | Not needed | Required | Required | Required (or private-only) |
| VMs in **peered** VNets | **No** | Yes | Yes | Yes |
| Concurrent connections | One VM at a time | Yes | Yes, scalable host instances | Yes |
| Native client (`az network bastion ssh/rdp`), IP-based connect, shareable links, file transfer | — | — | Yes | Yes |
| Session recording, private-only deployment | — | — | — | Yes |

The subnet must be named exactly **`AzureBastionSubnet`** and be **/26 or larger**. The target VMs need **no public IP**. You can upgrade a SKU but not downgrade.

**🎯 EXAM TIP — Bastion RBAC.** To connect, a user needs **Reader** on the VM, the VM's NIC and the Bastion resource (plus the target VNet when Bastion is in a peered VNet), and valid OS credentials. If an NSG is applied to `AzureBastionSubnet` it must allow Bastion's required ports: 443 inbound from Internet and GatewayManager, and 22/3389 outbound to VirtualNetwork, among others.

**🎯 EXAM TIP — NSG rule processing:**
- Priority **100–4096**. **Lower number = evaluated first**, and processing **stops at the first match**.
- Rules are **stateful**: return traffic is allowed automatically.
- **Default rules** (priorities 65000+) can't be deleted, only overridden. Inbound: `AllowVnetInBound`, `AllowAzureLoadBalancerInBound`, `DenyAllInBound`. Outbound: `AllowVnetOutBound`, `AllowInternetOutBound`, `DenyAllOutBound`.
- The **`VirtualNetwork` service tag** covers the VNet's address space, **peered VNets**, and **on-prem ranges connected through a gateway**. That's why it's broader than you might think.
- An NSG must be in the **same region** as the subnet/NIC it's associated with.

**🎯 EXAM TIP — Application security groups** let rules target "web servers" instead of IP lists. All NICs in an ASG must be in the **same VNet**, and when a rule uses ASGs as both source and destination, both ASGs must be in that same VNet. ASGs are regional resources.

**🎯 EXAM TIP — Subnet NSG + NIC NSG.** Both are evaluated and **both must allow** the traffic. **Inbound: subnet NSG first, then NIC NSG. Outbound: NIC NSG first, then subnet NSG.** A typical question gives you both rule sets and asks whether a flow succeeds. Work through them in that order.

**🎯 EXAM TIP — Service endpoint facts:**
- Enabled **per subnet, per service**. Traffic to the service uses the Azure backbone with the subnet's **private** source IP.
- The PaaS resource **keeps its public endpoint and public IP**. You restrict it with a **virtual network rule**.
- `Microsoft.Storage` reaches accounts in the **same region**. **`Microsoft.Storage.Global`** reaches accounts in **any region**. A subnet can have only one of the two.
- Once a subnet has the endpoint, **IP rules for that subnet's public IPs stop matching**. Use the VNet rule.
- **Service endpoint policies** restrict *which* storage accounts the subnet can reach (data exfiltration control).
- It doesn't work from on-premises or from peered VNets. Each subnet needs its own endpoint.

**⚠️ EXAM TRAP — Storage IP rules don't apply to requests from the same Azure region as the account.** Those use private Azure addresses. To allow an Azure VM in the same region, use a VNet rule (service endpoint) or a private endpoint, not its outbound public IP.

**🎯 EXAM TIP — Private endpoint vs service endpoint:**

| | Service endpoint | Private endpoint (Private Link) |
|---|---|---|
| What you get | Optimized route + VNet rule | A **NIC with a private IP** for one sub-resource |
| PaaS public endpoint | Still exists (restricted by rules) | Can be **disabled** entirely |
| Reachable from peered VNets / on-prem (VPN/ER) | No | **Yes** |
| DNS changes needed | No | **Yes**: `privatelink.*` zone (or on-prem forwarding) |
| Cost | Free | Hourly + per GB |
| Granularity | Whole service in region (or global) | **Per resource, per sub-resource** (blob, file, dfs, queue, table, web…) |

**🎯 EXAM TIP — Private DNS for Private Link.** Clients keep using the **public FQDN** (`acct.blob.core.windows.net`). Azure DNS answers with a CNAME to `acct.privatelink.blob.core.windows.net`, and the private zone resolves that to the private IP. The zone must be **linked to every VNet** whose clients resolve the name. Zone names to recognize: `privatelink.blob.core.windows.net`, `privatelink.file.core.windows.net`, `privatelink.vaultcore.azure.net`, `privatelink.azurewebsites.net`, `privatelink.database.windows.net`, `privatelink.azurecr.io`.

## Lab 07 — Hybrid Connectivity: Chicago HQ to Azure over Site-to-Site VPN

Source: [`labs/07-hybrid-site-to-site-vpn.md`](../labs/07-hybrid-site-to-site-vpn.md)

**🎯 EXAM TIP — Connection types:**
- **Site-to-site (IPsec):** your on-prem VPN device ↔ VPN gateway, over the internet. Needs a local network gateway.
- **VNet-to-VNet:** VPN gateway ↔ VPN gateway, no local network gateway needed.
- **Point-to-site:** individual clients. Auth by certificate, **Microsoft Entra ID** (OpenVPN) or RADIUS. Protocols: OpenVPN, IKEv2, SSTP.
- **ExpressRoute:** private circuit through a provider, **not over the internet**. Gateway type ExpressRoute.

**Route-based** VPNs are required for P2S, VNet-to-VNet, multiple S2S tunnels and ExpressRoute coexistence. **Policy-based** is the legacy single-tunnel option.

**⚠️ EXAM TRAP — GatewaySubnet rules.** Don't associate an **NSG** with GatewaySubnet (it can break the gateway). Don't add a UDR with `0.0.0.0/0` → anything on it. Don't deploy VMs into it. The name is case-sensitive and must be exact.

**🎯 EXAM TIP — The local network gateway's address space is what gets routed into the tunnel.** If Chicago's side lists only the hub (`10.20.0.0/16`), Chicago can never reach the spokes, even with gateway transit configured. On a real on-prem firewall, these are the "remote networks" or "encryption domain".

**🎯 EXAM TIP — Gateway transit:**
- **Hub** peering: *Allow gateway transit* (`allowGatewayTransit`). **Spoke** peering: *Use remote gateways* (`useRemoteGateways`).
- The hub gateway must exist before a spoke can enable *use remote gateways*.
- A spoke that has **its own** gateway can't use remote gateways.
- Works across **global** peering.
- Without transit, each spoke would need its own gateway and tunnel.

**⚠️ EXAM TRAP — "The VPN is connected but on-prem can't reach a spoke."** Check in this order: **(1)** gateway transit + use remote gateways on the peerings, **(2)** the on-prem LNG/firewall includes the spoke's prefix, **(3)** a UDR or *Propagate gateway routes = No* on the spoke's route table, **(4)** NSGs, where `VirtualNetwork` *does* include on-prem.

**🎯 EXAM TIP — Why on-prem can't just use Azure DNS.** Azure's resolver at **168.63.129.16** is only reachable **from inside Azure**. On-prem DNS must forward to something inside a VNet: a **DNS Private Resolver inbound endpoint** (managed) or a DNS forwarder VM. Forward the **public** zone (`blob.core.windows.net`), not `privatelink.…`. Clients resolve the public name, and Azure DNS follows the CNAME into the private zone.

**🎯 EXAM TIP — S2S checklist:** matching **shared key**, matching **IKE version/IPsec policy**, correct **public IPs** in both LNGs, **non-overlapping** address spaces, route-based on both ends, and **GatewaySubnet** sized /27+. VPN troubleshoot needs a storage account for its logs.

## Lab 08 — Virtual Machines: Create, Encrypt, Resize, Disks, Availability and Moves

Source: [`labs/08-virtual-machines.md`](../labs/08-virtual-machines.md)

**🎯 EXAM TIP — Things the exam asks about VM creation:**
- **Trusted launch** is the default security type for Gen2 images. **Confidential VMs** need specific sizes.
- **Zone** and **availability set** are chosen **at creation**. You can't add an existing VM to a set or move it into a zone in place. You redeploy (or use Resource Mover/ASR for zones).
- A **Spot** VM's eviction policy is *Deallocate* or *Delete*, and its max price can be capped.
- **Auto-shutdown** is a DevTest Labs schedule attached to the VM. It deallocates, so compute billing stops.
- **Entra ID login** needs the AADLogin extension (added by the checkbox) **and** the *Virtual Machine Administrator Login* or *User Login* role.

**🎯 EXAM TIP — Disk encryption options:**
- **SSE with platform-managed keys:** always on, for every managed disk.
- **SSE with customer-managed keys:** through a **disk encryption set** pointing at Key Vault.
- **Encryption at host:** also encrypts the **temp disk** and **OS/data disk caches** on the host, end to end. Register the `EncryptionAtHost` feature first, and the **VM must be deallocated** to turn it on.
- **Azure Disk Encryption (BitLocker/DM-Crypt inside the guest)** is **scheduled for retirement on 15 September 2028**. Microsoft's guidance is to use encryption at host instead. Older exam questions still mention ADE + Key Vault.
- **Confidential disk encryption:** confidential VM sizes only.

**🎯 EXAM TIP — Resizing:** resizing a running VM **always restarts it**. If the target size isn't on the current cluster, **deallocate first** to see and choose it. VMs in an **availability set** may need **all VMs in the set deallocated** to move to a size family the cluster doesn't host. Size changes are also limited by regional **quota** per family and by **policy**.

**🎯 EXAM TIP — Disk facts:**
- Types: **Standard HDD**, **Standard SSD**, **Premium SSD**, **Premium SSD v2**, **Ultra Disk**. v2 and Ultra are **data disks only**, are zonal, and don't support host caching.
- **Changing disk type** needs the VM **deallocated** (or the disk unattached).
- Disks can be **expanded, never shrunk**. After expanding, extend the partition in the OS.
- Host caching: **Read-only** for read-heavy data, **None** for write-heavy or log disks, **Read/Write** only for OS disks or apps that handle it.
- **Temporary disk** data is lost on **deallocation, redeploy or host maintenance**. A restart keeps it.
- **Incremental snapshots** store only changes (cheaper) and can be copied across regions.
- Max data disks depends on **VM size**.

**🎯 EXAM TIP — Availability set vs zones:**

| | Availability set | Availability zones |
|---|---|---|
| Protects against | Rack/power failure (**fault domain**) and planned maintenance (**update domain**) **within one datacenter** | Loss of an entire **datacenter** in the region |
| VM SLA | **99.95%** (2+ VMs) | **99.99%** (2+ VMs across zones) |
| Limits | Up to **3 FDs** (region-dependent), up to **20 UDs** (default 5) | Usually 3 zones per region; not every region has them |
| Rules | VMs join **at creation**, and set and VMs share a **resource group** | Zone chosen at creation; use zone-redundant/zonal Standard public IPs and LBs |

A single VM with **Premium SSD/Ultra** disks gets a **99.9%** SLA. You can't combine an availability set with zones on the same VM.

**🎯 EXAM TIP — Moving VMs:**

| Move | Tool | Key rules |
|---|---|---|
| Another **resource group** | Portal *Move*, `az resource move`, `Move-AzResource` | Region unchanged, **resource ID changes**, both RGs locked for writes during the move |
| Another **subscription** | Same tools | **Same Entra tenant**. Target subscription must have the provider registered. Move **dependent resources together** (NIC, disks, and the VNet when VMs share it). |
| Another **region** | **Azure Resource Mover** or **Azure Site Recovery** (Lab 15) | Creates copies in the target region, then you commit and delete the source |

You can't move a VM that's being replicated by Site Recovery, and some marketplace-plan resources are restricted.

## Lab 09 — Scale Sets, Load Balancers and Azure DNS

Source: [`labs/09-scale-sets-load-balancing-dns.md`](../labs/09-scale-sets-load-balancing-dns.md)

**🎯 EXAM TIP — Load balancer basics:**
- **Layer 4** (TCP/UDP) only. For HTTP routing, TLS termination or a WAF, use **Application Gateway** (regional) or **Front Door** (global).
- **Standard** is the only SKU for new deployments (**Basic LB retired 30 Sept 2025**). Standard is **secure by default**: backends need an **NSG that allows** the client traffic.
- Backend pool members must be in **one VNet**. Zone-redundant frontends and a 99.99% SLA are available.
- Pieces: **frontend IP**, **backend pool**, **health probe** (TCP, HTTP, HTTPS), **load-balancing rule**, optional **inbound NAT rule** (port-forward to one instance), **outbound rule** (SNAT).
- **Session persistence:** *None* (5-tuple hash), *Client IP* (2-tuple), *Client IP and protocol* (3-tuple).

**🎯 EXAM TIP — Health probes come from `168.63.129.16`,** matched by the **`AzureLoadBalancer`** service tag. The default NSG rule `AllowAzureLoadBalancerInBound` (65001) allows them. Override it with a deny and every backend goes unhealthy (Task 5).

**🎯 EXAM TIP — Flexible vs Uniform orchestration.** **Flexible** (the default) runs instances as regular VMs you can manage individually, mixes sizes, spreads across zones and fault domains, and supports most VM features. **Uniform** is identical instances managed as one resource (legacy, large stateless fleets). **Overprovisioning** is Uniform-only. Questions that say "add a specific existing VM type" or "different VM sizes in one set" point to Flexible.

**🎯 EXAM TIP — Autoscale rules.** Always pair a **scale-out** rule with a **scale-in** rule. Autoscale won't scale in below **minimum**, never exceeds **maximum**, and waits the **cool-down** between actions. Metrics can be host metrics (CPU, network, disk) or a schedule/date-based profile ("10 instances weekdays 08:00–18:00"). **Default** scale-in balances across zones and fault domains first, then removes the highest instance ID.

**⚠️ EXAM TRAP — Internal LB hairpinning.** A backend VM that connects to its own internal load balancer's frontend fails whenever the flow is mapped back to **itself**. If backend servers must call each other through the ILB, use two ILBs, or call the other tier directly.

**🎯 EXAM TIP — HA ports** (internal Standard LB only) is a rule for **all ports and all protocols**. It's the standard pattern for load-balancing **NVAs/firewalls** in a hub.

**🎯 EXAM TIP — Load balancer troubleshooting order:**
1. **Health Probe Status** metric: are backends healthy? If not: app listening on the probe port/path? NSG allows `AzureLoadBalancer`? Guest firewall?
2. **Data Path Availability** metric: is the frontend reachable?
3. **NSG allows client traffic** to the backends (Standard LB is closed by default).
4. **SKU match**: Standard LB + Standard public IP, backends in one VNet.
5. Backend → own ILB frontend = **hairpin**, which fails.
6. Outbound problems → **outbound rules / NAT gateway**, not the inbound rule.

**🎯 EXAM TIP — Azure DNS public zones:**
- **Delegation** = set **NS records at the registrar** (or the parent zone) to Azure's name servers. A **child zone** is delegated with an NS record set in the parent zone.
- **Alias records** (A, AAAA, CNAME) point at an **Azure resource**: public IP, Traffic Manager, Front Door, CDN endpoint, or another record set. They **update automatically** when the resource's IP changes and are the way to point the **zone apex (`@`)** at an Azure resource, because a CNAME isn't allowed at the apex.
- Azure DNS hosts zones. It doesn't register domains (App Service Domains do).
- Record sets have a **TTL**. Several records of the same type share one record set.

**🎯 EXAM TIP — Private DNS zones:**
- Resolve only for **linked VNets** (resolution links scale to many VNets).
- **Auto-registration** creates and deletes A records for VMs as they come and go. A VNet can be the **registration network for only one private zone**, though it can have resolution links to many.
- Records are resolved by Azure DNS (**168.63.129.16**). VNets that use **custom DNS servers** need those servers to forward to Azure DNS, or to a Private Resolver.
- Private zones are **global** resources, so one zone serves VNets in every region.

## Lab 10 — Storage Accounts: Redundancy, Encryption, Keys, SAS, Firewalls and Identity-Based Azure Files

Source: [`labs/10-storage-accounts-security-access.md`](../labs/10-storage-accounts-security-access.md)

**🎯 EXAM TIP — Settings you can only choose at creation:** account **name**, **performance** (Standard/Premium), **account kind** (Premium types), **infrastructure encryption**, **CMK support for queues/tables**, and **hierarchical namespace**. HNS can be upgraded once and never reverted. Questions that ask "what must you do first" often expect "create a new account".

**🎯 EXAM TIP — Redundancy options:**

| Option | Copies | Survives | Secondary readable? |
|---|---|---|---|
| **LRS** | 3 in one datacenter | Disk/rack failure | — |
| **ZRS** | 3 across **zones** in the region | Datacenter (zone) loss | — |
| **GRS** | LRS + 3 in the **paired region** | Regional disaster (after failover) | No |
| **RA-GRS** | GRS | Same | **Yes**, `-secondary` endpoint |
| **GZRS** | ZRS + LRS in paired region | Zone **and** region | No |
| **RA-GZRS** | GZRS | Same | **Yes** |

**Premium** accounts support **LRS and ZRS only**. The **Archive** tier works only with **LRS, GRS and RA-GRS**, not ZRS/GZRS/RA-GZRS. Geo-replication is **asynchronous**: check **Last sync time** before failing over, because recent writes may be lost.

**🎯 EXAM TIP — Storage encryption:**
- **Always on** with AES-256 and can't be disabled. The only choice is **who manages the key**: Microsoft-managed, **customer-managed** (Key Vault or Managed HSM), or **customer-provided** (per request, Blob only).
- CMK requirements: the vault needs **soft delete + purge protection**, and the storage account's managed identity needs **wrap/unwrap rights** (*Key Vault Crypto Service Encryption User*). If you disable the key, the data becomes inaccessible until it's re-enabled.
- **Infrastructure encryption** adds a second encryption layer. Creation-time only.
- **Encryption scopes** let different containers or blobs in one account use different keys. That's the answer to "one account, separate keys per tenant/department".

**⚠️ EXAM TRAP — Key Vault permission models.** With **Azure RBAC** (now the default), Owner/Contributor on the vault **can't** read keys or secrets. You need **Key Vault Crypto Officer / Secrets Officer / Administrator** or the matching *User* roles. With the older **access policies** model, you grant permissions per principal in the vault's *Access policies* blade instead.

**🎯 EXAM TIP — Access keys** grant **full** control of the account's data (everything except Entra-only operations). Anyone with `listKeys` (Owner, Contributor, Storage Account Contributor) effectively has data access. Best practice: **Entra ID + RBAC** for apps, keys disabled, keys rotated through Key Vault if you must keep them. Rotating a key **invalidates every SAS signed with it**, which is the emergency revocation for account and service SAS.

**🎯 EXAM TIP — SAS types:**

| Type | Signed with | Scope | Revoke by |
|---|---|---|---|
| **Account SAS** | Account key | One or more **services** (blob, file, queue, table) and service-level operations | Rotating the key |
| **Service SAS** | Account key | One service's resource (container, blob, share, file, queue, table) | Rotating the key, or a **stored access policy** |
| **User delegation SAS** | **Entra credentials** (user delegation key) | **Blob/Data Lake** | `revoke-delegation-keys`, or removing the user's RBAC role; **max 7 days** |

Microsoft recommends **user delegation SAS** where possible, because no account key is involved. Always use **HTTPS only**, short expiry, least permissions, and optionally an IP range.

**🎯 EXAM TIP — Stored access policies:** defined **on a container, file share, queue or table**. Up to **5** per resource. Work only with **service SAS** (not account or user delegation SAS). Changing or deleting the policy **revokes or changes every SAS bound to it** within about 30 seconds. That's the answer to "revoke a partner's SAS without affecting other users".

**🎯 EXAM TIP — Storage network rules:**
- Rule types: **IP rules** (public IPv4 addresses/ranges, no private ranges), **virtual network rules** (subnets with a service endpoint), **resource instance rules**, and **trusted service exceptions**.
- **IP rules don't work for clients in the same Azure region** as the account. Use VNet rules or private endpoints for those.
- Network rules and authorization are separate: an allowed network still needs a valid key, SAS or RBAC role.
- **Disabled** public network access means **private endpoints only**.

**🎯 EXAM TIP — Azure Files authorization layers:**
1. **Share-level** = Azure RBAC: **SMB Share Reader**, **SMB Share Contributor**, **SMB Share Elevated Contributor** (can also change NTFS ACLs), or a **default share-level permission** for all authenticated identities.
2. **Directory/file-level** = **Windows ACLs (NTFS)**.

Both must allow. The **storage account key** bypasses both (super-user), which is why the key is only for admins and break-glass. Only **one** AD source can be enabled per account. SMB uses **TCP 445**: if a client "can't map the drive", check whether the ISP or corporate firewall blocks 445.

## Lab 11 — Blob and Files Data Management: Tiers, Versioning, Soft Delete, Lifecycle, Replication, AzCopy

Source: [`labs/11-blob-and-files-data-management.md`](../labs/11-blob-and-files-data-management.md)

**🎯 EXAM TIP — Blob basics:**
- **Block blobs** hold files and documents (up to ~190 TiB). **Append blobs** are for logs (append only). **Page blobs** hold VHDs/random access (disks).
- **Container access levels:** *Private*, *Blob* (anonymous read of blobs), *Container* (anonymous read and list). They only apply when the **account allows anonymous access**.
- **Metadata** is name/value data on a blob but **isn't indexed**. **Blob index tags** are indexed: you can search across containers and use them in lifecycle rules.
- Container names: 3–63 characters, lowercase letters, numbers and hyphens.

**🎯 EXAM TIP — Tiers:**

| Tier | Online? | Minimum retention (early-deletion charge) | Use |
|---|---|---|---|
| **Hot** | ✅ | — | Frequent access |
| **Cool** | ✅ | **30 days** | Infrequent, about monthly |
| **Cold** | ✅ | **90 days** | Rare, still instant |
| **Archive** | ❌ (rehydrate first) | **180 days** | Retention/compliance |

Archive is set **per blob**, never as the account default, and only on **LRS/GRS/RA-GRS** accounts. Rehydrate either by **changing the tier** or by **copying to an online tier** (Standard up to 15 h, High faster). **Lifecycle policies can't rehydrate.**

**🎯 EXAM TIP — Versioning vs snapshots.** **Versioning** creates a version **automatically on every write or delete**. **Snapshots** are **manual** point-in-time copies. Versions are billed for their unique data, so pair versioning with a lifecycle rule that deletes old versions. **Object replication** (Task 6) and **point-in-time restore** need versioning.

**🎯 EXAM TIP — Data protection features:**
- **Blob soft delete** (1–365 days) restores deleted blobs, versions and snapshots. With versioning on, a delete makes the current version a previous version, and soft delete keeps previous versions recoverable.
- **Container soft delete** (1–365 days) restores a whole container with its contents.
- **Point-in-time restore** rolls block blobs in containers back to a time. It needs versioning, change feed and soft delete.
- **None** of these protect against **deleting the storage account**. That's what a **CanNotDelete lock** is for (Lab 02).

**🎯 EXAM TIP — Lifecycle rules:**
- Filters: **blob types**, **prefix** (which starts with the **container name**), **blob index tags**.
- Actions on **base blobs**, **versions** and **snapshots**: `tierToCool`, `tierToCold`, `tierToArchive`, `delete`, `enableAutoTierToHotFromCool`.
- Conditions: `daysAfterModificationGreaterThan`, `daysAfterCreationGreaterThan`, `daysAfterLastAccessTimeGreaterThan` (needs access tracking), `daysAfterLastTierChangeGreaterThan`.
- Policies run **about once a day**, and a new or changed policy can take **up to 24 hours** to start acting. Don't expect instant results.

**🎯 EXAM TIP — Object replication requirements:** **versioning on both** accounts, **change feed on the source**, **GPv2 or premium block blob** accounts, **block blobs only**, **no hierarchical namespace**. Replication is **asynchronous**. **Archived blobs and snapshots aren't replicated**, and the destination container is **read-only** while the policy exists. A source can replicate to up to **2** destination accounts, with up to 1,000 rules per policy. Across tenants, *Allow cross-tenant replication* must be enabled.

**⚠️ EXAM TRAP — Object replication ≠ GRS.** GRS replicates the **whole account** to the **paired** region, isn't readable unless you choose RA-GRS, and you can't pick the region. Object replication copies **chosen containers** to **any region/account**, readable immediately. "Replicate one container to a specific non-paired region for low-latency reads" → object replication.

**🎯 EXAM TIP — Azure Files protection:**
- **Share snapshots** are **read-only, incremental, share-level** copies, up to **200 per share**. Restore individual files or folders from them. Windows shows them as **Previous Versions**.
- **Soft delete for file shares** (1–365 days) recovers a **deleted share**, not individual deleted files. Files need snapshots or Azure Backup.
- **Azure Backup for Azure Files** (Lab 15 mentions it) schedules and retains snapshots in a **Recovery Services vault**.
- Tiers: **Premium** (SSD, FileStorage account) vs Standard **Transaction optimized / Hot / Cool** (GPv2).
- SMB over **445**, and NFS 4.1 on Premium.

**🎯 EXAM TIP — Storage Explorer** manages Blob, Files, Queues and Tables (and ADLS Gen2) from Windows, macOS or Linux. It connects with **Entra ID**, **account name + key**, a **connection string** or a **SAS URL**. Large transfers run on **AzCopy** under the hood. With Entra sign-in you still need **data roles**: Reader alone shows the account, not its data.

**🎯 EXAM TIP — AzCopy:**
- Commands: `copy`, `sync` (one-way; `--delete-destination` mirrors deletes), `make`, `list`, `remove`, `jobs list|resume|show`, `login`.
- Auth for **Blob**: **Entra ID** (`azcopy login`, managed identity, or reuse the Azure CLI token) **or SAS**. Entra auth needs **Storage Blob Data Contributor/Owner**. Owner on the account isn't enough.
- Auth for **Azure Files**: SAS is the classic answer. Newer AzCopy versions also support Entra ID for Files.
- **Server-to-server** copies run between storage endpoints, without downloading to the client.
- Interrupted jobs **resume** with `azcopy jobs resume <id>`.
- Offline bulk options for huge datasets: **Azure Data Box** or the **Import/Export service**.

## Lab 12 — Containers: Azure Container Registry, Container Instances and Container Apps

Source: [`labs/12-containers-acr-aci-container-apps.md`](../labs/12-containers-acr-aci-container-apps.md)

**🎯 EXAM TIP — ACR SKUs.** All tiers give a private registry, webhooks and Entra auth. **Premium** adds **geo-replication** (one registry name, replicas close to each region's workloads), **private endpoints**, **customer-managed keys**, content trust, higher throughput and storage, and more. Questions that say "pull images from the nearest region" or "no public access to the registry" need **Premium**.

**🎯 EXAM TIP — Registry authentication.** Prefer **Entra ID**: `az acr login`, a **managed identity** with **AcrPull** (AKS, Container Apps, App Service), or service principals. The **admin user** is a single shared username/password, disabled by default, and is what some portal flows (like ACI from ACR) ask for. Name rules: 5–50 alphanumeric characters, globally unique. Login server: `<name>.azurecr.io`. `az acr build` (ACR Tasks) builds in the cloud without local Docker, but some subscription offers restrict Tasks.

**🎯 EXAM TIP — ACI concepts:**
- The **container group** is the unit of deployment: one or more containers (multi-container groups are **Linux only**) sharing a lifecycle, IP, ports, network and storage (for example an **Azure Files volume**).
- Deploy with the portal, CLI, **YAML** (needed for multi-container groups via CLI) or ARM/Bicep.
- **Restart policies:** *Always* (web servers), *OnFailure* (batch that should retry), *Never* (run once).
- Billed **per second** for requested vCPU and memory.
- Can run inside a **VNet** (delegated subnet, private IP).

**🎯 EXAM TIP — ACI updates.** These need **delete + redeploy**: **OS type, CPU, memory, GPU, restart policy, network profile**. You can redeploy in place to change things like the **image tag, environment variables or DNS label**. **ACI has no autoscaling.** Choose **Container Apps** (or AKS) when a question needs scale rules, revisions or scale-to-zero.

**🎯 EXAM TIP — Container Apps concepts:**
- **Environment** = the secure boundary (shared VNet, logging, Dapr). Apps in one environment can talk to each other.
- **Workload profiles:** *Consumption* (serverless, pay per use) and *Dedicated* (reserved compute sizes).
- **Ingress:** external or internal, HTTP or TCP, target port.
- **Revisions:** immutable snapshots of a version of the app.
- Use Container Apps for microservices, APIs and event-driven jobs without managing Kubernetes.

**🎯 EXAM TIP — Container Apps scaling:**
- Scale rules: **HTTP** (concurrent requests), **TCP** (concurrent connections), **custom/KEDA** (Service Bus, Event Hubs, Kafka, cron, …) and **CPU/memory**.
- **min replicas 0** = **scale to zero** (not possible with CPU/memory rules alone, because a stopped replica has no CPU to measure).
- Replicas scale between min and max.
- **Revision-scope changes** (image, env vars, CPU/memory, scale rules) **create a new revision**. **Application-scope changes** (ingress, secrets, revision mode) don't.
- CPU/memory come in **fixed combinations** on Consumption (for example 0.25/0.5Gi, 0.5/1Gi, … up to 4/8Gi).

**🎯 EXAM TIP — Revision modes.** **Single** (default): only the latest revision is active, and a new one replaces the old. **Multiple**: several active revisions with **traffic weights**, used for blue/green and canary releases. Labels give a stable URL to a specific revision.

## Lab 13 — Azure App Service: Plans, Scaling, Slots, Networking, TLS, Custom Domains and Backup

Source: [`labs/13-app-service.md`](../labs/13-app-service.md)

**🎯 EXAM TIP — The plan is the compute.** Apps in the same plan **share its instances** and scale together. **Scale up** = change tier/size (more CPU/RAM, more features). **Scale out** = more instances. Region, OS and tier belong to the plan. Moving an app to another plan requires the **same region and resource group** (and a compatible OS).

**🎯 EXAM TIP — App settings** become **environment variables** for the app and override values in code or config files. **Connection strings** are a separate section with typed prefixes. Both can be marked **deployment slot setting** (sticky). Changing app settings **restarts** the app.

**🎯 EXAM TIP — Scaling limits by tier:** Free/Shared: none. **Basic: manual, max 3.** **Standard: autoscale, max 10.** **Premium v3: max 30**, plus automatic (elastic) scaling. **Isolated: max 100.** Autoscale needs **Standard or higher**. Always define both scale-out and scale-in rules.

**🎯 EXAM TIP — What swaps and what doesn't.**
- **Swapped (moves with the code):** app settings and connection strings *not* marked as slot settings, language/framework versions, handler mappings, public certificates, WebJobs content.
- **Not swapped (stays with the slot):** **slot settings**, **custom domains**, **TLS/SSL bindings and private certificates**, **scale settings**, **IP restrictions**, **Always On**, **CORS**, **managed identities**, **VNet integration**, diagnostic settings, publishing endpoints.
- Slots need **Standard+** (Standard = 5 slots).
- **Auto swap isn't supported on Linux** or Web App for Containers.
- Swap = warm-up then routing switch, so **no downtime**. Rollback = swap again.

**🎯 EXAM TIP — App Service networking directions:**

| Direction | Feature | Use |
|---|---|---|
| **Outbound** (app → your network) | **VNet integration** (delegated subnet, Basic+), **Hybrid Connections** (one TCP endpoint on-prem, through a relay), NAT gateway on the integration subnet | Reach private VMs, databases, on-prem via VPN |
| **Inbound** (clients → app) | **Access restrictions** (IP/service tag/VNet rules, priority-ordered), **private endpoint** (private IP, Basic+), **App Service Environment** | Lock down who can reach the app |

VNet integration doesn't give the app an inbound private IP. That's what the private endpoint is for. Exam questions mix them up on purpose.

**🎯 EXAM TIP — App Service certificates and TLS:**
- **App Service Managed Certificate:** **free**, auto-renewing, **Basic tier or higher**, **no wildcard**, **not exportable**, needs the custom domain mapped first.
- **Uploaded PFX:** password-protected, includes the private key.
- **Key Vault import:** the app's identity needs access to the vault.
- **Bindings:** **SNI SSL** (many certificates on one IP; the norm) vs **IP-based SSL** (dedicated IP).
- **HTTPS Only** redirects HTTP → HTTPS. Minimum TLS version applies to inbound requests.

**🎯 EXAM TIP — Custom domain records:**

| Domain | Records |
|---|---|
| Subdomain (`www`, `tracker`) | **CNAME** → `<app>.azurewebsites.net` + **TXT** `asuid.<sub>` = verification ID |
| Apex (`contoso.com`) | **A** → the app's **inbound IP** + **TXT** `asuid` = verification ID |

The `asuid` TXT record proves you own the domain. It also lets you validate **before** moving live traffic, so you can migrate without downtime. Custom domains need **Shared (D1) or higher**; TLS bindings need **Basic or higher**. Custom domains **don't swap** between slots.

**🎯 EXAM TIP — App Service backup:**

| | Automatic | Custom |
|---|---|---|
| Tiers | Basic, Standard, Premium, Isolated | Basic, Standard, Premium, Isolated |
| Storage account | Not needed | **Required** (SAS-based; firewall-protected storage only over VNet integration) |
| Frequency / retention | Hourly / 30 days, fixed | Every 2 h+ (up to 12/day) / 0–30 days or indefinite |
| Size limit | 30 GB | 10 GB (4 GB of it linked databases) |
| Linked databases | No | Yes, but deprecated (removed from custom backups by 2028) |
| Partial backups | No | Yes |

Basic tier backs up **only the production slot**. Restores don't bring back custom domains, TLS, identities, networking or scale settings.

## Lab 14 — Monitor and Maintain: Metrics, Logs, KQL, Alerts, Insights and Connection Monitor

Source: [`labs/14-monitoring-alerts-network-watcher.md`](../labs/14-monitoring-alerts-network-watcher.md)

**🎯 EXAM TIP — Workspace design.** Pricing is mostly **per GB ingested**. Commitment tiers discount high volume, and a **daily cap** stops ingestion (except some security data) once reached, so you **lose data** for the rest of the day. Access is controlled by **workspace-context** or **resource-context** permissions (*Log Analytics Reader/Contributor*, or table-level RBAC). Keep one central workspace unless regulation or billing requires separation.

**🎯 EXAM TIP — Metrics vs logs.**
- **Platform metrics** are collected automatically, are free, have about 1-minute granularity and **93 days** retention, and you view them in Metrics explorer.
- **Guest OS** metrics (memory inside the VM, disk per mount) need the **Azure Monitor Agent** + a data collection rule.
- **Logs** (resource logs, activity log, VM logs) go to Log Analytics only when you configure them (Task 3).
- **Aggregations:** Avg, Min, Max, Sum, Count.
- **Splitting** = one line per dimension value. **Filtering** = only some dimension values.
- "Average CPU looks fine but users report spikes" → look at **Max**.

**🎯 EXAM TIP — Where data comes from and how it gets there:**

| Data | Collected by | How to enable |
|---|---|---|
| Platform metrics | Automatic | Nothing |
| **Activity log** (control-plane events) | Automatic, **90 days** in the portal | **Diagnostic setting** on the subscription to keep or analyse it |
| **Resource logs** (data-plane: blob reads, Key Vault access, NSG events) | **Not collected by default** | **Diagnostic setting** per resource (up to **5** per resource) |
| Guest OS perf, syslog, Windows events | **Azure Monitor Agent** | **Data collection rule (DCR)** associated with the VMs |

Diagnostic setting destinations: **Log Analytics** (query/alert), **Storage account** (cheap archive), **Event Hub** (stream to a SIEM or third party), partner solutions. The legacy **Log Analytics agent (MMA/OMS)** was **retired 31 Aug 2024**. On a current exam the answer is **AMA + DCR**.

**🎯 EXAM TIP — Read KQL fast.** `Table | where … | summarize agg() by col, bin(TimeGenerated, 5m) | project … | order by … | take N | render timechart`.
- `where` filters **rows**. `project` picks **columns**. `extend` **adds** a column. `summarize` **aggregates** (`count()`, `avg()`, `max()`, `dcount()`, `arg_max()`).
- `ago(1h)` = relative time. `has` matches whole terms (fast). `contains` matches substrings (slow).
- Expect a query on screen and a question like "what does it return?" or "which line do you change to get X?".
- Tables to recognize: **Heartbeat**, **Perf**, **InsightsMetrics**, **Syslog**, **Event**, **AzureActivity**, **AzureDiagnostics** (legacy shared table), resource-specific tables such as **StorageBlobLogs**.

**🎯 EXAM TIP — Alert building blocks:**
- **Alert rule** = scope + **condition (signal)** + actions + severity (**Sev0 Critical … Sev4 Verbose**).
- Signal types: **metric**, **log search**, **activity log** (including **Service Health** and **Resource Health**), Prometheus, smart detection.
- **Action group** = **who** is notified (email, SMS, push, voice) + **what runs** (runbook, Function, Logic App, webhook, ITSM, Event Hub). It's reusable across alert rules. **Rate limits:** SMS and voice at most once every 5 minutes per number, email at most 100 per hour per address.
- **Alert processing rule** = acts on **fired alerts** at a scope. It can **suppress** notifications (maintenance windows) or **add action groups**, with filters (severity, resource type, alert rule, monitor service) and schedules. It **doesn't** stop alerts from firing.
- **Monitor condition** (Fired/Resolved) is set by the system. **Alert state** (New/Acknowledged/Closed) is set by people.

**🎯 EXAM TIP — Insights are curated workbooks over metrics and logs.** **VM insights** needs AMA + its DCR (performance; the **Map** needs the Dependency agent). **Storage insights** works from platform metrics with no setup. **Network insights** shows topology, health and Connection monitor/Traffic analytics results. When a question says "see the performance of all VMs in one place" or "find which storage accounts have availability problems", the answer is the matching insight.

**🎯 EXAM TIP — Connection monitor vs connection troubleshoot.** **Connection troubleshoot** is a **one-time** check (Lab 05). **Connection monitor** is **continuous** monitoring from sources (Azure VMs and scale sets with the Network Watcher agent, or on-prem machines with AMA) to destinations (VMs, URLs, FQDNs, IPs) over TCP/HTTP/ICMP, with **alerts** and results in Log Analytics. Connection monitor replaces the retired *Network Performance Monitor* and the classic connection monitor.

**🎯 EXAM TIP — Flow logs.** **NSG flow logs retire on 30 September 2027 and new ones can't be created.** Use **VNet flow logs** (VNet, subnet or NIC scope), which also log traffic that NSGs don't evaluate. The storage account **must be in the same region** as the target. **Traffic analytics** processes flow logs into Log Analytics for maps and top talkers.

## Lab 15 — Backup and Disaster Recovery: Recovery Services Vault, Backup Vault and Site Recovery

Source: [`labs/15-backup-and-site-recovery.md`](../labs/15-backup-and-site-recovery.md)

**🎯 EXAM TIP — Which vault?**

| **Recovery Services vault** | **Backup vault** |
|---|---|
| Azure **VMs** | Azure **Disks** (managed disks) |
| **SQL Server / SAP HANA in Azure VMs** | Azure **Blobs** (operational + vaulted) |
| **Azure Files** | Azure Database for **PostgreSQL** |
| **MARS agent** (on-prem files/folders/system state), **MABS/DPM** | **AKS** (and other newer workloads) |
| **Azure Site Recovery** | — |

The vault must be in the **same region as the data it backs up**. **Storage redundancy** (LRS/ZRS/GRS) can only be changed **before the first item is protected**.

**🎯 EXAM TIP — Standard vs Enhanced VM policies.** **Enhanced** supports **multiple backups per day** (every 4 h+), **instant restore snapshots for 1–30 days**, **zone-redundant snapshot storage**, and newer VM types (**Trusted Launch**, **Premium SSD v2**, **Ultra Disk**). The portal requires Enhanced for Trusted Launch VMs (Standard works for them only via newer CLI/PowerShell/REST). **Once a VM uses Enhanced, it can't go back to Standard.** Restore points live in the **snapshot tier** (fast, instant restore) and then the **vault tier** (long-term).

**🎯 EXAM TIP — How Azure VM backup works:** a VM **extension** coordinates **snapshots** (app-consistent with VSS on Windows, file-system-consistent with pre/post scripts on Linux, otherwise crash-consistent). No agent install, no VM downtime. **You don't need to stop the VM**, and deallocated VMs can be backed up too.

**🎯 EXAM TIP — VM restore options:**
- **Create new VM:** a quick, basic config.
- **Restore disks:** you get the disks plus a **template** to customize the VM (for example, to add it to an availability set).
- **Replace existing:** swaps the disks in place; the current disk is kept as a snapshot.
- **Cross Region Restore:** restore in the **paired region** (GRS vault with CRR enabled).
- **File Recovery:** individual files without restoring the VM.

A restored VM may **conflict** with the original (same hostname, and the same IP if you choose it), so restore to a different subnet or shut down the original.

**🎯 EXAM TIP — Backup vault permissions.** Backup vault workloads use the **vault's managed identity**, which needs data-source roles: **Disk Backup Reader** + **Disk Snapshot Contributor** for disks, **Storage Account Backup Contributor** for blobs. "Backup configuration fails validation" in a question almost always means a missing role for the vault identity. Azure Disk Backup stores **incremental snapshots** in your snapshot RG, so restores are fast. It doesn't replace application-consistent VM backup.

**🎯 EXAM TIP — Site Recovery vault location.** For Azure-to-Azure DR, create the vault in a region **other than the source**, typically the **target** region. If the source region goes down, a vault in that region would go down with it. (Backup vaults are the opposite: same region as the data.)

**🎯 EXAM TIP — ASR building blocks:** the **Mobility service extension** on the source VM, a **cache storage account in the source region** (changes are staged there before going to the target), a **replication policy** (recovery point retention, **app-consistent snapshot frequency**; crash-consistent points are created about every 5 minutes), and **target resources** (RG, VNet, availability set/zone). The source VM needs **outbound** connectivity to Site Recovery endpoints (service tags or URLs). An NSG or UDR that blocks egress breaks replication.

**🎯 EXAM TIP — Failover types:**
- **Test failover:** non-disruptive, into an **isolated VNet**, replication continues. Always clean up afterwards.
- **Failover** (planned/unplanned): brings VMs up in the target from a chosen recovery point (**latest**, **latest processed**, **latest app-consistent**, or custom).
- **Commit:** locks in the chosen recovery point.
- **Re-protect:** reverses replication direction.
- **Failback:** fail over again to the original region.

**Site Recovery = disaster recovery (RPO of minutes, RTO via failover). Backup = point-in-time restore (deletions, corruption, ransomware).** Many questions hinge on picking the right one. ASR is also a way to **move VMs to another region** (Lab 08).

**🎯 EXAM TIP — Backup monitoring:**
- **Backup reports** need vault **diagnostic settings → Log Analytics** (resource-specific tables) and then show history, trends, usage and optimization across vaults and subscriptions.
- **Backup jobs** and **Backup items** in the portal give the current view.
- **Azure Monitor–based alerts** for Azure Backup are **built in** for job failures and security events (like deleting backup data). Notifications go through **alert processing rules + action groups**. Classic backup alerts are being retired.
