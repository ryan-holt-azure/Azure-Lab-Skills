# Lab 09: Scale Sets, Load Balancers and Azure DNS

**Status:** Not started · **Date(s):** - · **Time spent:** - · **Cost (Cost analysis):** -

Lab guide: [labs/09-scale-sets-load-balancing-dns.md](../labs/09-scale-sets-load-balancing-dns.md) · Screenshots: `screenshots/lab-09/`

## What I built
<!-- 3-5 bullets in my own words, written after finishing the lab. -->
-

## Evidence
<!-- When a screenshot is committed, replace its path with an embed, e.g.
     ![Checkpoint 09-01: what it proves](../screenshots/lab-09/09-01-name.png)
     and set Status to Done. Redact first: docs/screenshot-guide.md -->
| Checkpoint | What it proves | Screenshot | Status |
|---|---|---|---|
| 09-01 | The LB's frontend, backend pool, probe and rule summary | `screenshots/lab-09/09-01-public-lb.png` | Pending |
| 09-02 | The curl loop showing two different hostnames, plus the backend pool membership | `screenshots/lab-09/09-02-vmss-lb.png` | Pending |
| 09-03 | Autoscale Run history showing scale-out and scale-in events | `screenshots/lab-09/09-03-autoscale.png` | Pending |
| 09-04 | The hub curl loop alternating between `hlg-sea-app01` and `vm-hlg-sea-app02`, plus the hairpin FAILs | `screenshots/lab-09/09-04-internal-lb.png` | Pending |
| 09-05 | Health Probe Status at 0 with IP flow verify showing the deny, then recovered | `screenshots/lab-09/09-05-lb-troubleshoot.png` | Pending |
| 09-06 | The zone's record sets, plus the `nslookup` result | `screenshots/lab-09/09-06-public-dns.png` | Pending |
| 09-07 | Private zone records (auto-registered + `orders-api.sea`), plus the WEU resolve-and-curl output | `screenshots/lab-09/09-07-private-dns.png` | Pending |

## Commands I want to remember
```bash
```

## What broke and how I fixed it
- **Symptom:**
  **Cause:**
  **Fix:**

## Exam tips in my own words
-

## Knowledge check score
- __ / 5 first try. Misses:

## Questions to follow up
-