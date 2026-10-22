# Lab 05: Virtual Networks, Peering, Public IPs, UDRs and Troubleshooting

**Status:** Not started
**Dates:** -
**Cost for this lab (from Cost analysis):** -

**Business problem:** Let Europe and Asia talk only through the hub, prove every hop, and fix the loss of default outbound internet access.

Built in my own Azure subscription for a fictional company, Halsted Logistics,
following the AZ-104 Hands-On Lab Guide. This is a personal lab, not
production work for an employer.

## AZ-104 skills practised

- Create and configure virtual networks and subnets
- Create and configure virtual network peering
- Configure public IP addresses
- Configure user-defined routes
- Troubleshoot network connectivity

## What I built

_Written in my own words after completing the lab._

## Evidence

Every screenshot is redacted (no subscription/tenant IDs, keys, SAS tokens,
public IPs or emails) before it's committed.

| Checkpoint | What it proves | File | Status |
|---|---|---|---|
| 05-01 | Peering sync after address-space change | `screenshots/05-01-peering-sync.png` | Pending |
| 05-02 | Spoke-to-spoke timeout + effective routes | `screenshots/05-02-non-transitive.png` | Pending |
| 05-03 | Standard zone-redundant public IP | `screenshots/05-03-public-ip.png` | Pending |
| 05-04 | Route table via hub NVA + working cross-spoke traffic | `screenshots/05-04-udr-nva.png` | Pending |
| 05-05 | Next hop + connection troubleshoot failing with IP forwarding off | `screenshots/05-05-network-watcher.png` | Pending |
| 05-06 | Private subnet with no outbound, then NAT gateway IP | `screenshots/05-06-nat-gateway.png` | Pending |

## What broke and how I fixed it

_Symptom, hypothesis, evidence, fix._

## Knowledge check

- First-try score: __ / 5
- Misses and what I learned:

## Interview talking point

_One or two sentences I could say out loud in an interview._