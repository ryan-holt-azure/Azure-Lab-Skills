# Skills Coverage Matrix — AZ-104 (skills measured as of 17 April 2026)

Every skill in Microsoft's study guide, mapped to the lab and task (T#) where you practise it. `scripts/check-coverage.py` verifies this file and the labs stay in sync with [`az104-skills-measured-2026-04-17.md`](az104-skills-measured-2026-04-17.md).

**Coverage: 82 / 82 skills hands-on.**

## Manage Azure identities and governance (20–25%)

| Skill (verbatim from the study guide) | Where | How you practise it |
|---|---|---|
| Create users and groups | [Lab 01](../labs/01-identities-and-conditional-access.md) T1, T2, T4 | Portal create, CSV bulk create, Graph PowerShell; assigned, dynamic and Microsoft 365 groups |
| Manage user and group properties | [Lab 01](../labs/01-identities-and-conditional-access.md) T3, T4 | Job info, usage location, manager, block sign-in, reset, revoke sessions, restore deleted users, group owners |
| Manage licenses in Microsoft Entra ID | [Lab 01](../labs/01-identities-and-conditional-access.md) T5 | Group-based P2 licensing, reproduce and fix the usage-location error, direct vs inherited |
| Manage external users | [Lab 01](../labs/01-identities-and-conditional-access.md) T6 · [Lab 04](../labs/04-rbac-access-control.md) T6 | External collaboration settings, B2B invite and redemption, Guest Inviter, RBAC for a guest |
| Configure self-service password reset (SSPR) | [Lab 01](../labs/01-identities-and-conditional-access.md) T7 | Scoped to a pilot group, methods, registration, notifications, end-to-end reset test |
| Manage built-in Azure roles | [Lab 04](../labs/04-rbac-access-control.md) T1, T5, T8 | Read Owner/Contributor/Reader/UAA/RBAC Admin/VM Contributor/data roles; Entra vs Azure roles |
| Assign roles at different scopes | [Lab 04](../labs/04-rbac-access-control.md) T2–T5 · [Lab 16](../labs/16-capstone-break-fix-and-teardown.md) INC-107 | Management group, subscription, RG and resource scope; conditions on RBAC Administrator |
| Interpret access assignments | [Lab 04](../labs/04-rbac-access-control.md) T6, T7 · [Lab 16](../labs/16-capstone-break-fix-and-teardown.md) INC-107 | Sign in as each user, Check access, inherited vs direct, interpret a custom role's NotActions |
| Implement and manage Azure Policy | [Lab 02](../labs/02-governance-policy-locks-costs.md) T4 · [Lab 15](../labs/15-backup-and-site-recovery.md) T6 | Allowed locations, tagging initiative with Modify-before-Deny, VM SKU policy, exemption, remediation, updating parameters |
| Configure resource locks | [Lab 02](../labs/02-governance-policy-locks-costs.md) T5 · [Lab 03](../labs/03-iac-bicep-arm-foundation.md) T3 · [Lab 16](../labs/16-capstone-break-fix-and-teardown.md) INC-104 | ReadOnly vs CanNotDelete effects (listKeys, VM start), resource-level lock on the hub VNet |
| Apply and manage tags on resources | [Lab 02](../labs/02-governance-policy-locks-costs.md) T3, T4 | Portal, bulk, CLI merge/replace/delete; tag inheritance via policy and Cost Management |
| Manage resource groups | [Lab 02](../labs/02-governance-policy-locks-costs.md) T3 | Create 8 tagged RGs, move a resource between RGs and observe the resource ID change |
| Manage subscriptions | [Lab 00](../labs/00-setup-and-safety-net.md) T1, T5 · [Lab 02](../labs/02-governance-policy-locks-costs.md) T1, T2 | Offer type, providers, quotas, rename, move into a management group, directory/billing transfer |
| Manage costs by using alerts, budgets, and Azure Advisor recommendations | [Lab 00](../labs/00-setup-and-safety-net.md) T6 · [Lab 02](../labs/02-governance-policy-locks-costs.md) T6 | Subscription and RG budgets with action groups, anomaly alerts, cost analysis by tag, Advisor config and alerts |
| Configure management groups | [Lab 02](../labs/02-governance-policy-locks-costs.md) T1 | Four-MG hierarchy, subscription placement, elevate access, inheritance of policy and RBAC |

