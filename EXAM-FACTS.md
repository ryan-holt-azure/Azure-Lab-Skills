# AZ-104 Exam Facts & Practice Questions

Every "Exam facts" bullet from all 18 labs, in lab order, plus 1–2 scenario-style
practice questions per lab modeled on how AZ-104 actually asks them (a short
scenario, four options, one best answer). Use this as a pre-exam cram sheet —
the full reasoning for each fact lives in the corresponding lab's `README.md`.

---

## Lab 01 — Entra Users, Groups, SSPR

**Exam facts**
1. Dynamic groups and SSPR-with-writeback require **Entra ID P1** (writeback also needs Entra Connect).
2. Group expiration policies apply to **Microsoft 365 groups only**, not security groups.
3. License assignment needs **Usage Location** set on the user.
4. Guests get fewer default directory permissions than members. External collaboration settings control who can send invitations (members can, by default).
5. Group-based licensing requires the target to have a Usage Location; assign the license to the group, not the user.

**Q1.** An admin creates a dynamic group rule based on the `department` attribute, but the "Dynamic User" membership type option is greyed out. What is the most likely cause?
A) The admin lacks the Global Administrator role
B) The tenant does not have Entra ID P1 or higher licensing
C) The group type is Microsoft 365 instead of Security
D) The rule syntax is invalid

**Answer: B** — Dynamic membership requires at least Entra ID P1. The UI greys out the option entirely when no qualifying license exists in the tenant, regardless of the admin's role or the rule itself.

**Q2.** A new user needs a license assigned via group-based licensing, but the assignment sits stuck in a "Provisioning" error state. What should be checked first?
A) Whether MFA is enabled for the user
B) Whether the user has a Usage Location set
C) Whether the group is a distribution group
D) Whether the license SKU is E5 instead of E3

**Answer: B** — Usage Location is required before any license (direct or group-based) can be assigned, because licensing eligibility is regulated by country. Missing it is the #1 cause of silent assignment failures.

---

## Lab 02 — RBAC: Roles, Scopes, Custom Roles

**Exam facts**
1. Roles inherit **down** scope: management group → subscription → resource group → resource.
2. There is no "deny" in a role definition. `notActions` subtracts from `actions` within the same role — it does not block grants from other assignments.
3. **Owner** = Contributor + the ability to grant roles to others. **User Access Administrator** = can grant roles but can't build resources.
4. You cannot modify built-in roles — clone to a custom role. Custom roles need at least one assignable scope.
5. Entra directory roles ≠ Azure RBAC roles — know which system a question is in.
6. The only true blockers to accumulated grants: Azure Policy, resource locks, and Deny Assignments.

**Q1.** A user has plain Contributor at a resource group scope, plus a custom role at the same scope that excludes `Microsoft.Network/*/write` via `notActions`. Can the user still create a VNet in that resource group?
A) No, `notActions` always blocks the action regardless of other assignments
B) Yes, because the plain Contributor assignment still grants the permission, and Azure unions grants across assignments
C) No, Azure evaluates the most restrictive assignment first
D) Yes, but only after an Entra Connect sync

**Answer: B** — Azure RBAC is additive across all applicable assignments. `notActions` only subtracts from what *that specific role* grants; it cannot override a broader grant coming from a different assignment at the same scope.

**Q2.** Which role can assign RBAC roles to other users but cannot create or modify resources like VMs or storage accounts?
A) Owner
B) Contributor
C) User Access Administrator
D) Reader

**Answer: C** — User Access Administrator is scoped purely to managing access. It has no rights over the resources themselves, unlike Owner (which is Contributor plus role-assignment rights).

---

## Lab 03 — Governance: Management Groups, Policy, Locks, Tags

**Exam facts**
1. Policy effects hierarchy: **Deny, Audit, Append, Modify, DeployIfNotExists**. **Modify** and **DeployIfNotExists** require a managed identity; **Deny** and **Audit** do not.
2. Tags do **not** inherit by default (policy can force it). Tag names are case-insensitive; values are case-sensitive.
3. Two lock types only: **CanNotDelete** and **ReadOnly**. Locks **inherit downward** and apply to everyone, including Owners. Removing a lock requires `Microsoft.Authorization/locks/delete`.
4. Management group **IDs are permanent**; display names can be renamed anytime.
5. Policy assignment and dynamic evaluation are **not instant** — allow 10–15 minutes.

