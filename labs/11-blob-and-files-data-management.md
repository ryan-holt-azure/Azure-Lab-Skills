# Lab 11 — Blob and Files Data Management: Tiers, Versioning, Soft Delete, Lifecycle, Replication, AzCopy

> **Scenario:** Shipment manifests pile up at about 10,000 a month. They're hot for 30 days, rarely read after 90, and legally kept for 7 years. APAC wants a read copy in Singapore. Operations keeps overwriting files by mistake and wants an undo button. And the data team moves bulk data with scripts, not by clicking. You'll build all of it on `sthlgops…` and a new Singapore account.
>
> **Time:** ~3 h · **Cost:** < $0.30 · **Prereqs:** Lab 10

## What you'll build

```
sthlgops… (East US)                                    sthlgsea… (Southeast Asia)
 ├─ manifests        versioning · soft delete · tiers   ──object replication──►  manifests-replica (read-only)
 │                   lifecycle: Cool 30d → Cold 90d → Archive 180d → delete 7y
 ├─ partner-drop     metadata + blob index tags
 ├─ azcopy-demo      AzCopy copy / sync / list
 └─ ops-share (Files) snapshots · share soft delete
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Create and configure a container in Azure Blob Storage | Task 1 |
| Configure storage tiers | Task 2 |
| Configure blob versioning | Task 3 |
| Configure soft delete for blobs and containers | Task 4 |
| Configure blob lifecycle management | Task 5 |
| Configure object replication | Task 6 |
| Create and configure a file share in Azure Files | Task 7 |
| Configure snapshots and soft delete for Azure Files | Task 7 |
| Manage data by using Azure Storage Explorer and AzCopy | Tasks 8, 9 |

```bash
OPS=$(az storage account list -g rg-hlg-data-eus --query "[?starts_with(name,'sthlgops')].name | [0]" -o tsv); echo $OPS
```

---

## Task 1 — Containers, metadata and blob index tags

1. **Containers → + Container** → `partner-drop`. Open **Anonymous access level**: it's greyed out because the account disallows anonymous access (Lab 10, Task 1). Private it is.
2. **Upload** a file → expand **Advanced**: blob type (**Block** / Append / Page), block size, **access tier**, upload to folder, encryption scope, **blob index tags** → add tag `Region` = `EU` → Upload.
3. Open the blob → **Properties** (ETag, last modified, tier) → **Metadata** → add `Partner=Northbridge` → Save.
4. Find blobs by tag across the account:
   ```bash
   az storage blob filter --account-name $OPS --tag-filter "\"Region\"='EU'" --auth-mode login -o table
   ```

> [!TIP]
> **🎯 EXAM TIP — Blob basics:**
> - **Block blobs** hold files and documents (up to ~190 TiB). **Append blobs** are for logs (append only). **Page blobs** hold VHDs/random access (disks).
> - **Container access levels:** *Private*, *Blob* (anonymous read of blobs), *Container* (anonymous read and list). They only apply when the **account allows anonymous access**.
> - **Metadata** is name/value data on a blob but **isn't indexed**. **Blob index tags** are indexed: you can search across containers and use them in lifecycle rules.
> - Container names: 3–63 characters, lowercase letters, numbers and hyphens.

> 📸 **Checkpoint 11-01** — The upload Advanced panel with the index tag, plus the `blob filter` result. → `screenshots/lab-11/11-01-container-tags.png`

---

## Task 2 — Access tiers and rehydration

1. `manifests` → `route-ams-chi.json` → **Change tier** → **Cool** → then **Cold** → then **Archive**. Read the early-deletion warnings each time.
2. Try to **Download** it → error: an archived blob is **offline** and can't be read.
3. **Rehydrate by copy** (recommended), keeping the archived original:
   ```bash
   az storage blob copy start --account-name $OPS --auth-mode login \
     --source-container manifests --source-blob route-ams-chi.json \
     --destination-container manifests --destination-blob route-ams-chi.rehydrated.json \
     --tier Hot --rehydrate-priority High
   az storage blob show --account-name $OPS --auth-mode login -c manifests -n route-ams-chi.rehydrated.json \
     --query "properties.{tier:blobTier, status:archiveStatus, copy:copy.status}"
   ```
   `archiveStatus` shows `rehydrate-pending-to-hot`. **High** priority usually completes within an hour for small blobs. **Standard** can take up to 15 hours.
4. **Configuration → Blob access tier (default)**: the options are Hot, Cool and Cold. There's no Archive.

> [!TIP]
> **🎯 EXAM TIP — Tiers:**
>
> | Tier | Online? | Minimum retention (early-deletion charge) | Use |
> |---|---|---|---|
> | **Hot** | ✅ | — | Frequent access |
> | **Cool** | ✅ | **30 days** | Infrequent, about monthly |
> | **Cold** | ✅ | **90 days** | Rare, still instant |
> | **Archive** | ❌ (rehydrate first) | **180 days** | Retention/compliance |
>
> Archive is set **per blob**, never as the account default, and only on **LRS/GRS/RA-GRS** accounts. Rehydrate either by **changing the tier** or by **copying to an online tier** (Standard up to 15 h, High faster). **Lifecycle policies can't rehydrate.**

> 📸 **Checkpoint 11-02** — The tier dropdown, the archived-blob error, and `archiveStatus` pending. → `screenshots/lab-11/11-02-tiers.png`

---

## Task 3 — Blob versioning

1. **Data management → Data protection** → ✅ **Enable versioning for blobs** → *Keep all versions* (note the *Delete versions after N days* option) → Save.
2. Overwrite a blob twice:
   ```bash
   for v in 2 3; do echo "{\"route\":\"chi-ams\",\"rev\":$v}" > /tmp/r.json
     az storage blob upload --account-name $OPS --auth-mode login -c manifests -n route-chi-ams.json -f /tmp/r.json --overwrite; done
   ```
3. Portal: `route-chi-ams.json` → **Versions** tab → three versions, the newest marked *current*. Select the **original** → **Make current version**. Download it to confirm.
4. Delete one non-current version.

> [!TIP]
> **🎯 EXAM TIP — Versioning vs snapshots.** **Versioning** creates a version **automatically on every write or delete**. **Snapshots** are **manual** point-in-time copies. Versions are billed for their unique data, so pair versioning with a lifecycle rule that deletes old versions. **Object replication** (Task 6) and **point-in-time restore** need versioning.

> 📸 **Checkpoint 11-03** — The Versions tab with three versions. → `screenshots/lab-11/11-03-versioning.png`

---

## Task 4 — Soft delete for blobs and containers

1. Confirm **Data protection** has **soft delete for blobs** and **for containers** at 7 days (set in Lab 10).
2. **Blob:** delete `route-sin-chi.json` → toggle **Show deleted blobs** → select it → **Undelete**.
3. **Container:** create `temp-delete-me`, upload a file, **delete the container** → Containers list → **Show deleted containers** → **Restore**.

> [!TIP]
> **🎯 EXAM TIP — Data protection features:**
> - **Blob soft delete** (1–365 days) restores deleted blobs, versions and snapshots. With versioning on, a delete makes the current version a previous version, and soft delete keeps previous versions recoverable.
> - **Container soft delete** (1–365 days) restores a whole container with its contents.
> - **Point-in-time restore** rolls block blobs in containers back to a time. It needs versioning, change feed and soft delete.
> - **None** of these protect against **deleting the storage account**. That's what a **CanNotDelete lock** is for (Lab 02).

> 📸 **Checkpoint 11-04** — The *Show deleted blobs* view with the undelete option, plus the restored container. → `screenshots/lab-11/11-04-soft-delete.png`

---

## Task 5 — Lifecycle management

1. **Data management → Lifecycle management** → **Code view** → paste [`storage/lifecycle-policy.json`](../storage/lifecycle-policy.json) → Save.
2. Switch to **List view** and read the rule: filter `manifests/`, block blobs only. Base blobs go to Cool at 30 days, Cold at 90, Archive at 180, and are deleted at 2,555 days (about 7 years). Versions and snapshots are deleted after 90 days.
3. Look at **Enable access tracking**, which you'd need for rules based on *last accessed* rather than *last modified*.

> [!TIP]
> **🎯 EXAM TIP — Lifecycle rules:**
> - Filters: **blob types**, **prefix** (which starts with the **container name**), **blob index tags**.
> - Actions on **base blobs**, **versions** and **snapshots**: `tierToCool`, `tierToCold`, `tierToArchive`, `delete`, `enableAutoTierToHotFromCool`.
> - Conditions: `daysAfterModificationGreaterThan`, `daysAfterCreationGreaterThan`, `daysAfterLastAccessTimeGreaterThan` (needs access tracking), `daysAfterLastTierChangeGreaterThan`.
> - Policies run **about once a day**, and a new or changed policy can take **up to 24 hours** to start acting. Don't expect instant results.

> 📸 **Checkpoint 11-05** — The lifecycle rule in list view. → `screenshots/lab-11/11-05-lifecycle.png`

---

## Task 6 — Object replication to Singapore

1. **Destination account:** `sthlgsea<digits>`, RG `rg-hlg-data-eus`, **Southeast Asia**, Standard **LRS**. In **Data protection**, enable **versioning**. Give yourself **Storage Blob Data Contributor** on it. Create container `manifests-replica`.
2. **Source prerequisites:** `sthlgops…` → Data protection → ✅ **Enable blob change feed** (versioning is already on).
3. `sthlgops…` → **Data management → Object replication** → **Create replication rules**:
   - Destination account `sthlgsea…`
   - Source container `manifests` → destination container `manifests-replica`
   - **Copy over:** *Everything*
   - Save.
4. Upload a new blob to `manifests`, wait a few minutes, then list the destination:
   ```bash
   SEA=$(az storage account list -g rg-hlg-data-eus --query "[?starts_with(name,'sthlgsea')].name | [0]" -o tsv)
   az storage blob list --account-name $SEA -c manifests-replica --auth-mode login --query "[].name" -o tsv
   ```
5. Open a **source** blob → **Properties** → **Object replication** status. `route-ams-chi.json` shows **failed**: archived blobs don't replicate.
6. Try uploading directly to `manifests-replica` → **409**. Destination containers are read-only while the policy exists.

> [!TIP]
> **🎯 EXAM TIP — Object replication requirements:** **versioning on both** accounts, **change feed on the source**, **GPv2 or premium block blob** accounts, **block blobs only**, **no hierarchical namespace**. Replication is **asynchronous**. **Archived blobs and snapshots aren't replicated**, and the destination container is **read-only** while the policy exists. A source can replicate to up to **2** destination accounts, with up to 1,000 rules per policy. Across tenants, *Allow cross-tenant replication* must be enabled.

> [!CAUTION]
> **⚠️ EXAM TRAP — Object replication ≠ GRS.** GRS replicates the **whole account** to the **paired** region, isn't readable unless you choose RA-GRS, and you can't pick the region. Object replication copies **chosen containers** to **any region/account**, readable immediately. "Replicate one container to a specific non-paired region for low-latency reads" → object replication.

> 📸 **Checkpoint 11-06** — The replication rule, plus the destination listing and the 409 on write. → `screenshots/lab-11/11-06-object-replication.png`

---

## Task 7 — Azure Files: share, snapshots and share soft delete

1. **File shares → + File share** → `ops-share`, tier **Hot**, quota **50 GiB**.
2. Browse → **+ Add directory** `dispatch` → **Upload** a few files.
3. **Snapshot:** `ops-share` → **Snapshots** → **+ Add snapshot** → comment `before-cleanup`.
4. Delete one file from `dispatch`. Then **Snapshots** → open `before-cleanup` → browse to the file → **Restore** (overwrite original).
5. **Share soft delete:** create `temp-share` → delete it → File shares list → **Show deleted shares** → **Undelete**.
6. Optional: mount `ops-share` on `vm-hlg-hub-wks01` using the share's **Connect** script (Windows, storage account key). Then open a file's **Properties → Previous Versions** in Windows: those are your share snapshots.

> [!TIP]
> **🎯 EXAM TIP — Azure Files protection:**
> - **Share snapshots** are **read-only, incremental, share-level** copies, up to **200 per share**. Restore individual files or folders from them. Windows shows them as **Previous Versions**.
> - **Soft delete for file shares** (1–365 days) recovers a **deleted share**, not individual deleted files. Files need snapshots or Azure Backup.
> - **Azure Backup for Azure Files** (Lab 15 mentions it) schedules and retains snapshots in a **Recovery Services vault**.
> - Tiers: **Premium** (SSD, FileStorage account) vs Standard **Transaction optimized / Hot / Cool** (GPv2).
> - SMB over **445**, and NFS 4.1 on Premium.

> 📸 **Checkpoint 11-07** — The snapshot list plus the file restore dialog, and *Show deleted shares*. → `screenshots/lab-11/11-07-files-snapshots.png`

---

## Task 8 — Azure Storage Explorer

1. Install **Azure Storage Explorer** on your PC → **Sign in with Azure** (Entra ID) → select your tenant and subscription.
2. Browse `sthlgops…` → **Blob Containers → manifests**. Note that it shows versions and soft-deleted items like the portal does.
3. **Upload folder** → any local folder → watch the **Activities** pane.
4. Right-click a blob → **Change Access Tier** → Cool.
5. Right-click `partner-drop` → **Get Shared Access Signature** → Read/List, 1 hour → copy the URL. Then **Connect** (plug icon) → **Blob container** → **Shared access signature URL** → paste. You're now browsing *as the SAS*, with exactly its permissions.
6. Look at **File Shares → ops-share** too.

> [!TIP]
> **🎯 EXAM TIP — Storage Explorer** manages Blob, Files, Queues and Tables (and ADLS Gen2) from Windows, macOS or Linux. It connects with **Entra ID**, **account name + key**, a **connection string** or a **SAS URL**. Large transfers run on **AzCopy** under the hood. With Entra sign-in you still need **data roles**: Reader alone shows the account, not its data.

> 📸 **Checkpoint 11-08** — Storage Explorer showing both accounts plus the Activities pane. Blur account keys if the panel shows them. → `screenshots/lab-11/11-08-storage-explorer.png`

---

## Task 9 — AzCopy

Cloud Shell has AzCopy. Reuse your Azure CLI sign-in:
```bash
export AZCOPY_AUTO_LOGIN_TYPE=AZCLI            # AzCopy uses your az login token (needs Blob Data roles)
azcopy --version