## Implement and manage storage (15–20%)

| Skill (verbatim from the study guide) | Where | How you practise it |
|---|---|---|
| Configure Azure Storage firewalls and virtual networks | [Lab 06](../labs/06-secure-access-nsg-bastion-endpoints.md) T4 · [Lab 10](../labs/10-storage-accounts-security-access.md) T7 · [Lab 16](../labs/16-capstone-break-fix-and-teardown.md) INC-105 | VNet rules with service endpoints, IP rules, exceptions, resource instances, same-region caveat |
| Create and use shared access signature (SAS) tokens | [Lab 10](../labs/10-storage-accounts-security-access.md) T5 | Account, service and user delegation SAS, each tested with curl/CLI |
| Configure stored access policies | [Lab 10](../labs/10-storage-accounts-security-access.md) T6 | Partner policy on a container, SAS bound to it, revocation in ~30 s |
| Manage access keys | [Lab 10](../labs/10-storage-accounts-security-access.md) T4 | Rotation drill, rotation reminder, disabling shared key access and its effects |
| Configure identity-based access for Azure Files | [Lab 10](../labs/10-storage-accounts-security-access.md) T8 | Microsoft Entra Kerberos (cloud-only), admin consent, share-level RBAC, NTFS layer; stretch: mount as an Entra user |
| Create and configure storage accounts | [Lab 03](../labs/03-iac-bicep-arm-foundation.md) T6 · [Lab 10](../labs/10-storage-accounts-security-access.md) T1 | ARM-deployed account plus a full portal walkthrough of creation-only settings |
| Configure Azure Storage redundancy | [Lab 10](../labs/10-storage-accounts-security-access.md) T2 | LRS → GRS → RA-GRS → LRS, secondary endpoint, last sync time, ZRS conversion, failover |
| Configure object replication | [Lab 11](../labs/11-blob-and-files-data-management.md) T6 | East US → Southeast Asia container replication, prerequisites, read-only destination, archive caveat |
| Configure storage account encryption | [Lab 10](../labs/10-storage-accounts-security-access.md) T3 | CMK in Key Vault (RBAC, purge protection), managed identity, encryption scope per container |
| Manage data by using Azure Storage Explorer and AzCopy | [Lab 11](../labs/11-blob-and-files-data-management.md) T8, T9 | Explorer via Entra and SAS URL; AzCopy copy/sync/S2S/jobs with CLI auth and Files SAS |
| Create and configure a file share in Azure Files | [Lab 10](../labs/10-storage-accounts-security-access.md) T8 · [Lab 11](../labs/11-blob-and-files-data-management.md) T7 | Shares with tiers and quotas, Connect script, port 445 |
| Create and configure a container in Azure Blob Storage | [Lab 11](../labs/11-blob-and-files-data-management.md) T1 | Access levels, upload options, metadata vs blob index tags, tag-based search |
| Configure storage tiers | [Lab 11](../labs/11-blob-and-files-data-management.md) T2 | Hot → Cool → Cold → Archive, rehydration by copy with High priority, default tier |
| Configure soft delete for blobs and containers | [Lab 11](../labs/11-blob-and-files-data-management.md) T4 | Undelete a blob, restore a deleted container |
| Configure snapshots and soft delete for Azure Files | [Lab 11](../labs/11-blob-and-files-data-management.md) T7 | Share snapshot + single-file restore, share soft delete + undelete |
| Configure blob lifecycle management | [Lab 11](../labs/11-blob-and-files-data-management.md) T5 | JSON rule: Cool 30 → Cold 90 → Archive 180 → delete 7 years, plus version cleanup |
| Configure blob versioning | [Lab 11](../labs/11-blob-and-files-data-management.md) T3 | Overwrite, list versions, promote a previous version |

## Deploy and manage Azure compute resources (20–25%)