**Q1.** A policy assignment uses "Inherit a tag from the resource group" with effect = Modify. What's required for it to actually retag resources that already exist and are non-compliant?
A) Nothing — Modify effects apply automatically in real time to existing resources
B) A managed identity on the assignment, plus a remediation task run against the existing resources
C) Removing any CanNotDelete lock on the resource group first
D) Adding the tag to the management group manually first

**Answer: B** — Modify (and DeployIfNotExists) need a managed identity with permission to act. Policy only auto-applies going forward to newly evaluated resources; a separate **remediation task** is required to fix resources that were already out of compliance.

**Q2.** An Owner tries to delete a resource group that has a CanNotDelete lock. What happens?
A) The delete succeeds — Owners bypass all locks
B) The delete fails; the lock must be removed first, which requires the locks/delete permission
C) The delete succeeds after a 15-minute delay
D) The delete fails permanently with no way to override it

**Answer: B** — Locks apply to everyone, including Owners, with no bypass. The lock must be explicitly removed (typically requiring Owner or User Access Administrator) before deletion can proceed.

---

## Lab 04 — Cost Control: Budgets, Action Groups, Advisor

**Exam facts**
1. **Budgets alert only** — they never stop spending. Nothing automatically caps subscription spend, except a spending limit on free/credit accounts.
2. Advisor's five pillars: **Cost, Security, Reliability, Operational Excellence, Performance**. Advisor's Security findings come from **Microsoft Defender for Cloud**.

**Q1.** A subscription owner sets a $50 budget with a 100%-actual alert, expecting Azure to stop provisioning once the budget is hit. What actually happens?
A) All resource creation is blocked immediately at 100%
B) An alert email is sent, but spending is not stopped or capped
C) The subscription is automatically suspended
D) Only VM creation is blocked; other resources continue

**Answer: B** — Budgets are alerting-only. Aside from the spending limit on free/credit accounts, nothing in Azure automatically enforces a spend cap — a human has to act on the alert.

**Q2.** Which service provides the underlying findings shown in Azure Advisor's Security pillar?
A) Azure Monitor
B) Microsoft Defender for Cloud
C) Azure Policy
D) Microsoft Sentinel

**Answer: B** — Advisor surfaces Security recommendations directly from Defender for Cloud rather than generating its own independent security analysis.

---

## Lab 05 — Storage Accounts, Keys, SAS, Firewall

**Exam facts**
1. A SAS bound to a **stored access policy** is revocable by editing/deleting the policy. An **ad-hoc SAS** only dies when the signing key is rotated.
2. Redundancy copy counts: **LRS** = 3 (one datacenter), **ZRS** = 3 (across zones), **GRS/GZRS** = 6 (3 + 3 in the paired region).
3. **GRS → ZRS conversion** may require a support-assisted or manual migration path.
4. "**Trusted Microsoft services**" bypass exists on the storage firewall.

**Q1.** An admin needs to revoke a SAS token immediately without affecting any other SAS tokens issued from the same account. What must have been true when it was generated?
A) It must have been an account SAS
B) It must have been bound to a stored access policy
C) It must have used HTTPS only
D) It must have had an expiry under 1 hour

**Answer: B** — Only a policy-bound SAS can be revoked individually (by editing/deleting the policy) without rotating the account key, which would invalidate every ad-hoc SAS issued from that account.

**Q2.** How many total copies of data exist under GRS redundancy?
A) 3
B) 4
C) 6
D) 2

**Answer: C** — GRS (and GZRS) keep 3 copies in the primary region and 3 more in the paired secondary region, for 6 total.

---

## Lab 06 — Blob Tiers, Lifecycle, Versioning

