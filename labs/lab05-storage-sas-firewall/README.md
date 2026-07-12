# Lab 05 — Storage Accounts, Keys, SAS, Firewall

**Domain:** Storage (15–20%) · **Week:** 3 (with networking) · **Cost:** low —
one GPv2 LRS account, delete same session

## Objectives (exam skills covered)

Configure network access to storage accounts · Create and configure storage
accounts · Generate shared access signature · Manage access keys · Implement
Azure storage replication

## Build

1. Create a **GPv2 storage account (LRS)**:
   ```bash
   az group create -n rg-lab05 -l eastus
   az storage account create -n stlab05ryan$RANDOM -g rg-lab05 -l eastus \
     --sku Standard_LRS --kind StorageV2
   ```
2. **Rotate key1** (Storage account → Access keys → Rotate). Note what breaks —
   anything using the old key (mounted shares, apps with the key hardcoded)
   stops authenticating immediately.
3. Create a **container** → **Stored access policy** on it → issue a **service
   SAS bound to that policy**. Test the SAS works, then **revoke it by
   deleting/editing the policy** — confirm the SAS immediately stops working.
4. Reuse the VNet from **Lab 12** (do networking labs first, or come back).
   Enable the **storage firewall**: allow only your VNet (service endpoint) +
   your home IP. Watch portal blob browsing break until the exceptions are
   added, then confirm it works again from an allowed source.

## Exam facts

- A SAS **bound to a stored access policy** is revocable by editing/deleting the
  policy. An **ad-hoc SAS** (not policy-bound) only dies when the account key it
  was signed with is rotated.
- Redundancy copy counts: **LRS** = 3 copies (one datacenter), **ZRS** = 3 copies
  (across zones), **GRS/GZRS** = 6 copies (3 + 3 in the paired region).
- **GRS → ZRS conversion** may require a support-assisted or manual migration
  path — it isn't always a simple toggle.
- "**Trusted Microsoft services**" bypass on the storage firewall is a favorite
  checkbox question — it lets specific first-party Azure services reach the
  account even when public network access is otherwise restricted.

## Pro / interview talking point

Handing out account keys is malpractice — anyone with the key has full control
and there's no way to scope or expire it granularly. A policy-bound SAS is the
professional pattern: same least-privilege instinct as a firewall allow-list, and
it's revocable without rotating the key for everyone else.

## Cleanup

```bash
az group delete -n rg-lab05 --yes --no-wait
```
