# Lab 18 — Backup and Site Recovery

**Domain:** Monitoring & Backup (10–15%) · **Week:** 4 · **Cost:** one B1s VM +
vault storage — **ASR is free per instance for the first 31 days**, stay inside
that window

## Objectives (exam skills covered)

Create a Recovery Services Vault · Create and configure backup policy · Perform
backup and restore operations · Perform site-to-site recovery with Azure Site
Recovery

## Build

1. Create a **Recovery Services vault** (same region as the VM being
   protected). Set a **daily backup policy**, back up a B1s VM, and trigger an
   **on-demand first backup** rather than waiting for the schedule.
2. **File-level restore**: mount the recovery point, pull one file out without
   restoring the whole VM.
3. **Full restore to a NEW VM** (not restore-in-place).
4. **Azure Site Recovery**: replicate the VM to the paired region, run a
   **TEST failover** into an isolated VNet, verify it boots and is reachable,
   clean up the test failover, then **disable replication the same day** — ASR
   billing starts after the 31-day free window per instance.

## Exam facts

- The vault must be in the **same region** as the protected VMs (the restore
  target can be elsewhere).
- A vault with protected items **cannot be deleted** — stop protection on
  every item first.
- **Restore-replace** needs the VM stopped; **restore-to-new** works anytime.
- **Test failover touches production zero** — it's fully isolated.
- **Recovery Services vault** = classic workloads (VMs, SQL-in-VM, Files).
  **Backup vault** = newer workload types (Blobs, Disks, PostgreSQL).
- ASR is **free per instance for the first 31 days**.

## Pro / interview talking point

"Backups exist" means nothing on its own. "Restore verified on \<date\>" is the
sentence that actually matters — the same standard applied to any backup
system in a real job, not just Azure VMs.

## Cleanup

```bash
# disable ASR replication FIRST (same day it's tested)
# stop protection on the VM in the vault, then:
az group delete -n rg-lab18 --yes --no-wait
```
Confirm the vault has no protected items remaining before attempting to delete
it, or the delete will fail.