| Skill (verbatim from the study guide) | Where | How you practise it |
|---|---|---|
| Interpret an Azure Resource Manager template or a Bicep file | [Lab 03](../labs/03-iac-bicep-arm-foundation.md) T1 | Eight questions on the foundation Bicep, then read the compiled ARM JSON |
| Modify an existing Azure Resource Manager template | [Lab 03](../labs/03-iac-bicep-arm-foundation.md) T6 | Add allowedValues, security properties, a child container and an output; validate and deploy |
| Modify an existing Bicep file | [Lab 03](../labs/03-iac-bicep-arm-foundation.md) T5 | Add a subnet, an @allowed decorator and an output; what-if and compile-time validation |
| Deploy resources by using an Azure Resource Manager template or a Bicep file | [Lab 03](../labs/03-iac-bicep-arm-foundation.md) T2, T4, T6, T7 · [Lab 07](../labs/07-hybrid-site-to-site-vpn.md) T1 | Subscription and RG scope deployments, what-if, incremental vs complete, portal custom deployment |
| Export a deployment as an Azure Resource Manager template or convert an Azure Resource Manager template to a Bicep file | [Lab 03](../labs/03-iac-bicep-arm-foundation.md) T8 | Export RG and deployment history (portal + CLI), decompile ARM → Bicep |
| Create a virtual machine | [Lab 08](../labs/08-virtual-machines.md) T1 | Every create-wizard tab: zone, Trusted launch, encryption at host, no public IP, Entra login, auto-shutdown |
| Configure encryption at host for Azure virtual machines | [Lab 08](../labs/08-virtual-machines.md) T1, T2 | At creation, and on an existing deallocated VM; ADE retirement |
| Move a virtual machine to another resource group, subscription, or region | [Lab 08](../labs/08-virtual-machines.md) T6 | RG move and back; subscription rules; Resource Mover walkthrough for region moves |
| Manage virtual machine sizes | [Lab 08](../labs/08-virtual-machines.md) T3 | Live resize, policy-denied size, deallocate to see all sizes |
| Manage virtual machine disks | [Lab 08](../labs/08-virtual-machines.md) T4 | Attach, initialize, expand, change type, incremental snapshot, restore disk, temp disk |
| Deploy virtual machines to availability zones and availability sets | [Lab 08](../labs/08-virtual-machines.md) T1, T5 | Zonal VM in East US; availability set in North Central US (no zones) |
| Deploy and configure an Azure Virtual Machine Scale Sets | [Lab 09](../labs/09-scale-sets-load-balancing-dns.md) T2, T3 | Flexible, zones 1–3, behind a public LB, manual + CPU autoscale, scale-in policy, instance protection |
| Create and manage an Azure Container Registry | [Lab 12](../labs/12-containers-acr-aci-container-apps.md) T1 | Create, import images, repositories/tags, admin user, roles, optional Premium geo-replication |
| Provision a container by using Azure Container Instances | [Lab 12](../labs/12-containers-acr-aci-container-apps.md) T2 | Portal deploy from ACR with DNS label, restart policy, logs, exec |
| Provision a container by using Azure Container Apps | [Lab 12](../labs/12-containers-acr-aci-container-apps.md) T4 | Environment + app from ACR with managed identity and external ingress |
| Manage sizing and scaling for containers, including Azure Container Instances and Azure Container Apps | [Lab 12](../labs/12-containers-acr-aci-container-apps.md) T3, T5, T6 | ACI delete-to-resize; Container Apps HTTP scale rule 0→5, resize revision, traffic split |
| Provision an App Service plan | [Lab 13](../labs/13-app-service.md) T1 | Linux plan, tier comparison, start on Free |
| Configure scaling for an App Service plan | [Lab 13](../labs/13-app-service.md) T3 | Scale up F1 → S1, scale out to 2, session affinity, rules-based autoscale |
| Create an App Service | [Lab 13](../labs/13-app-service.md) T2 | Node.js web app, zip deploy, app settings with slot stickiness |
| Configure certificates and Transport Layer Security (TLS) for an App Service | [Lab 13](../labs/13-app-service.md) T6 | HTTPS only, minimum TLS, client certs, managed vs uploaded vs Key Vault certificates, SNI |
| Map an existing custom DNS name to an App Service | [Lab 13](../labs/13-app-service.md) T7 | CNAME + asuid TXT in Azure DNS, validation, managed certificate binding |
| Configure backup for an App Service | [Lab 13](../labs/13-app-service.md) T8 | Automatic backups, restore to a slot, custom backups to storage, partial backups |
| Configure networking settings for an App Service | [Lab 13](../labs/13-app-service.md) T5 | VNet integration (outbound), access restrictions and private endpoint (inbound) |
| Configure deployment slots for an App Service | [Lab 13](../labs/13-app-service.md) T4 | Staging slot, sticky vs swapped settings, swap with preview, 20% traffic routing |

