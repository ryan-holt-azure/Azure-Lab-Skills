# Scenario 5 — Data Loss and the Question Nobody Wants to Ask

## Business context

A production VM running a small business's order-processing application
was affected by a bad script during routine maintenance — critical files
were overwritten. Leadership's first question isn't technical.

## What gets reported

**Not this:** "Perform file-level restore from the recovery point."

**This:** A call from the owner: *"We think we lost the order data from
this week. Can we get it back? And — be honest — are we protected against
this happening again, or did we just get lucky that it wasn't worse?"*

## Business consequence if unresolved

This is "backups depend on someone remembering — until data is just gone,"
except now it's happened, and the real cost isn't just this week's data —
it's whether leadership can trust the infrastructure going forward. A
vague "I think we have backups" answer here is almost as damaging as no
backup at all.

## Investigation

1. **Don't promise anything before checking.** Open the Recovery Services
   vault (Lab 18) and confirm: is this VM actually protected, is there a
   recent recovery point, and what's actually in it.
2. Identify the **most recent clean recovery point** — before the bad
   script ran, not just the most recent one available.
3. Decide the restore approach based on what's actually needed: **file-level
   restore** (mount the recovery point, pull the specific overwritten files)
   if only certain files are affected, versus **full restore to a new VM**
   if the damage is broader than a few files.

## Root cause

The proximate cause is a script that ran without a safeguard. The deeper
question — the one leadership is actually asking — is whether this was
survivable *by design* or *by luck*. That answer depends entirely on
whether backup policy, recovery point frequency, and (ideally) a resource
lock were already in place before this happened, not improvised afterward.

## Resolution

1. **File-level restore** (Lab 18): mount the identified recovery point,
   recover the specific overwritten files, verify their contents are
   actually correct — not just that the restore operation reported
   success. "Restore verified on \<date\>" is the standard; "restore
   completed" is not the same claim.
2. If needed, **full restore to a new VM** rather than restore-in-place,
   so the original (possibly still-compromised) VM isn't touched until the
   restored copy is confirmed good.
3. Report back with specifics: what was recovered, what (if anything) is
   genuinely unrecoverable, and the exact recovery point timestamp used —
   not a vague "it's handled."

## Prevention / hardening

This is where the honest answer to "are we protected" actually gets built,
if it wasn't already:

- **Resource lock** (Lab 03, `CanNotDelete` or `ReadOnly`) on production
  VMs and their disks — a bad script or a rushed `az vm delete` shouldn't
  be able to destroy production infrastructure outright, only backup
  restores should recover from that class of mistake, not prevent it from
  happening in the first place at the compute layer.
- **Tighten backup policy frequency** if the gap between recovery points
  was larger than the business can tolerate losing.
- **Require scripts touching production data to run against a snapshot or
  a non-production copy first** — a process fix, since the technical
  controls above don't stop a script from running, they only limit the
  blast radius and guarantee recoverability after the fact.

## Skills drawn from

| Lab | What it contributed |
|---|---|
| Lab 18 (Backup/Site Recovery) | The actual restore, both file-level and full-VM |
| Lab 03 (Resource locks) | The preventive control against future accidental destruction |
| Lab 06 (Blob versioning/soft delete, if data lived in storage too) | The equivalent recovery mechanism for storage-layer data loss |

## Interview framing (problem → action → result)

*"A maintenance script overwrote production order data. I confirmed we had
a clean recovery point from before the incident, performed a file-level
restore, and verified the recovered data's integrity before reporting back
— not just that the restore operation succeeded. I then added resource
locks on production VMs so a future scripting mistake can't delete
infrastructure outright, closing the actual gap the incident exposed."*
