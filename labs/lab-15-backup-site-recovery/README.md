# Lab 15: Backup and Disaster Recovery: Recovery Services Vault, Backup Vault and Site Recovery

**Status:** Not started
**Dates:** -
**Cost for this lab (from Cost analysis):** -

**Business problem:** Answer the auditors: restore a deleted server fast, and keep EU operations running if West Europe goes down.

Built in my own Azure subscription for a fictional company, Halsted Logistics,
following the AZ-104 Hands-On Lab Guide. This is a personal lab, not
production work for an employer.

## AZ-104 skills practised

- Create a Recovery Services vault
- Create an Azure Backup vault
- Create and configure a backup policy
- Perform backup and restore operations
- Configure Azure Site Recovery
- Perform a failover to a secondary region
- Configure and interpret reports and alerts for backups

## What I built

_Written in my own words after completing the lab._

## Evidence

Every screenshot is redacted (no subscription/tenant IDs, keys, SAS tokens,
public IPs or emails) before it's committed.

| Checkpoint | What it proves | File | Status |
|---|---|---|---|
| 15-01 | Vault redundancy + security settings | `screenshots/15-01-rsv.png` | Pending |
| 15-02 | Backup job sub-tasks + restore points | `screenshots/15-02-vm-backup.png` | Pending |
| 15-03 | Restored VM serving the app | `screenshots/15-03-restore.png` | Pending |
| 15-04 | Missing roles, then validation success | `screenshots/15-04-backup-vault.png` | Pending |
| 15-05 | Policy blocks DR region, then fixed | `screenshots/15-05-policy-dr-region.png` | Pending |
| 15-06 | Replicated item Protected + RPO | `screenshots/15-06-asr-protected.png` | Pending |
| 15-07 | App served from North Europe + cleanup | `screenshots/15-07-test-failover.png` | Pending |
| 15-08 | Backup reports + alert routing | `screenshots/15-08-backup-reports-alerts.png` | Pending |

## What broke and how I fixed it

_Symptom, hypothesis, evidence, fix._

## Knowledge check

- First-try score: __ / 5
- Misses and what I learned:

## Interview talking point

_One or two sentences I could say out loud in an interview._