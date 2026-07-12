# Lab 07 — Azure Files, Storage Explorer, AzCopy

**Domain:** Storage (15–20%) · **Week:** 3 · **Cost:** low — one small file share
+ a lab VM (deallocate when idle)

## Objectives (exam skills covered)

Create an Azure file share · Create and configure Azure File Sync service ·
Install and use Azure Storage Explorer · Copy data by using AzCopy

## Build

1. Create a **file share** in a storage account. Mount it on a lab VM via
   **SMB (port 445, key auth)**:
   ```
   net use Z: \\<account>.file.core.windows.net\<share> /u:AZURE\<account> <key>
   ```
2. Browse the account (blobs, files, queues, tables) in **Storage Explorer**.
3. **AzCopy**: copy a local folder up (`azcopy copy`), change one file locally,
   then run `azcopy sync` and observe that only the changed file transfers
   (delta-only).

## Exam facts

- `azcopy copy` = **one-way transfer**. `azcopy sync` = **mirror deltas**
  (can delete at the destination if the flag is passed — dangerous without
  understanding it first).
- Identity-based access for Azure Files: **Entra Kerberos / AD DS** options vs.
  the simpler storage-key auth used above.
- **Azure File Sync**: exactly **one cloud endpoint** per sync group, many
  server endpoints allowed. Cloud tiering keeps only hot data local on the
  server.

## Pro / interview talking point

AzCopy sync is the migration workhorse — it's the tool reached for the first
time a clinic (or any) file server moves to the cloud, because it only moves
what changed instead of re-copying everything.

## Cleanup

```bash
az group delete -n rg-lab07 --yes --no-wait
```
Deallocate the mount VM before deleting, or just let the RG delete handle both.
