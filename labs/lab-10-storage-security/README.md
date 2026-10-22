# Lab 10: Storage Accounts: Redundancy, Encryption, Keys, SAS, Firewalls and Azure Files Identity

**Status:** Not started
**Dates:** -
**Cost for this lab (from Cost analysis):** -

**Business problem:** Encrypt shipment data with company-owned keys, give partners access that can be revoked instantly, and secure finance files with staff identities.

Built in my own Azure subscription for a fictional company, Halsted Logistics,
following the AZ-104 Hands-On Lab Guide. This is a personal lab, not
production work for an employer.

## AZ-104 skills practised

- Create and configure storage accounts
- Configure Azure Storage redundancy
- Configure storage account encryption
- Manage access keys
- Create and use SAS tokens
- Configure stored access policies
- Configure Azure Storage firewalls and virtual networks
- Configure identity-based access for Azure Files

## What I built

_Written in my own words after completing the lab._

## Evidence

Every screenshot is redacted (no subscription/tenant IDs, keys, SAS tokens,
public IPs or emails) before it's committed.

| Checkpoint | What it proves | File | Status |
|---|---|---|---|
| 10-01 | Account review tab + seeded blobs | `screenshots/10-01-storage-create.png` | Pending |
| 10-02 | RA-GRS secondary region + last sync time | `screenshots/10-02-redundancy.png` | Pending |
| 10-03 | Customer-managed key + encryption scope | `screenshots/10-03-cmk-scope.png` | Pending |
| 10-04 | Key rotation reminder (keys hidden) | `screenshots/10-04-access-keys.png` | Pending |
| 10-05 | Three SAS types tested (no tokens visible) | `screenshots/10-05-sas.png` | Pending |
| 10-06 | Partner access revoked: 403 | `screenshots/10-06-stored-access-policy.png` | Pending |
| 10-07 | VNet + IP rules, 200 vs 403 | `screenshots/10-07-storage-firewall.png` | Pending |
| 10-08 | Entra Kerberos enabled + share-level RBAC | `screenshots/10-08-azure-files-identity.png` | Pending |

## What broke and how I fixed it

_Symptom, hypothesis, evidence, fix._

## Knowledge check

- First-try score: __ / 5
- Misses and what I learned:

## Interview talking point

_One or two sentences I could say out loud in an interview._