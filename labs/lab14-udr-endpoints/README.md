# Lab 14 — UDRs, Service Endpoints, Private Endpoints

**Domain:** Networking (15–20%) · **Week:** 3 · **Cost:** low, reuses Lab 05's
storage account and Lab 12's VNet

## Objectives (exam skills covered)

Configure user-defined network routes · Configure endpoints on subnets

## Build

1. Create a **route table** on subnet A: `0.0.0.0/0 → next hop None`. Confirm
   internet access from a VM in that subnet dies. Remove the route.
2. Reuse the **storage account from Lab 05**: add a **service endpoint** from
   subnet A. Note that the storage account's traffic source becomes "VNet"
   instead of a public IP, but the account **keeps its public IP address**.
3. Build a **private endpoint** instead — with the `privatelink.*` DNS zone
   **linked to the VNet**. `nslookup` the storage account's FQDN from the VM:
   confirm it resolves to a **private IP**.

## Exam facts

- Next hop types: **VirtualAppliance, VirtualNetworkGateway, VNet, Internet,
  None**.
- **Service endpoint**: traffic stays on the Azure backbone, the service keeps
  its **public IP**, and the traffic's source identity becomes the VNet.
- **Private endpoint**: the service gets a **private IP inside your subnet**,
  and requires the `privatelink.*` DNS zone linked — **broken DNS is the #1
  private-endpoint failure**, both on the exam and in real enterprise
  deployments.

## Pro / interview talking point

This is likely the single most job-relevant hour in the whole curriculum.
Private-endpoint DNS fluency — knowing exactly why a private endpoint "isn't
working" almost always traces back to a missing or unlinked `privatelink.*`
zone — is what separates senior admins from associates.

## Cleanup

```bash
az group delete -n rg-lab14 --yes --no-wait
```
Remove the route table and private endpoint before deleting Lab 05's storage
account if that lab's RG is still active.
