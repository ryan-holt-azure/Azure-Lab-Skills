# Cost Guide — What Bills, How Much, and How to Stop It

Prices are **approximate US pay-as-you-go list prices** at the time of writing. They vary by region and change. Confirm in the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) before a lab, and trust **Cost analysis** for what you actually spent.

**Rule of thumb:** follow each lab's *Clean up* section the same day and the whole series costs roughly **$40–80**. Leave a VPN gateway pair or Bastion running for a month and that alone costs well over $100.

Run this at the end of every session:
```bash
bash scripts/cost-check.sh     # lists hourly-billed resources + running VMs
bash scripts/stop-all-vms.sh   # deallocates every rg-hlg-* VM
```

## Hourly-billed resources (the ones that hurt when forgotten)

| Resource | Approx. rate | Labs | Kill it with |
|---|---|---|---|
| **VPN gateway** (VpnGw1AZ) ×2 | ~$0.19–0.36/hr **each** (AZ SKU prices were cut in 2025; check the calculator) | 07 | `az network vnet-gateway delete` (Lab 07 Clean up order) |
| **Azure Bastion** Basic | ~$0.19/hr | 06, 10 (stretch) | `az network bastion delete -g rg-hlg-hub-eus -n bas-hlg-hub-eus` + its public IP |
| **DNS Private Resolver** endpoint | roughly $0.25/hr per endpoint | 07 (optional) | Delete the resolver |
| **App Service plan** S1 Linux | ~$0.10/hr per instance | 13 | Scale to F1 (delete slots first) or delete the plan |
| **NAT gateway** | ~$0.045/hr + ~$0.045/GB | 05 | Disassociate, then delete |
| **Standard Load Balancer** | ~$0.025/hr (first 5 rules) + per GB | 09, 16 | Delete the LB |
| **Private endpoint** | ~$0.01/hr + ~$0.01/GB | 06, 13 | Delete the endpoint |
| **Standard public IP** | ~$0.005/hr | 05–09, 13 | Delete when unattached |
| **Linux VM** B1s | ~$0.01/hr each (4–8 in use) | 03–16 | `scripts/stop-all-vms.sh` (deallocate) |
| **Windows VM** B2s/B2ms | ~$0.05–0.10/hr | 08, 10, 11 | Auto-shutdown 19:00 + deallocate |
| **ACR** Basic / Premium | ~$0.17/day / ~$1.67/day (+ same per geo-replica) | 12 | Downgrade to Basic, delete replicas, or delete the registry |
| **Container Instances** | ~$0.04 per vCPU-hour + ~$0.005 per GB-hour | 12 | `az container delete` |
| **Container Apps** (Consumption) | Monthly free grant (vCPU-seconds, GiB-seconds, requests) covers this lab | 12 | Min replicas 0 |
| **Connection monitor** | Per test per month (small) | 14 | Delete the monitor |

## Usage-billed (small, but know them)

| Resource | Approx. | Labs |
|---|---|---|
| Log Analytics ingestion | ~$2.30–2.80/GB after the monthly free allowance. **The 0.5 GB/day cap** keeps this tiny. | 12, 14, 15 |
| Log search alert rules | ~$1–1.50/month per rule at 5-minute frequency | 14 |
| Metric alert rules | ~$0.10/month per monitored time series | 14 |
| Azure Backup | Protected-instance fee (a few $/month per small VM) + backup storage | 15 |
| Azure Site Recovery | ~$25 per protected VM per month, **first 31 days free** per VM | 15 |
| Storage accounts | Cents for lab data volumes. GRS/RA-GRS doubles storage cost. | 03, 06, 10, 11 |
| Global VNet peering | Per GB in each direction | 03–09 |
| Key Vault | ~$0.03 per 10,000 operations | 10 |
| DNS zones | ~$0.50/zone/month | 06, 09 |

## Free in these labs

VNets, subnets, NSGs, ASGs, route tables, peering setup (not traffic), management groups, Azure Policy, RBAC, locks, tags, budgets, Advisor, platform metrics, activity log (90 days), Network Watcher diagnostic tools (IP flow verify, next hop, …), Entra ID P2 **trial** (30 days), Cloud Shell (plus pennies for its storage).

## Guardrails already in place

- **Budgets** (Lab 00, Lab 02) at $50/subscription and $20 on the hub RG, with email + action group.
- **Allowed VM sizes** policy (Lab 02), so nobody can deploy a 64-core VM by accident.
- **Auto-shutdown** on the Windows workstation (Lab 08).
- **Log Analytics daily cap** (Lab 14).
- Expensive components are **separate templates** (`bastion.bicep`, `hybrid-vpn.bicep`) so you can delete and recreate them in minutes.
