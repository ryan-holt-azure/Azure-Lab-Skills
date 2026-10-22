# Lab 09: Scale Sets, Load Balancers and Azure DNS

**Status:** Not started
**Dates:** -
**Cost for this lab (from Cost analysis):** -

**Business problem:** Keep the public tracking site up through demand spikes and datacenter loss, and make internal APIs reachable by name.

Built in my own Azure subscription for a fictional company, Halsted Logistics,
following the AZ-104 Hands-On Lab Guide. This is a personal lab, not
production work for an employer.

## AZ-104 skills practised

- Deploy and configure an Azure Virtual Machine Scale Set
- Configure an internal or public load balancer
- Troubleshoot load balancing
- Configure Azure DNS

## What I built

_Written in my own words after completing the lab._

## Evidence

Every screenshot is redacted (no subscription/tenant IDs, keys, SAS tokens,
public IPs or emails) before it's committed.

| Checkpoint | What it proves | File | Status |
|---|---|---|---|
| 09-01 | Public Standard LB configuration | `screenshots/09-01-public-lb.png` | Pending |
| 09-02 | Requests balanced across scale set instances | `screenshots/09-02-vmss-lb.png` | Pending |
| 09-03 | Autoscale scale-out / scale-in history | `screenshots/09-03-autoscale.png` | Pending |
| 09-04 | Internal LB + hairpin failure | `screenshots/09-04-internal-lb.png` | Pending |
| 09-05 | Health probe failure diagnosed and recovered | `screenshots/09-05-lb-troubleshoot.png` | Pending |
| 09-06 | Public zone alias records + nslookup | `screenshots/09-06-public-dns.png` | Pending |
| 09-07 | Private zone auto-registration + name resolution | `screenshots/09-07-private-dns.png` | Pending |

## What broke and how I fixed it

_Symptom, hypothesis, evidence, fix._

## Knowledge check

- First-try score: __ / 5
- Misses and what I learned:

## Interview talking point

_One or two sentences I could say out loud in an interview._