## Implement and manage virtual networking (15–20%)

| Skill (verbatim from the study guide) | Where | How you practise it |
|---|---|---|
| Create and configure virtual networks and subnets | [Lab 03](../labs/03-iac-bicep-arm-foundation.md) T2, T5 · [Lab 05](../labs/05-vnets-peering-routing.md) T1, T6 | Four VNets from Bicep, add a subnet, address-space changes, private subnets |
| Create and configure virtual network peering | [Lab 03](../labs/03-iac-bicep-arm-foundation.md) T2 · [Lab 05](../labs/05-vnets-peering-routing.md) T1, T2 · [Lab 07](../labs/07-hybrid-site-to-site-vpn.md) T5 | Global hub-spoke peering, sync, non-transitivity, forwarded traffic, gateway transit |
| Configure public IP addresses | [Lab 05](../labs/05-vnets-peering-routing.md) T3 · [Lab 09](../labs/09-scale-sets-load-balancing-dns.md) T1 | Standard zone-redundant IPs for NAT gateway and load balancer; SKU/tier/routing preference |
| Configure user-defined routes | [Lab 05](../labs/05-vnets-peering-routing.md) T4 · [Lab 16](../labs/16-capstone-break-fix-and-teardown.md) INC-102 | Spoke-to-spoke routing through a hub NVA, effective routes, next hop types |
| Troubleshoot network connectivity | [Lab 05](../labs/05-vnets-peering-routing.md) T2, T5, T6 · [Lab 07](../labs/07-hybrid-site-to-site-vpn.md) T4–T7 · [Lab 16](../labs/16-capstone-break-fix-and-teardown.md) | Next hop, IP flow verify, connection troubleshoot, topology, VPN troubleshoot, NAT gateway |
| Create and configure network security groups (NSGs) and application security groups | [Lab 06](../labs/06-secure-access-nsg-bastion-endpoints.md) T2 · [Lab 07](../labs/07-hybrid-site-to-site-vpn.md) T5 · [Lab 09](../labs/09-scale-sets-load-balancing-dns.md) T1 | Least-access rules with an ASG, explicit deny over defaults, on-prem sources |
| Evaluate effective security rules in NSGs | [Lab 06](../labs/06-secure-access-nsg-bastion-endpoints.md) T3 · [Lab 16](../labs/16-capstone-break-fix-and-teardown.md) INC-101 | Effective rules with subnet + NIC NSGs, NSG diagnostics |
| Implement Azure Bastion | [Lab 06](../labs/06-secure-access-nsg-bastion-endpoints.md) T1 | Basic SKU in the hub, SSH to VMs across peering, SKU comparison |
| Configure service endpoints for Azure platform as a service (PaaS) | [Lab 06](../labs/06-secure-access-nsg-bastion-endpoints.md) T4 · [Lab 10](../labs/10-storage-accounts-security-access.md) T7 | Microsoft.Storage on a subnet + VNet rule, 403 vs 200 tests |
| Configure private endpoints for Azure PaaS | [Lab 06](../labs/06-secure-access-nsg-bastion-endpoints.md) T5 · [Lab 13](../labs/13-app-service.md) T5 · [Lab 16](../labs/16-capstone-break-fix-and-teardown.md) INC-103 | Blob private endpoint with private DNS links, public access disabled; App Service private endpoint |
| Configure Azure DNS | [Lab 06](../labs/06-secure-access-nsg-bastion-endpoints.md) T5 · [Lab 07](../labs/07-hybrid-site-to-site-vpn.md) T6 · [Lab 09](../labs/09-scale-sets-load-balancing-dns.md) T6, T7 · [Lab 16](../labs/16-capstone-break-fix-and-teardown.md) INC-108 | Public zone with alias records, private zone with auto-registration, Private Link zones, hybrid resolution |
| Configure an internal or public load balancer | [Lab 09](../labs/09-scale-sets-load-balancing-dns.md) T1, T4 | Public Standard LB for a scale set; internal LB with a static frontend; HA ports |
| Troubleshoot load balancing | [Lab 09](../labs/09-scale-sets-load-balancing-dns.md) T5 · [Lab 16](../labs/16-capstone-break-fix-and-teardown.md) INC-106 | Probe blocked by NSG, wrong probe path/port, hairpin, metrics and insights |

