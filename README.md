# Azure Hybrid Cloud Lab: AZ-104 Portfolio

A multi-region hybrid Azure environment I'm building, securing, breaking and
fixing in my own subscription for a fictional freight company, **Halsted
Logistics**. It follows the AZ-104 (Azure Administrator) skills measured as of
17 April 2026.

> This is a personal lab project, not production work for an employer. A lab is
> marked **Complete** only when its notes and redacted screenshots are committed
> to its folder, so everything here can be checked.

## The environment

- **Chicago HQ (simulated on-premises)**: North Central US, 10.10.0.0/16, connected only by site-to-site VPN
- **Hub**: East US, 10.20.0.0/16, with VPN gateway, Bastion, router NVA and private endpoints
- **EU spoke**: West Europe, 10.30.0.0/16, with app VM, scale set, load balancer and App Service
- **APAC spoke**: Southeast Asia, 10.40.0.0/16, with app VMs and an internal orders API
- **Disaster recovery**: North Europe, as the Site Recovery target for the EU spoke

Identity (Microsoft Entra ID), governance (management groups, Policy, locks,
budgets), storage, compute, monitoring, backup and disaster recovery are all
built on top of this network.

## Progress

| Lab | Topic | Status | Completed |
|---|---|---|---|
| [00](labs/lab-00-setup-tooling-cost-guardrails/) | Setup, Tooling and a Cost Safety Net | Not started | - |
| [01](labs/lab-01-identities-licensing-guests-sspr-ca/) | Staff Identities, Licensing, Guests, SSPR and Conditional Access | Not started | - |
| [02](labs/lab-02-governance-policy-tags-locks-costs/) | Governance: Management Groups, Policy, Tags, Locks and Costs | Not started | - |
| [03](labs/lab-03-iac-bicep-arm/) | Infrastructure as Code: Hybrid Foundation with Bicep and ARM | Not started | - |
| [04](labs/lab-04-rbac-across-scopes/) | Role-Based Access Control Across Scopes | Not started | - |
| [05](labs/lab-05-vnets-peering-udr-troubleshooting/) | Virtual Networks, Peering, Public IPs, UDRs and Troubleshooting | Not started | - |
| [06](labs/lab-06-nsg-asg-bastion-endpoints/) | Secure Access: NSGs, ASGs, Bastion, Service and Private Endpoints | Not started | - |
| [07](labs/lab-07-site-to-site-vpn-hybrid/) | Hybrid Connectivity: Chicago HQ to Azure over Site-to-Site VPN | Not started | - |
| [08](labs/lab-08-virtual-machines/) | Virtual Machines: Create, Encrypt, Resize, Disks, Availability and Moves | Not started | - |
| [09](labs/lab-09-scale-sets-load-balancers-dns/) | Scale Sets, Load Balancers and Azure DNS | Not started | - |
| [10](labs/lab-10-storage-security/) | Storage Accounts: Redundancy, Encryption, Keys, SAS, Firewalls and Azure Files Identity | Not started | - |
| [11](labs/lab-11-blob-files-data-management/) | Blob and Files Data Management: Tiers, Versioning, Lifecycle, Replication, AzCopy | Not started | - |
| [12](labs/lab-12-containers-acr-aci-container-apps/) | Containers: Container Registry, Container Instances and Container Apps | Not started | - |
| [13](labs/lab-13-app-service/) | Azure App Service: Plans, Scaling, Slots, Networking, TLS, Domains and Backup | Not started | - |
| [14](labs/lab-14-monitoring-kql-alerts/) | Monitor and Maintain: Metrics, Logs, KQL, Alerts, Insights and Connection Monitor | Not started | - |
| [15](labs/lab-15-backup-site-recovery/) | Backup and Disaster Recovery: Recovery Services Vault, Backup Vault and Site Recovery | Not started | - |
| [16](labs/lab-16-capstone-break-fix/) | Capstone: Break-Fix Tickets, Teardown and Portfolio | Not started | - |

## Results

- **Labs completed:** 0 / 17
- **Total Azure spend:** -
- **Capstone incidents diagnosed without the answer key:** - / 8
- **Biggest lessons:** _filled in as I go_

## How to review this work

Each lab folder has:
- **README.md**: the business problem, what I built in my own words, what broke
  and how I fixed it, and an interview talking point
- **screenshots/**: redacted evidence for each checkpoint in the evidence table

## Tools used

Azure portal, Azure CLI, Azure PowerShell, Bicep, ARM templates, Microsoft
Entra ID, Microsoft Graph PowerShell, KQL, Git and GitHub.

## Security habits

- No subscription IDs, tenant IDs, keys, SAS tokens, passwords or public IPs
  in commits or screenshots. See [docs/redaction-checklist.md](docs/redaction-checklist.md).
- Every expensive resource (VPN gateways, Bastion, App Service plans) is
  deleted the same day it's built, and spend is tracked against a budget from day one.