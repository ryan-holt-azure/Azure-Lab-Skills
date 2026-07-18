# Lab 19 — Azure Firewall

**Domain:** Networking (15–20%) · **Extension lab** — closes a real gap in the
original 18-lab curriculum, since Azure Firewall (a genuine AZ-104 objective) never
got a dedicated hands-on build. · **Cost:** Firewall bills continuously
(~$1.25/day, Standard SKU) — **deploy, use, delete in the same session**, same
discipline as Bastion in Lab 13.

## Objectives (exam skills covered)

Deploy and configure Azure Firewall

## Why this lab exists

Lab 13 covers NSGs — free, distributed, subnet/NIC-level filtering. Lab 14 covers
UDRs and next-hop types, including `VirtualAppliance`. Neither one builds an
actual centralized firewall appliance. Azure Firewall is explicitly named in
AZ-104's own objectives (4.2.4), and it's the piece that ties Lab 13's filtering
concepts and Lab 14's routing concepts together into one enforcement point —
which is also exactly the pattern a consultancy/MSP uses to standardize egress
control across many customer VNets from a single place.

## Build

1. Create the sandbox and a VNet (or reuse Lab 12/14's if still active):
   ```bash
   az group create -n rg-lab19 -l eastus
   ```
2. Create a **dedicated subnet named exactly `AzureFirewallSubnet`**, minimum
   `/26` — same literal-name requirement pattern as Bastion in Lab 13.
3. Deploy **Azure Firewall (Standard SKU)** into that subnet with a public IP:
   ```bash
   az network firewall create -n fw-lab19 -g rg-lab19 -l eastus --sku AZFW_VNet --tier Standard
   ```
   Note the firewall's **private IP** once deployed — it's the next-hop target.
4. On the **workload subnet** (where a test VM lives), create/associate a route
   table with a UDR:
   - Address prefix: `0.0.0.0/0`
   - Next hop type: **Virtual Appliance**
   - Next hop address: the firewall's private IP

   This is the exact next-hop-type lesson from Lab 14, applied for real — traffic
   doesn't reach the firewall unless something routes it there.
5. Configure a **Network rule collection** — e.g., allow outbound DNS (port 53)
   from the workload subnet to the internet.
6. Configure an **Application rule collection** — allow a specific FQDN (e.g.
   `*.microsoft.com`), and leave everything else unlisted.
7. From a VM in the workload subnet: try to reach the **allowed** FQDN (works),
   then try an **unlisted** one (blocked — Azure Firewall denies by default when
   no rule matches).
8. Enable **diagnostic settings** on the firewall, sending logs to the Log
   Analytics workspace from Lab 16. Query the result:
   ```kql
   AzureDiagnostics
   | where Category == "AzureFirewallApplicationRule"
   ```

## Exam facts

- Azure Firewall requires a subnet named **exactly `AzureFirewallSubnet`**,
  minimum **/26** — same pattern as Bastion's `AzureBastionSubnet`, different
  literal name.
- SKUs: **Basic, Standard, Premium** — Premium adds TLS inspection and
  IDPS (intrusion detection/prevention).
- Rule processing order: **NAT rules, then Network rules, then Application
  rules** — first match wins within its category; if nothing matches, traffic
  is **denied by default**.
- To actually force traffic through the firewall, a **UDR with next hop type
  Virtual Appliance** pointing at the firewall's private IP must be applied to
  the workload subnet — the firewall does nothing on its own without routing
  traffic to it.
- **NSGs vs. Azure Firewall**: NSGs are free, distributed L3/L4 filtering at the
  subnet/NIC level. Azure Firewall is a centralized, stateful, paid PaaS service
  supporting FQDN/application-layer filtering and centralized logging — exam
  scenarios frequently ask which one fits a given requirement.
- Azure Firewall integrates natively with Azure Monitor for centralized logging
  (Network rule log, Application rule log, DNS proxy log).

## Pro / MSP talking point

A single Azure Firewall enforcing egress policy in front of a hub-spoke topology
is exactly how a consultancy standardizes security posture across many customer
environments from one control point, instead of maintaining inconsistent NSG
rules per customer VNet — the same "allow only what's needed" instinct from NSGs,
applied at organizational scale.

## Job posting relevance

Directly named in the HIPAA/Sophos posting: "Administer and maintain firewall
and security appliance environments." The deny-by-default behavior when no
rule matches is the technical enforcement of least privilege at the network
layer — the same "open port" boring-misconfiguration risk from Labs 13/14,
closed by a centralized, logged control point instead of per-VM NSG rules
that are easy to forget or get inconsistent across a growing environment.

## Cleanup

```bash
# delete the firewall FIRST — it bills continuously like Bastion, don't wait on RG propagation
az network firewall delete -n fw-lab19 -g rg-lab19
az group delete -n rg-lab19 --yes --no-wait
```