**Exam facts**
1. **Archive** tier is offline — no reads until rehydration completes (hours; Standard vs. High priority).
2. Lifecycle management requires a **GPv2 or Blob storage** account.
3. **Versioning** = automatic on every write. **Snapshots** = manual, point-in-time. **Soft delete** = a recycle bin with a retention window.
4. The **Cold** tier sits between Cool and Archive — it's online.

**Q1.** A user tries to download a blob currently in the Archive tier and gets an error. What must happen first?
A) Move it to Cold tier via a lifecycle rule
B) Rehydrate it to Hot or Cool tier
C) Upgrade the storage account SKU
D) Regenerate the blob's SAS token

**Answer: B** — Archive is fully offline. The blob must be rehydrated (Standard or High priority) back to an online tier before it can be read at all.

**Q2.** What's the key difference between blob versioning and blob snapshots?
A) They're functionally identical
B) Versioning is automatic on every write; snapshots are manual, point-in-time
C) Snapshots are automatic; versioning is manual
D) Versioning only works on Archive-tier blobs

**Answer: B** — Versioning requires no action — a new version is captured on every overwrite. A snapshot must be explicitly triggered.

---

## Lab 07 — Azure Files, Storage Explorer, AzCopy

**Exam facts**
1. `azcopy copy` = **one-way transfer**. `azcopy sync` = **mirror deltas** (can delete at the destination with a flag).
2. Identity-based access for Azure Files: **Entra Kerberos/AD DS** options vs. storage-key auth.
3. Azure File Sync: exactly **ONE cloud endpoint** per sync group, many server endpoints. Cloud tiering keeps hot data local.

**Q1.** After copying a folder to Blob storage with AzCopy, one local file changes. Which command updates only that file at the destination?
A) `azcopy copy`, since it transfers changed files by default
B) `azcopy sync`, which mirrors deltas
C) `azcopy remove` followed by `azcopy copy`
D) There's no way to transfer only changed files

**Answer: B** — `azcopy sync` compares source and destination and moves only the deltas; `azcopy copy` is a straightforward one-way transfer of everything specified, with no delta awareness.

**Q2.** How many cloud endpoints can a single Azure File Sync sync group have?
A) Unlimited
B) Exactly one
C) Up to five
D) One per region

**Answer: B** — Each sync group supports exactly one cloud endpoint (an Azure file share), though it can have many server endpoints.

---

## Lab 08 — ARM & Bicep Round-Trip

**Exam facts**
1. **Incremental** is the default deployment mode (adds/updates, never deletes). **Complete** mode deletes anything not in the template.
2. Template sections: `parameters`, `variables`, `resources`, `outputs`.
3. `what-if` previews changes before deployment.
4. Exporting from the portal captures current state **including defaults**.

**Q1.** A team deploys a template in Complete mode against a resource group that also contains a manually created NSG not defined in the template. What happens to the NSG?
A) It's ignored and left untouched
B) It's deleted, because Complete mode removes anything not in the template
C) It's automatically imported into the template
D) The deployment fails with a conflict error

**Answer: B** — Complete mode reconciles the resource group to exactly match the template, deleting anything present that isn't declared. Incremental mode (the default) would leave it alone.

**Q2.** Which command previews the changes a deployment would make without applying them?
A) `az deployment group validate`
B) `az deployment group what-if`
C) `az deployment group preview`
D) `az group export`

**Answer: B** — `what-if` performs a dry-run comparison of current vs. proposed state, showing exactly what would be created, modified, or deleted.

---

## Lab 09 — VM Operations End to End

**Exam facts**
1. Resize = reboot, when the resize crosses hardware clusters.
2. **Availability set** membership is decided at creation — changing it requires delete/recreate.
3. **Sets** = fault + update domains in one datacenter. **Zones** = separate datacenters (99.99% multi-zone SLA vs. 99.95% for a set).
4. Managed disks don't "move" between regions — snapshot/copy instead.
5. **Encryption at host** ≠ **Azure Disk Encryption** (BitLocker/dm-crypt) ≠ **SSE with customer-managed key**.

