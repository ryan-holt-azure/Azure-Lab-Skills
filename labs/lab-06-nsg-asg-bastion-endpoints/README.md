# Lab 06: Secure Access: NSGs, ASGs, Bastion, Service and Private Endpoints

**Status:** Not started
**Dates:** -
**Cost for this lab (from Cost analysis):** -

**Business problem:** Remove public IPs from every VM, give admins secure access, and take shared data off the public internet.

Built in my own Azure subscription for a fictional company, Halsted Logistics,
following the AZ-104 Hands-On Lab Guide. This is a personal lab, not
production work for an employer.

## AZ-104 skills practised

- Implement Azure Bastion
- Create and configure NSGs and application security groups
- Evaluate effective security rules in NSGs
- Configure service endpoints for Azure PaaS
- Configure private endpoints for Azure PaaS
- Configure Azure DNS

## What I built

_Written in my own words after completing the lab._

## Evidence

Every screenshot is redacted (no subscription/tenant IDs, keys, SAS tokens,
public IPs or emails) before it's committed.

| Checkpoint | What it proves | File | Status |
|---|---|---|---|
| 06-01 | Bastion SSH to a VM across peering | `screenshots/06-01-bastion-ssh.png` | Pending |
| 06-02 | Least-access NSG rules with ASG + allowed/blocked tests | `screenshots/06-02-nsg-asg-rules.png` | Pending |
| 06-03 | Effective rules with subnet + NIC NSG | `screenshots/06-03-effective-rules.png` | Pending |
| 06-04 | Storage VNet rule: 403 vs 200 | `screenshots/06-04-service-endpoint.png` | Pending |
| 06-05 | Private DNS zone links + name resolving to private IP | `screenshots/06-05-private-endpoint.png` | Pending |

## What broke and how I fixed it

_Symptom, hypothesis, evidence, fix._

## Knowledge check

- First-try score: __ / 5
- Misses and what I learned:

## Interview talking point

_One or two sentences I could say out loud in an interview._