# make a container, upload a folder, list it
azcopy make "https://$OPS.blob.core.windows.net/azcopy-demo"
azcopy copy "$HOME/manifests" "https://$OPS.blob.core.windows.net/azcopy-demo" --recursive
azcopy list "https://$OPS.blob.core.windows.net/azcopy-demo"

# one-way sync: add a file locally, delete one, then sync (and mirror deletes)
echo '{"route":"chi-dub"}' > ~/manifests/route-chi-dub.json; rm ~/manifests/route-ams-sin.json
azcopy sync "$HOME/manifests" "https://$OPS.blob.core.windows.net/azcopy-demo/manifests" --delete-destination=true

# server-to-server copy East US -> Singapore (no data passes through Cloud Shell)
azcopy make "https://$SEA.blob.core.windows.net/azcopy-s2s"
azcopy copy "https://$OPS.blob.core.windows.net/azcopy-demo/*" "https://$SEA.blob.core.windows.net/azcopy-s2s" --recursive
azcopy jobs list | head
```

**Azure Files with AzCopy** uses a SAS: `ops-share` → **Generate SAS** (or account SAS with *File* service) →
```bash
read -r -p "File share SAS token (?sv=...): " FSAS
azcopy copy "$HOME/manifests" "https://$OPS.file.core.windows.net/ops-share/from-azcopy${FSAS}" --recursive
```

> [!TIP]
> **🎯 EXAM TIP — AzCopy:**
> - Commands: `copy`, `sync` (one-way; `--delete-destination` mirrors deletes), `make`, `list`, `remove`, `jobs list|resume|show`, `login`.
> - Auth for **Blob**: **Entra ID** (`azcopy login`, managed identity, or reuse the Azure CLI token) **or SAS**. Entra auth needs **Storage Blob Data Contributor/Owner**. Owner on the account isn't enough.
> - Auth for **Azure Files**: SAS is the classic answer. Newer AzCopy versions also support Entra ID for Files.
> - **Server-to-server** copies run between storage endpoints, without downloading to the client.
> - Interrupted jobs **resume** with `azcopy jobs resume <id>`.
> - Offline bulk options for huge datasets: **Azure Data Box** or the **Import/Export service**.

> 📸 **Checkpoint 11-09** — The `sync` summary and `jobs list` output (no SAS visible). → `screenshots/lab-11/11-09-azcopy.png`

---

## Break-fix challenges

1. A manifest archived last week must be read **today**. A colleague changes its tier to Hot with **Standard** priority, and it's still unavailable 6 hours later. What should they have done?
2. Object replication shows *failed* for one blob. Everything else replicates. What's special about it?
3. `azcopy copy` returns `403 AuthorizationPermissionMismatch` even though you're the account Owner. Fix it.

<details><summary>Answers</summary>

1. Rehydrate with **High** priority (and ideally by copy, to keep the original archived). Standard can take up to 15 hours.
2. It's in the **Archive** tier (or has a snapshot change, or the destination is read-only). Archived blobs don't replicate.
3. Assign **Storage Blob Data Contributor** (data plane). Owner is control plane only.
</details>

---

## Knowledge check

1. Logs must move to Cool after 30 days, to Archive after 90, and be deleted after 365, automatically. What do you configure?
2. You need accidental **overwrites** of blobs to be recoverable. Soft delete or versioning?
3. Which two prerequisites does object replication add to the source account that the destination doesn't need?
4. A user deletes a file in an Azure file share. Can share soft delete recover it?
5. You must copy 40 TB from on-premises over a slow link within a week. Which tool?

<details><summary>Answers</summary>

1. A **lifecycle management** rule with `tierToCool` 30 days, `tierToArchive` 90 days and `delete` 365 days (since modification).
2. **Versioning**. Soft delete alone covers deletes; versioning captures every overwrite.
3. **Change feed** (both need versioning).
4. **No.** Share soft delete recovers deleted *shares*. Use a **share snapshot** or Azure Backup.
5. **Azure Data Box** (offline transfer).
</details>

---

## Clean up

```bash
az storage container delete --account-name $OPS -n azcopy-demo --auth-mode login
az storage container delete --account-name $SEA -n azcopy-s2s --auth-mode login
```
**Keep:** `manifests`, versioning, lifecycle, object replication and `ops-share`. Lab 15's Backup vault and the Lab 16 capstone use `sthlgops…`. The cost is pennies.

## 📣 Document it

```bash
git add notes/lab-11.md screenshots/lab-11 && git commit -m "Lab 11: tiers + rehydration, versioning, soft delete, lifecycle, object replication to SEA, Files snapshots, Storage Explorer, AzCopy"
```

**LinkedIn post template:**
> Lab 11 of my AZ-104 hybrid build: managing data, not just storing it.
>
> 🧊 Archived a manifest, watched the read fail, rehydrated it by copy with High priority
> 🕰️ Versioning + soft delete as an undo button for overwrites and deletes (and why neither protects the account itself, so add a lock)
> 📅 Lifecycle policy: Cool at 30 days → Cold at 90 → Archive at 180 → delete at 7 years, plus cleanup of old versions
> 🌏 Object replication East US → Singapore: the read-only destination, and why archived blobs don't replicate
> 📁 Azure Files share snapshots (Previous Versions in Windows) vs share soft delete
> 🚚 AzCopy copy/sync/server-to-server using my Azure CLI token, plus Storage Explorer over Entra ID and a SAS URL
>
> #Azure #AZ104 #AzureStorage #AzCopy #LearningInPublic