**Q1.** A VM was deployed into Availability Zone 2. The team now wants to also place it into an Availability Set. What must be done?
A) Add it to a set from the VM's Configuration blade
B) It's not possible without deleting and recreating the VM
C) Use `az vm update` to reassign the fault domain
D) Only possible via PowerShell, not the portal or CLI

**Answer: B** — Zone/set placement is fixed at creation. Changing between them requires deleting and redeploying the VM.

**Q2.** Which encryption technology operates at the Azure hypervisor/host level, distinct from BitLocker/dm-crypt running inside the guest OS?
A) Azure Disk Encryption (ADE)
B) Encryption at host
C) Client-side encryption
D) Transparent Data Encryption

**Answer: B** — Encryption at host encrypts data at the hypervisor layer before it reaches the storage service. ADE relies on BitLocker/dm-crypt running inside the guest OS — a materially different mechanism.

---

## Lab 10 — Scale Sets

**Exam facts**
1. **Uniform** = identical instances, the classic model. **Flexible** = mixed sizes/Spot+Standard, the modern default.
2. Autoscale needs **min/max/default** instance counts; rules pair scale-out **and** scale-in.
3. Zonal spreading is set at creation.

**Q1.** Which VMSS orchestration mode supports mixing Spot and Standard instances in the same scale set?
A) Uniform
B) Flexible
C) Both support this equally
D) Neither supports this

**Answer: B** — Flexible mode is designed for heterogeneous instances — mixed sizes and mixed Spot/Standard pricing. Uniform enforces identical instances.

**Q2.** An autoscale profile has a scale-out rule (CPU > 70% adds an instance) but no scale-in rule. What happens?
A) Instances scale out but never scale back in automatically
B) Azure pairs a default scale-in rule automatically
C) The profile fails validation
D) Instances scale in based on memory usage by default

**Answer: A** — Rules must be explicitly paired. Without a scale-in condition, the set only grows (up to max instances) and needs manual intervention to shrink.

---

## Lab 11 — App Service, Slots, Containers

**Exam facts**
1. **Deployment slots require Standard tier or higher**; swap exchanges content + a subset of config (slot-sticky settings exist).
2. **One App Service plan** hosts many apps — they share the compute.
3. **ACI multi-container groups are Linux only.**
4. **Container Apps scale to zero; ACI does not.**
5. **ACR tiers**: Basic/Standard/Premium (Premium = private link + geo-replication).

**Q1.** A team on the Free-tier App Service plan wants to add a staging deployment slot. What's blocking them?
A) Nothing — slots are available on every tier
B) Deployment slots require Standard tier or higher
C) Slots require Premium v3 specifically
D) Slots only work on Linux App Service plans

**Answer: B** — Free and Shared tiers don't support deployment slots at all; Standard is the minimum.

**Q2.** Which container hosting option can scale down to zero instances when idle?
A) Azure Container Instances (ACI)
B) Azure Container Apps
C) Both scale to zero identically
D) Neither supports scale-to-zero

**Answer: B** — Container Apps supports scaling to zero replicas on no traffic. ACI runs continuously as long as the container group exists.

---

## Lab 12 — VNets and Peering

**Exam facts**
1. **Peering is non-transitive.**
2. Address spaces must **not overlap** between peered VNets.
3. Peering works **cross-region and cross-subscription**.
4. Azure **reserves 5 IP addresses per subnet**.

**Q1.** VNet A is peered to both B and C, but B and C are not peered to each other. Can a VM in B reach a VM in C through A?
A) Yes, peering is transitive by default
B) No — peering is non-transitive; B and C need direct peering or a hub-spoke design with NVA/gateway transit
C) Yes, but only if all three VNets share a region
D) Yes, automatically once gateway transit is enabled on A

**Answer: B** — Peering never transits through an intermediate VNet. B and C have no relationship to each other regardless of their shared peering to A.

**Q2.** How many IP addresses does Azure reserve in every subnet, regardless of size?
A) 2
B) 5
C) 10
D) 0 — all addresses are usable

**Answer: B** — Azure reserves 5 addresses per subnet (network address, default gateway, two DNS-reserved addresses, and the broadcast address).

