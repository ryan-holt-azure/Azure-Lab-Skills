# Lab 13 — NSG, ASG, Bastion, Effective Rules

**Domain:** Networking (15–20%) · **Week:** 3 · **Cost:** Bastion bills
**~$4.50/day idle** — deploy, use, delete in the same session

## Objectives (exam skills covered)

Create security rules · Associate an NSG to a subnet or NIC · Evaluate effective
security rules · Deploy and configure Azure Bastion

## Build

1. Create an **NSG on the subnet** and a second **NSG on a NIC**.
2. Create an **ASG** named `asg-web`, put the VM's NIC in it, write a rule
   allowing **443 to the ASG**.
3. Use **Effective security rules** on the NIC to see the merged result of both
   NSGs.
4. Deploy **Bastion**:
   - Subnet must be named exactly **`AzureBastionSubnet`**, **/26 or larger**.
   - Connect to the VM with **no public IP** on the VM itself.
5. **Delete Bastion before logging off** — it bills whether or not it's in use.

## Exam facts

- NSGs are **stateful** — reply traffic is auto-allowed once the initial
  direction is permitted.
- Evaluation order for inbound traffic: **subnet-NSG then NIC-NSG** — both must
  allow the traffic.
- **Priority**: lower number wins. Default rules live at the 65000s.
- **ASGs** group NICs within **one VNet** as a single target for rules.
- Bastion subnet name is literal: `AzureBastionSubnet`, minimum `/26`.

## Pro / interview talking point

Public RDP/SSH is never the right answer in production — Bastion or a VPN,
always. **Effective security rules** is the "why is this blocked" debugger
reached for constantly once NSGs start stacking at subnet and NIC level.

## Cleanup

```bash
# Bastion FIRST — it's the expensive one
az network bastion delete -n <bastionName> -g rg-lab13

az group delete -n rg-lab13 --yes --no-wait
```
