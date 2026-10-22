# Lab 03: Infrastructure as Code: Hybrid Foundation with Bicep and ARM

**Status:** Not started
**Dates:** -
**Cost for this lab (from Cost analysis):** -

**Business problem:** Make a 4-region network reproducible from Git instead of hand-built, so it can be rebuilt on demand and reviewed like code.

Built in my own Azure subscription for a fictional company, Halsted Logistics,
following the AZ-104 Hands-On Lab Guide. This is a personal lab, not
production work for an employer.

## AZ-104 skills practised

- Interpret an Azure Resource Manager template or a Bicep file
- Deploy resources by using an ARM template or a Bicep file
- Modify an existing Bicep file
- Modify an existing ARM template
- Export a deployment / convert ARM to Bicep
- Configure resource locks

## What I built

_Written in my own words after completing the lab._

## Evidence

Every screenshot is redacted (no subscription/tenant IDs, keys, SAS tokens,
public IPs or emails) before it's committed.

| Checkpoint | What it proves | File | Status |
|---|---|---|---|
| 03-01 | what-if output + successful subscription deployment | `screenshots/03-01-whatif-deploy.png` | Pending |
| 03-02 | Hub-spoke peerings Connected | `screenshots/03-02-peerings.png` | Pending |
| 03-03 | Run Command result from a VM with no public IP | `screenshots/03-03-run-command.png` | Pending |
| 03-04 | what-if for Bicep change + @allowed compile error | `screenshots/03-04-modify-bicep.png` | Pending |
| 03-05 | ARM output + Premium_LRS validation failure | `screenshots/03-05-modify-arm.png` | Pending |
| 03-06 | Complete-mode what-if showing a delete | `screenshots/03-06-complete-mode.png` | Pending |
| 03-07 | Exported JSON vs decompiled Bicep | `screenshots/03-07-export-decompile.png` | Pending |

## What broke and how I fixed it

_Symptom, hypothesis, evidence, fix._

## Knowledge check

- First-try score: __ / 5
- Misses and what I learned:

## Interview talking point

_One or two sentences I could say out loud in an interview._