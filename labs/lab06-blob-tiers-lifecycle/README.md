# Lab 06 — Blob Tiers, Lifecycle, Versioning

**Domain:** Storage (15–20%) · **Week:** 3 · **Cost:** low — small test blobs only

## Objectives (exam skills covered)

Configure storage tiers for Azure blobs · Configure blob lifecycle management ·
Manage data in Azure Storage

## Build

1. In a container, upload a handful of test blobs.
2. Move one blob **Hot → Cool → Archive**. Attempt to **read the archived
   blob** (it fails — archive is offline) → **rehydrate** it and confirm it
   becomes readable again once rehydration completes.
3. Create a **lifecycle management rule**: move to Cool after 30 days, Archive
   after 90 days, delete after 365 days.
4. Enable **versioning** AND **soft delete** on the account/container.
   Overwrite a blob (creates a new version), delete a blob, then **restore
   from each mechanism** — pull back a prior version, and undelete the
   soft-deleted blob. Take a **snapshot** of a blob and compare it against a
   version: a snapshot is a manual point-in-time copy; a version is created
   automatically on every write.

## Exam facts

- **Archive** tier is offline — no reads until rehydration completes (can take
  hours; Standard vs. High priority rehydration).
- Lifecycle management requires a **GPv2 or Blob storage** account.
- **Versioning** = automatic on every write. **Snapshots** = manual,
  point-in-time. **Soft delete** = a recycle bin with a retention window.
- The **Cold** tier sits between Cool and Archive — it's online (unlike
  Archive) but cheaper than Cool for infrequently accessed data.

## Pro / interview talking point

Tiering is where real storage bills quietly go to die — it's FinOps talking
point #1 in almost any cloud interview. Being able to describe the difference
between versioning, snapshots, and soft delete precisely (not "they're all kind
of backups") signals real hands-on time, not just reading the docs page.

## Cleanup

```bash
az group delete -n rg-lab06 --yes --no-wait
```