---

## Lab 13 — NSG, ASG, Bastion, Effective Rules

**Exam facts**
1. NSGs are **stateful** — reply traffic is auto-allowed.
2. Evaluation order: inbound hits **subnet-NSG then NIC-NSG** — both must allow.
3. **Priority**: lower number wins. Default rules sit at the 65000s.
4. **ASGs** group NICs within one VNet as a single rule target.
5. Bastion subnet name is literal **`AzureBastionSubnet`**, **/26 or larger**.

**Q1.** A subnet-level NSG allows port 443 inbound, but the NIC-level NSG on the target VM has no matching allow rule and falls back to defaults. What happens to inbound HTTPS traffic?
A) It's allowed because the subnet NSG permits it
B) It's denied — inbound traffic must be allowed by both the subnet NSG and the NIC NSG
C) It's allowed only if the VM has a public IP
D) NIC-level NSGs are ignored if a subnet NSG exists

**Answer: B** — Both the subnet NSG and NIC NSG must permit inbound traffic. If the NIC NSG falls back to its default deny, the traffic is blocked even though the subnet NSG allowed it.

**Q2.** What's required for an Azure Bastion deployment to succeed?
A) A subnet named "AzureBastionSubnet" that is /27 or smaller
B) A subnet named exactly "AzureBastionSubnet" that is /26 or larger
C) Any subnet name tagged "bastion"
D) A public IP assigned directly to each target VM

**Answer: B** — Bastion requires the exact literal subnet name `AzureBastionSubnet` and a minimum size of /26.

---

## Lab 14 — UDRs, Service Endpoints, Private Endpoints

**Exam facts**
1. Next hop types: **VirtualAppliance, VirtualNetworkGateway, VNet, Internet, None**.
2. **Service endpoint**: traffic stays on the backbone, the service keeps its **public IP**, source identity = VNet.
3. **Private endpoint**: private IP inside your subnet + requires the **`privatelink.*` DNS zone** — broken DNS is the #1 failure.

**Q1.** After configuring a private endpoint for a storage account, the hostname still doesn't resolve to a private IP from inside the VNet. What's the most likely cause?
A) The storage account firewall is still set to allow all networks
B) The privatelink DNS zone is missing or not linked to the VNet
C) The private endpoint is in the wrong region
D) The storage account SKU doesn't support private endpoints

**Answer: B** — A private endpoint doesn't rewrite DNS by itself. Resolution to the private IP depends on the matching `privatelink.*` zone existing and being linked to the VNet — the single most common private-endpoint failure.

**Q2.** What's the key architectural difference between a service endpoint and a private endpoint?
A) They're functionally identical
B) A service endpoint keeps the service's public IP and routes over the backbone; a private endpoint gives the service a private IP inside the subnet
C) Private endpoints only work for Azure SQL, not Storage
D) Service endpoints require a privatelink DNS zone; private endpoints do not

**Answer: B** — A service endpoint optimizes routing but the service still has a public IP. A private endpoint actually projects the service into the VNet with its own private address — a materially different security posture.

---

## Lab 15 — DNS and Load Balancing

**Exam facts**
1. **Standard LB**: zone-redundant, SLA-backed, secure by default. **Basic**: none of that, and it's being retired.
2. LB is **regional** — cross-region failover needs **Traffic Manager** (DNS) or **Front Door** (HTTP).
3. **Health probe failure removes the instance from rotation — it does not heal it.**
4. Private DNS **auto-registration only works via linked VNets**.

**Q1.** A company needs automatic failover between load balancers in two different Azure regions. What should they use?
A) A single Standard Load Balancer spanning both regions
B) Traffic Manager or Azure Front Door
C) NSGs with region-aware rules
D) Azure Bastion in each region

**Answer: B** — Load Balancer is a regional service with no cross-region failover of its own. A global, DNS-based (Traffic Manager) or HTTP-based (Front Door) layer is required in front of the regional balancers.

