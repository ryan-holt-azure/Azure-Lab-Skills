# Lab 15 — Backup and Disaster Recovery: Recovery Services Vault, Backup Vault and Site Recovery

> **Scenario:** HLG's auditors ask two questions. *"If someone deletes the EU app server, how fast can you get it back?"* and *"If West Europe goes down, where does EU Operations run?"* You'll back up the EU app server to a Recovery Services vault, back up the hub workstation's data disk to a Backup vault, replicate the EU server to **North Europe** with Azure Site Recovery, run a **test failover**, and route backup alerts and reports to Operations. Along the way, your own Lab 02 policy blocks the DR region, and you'll fix that properly.
>
> **Time:** ~4 h (much of it is waiting for initial backup and replication) · **Cost:** ~$1–2 (backup storage, a short test-failover VM; Site Recovery is free for the first 31 days per protected VM) · **Prereqs:** Labs 02, 03, 08, 14

## What you'll build

```
West Europe                                          North Europe (DR, paired with West Europe)
vm-hlg-weu-app01 ──backup──► rsv-hlg-weu (LRS)       rsv-hlg-dr-neu (Site Recovery)
        └────────── ASR replication ────────────────► vnet-hlg-dr-neu        (failover network)
                                                      vnet-hlg-dr-neu-test   (isolated test failover)
East US
disk-hlg-wks01-data01 ──backup──► bvault-hlg-eus (Backup vault, LRS)

Reports + alerts: vault diagnostics → law-hlg-eus · Azure Monitor backup alerts → apr-hlg-backup-notify → ag-hlg-ops
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Create a Recovery Services vault | Task 1 |
| Create and configure a backup policy | Tasks 2, 5 |
| Perform backup and restore operations by using Azure Backup | Tasks 3, 4, 5 |
| Create an Azure Backup vault | Task 5 |
| Configure Azure Site Recovery for Azure resources | Tasks 6, 7 |
| Perform a failover to a secondary region by using Site Recovery | Task 8 |
| Configure and interpret reports and alerts for backups | Task 9 |
| Implement and manage Azure Policy | Task 6 (updating an assignment) |

```bash
rc() { az vm run-command invoke -g "$1" -n "$2" --command-id RunShellScript --scripts "$3" --query "value[0].message" -o tsv; }
az vm start -g rg-hlg-spoke-weu -n vm-hlg-weu-app01
```

---

## Task 1 — Recovery Services vault

1. **Create a resource → Recovery Services vault** → RG `rg-hlg-spoke-weu`, name `rsv-hlg-weu`, **West Europe** → Create.
2. **Before protecting anything:** vault → **Properties → Backup configuration → Update** → storage replication type **Locally-redundant (LRS)** → Save. Note that **Cross Region Restore** is only available with **GRS**.
3. **Properties → Security settings:** read **soft delete** (on, 14 days, with an optional *always-on* setting that can't be reversed) and **immutability**. Leave the defaults and **don't** enable always-on, or cleanup will take 14+ days.
4. Look at **Multi-user authorization** (Resource Guard) under Security settings.

> [!TIP]
> **🎯 EXAM TIP — Which vault?**
>
> | **Recovery Services vault** | **Backup vault** |
> |---|---|
> | Azure **VMs** | Azure **Disks** (managed disks) |
> | **SQL Server / SAP HANA in Azure VMs** | Azure **Blobs** (operational + vaulted) |
> | **Azure Files** | Azure Database for **PostgreSQL** |
> | **MARS agent** (on-prem files/folders/system state), **MABS/DPM** | **AKS** (and other newer workloads) |
> | **Azure Site Recovery** | — |
>
> The vault must be in the **same region as the data it backs up**. **Storage redundancy** (LRS/ZRS/GRS) can only be changed **before the first item is protected**.

> 📸 **Checkpoint 15-01** — Backup configuration set to LRS, plus the security settings page. → `screenshots/lab-15/15-01-rsv.png`

---

## Task 2 — VM backup policy (Enhanced)

Vault → **Manage → Backup policies → + Add** → **Azure Virtual Machine** → policy sub-type **Enhanced**:
- Name `pol-hlg-vm-daily`
- Schedule: **Daily** at **21:00** (your time zone). Look at the hourly options (every 4, 6, 8, 12 h) that only Enhanced offers.
- **Instant restore:** keep snapshots **2 days**
- Retention: **daily 7 days**, **weekly** (Sunday) **4 weeks**, **monthly** (first Sunday) **3 months**, yearly off
- Look at the **Azure Backup resource group** setting for snapshot collections. Your Lab 02 policy auto-tags the RG Azure creates.
- Create.

> [!TIP]
> **🎯 EXAM TIP — Standard vs Enhanced VM policies.** **Enhanced** supports **multiple backups per day** (every 4 h+), **instant restore snapshots for 1–30 days**, **zone-redundant snapshot storage**, and newer VM types (**Trusted Launch**, **Premium SSD v2**, **Ultra Disk**). The portal requires Enhanced for Trusted Launch VMs (Standard works for them only via newer CLI/PowerShell/REST). **Once a VM uses Enhanced, it can't go back to Standard.** Restore points live in the **snapshot tier** (fast, instant restore) and then the **vault tier** (long-term).

---

## Task 3 — Back up the EU app server

1. Vault → **Getting started → Backup** → workload **Azure / Virtual machine** → **Backup**.
2. Policy `pol-hlg-vm-daily` → **Add** → `vm-hlg-weu-app01` → **Enable backup**.
3. **Protected items → Backup items → Azure Virtual Machine** → `vm-hlg-weu-app01` → **Backup now** → retain until +7 days.
4. **Monitoring → Backup jobs**: watch the job's sub-tasks: **Take Snapshot** (minutes), then **Transfer data to vault** (longer). The snapshot recovery point is usable once the first sub-task finishes.

> [!TIP]
> **🎯 EXAM TIP — How Azure VM backup works:** a VM **extension** coordinates **snapshots** (app-consistent with VSS on Windows, file-system-consistent with pre/post scripts on Linux, otherwise crash-consistent). No agent install, no VM downtime. **You don't need to stop the VM**, and deallocated VMs can be backed up too.

> 📸 **Checkpoint 15-02** — The backup job with both sub-tasks, plus the restore points list. → `screenshots/lab-15/15-02-vm-backup.png`

---

## Task 4 — Restore as a new VM

1. Create a staging storage account (no firewall) in the VM's region: `az storage account create -g rg-hlg-spoke-weu -n sthlgweurst$RANDOM -l westeurope --sku Standard_LRS`.
2. Backup item → **Restore VM** → choose the latest restore point (note the **consistency type** and **tier**: *Snapshot* / *Snapshot and vault*).
3. Restore type **Create new virtual machine** → name `vm-hlg-weu-restore01` → RG `rg-hlg-spoke-weu` → VNet `vnet-hlg-spoke-weu` / `snet-app` → staging location = the new storage account → **Restore**.
4. When the restore job finishes:
   ```bash
   rc rg-hlg-spoke-weu vm-hlg-weu-restore01 "hostname; hostname -I; curl -s localhost | grep -o 'Site:</b> [^<]*'"
   ```
   The **hostname inside the OS** is still `hlg-weu-app01` (it came from the disk). The **private IP is new**.
5. Read the other restore types (**Restore disks**, **Replace existing**) and **File Recovery**, which mounts a recovery point through a downloaded script so you can copy individual files.
6. Delete `vm-hlg-weu-restore01` and the staging storage account.

> [!TIP]
> **🎯 EXAM TIP — VM restore options:**
> - **Create new VM:** a quick, basic config.
> - **Restore disks:** you get the disks plus a **template** to customize the VM (for example, to add it to an availability set).
> - **Replace existing:** swaps the disks in place; the current disk is kept as a snapshot.
> - **Cross Region Restore:** restore in the **paired region** (GRS vault with CRR enabled).
> - **File Recovery:** individual files without restoring the VM.
>
> A restored VM may **conflict** with the original (same hostname, and the same IP if you choose it), so restore to a different subnet or shut down the original.

> 📸 **Checkpoint 15-03** — The restore job succeeded, plus the Run Command output from the restored VM. → `screenshots/lab-15/15-03-restore.png`

---

## Task 5 — Backup vault for the workstation's data disk

1. **Create a resource → Backup vault** → RG `rg-hlg-mgmt-eus`, name `bvault-hlg-eus`, **East US**, backup storage redundancy **LRS** → Create.
2. Vault → **Backup policies → + Add** → datasource **Azure Disks** → `pol-hlg-disk-daily` → backup **daily**, retention **7 days** (operational tier) → Create.
3. Vault → **+ Backup** → datasource **Azure Disks** → policy `pol-hlg-disk-daily` → **Add** `disk-hlg-wks01-data01` (Lab 08) → **snapshot resource group** `rg-hlg-mgmt-eus` → **Validate**.
4. Validation fails with **role assignment not done**. Select **Assign missing roles**. The vault's managed identity gets **Disk Backup Reader** on the disk and **Disk Snapshot Contributor** on the snapshot RG. Re-validate → **Configure backup**.
5. **Backup instances** → the disk → **Backup now**.
6. **Restore:** **Restore** → pick the recovery point → target RG `rg-hlg-hub-eus` → validate (assign the **Disk Restore Operator** role if prompted) → **Restore**. A new disk appears in `rg-hlg-hub-eus`. Delete it afterwards.

> [!TIP]
> **🎯 EXAM TIP — Backup vault permissions.** Backup vault workloads use the **vault's managed identity**, which needs data-source roles: **Disk Backup Reader** + **Disk Snapshot Contributor** for disks, **Storage Account Backup Contributor** for blobs. "Backup configuration fails validation" in a question almost always means a missing role for the vault identity. Azure Disk Backup stores **incremental snapshots** in your snapshot RG, so restores are fast. It doesn't replace application-consistent VM backup.

> 📸 **Checkpoint 15-04** — Validation showing missing roles, then success. → `screenshots/lab-15/15-04-backup-vault.png`

---

## Task 6 — Get the DR region past your own governance

1. Try to create the DR resource group:
   ```bash
   az group create -n rg-hlg-dr-neu -l northeurope --tags Project=az104-hybrid CostCenter=CC-1001 Environment=lab
   ```
   **RequestDisallowedByPolicy.** Lab 02's *Allowed locations for resource groups* doesn't include North Europe.
2. Fix it properly. Don't exempt, change the standard: **Policy → Assignments** → `HLG - Allowed locations` → **Edit assignment** → **Parameters** → add **North Europe** → Save. Repeat for `HLG - Allowed locations for resource groups`.
3. Wait about 5–10 minutes and re-run step 1 ✅.
4. Pre-create the DR networks with the **same address space** as the source (they're never peered, so overlap is fine):
   ```bash
   for v in vnet-hlg-dr-neu vnet-hlg-dr-neu-test; do
     az network vnet create -g rg-hlg-dr-neu -n $v -l northeurope --address-prefixes 10.30.0.0/16 \
       --subnet-name snet-app --subnet-prefixes 10.30.1.0/24 -o none && echo "created $v"
   done
   ```
5. Create the Site Recovery vault: **Recovery Services vault** → RG `rg-hlg-dr-neu`, name `rsv-hlg-dr-neu`, **North Europe**.

> [!NOTE]
> These VNets were created **after 31 March 2026 with a current API**, so their subnets are **private by default** (Lab 05). A failed-over VM gets no internet until you add a NAT gateway. That doesn't matter for this test, but it's a real DR-runbook item.

> [!TIP]
> **🎯 EXAM TIP — Site Recovery vault location.** For Azure-to-Azure DR, create the vault in a region **other than the source**, typically the **target** region. If the source region goes down, a vault in that region would go down with it. (Backup vaults are the opposite: same region as the data.)

> 📸 **Checkpoint 15-05** — The policy denial, then the edited assignment parameters. → `screenshots/lab-15/15-05-policy-dr-region.png`

---

## Task 7 — Enable replication West Europe → North Europe

`rsv-hlg-dr-neu` → **Site Recovery** → **Azure virtual machines → Enable replication**:

| Step | Setting | Value |
|---|---|---|
| Source | Region / subscription / RG | **West Europe** / yours / `rg-hlg-spoke-weu`; disaster recovery between zones: **No** |
| Virtual machines | Select | `vm-hlg-weu-app01` |
| Replication settings | Target location | **North Europe** |
| | Target RG | `rg-hlg-dr-neu` (customize, don't let it create `-asr`) |
| | Failover virtual network | `vnet-hlg-dr-neu` / `snet-app` |
| | Availability | Single instance |
| | Storage | Cache storage account: auto-created **in the source region** |
| | Replication policy | Default (24-hour recovery point retention, app-consistent snapshot frequency). Read both values. |
| Manage | Extension settings | *Allow Site Recovery to manage* (creates an Automation account to keep the Mobility extension updated) |

**Enable replication**. Then **Replicated items** → status goes **Enabling protection → Initial replication → Protected** (about 30–60 minutes). Note the **RPO** shown on the item.

> [!TIP]
> **🎯 EXAM TIP — ASR building blocks:** the **Mobility service extension** on the source VM, a **cache storage account in the source region** (changes are staged there before going to the target), a **replication policy** (recovery point retention, **app-consistent snapshot frequency**; crash-consistent points are created about every 5 minutes), and **target resources** (RG, VNet, availability set/zone). The source VM needs **outbound** connectivity to Site Recovery endpoints (service tags or URLs). An NSG or UDR that blocks egress breaks replication.

> 📸 **Checkpoint 15-06** — The replicated item showing **Protected** and its RPO. → `screenshots/lab-15/15-06-asr-protected.png`

---

## Task 8 — Test failover, then clean up the test

1. **Replicated items** → `vm-hlg-weu-app01` → **Test failover** → recovery point **Latest processed (low RTO)** → Azure virtual network **`vnet-hlg-dr-neu-test`** → OK.
2. Watch **Site Recovery jobs**. When it's done, a VM named `vm-hlg-weu-app01-test` runs in North Europe:
   ```bash
   rc rg-hlg-dr-neu vm-hlg-weu-app01-test "hostname; curl -s localhost | grep -o 'Site:</b> [^<]*'"
   az vm show -g rg-hlg-dr-neu -n vm-hlg-weu-app01-test --query securityProfile.encryptionAtHost
   ```
   The EU app is serving from North Europe. `encryptionAtHost` is **empty**: Site Recovery doesn't carry it over (Lab 08 note).
3. **Production was never touched.** Replication kept running during the test.
4. **Cleanup test failover** → notes `Test OK – EU app served from NEU` → ✅ *Testing is complete* → OK. The test VM is deleted.
5. Read the real failover flow (don't run it unless you have time): **Failover** → choose a recovery point → (optional) *shut down the source VM first* → **Commit** → **Re-protect** (reverse replication NEU→WEU) → later **Failover** back and **Re-protect** again.
6. Optional: **Recovery plans → + Recovery plan** `rp-hlg-eu` (source WEU, target NEU, add the VM). Note **groups**, **pre/post actions** and **runbooks**, which give you multi-VM ordered failover.

> [!TIP]
> **🎯 EXAM TIP — Failover types:**
> - **Test failover:** non-disruptive, into an **isolated VNet**, replication continues. Always clean up afterwards.
> - **Failover** (planned/unplanned): brings VMs up in the target from a chosen recovery point (**latest**, **latest processed**, **latest app-consistent**, or custom).
> - **Commit:** locks in the chosen recovery point.
> - **Re-protect:** reverses replication direction.
> - **Failback:** fail over again to the original region.
>
> **Site Recovery = disaster recovery (RPO of minutes, RTO via failover). Backup = point-in-time restore (deletions, corruption, ransomware).** Many questions hinge on picking the right one. ASR is also a way to **move VMs to another region** (Lab 08).

> 📸 **Checkpoint 15-07** — The test-failover VM's Run Command output in North Europe, plus the cleanup job. → `screenshots/lab-15/15-07-test-failover.png`

---

## Task 9 — Backup reports and alerts

### 9a. Reports
1. `rsv-hlg-weu` → **Monitoring → Diagnostic settings → + Add** → send to `law-hlg-eus` with destination table **Resource specific**, categories: *Core Azure Backup Data*, *Addon Azure Backup Job Data*, *Addon Azure Backup Alert Data*, *Addon Azure Backup Policy Data*, *Addon Azure Backup Storage Data*, *Addon Azure Backup Protected Instance Data*. Repeat for `bvault-hlg-eus` with its categories.
2. **Business Continuity Center** (the portal's successor to **Backup center**) → **Reports** → select `law-hlg-eus`. Look at **Summary**, **Backup Items**, **Usage**, **Jobs**, **Policies** and **Optimize**. Report data can take up to **24 hours** to appear. Note what each tab answers.
3. Run query **#11** from [`kql/hlg-queries.kql`](../kql/hlg-queries.kql) once data arrives.

### 9b. Alerts
1. Vault → **Properties → Monitoring settings**: ✅ *Use Azure Monitor alerts for job failure scenarios* and ✅ *Use only Azure Monitor alerts* (turns off legacy classic alerts).
2. Built-in backup alerts **fire without an action group**. Route them: **Monitor → Alerts → Alert processing rules → + Create** → scope: `rg-hlg-spoke-weu` **and** `rg-hlg-mgmt-eus` → filter **Monitor service = Azure Backup** → **Apply action group** `ag-hlg-ops` → name `apr-hlg-backup-notify`.
3. You'll trigger a real one at cleanup: **Stop backup with delete data** raises a **security alert** for deletion of backup data. Watch for the email.

> [!TIP]
> **🎯 EXAM TIP — Backup monitoring:**
> - **Backup reports** need vault **diagnostic settings → Log Analytics** (resource-specific tables) and then show history, trends, usage and optimization across vaults and subscriptions.
> - **Backup jobs** and **Backup items** in the portal give the current view.
> - **Azure Monitor–based alerts** for Azure Backup are **built in** for job failures and security events (like deleting backup data). Notifications go through **alert processing rules + action groups**. Classic backup alerts are being retired.

> 📸 **Checkpoint 15-08** — The Backup Reports summary, plus the alert processing rule (and later, the deletion alert email). → `screenshots/lab-15/15-08-backup-reports-alerts.png`

---

## Break-fix challenges

1. Enabling backup for `vm-hlg-sea-app01` from `rsv-hlg-weu` doesn't list the VM. Why?
2. You can't change `rsv-hlg-weu` from LRS to GRS. Why?
3. Replication for a VM stays at *Initial replication 0%*. An NSG on its subnet denies all outbound traffic to the Internet tag. What do you change?

<details><summary>Answers</summary>

1. The vault is in **West Europe** and the VM is in **Southeast Asia**. VM backup requires a vault in the **same region**. Create `rsv-hlg-sea`.
2. Storage redundancy can't be changed after items are protected. Stop protection and delete the data (or use a new vault).
3. Allow outbound to Site Recovery's required endpoints, ideally with **service tags** (`AzureSiteRecovery`, `Storage.<region>`, `AzureActiveDirectory`, `EventHub.<region>`, `GuestAndHybridManagement`), instead of opening all internet egress.
</details>

---

## Knowledge check

1. Which vault type do you need to back up Azure managed disks independently of a VM? And Azure file shares?
2. A company needs VMs restorable to any hour in the last day and kept for 30 days. Which VM policy type?
3. Where do you create the Recovery Services vault for replicating VMs from East US to West US?
4. What does a **test failover** do to production replication?
5. You need an email whenever a backup job fails. Which two things do you configure?

<details><summary>Answers</summary>

1. Disks → **Backup vault**. Azure Files → **Recovery Services vault**.
2. **Enhanced** (multiple backups per day, up to 30 days of instant restore snapshots).
3. In **West US** (the target), or anywhere other than East US.
4. **Nothing.** It's non-disruptive and runs in an isolated network.
5. Azure Monitor–based backup alerts (enabled by default for job failures) **plus** an **alert processing rule** that applies an **action group** with email.
</details>

---

## Clean up (in this order; vaults block resource-group deletion)

1. **Site Recovery:** `rsv-hlg-dr-neu` → **Replicated items** → `vm-hlg-weu-app01` → **Disable replication** (removes replica disks in North Europe). When it's gone, delete the vault, then:
   ```bash
   az group delete -n rg-hlg-dr-neu --yes --no-wait
   ```
   (Delete the ASR cache storage account in `rg-hlg-spoke-weu` and the Site Recovery Automation account if they remain.)
2. **VM backup:** `rsv-hlg-weu` → Backup items → **Stop backup → Delete backup data** (type the VM name). This raises the security alert from Task 9. The item is **soft-deleted for 14 days** (no charge). To delete the vault immediately: Properties → Security settings → **disable soft delete** → *Undelete* the item → *Stop backup → Delete* again → delete the vault.
3. **Disk backup:** `bvault-hlg-eus` → Backup instances → **Stop backup → Delete backup data**. Same soft-delete behavior, then delete the vault.
4. Keep North Europe in the allowed-locations policy, or remove it. Your choice, but document it.
5. `bash scripts/cost-check.sh`

## 📣 Document it

```bash
git add notes/lab-15.md screenshots/lab-15 && git commit -m "Lab 15: RSV + Enhanced VM backup/restore, Backup vault disk backup, ASR WEU->NEU test failover, backup reports + alerts"
```

**LinkedIn post template:**
> Lab 15 of my AZ-104 hybrid build: answering "what if?"
>
> 💾 Recovery Services vault with an Enhanced policy (daily + weekly + monthly), backed up the EU app server and restored it as a new VM. Same OS hostname, new IP.
> 🧩 Backup vault for a managed disk: validation failed until the vault's managed identity got Disk Backup Reader + Disk Snapshot Contributor
> 🌍 Azure Site Recovery West Europe → North Europe, but first my own Allowed-Locations policy blocked the DR region, so I updated the standard instead of exempting it
> 🧪 Test failover into an isolated VNet: the EU app served from North Europe while production replication kept running. Then cleanup.
> 📈 Vault diagnostics → Log Analytics for Backup Reports, plus Azure Monitor backup alerts routed by an alert processing rule
>
> Backup ≠ DR: backup restores a point in time, Site Recovery keeps a warm copy in another region.
> #Azure #AZ104 #AzureBackup #DisasterRecovery #BusinessContinuity #LearningInPublic
