# Lab 12 — VNets and Peering

**Domain:** Networking (15–20%) · **Week:** 3 · **Cost:** low — three small VMs,
short-lived

## Objectives (exam skills covered)

Create and configure virtual networks, including peering · Configure private and
public IP addresses · Implement subnets

## Build

1. Create **two VNets**, non-overlapping address spaces:
   `10.10.0.0/16` and `10.20.0.0/16`, one B1s VM in each.
2. **Peer them** (both directions) → ping across private IPs to confirm
   connectivity.
3. Add a **third VNet** (`10.30.0.0/16`) peered only to the first. Prove:
   - A ↔ B works (direct peering)
   - A ↔ C works (direct peering)
   - **B ↔ C fails** (no direct peering, and peering doesn't transit through A)

## Exam facts

- **Peering is non-transitive** — the B ↔ C failure above is the exam's
  favorite scenario. Fix: hub-spoke topology with an NVA or gateway transit, or
  a full mesh of direct peerings.
- Address spaces **must not overlap** between peered VNets.
- Peering works **cross-region and cross-subscription**.
- Azure **reserves 5 IP addresses per subnet** (not just the usual 2).

## Pro / interview talking point

This lab *is* the hub-spoke design argument, built and observed firsthand
instead of just described — a live example of why real networks need a hub
(or a full mesh) rather than assuming peering chains transitively.

## Cleanup

```bash
az group delete -n rg-lab12 --yes --no-wait
```
Storage account firewall in **Lab 05** and load balancer VMs in **Lab 15** can
reuse this lab's VNets if run in the same session — coordinate cleanup order so
an earlier lab's teardown doesn't break a later one still in progress.