## Monitor and maintain Azure resources (10–15%)

| Skill (verbatim from the study guide) | Where | How you practise it |
|---|---|---|
| Interpret metrics in Azure Monitor | [Lab 14](../labs/14-monitoring-alerts-network-watcher.md) T2 | Aggregations, splitting/filtering, LB probe status, dashboard pins |
| Configure log settings in Azure Monitor | [Lab 14](../labs/14-monitoring-alerts-network-watcher.md) T3 | Activity log + resource diagnostic settings, AMA + data collection rule, VM insights |
| Query and analyze logs in Azure Monitor | [Lab 14](../labs/14-monitoring-alerts-network-watcher.md) T4 | KQL query pack: heartbeats, deletes, policy denials, storage failures; saved queries |
| Set up alert rules, action groups, and alert processing rules in Azure Monitor | [Lab 14](../labs/14-monitoring-alerts-network-watcher.md) T5 · [Lab 15](../labs/15-backup-and-site-recovery.md) T9 | Metric, log search and activity log alerts; action group; suppression and routing processing rules |
| Configure and interpret monitoring of virtual machines, storage accounts, and networks by using Azure Monitor Insights | [Lab 14](../labs/14-monitoring-alerts-network-watcher.md) T6 | VM, Storage, Network, LB and Key Vault insights with interpretation questions |
| Use Azure Network Watcher and Connection monitor | [Lab 05](../labs/05-vnets-peering-routing.md) T5 · [Lab 07](../labs/07-hybrid-site-to-site-vpn.md) T7 · [Lab 14](../labs/14-monitoring-alerts-network-watcher.md) T7 | Diagnostic tools, VPN troubleshoot, continuous Connection monitor, VNet flow logs + Traffic analytics |
| Create a Recovery Services vault | [Lab 15](../labs/15-backup-and-site-recovery.md) T1 | Vault with redundancy set before first backup, soft delete and security settings |
| Create an Azure Backup vault | [Lab 15](../labs/15-backup-and-site-recovery.md) T5 | Backup vault for managed disks with managed-identity roles |
| Create and configure a backup policy | [Lab 15](../labs/15-backup-and-site-recovery.md) T2, T5 | Enhanced VM policy (daily/weekly/monthly), disk policy |
| Perform backup and restore operations by using Azure Backup | [Lab 15](../labs/15-backup-and-site-recovery.md) T3–T5 | Backup now, restore as new VM, disk restore |
| Configure Azure Site Recovery for Azure resources | [Lab 15](../labs/15-backup-and-site-recovery.md) T6, T7 | Policy fix for the DR region, DR VNets, replication West Europe → North Europe |
| Perform a failover to a secondary region by using Site Recovery | [Lab 15](../labs/15-backup-and-site-recovery.md) T8 | Test failover into an isolated VNet, verify, clean up; full failover/commit/re-protect flow |
| Configure and interpret reports and alerts for backups | [Lab 15](../labs/15-backup-and-site-recovery.md) T9 | Vault diagnostics to Log Analytics, Backup reports, Azure Monitor backup alerts routed by a processing rule |

## Beyond the outline (in the HLG scenario, not in the April 2026 skills list)

| Topic | Where | Why it's included |
|---|---|---|
| Microsoft Entra Conditional Access | [Lab 01](../labs/01-identities-and-conditional-access.md) T8 | HLG security brief; needed for the Azure Files Kerberos exclusion; SC-300/AZ-500 overlap |
| Site-to-site VPN, local network gateways, connections | [Lab 07](../labs/07-hybrid-site-to-site-vpn.md) | The hybrid Chicago ↔ Azure scenario. Gateway transit **is** tested under peering. |
| Hybrid DNS for private endpoints (DNS Private Resolver) | [Lab 07](../labs/07-hybrid-site-to-site-vpn.md) T6 | The most common real-world private endpoint failure |
| NAT gateway and default outbound access retirement | [Lab 05](../labs/05-vnets-peering-routing.md) T6 | Changes how new VNets behave from 31 March 2026 |
| Custom RBAC roles | [Lab 04](../labs/04-rbac-access-control.md) T7 | Supports *Interpret access assignments* |