**Q2.** A backend VM behind a Standard Load Balancer fails its health probe. What does the LB do?
A) Automatically restarts the VM
B) Removes it from rotation until it passes the probe again — it does not attempt to heal it
C) Redirects future requests to a replacement instance automatically
D) Sends an alert but keeps routing traffic to it

**Answer: B** — The health probe only detects and reroutes around unhealthy instances. Remediation is a separate action for the operator or automation to take.

---

## Lab 16 — Azure Monitor + KQL + Alerts

**Exam facts**
1. **Metrics** = fast numeric time-series. **Logs** = KQL over Log Analytics.
2. **DCRs** target Log Analytics workspaces.
3. Alert flow: **rule → action group → (optional) processing rule**.
4. **Dynamic thresholds** learn baselines.

**Q1.** Which Azure Monitor data type would be queried with KQL to get "average CPU over the last 24 hours in 5-minute buckets"?
A) Metrics, via Metrics Explorer only
B) Logs, via Log Analytics using KQL
C) Activity Log, via Resource Graph
D) Alerts, via Action Groups

**Answer: B** — KQL runs against Logs data in a Log Analytics workspace (e.g., the `Perf` table). Metrics are a separate lightweight time-series store typically explored via Metrics Explorer.

**Q2.** What has to exist before an alert rule can send an email notification when triggered?
A) A Log Analytics workspace only
B) An action group configured with an email notification
C) A managed identity assigned to the alert rule
D) A Recovery Services vault

**Answer: B** — The alert rule only defines the trigger condition. The action group is what actually executes the notification (email, SMS, webhook, etc.).

---

## Lab 17 — Network Watcher

**Exam facts**
1. Network Watcher is **regional**, auto-enabled per region on VNet creation.
2. **IP Flow Verify** answers "which NSG rule blocked this." **Next Hop** answers "where is this packet routed."
3. **Connection Monitor** replaces the classic connection troubleshoot tool for **continuous** checks.

**Q1.** A ticket says "traffic from VM-A to VM-B on port 3389 is blocked, but we don't know which rule is responsible." Which tool answers this directly?
A) Next Hop
B) IP Flow Verify
C) Connection Monitor
D) NSG Flow Logs only

**Answer: B** — IP Flow Verify tests a specific flow against effective NSG rules and reports exactly which rule allowed or denied it.

**Q2.** Which tool continuously monitors connectivity and latency between two VMs over time, rather than a one-time check?
A) IP Flow Verify
B) Next Hop
C) Connection Monitor
D) Effective Security Rules

**Answer: C** — Connection Monitor is built for ongoing, continuous monitoring, replacing the older one-shot connection troubleshoot tool.

---

## Lab 18 — Backup and Site Recovery

**Exam facts**
1. The vault must be in the **same region** as the protected VMs (the restore target can be elsewhere).
2. A vault with protected items **cannot be deleted** — stop protection on every item first.
3. **Restore-replace** needs the VM stopped; **restore-to-new** works anytime.
4. **Test failover touches production zero.**
5. **Recovery Services vault** = classic workloads (VMs, SQL-in-VM, Files). **Backup vault** = newer types (Blobs, Disks, PostgreSQL).
6. **ASR is free per instance for the first 31 days.**

**Q1.** An admin tries to delete a Recovery Services vault but gets an error that it cannot be deleted. What's the most likely cause?
A) The vault's region doesn't match the subscription's default region
B) The vault still has protected items that must have protection stopped first
C) Recovery Services vaults can never be deleted, only Backup vaults can
D) A CanNotDelete lock needs to be removed first

**Answer: B** — A vault can't be deleted while it still has protected items (backed-up VMs, or VMs with active ASR replication). Protection must be explicitly stopped on every item first.

**Q2.** When running an ASR test failover, what's the impact on the live production VM?
A) Production replication pauses during the test
B) The production VM is briefly shut down
C) Test failover runs in an isolated environment with zero impact on production
D) The production VM is failed over permanently

**Answer: C** — Test failover exists specifically to validate a DR plan without touching the live, replicating production VM — it spins up an isolated copy for verification, then is cleaned up separately.
