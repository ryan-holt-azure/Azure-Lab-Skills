# Lab 08 — Virtual Machines: Create, Encrypt, Resize, Disks, Availability and Moves

> **Scenario:** HLG's admins need a Windows admin workstation in the hub, encrypted at the host, joined to Entra ID and shut down every evening. The Chicago web farm needs redundancy in a region that has **no availability zones**. And one server is being re-homed to another resource group. You'll do all of it and learn every VM create-wizard setting the exam asks about.
>
> **Time:** ~3 h · **Cost:** ~$0.50 (Windows B2s for a few hours, two B1s for an hour, disks and snapshots) · **Prereqs:** Labs 02–04 (EncryptionAtHost feature registered in Lab 00)

## What you'll build

```
rg-hlg-hub-eus     vm-hlg-hub-wks01   Windows Server 2025 · B2s→B2ms · zone 1 · Trusted launch
                                       encryption at host · Entra ID login · auto-shutdown 19:00
                                       + disk-hlg-wks01-data01 (32→64 GiB, Standard→Premium SSD)
rg-hlg-onprem-chi  avset-hlg-chi-web  (2 fault domains, 5 update domains)
                   ├─ vm-hlg-chi-web01
                   └─ vm-hlg-chi-web02
Move: vm-hlg-chi-srv01 (+NIC, +disk)  rg-hlg-onprem-chi → rg-hlg-sandbox → back
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Create a virtual machine | Task 1 |
| Configure encryption at host for Azure virtual machines | Tasks 1, 2 |
| Manage virtual machine sizes | Task 3 |
| Manage virtual machine disks | Task 4 |
| Deploy virtual machines to availability zones and availability sets | Tasks 1, 5 |
| Move a virtual machine to another resource group, subscription, or region | Task 6 |

---

## Task 1 — Create the hub admin workstation (every tab matters)

First confirm encryption at host is ready: `az feature show --namespace Microsoft.Compute --name EncryptionAtHost --query properties.state -o tsv` → `Registered`. If not: `az feature register …` (Lab 00), wait, then `az provider register -n Microsoft.Compute`.

**Create a resource → Virtual machine**:

**Basics**
| Field | Value | Exam note |
|---|---|---|
| RG / Name / Region | `rg-hlg-hub-eus` / `vm-hlg-hub-wks01` / East US | |
| Availability options | **Availability zone** → **Zone 1** | Other options: *No infrastructure redundancy*, *Virtual machine scale set*, *Availability set* |
| Security type | **Trusted launch** | Secure Boot + vTPM; needs a Gen2 image |
| Image | **Windows Server 2025 Datacenter: Azure Edition – Gen2** (use non-Azure Edition if it isn't offered for B2s) | |
| Azure Spot | Off | Spot VMs can be evicted at any time. Never for workloads that need an SLA. |
| Size | **Standard_B2s** | Allowed by your Lab 02 policy |
| Admin account | `hlgadmin` + strong password | |
| Inbound ports | **None** | Bastion only |
| Licensing | Leave **Azure Hybrid Benefit** unchecked | AHB = reuse your own Windows Server/SQL licenses with Software Assurance to cut cost |

**Disks**
| Field | Value | Exam note |
|---|---|---|
| OS disk type | Standard SSD (LRS) | |
| Delete with VM | ✅ | |
| Key management | Platform-managed key | |
| **Encryption at host** | ✅ | Greyed out = feature not registered or size unsupported |

**Networking:** VNet `vnet-hlg-hub-eus` · subnet `snet-shared` · **Public IP: None** · NIC NSG: **None** (the subnet NSG applies) · *Delete NIC when VM is deleted* ✅.

**Management**
- **Microsoft Entra ID → Login with Microsoft Entra ID** ✅. This enables a system-assigned identity and **Entra-joins** the VM (Lab 10 uses that).
- **Auto-shutdown** ✅ 19:00, your time zone, notify your email.
- Backup: off (Lab 15).

**Monitoring:** Boot diagnostics = **Enable with managed storage account**.

**Tags:** `Project=az104-hybrid`. CostCenter arrives automatically through the Lab 02 policy.

**Review + create.** While it deploys, give yourself Entra sign-in rights: VM → **Access control (IAM)** → **Virtual Machine Administrator Login** → `labadmin`.

> [!TIP]
> **🎯 EXAM TIP — Things the exam asks about VM creation:**
> - **Trusted launch** is the default security type for Gen2 images. **Confidential VMs** need specific sizes.
> - **Zone** and **availability set** are chosen **at creation**. You can't add an existing VM to a set or move it into a zone in place. You redeploy (or use Resource Mover/ASR for zones).
> - A **Spot** VM's eviction policy is *Deallocate* or *Delete*, and its max price can be capped.
> - **Auto-shutdown** is a DevTest Labs schedule attached to the VM. It deallocates, so compute billing stops.
> - **Entra ID login** needs the AADLogin extension (added by the checkbox) **and** the *Virtual Machine Administrator Login* or *User Login* role.

> 📸 **Checkpoint 08-01** — The Review + create summary showing zone 1, Trusted launch, encryption at host and no public IP. → `screenshots/lab-08/08-01-vm-create.png`

---

## Task 2 — Encryption at host on an existing VM

Check that the size supports it, then enable it on `vm-hlg-weu-app01`:
```bash
az vm list-skus -l westeurope --size Standard_B1s --query "[0].capabilities[?name=='EncryptionAtHostSupported'].value" -o tsv
az vm deallocate -g rg-hlg-spoke-weu -n vm-hlg-weu-app01
az vm update     -g rg-hlg-spoke-weu -n vm-hlg-weu-app01 --set securityProfile.encryptionAtHost=true
az vm start      -g rg-hlg-spoke-weu -n vm-hlg-weu-app01
az vm show -g rg-hlg-spoke-weu -n vm-hlg-weu-app01 --query securityProfile.encryptionAtHost
```
Portal equivalent: VM (deallocated) → **Disks** → **Additional settings** → *Encryption at host* = Yes.

> [!TIP]
> **🎯 EXAM TIP — Disk encryption options:**
> - **SSE with platform-managed keys:** always on, for every managed disk.
> - **SSE with customer-managed keys:** through a **disk encryption set** pointing at Key Vault.
> - **Encryption at host:** also encrypts the **temp disk** and **OS/data disk caches** on the host, end to end. Register the `EncryptionAtHost` feature first, and the **VM must be deallocated** to turn it on.
> - **Azure Disk Encryption (BitLocker/DM-Crypt inside the guest)** is **scheduled for retirement on 15 September 2028**. Microsoft's guidance is to use encryption at host instead. Older exam questions still mention ADE + Key Vault.
> - **Confidential disk encryption:** confidential VM sizes only.

> [!NOTE]
> Azure Site Recovery (Lab 15) can protect VMs with encryption at host, but **failover VMs don't keep the setting**. Re-enable it after failover.

> 📸 **Checkpoint 08-02** — `encryptionAtHost: true` in the output, or the Disks blade. → `screenshots/lab-08/08-02-encryption-at-host.png`

---

## Task 3 — Manage VM sizes

1. `vm-hlg-hub-wks01` (running) → **Size** → select **Standard_B2ms** → **Resize**. The VM **restarts**.
2. On the same blade, try **Standard_D4s_v5** → **denied by policy** (Lab 02's allowed-sizes list).
3. Stop (deallocate) the VM and open **Size** again. The list may be longer: a running VM can only choose sizes available on its current hardware cluster.
4. CLI:
   ```bash
   az vm list-vm-resize-options -g rg-hlg-hub-eus -n vm-hlg-hub-wks01 -o table | head
   az vm resize -g rg-hlg-hub-eus -n vm-hlg-hub-wks01 --size Standard_B2s
   ```

> [!TIP]
> **🎯 EXAM TIP — Resizing:** resizing a running VM **always restarts it**. If the target size isn't on the current cluster, **deallocate first** to see and choose it. VMs in an **availability set** may need **all VMs in the set deallocated** to move to a size family the cluster doesn't host. Size changes are also limited by regional **quota** per family and by **policy**.

> 📸 **Checkpoint 08-03** — The policy denial for D4s_v5. → `screenshots/lab-08/08-03-resize-policy.png`

---

## Task 4 — Manage disks

1. **Attach a new data disk:** `vm-hlg-hub-wks01` → **Disks** → **+ Create and attach a new disk** → LUN 0, name `disk-hlg-wks01-data01`, **Standard SSD**, **32 GiB**, host caching **Read-only** → **Apply**.
2. **Initialize it** without RDP:
   ```bash
   az vm run-command invoke -g rg-hlg-hub-eus -n vm-hlg-hub-wks01 --command-id RunPowerShellScript --scripts \
     "Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -DriveLetter F -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel HLGData -Confirm:\$false; Get-Volume -DriveLetter F" \
     --query "value[0].message" -o tsv
   ```
3. **Expand it to 64 GiB:** Disks → `disk-hlg-wks01-data01` → **Size + performance** → 64 GiB → Save. If the size option is greyed out while the VM runs, deallocate first. Then extend the volume:
   ```bash
   az vm run-command invoke -g rg-hlg-hub-eus -n vm-hlg-hub-wks01 --command-id RunPowerShellScript --scripts \
     "Update-HostStorageCache; Resize-Partition -DriveLetter F -Size (Get-PartitionSupportedSize -DriveLetter F).SizeMax; Get-Volume F" --query "value[0].message" -o tsv
   ```
4. **Change the disk type to Premium SSD:** **Stop** (deallocate) the VM → disk → **Size + performance** → **Premium SSD LRS** → Save → start the VM.
5. **Snapshot and restore:** disk → **Create snapshot** → `snap-hlg-wks01-data01-01`, **Incremental**, Standard HDD storage. Then **Create a resource → Managed disk** → source **Snapshot** → `disk-hlg-wks01-data01-restored`. Attach it as LUN 1 to see it, then detach and delete it.
6. Note the **temporary disk** (`D:` on Windows, `/mnt` on Linux) in File Explorer or `Get-Volume`. Never store data there.

> [!TIP]
> **🎯 EXAM TIP — Disk facts:**
> - Types: **Standard HDD**, **Standard SSD**, **Premium SSD**, **Premium SSD v2**, **Ultra Disk**. v2 and Ultra are **data disks only**, are zonal, and don't support host caching.
> - **Changing disk type** needs the VM **deallocated** (or the disk unattached).
> - Disks can be **expanded, never shrunk**. After expanding, extend the partition in the OS.
> - Host caching: **Read-only** for read-heavy data, **None** for write-heavy or log disks, **Read/Write** only for OS disks or apps that handle it.
> - **Temporary disk** data is lost on **deallocation, redeploy or host maintenance**. A restart keeps it.
> - **Incremental snapshots** store only changes (cheaper) and can be copied across regions.
> - Max data disks depends on **VM size**.

> [!WARNING]
> **💲 COST.** Keep `disk-hlg-wks01-data01` attached: Lab 15 backs it up with a Backup vault. Delete the snapshot and the restored disk now.

> 📸 **Checkpoint 08-04** — The Disks blade showing the 64 GiB Premium SSD data disk, plus `Get-Volume F` output. → `screenshots/lab-08/08-04-disks.png`

---

## Task 5 — Availability set for Chicago (a region with no zones)

1. Open **Create a VM** in **North Central US** and look at **Availability options**: there's **no zone option**, because the region has no availability zones. Cancel.
2. Create the set and two web VMs:
   ```bash
   az vm availability-set create -g rg-hlg-onprem-chi -n avset-hlg-chi-web -l northcentralus \
     --platform-fault-domain-count 2 --platform-update-domain-count 5
   sed 's/__SITE__/Chicago web farm (availability set)/' iac/bicep/cloudinit/web.yaml > /tmp/web-chi.yaml
   for i in 1 2; do
     az vm create -g rg-hlg-onprem-chi -n vm-hlg-chi-web0$i --image Ubuntu2404 --size Standard_B1s \
       --availability-set avset-hlg-chi-web --vnet-name vnet-hlg-onprem-chi --subnet snet-servers \
       --public-ip-address "" --nsg "" --admin-username hlgadmin --admin-password "$HLG_ADMIN_PASSWORD" \
       --custom-data /tmp/web-chi.yaml --os-disk-delete-option Delete --nic-delete-option Delete --no-wait
   done
   ```
3. When both are running: `avset-hlg-chi-web` → **Virtual machines** shows each VM's **fault domain** and **update domain**. They differ.

> [!TIP]
> **🎯 EXAM TIP — Availability set vs zones:**
>
> | | Availability set | Availability zones |
> |---|---|---|
> | Protects against | Rack/power failure (**fault domain**) and planned maintenance (**update domain**) **within one datacenter** | Loss of an entire **datacenter** in the region |
> | VM SLA | **99.95%** (2+ VMs) | **99.99%** (2+ VMs across zones) |
> | Limits | Up to **3 FDs** (region-dependent), up to **20 UDs** (default 5) | Usually 3 zones per region; not every region has them |
> | Rules | VMs join **at creation**, and set and VMs share a **resource group** | Zone chosen at creation; use zone-redundant/zonal Standard public IPs and LBs |
>
> A single VM with **Premium SSD/Ultra** disks gets a **99.9%** SLA. You can't combine an availability set with zones on the same VM.

> 📸 **Checkpoint 08-05** — The availability set's VM list showing different fault/update domains. → `screenshots/lab-08/08-05-availability-set.png`

---

## Task 6 — Move a VM to another resource group (and back)

1. `vm-hlg-chi-srv01` → **Overview** → **Move** → **Move to another resource group** → target `rg-hlg-sandbox`.
2. Review **Resources to move**. Include the VM's **NIC** and **OS disk**. Leave the VNet where it is (a NIC can reference a VNet in another RG).
3. Wait for **validation**, acknowledge that tools and scripts using the old resource IDs must be updated, then **Move**.
4. Check that the VM's **resource ID** changed, the **region** didn't, and it's still running with the same IP: `rc rg-hlg-sandbox vm-hlg-chi-srv01 "hostname -I"` (with the `rc` helper from Lab 05).
5. **Move it back** to `rg-hlg-onprem-chi`. Later labs and scripts expect it there.
6. **Region move (walkthrough only):** VM → **Move → Move to another region** opens **Azure Resource Mover**. Pick a target region, add the VM, and stop at **Validate dependencies**. Note what it adds (NIC, VNet, NSG, public IP), then discard.

> [!TIP]
> **🎯 EXAM TIP — Moving VMs:**
>
> | Move | Tool | Key rules |
> |---|---|---|
> | Another **resource group** | Portal *Move*, `az resource move`, `Move-AzResource` | Region unchanged, **resource ID changes**, both RGs locked for writes during the move |
> | Another **subscription** | Same tools | **Same Entra tenant**. Target subscription must have the provider registered. Move **dependent resources together** (NIC, disks, and the VNet when VMs share it). |
> | Another **region** | **Azure Resource Mover** or **Azure Site Recovery** (Lab 15) | Creates copies in the target region, then you commit and delete the source |
>
> You can't move a VM that's being replicated by Site Recovery, and some marketplace-plan resources are restricted.

> 📸 **Checkpoint 08-06** — The move validation screen, plus Resource Mover's dependency list. → `screenshots/lab-08/08-06-move.png`

<details><summary>CLI equivalent (resource group move)</summary>

```bash
IDS=$(az resource list -g rg-hlg-onprem-chi --query "[?contains(name,'vm-hlg-chi-srv01')].id" -o tsv)
az resource move --destination-group rg-hlg-sandbox --ids $IDS
```
</details>

---

## Break-fix challenges

1. You try to add `vm-hlg-hub-wks01` to a new availability set from the portal. Where's the option, and why isn't it there?
2. Changing `disk-hlg-wks01-data01` to **Standard HDD** is greyed out. Why?
3. After a restart, an app on `vm-hlg-weu-app01` lost files stored in `/mnt`. Was it the restart?

<details><summary>Answers</summary>

1. There isn't one. Availability sets are assigned **at VM creation**. Recreate the VM in the set (keep the OS disk and attach it to a new VM).
2. The VM is running. Deallocate it first (or detach the disk).
3. Not a plain restart. `/mnt` (temp disk) survives a guest reboot, but is wiped on **deallocation**, **redeploy** or host maintenance. Most likely it was deallocated, which is exactly what Task 2 did when enabling encryption at host.
</details>

---

## Knowledge check

1. You need 99.99% VM availability for a two-VM app in East US. What do you deploy?
2. Which setting encrypts a VM's temp disk and disk caches?
3. A VM must be moved to a different subscription in the same tenant. Name one prerequisite.
4. You attach a 1 TiB data disk to a Linux VM but `df -h` doesn't show it. What's missing?
5. Your Chicago region has no zones. How do you protect two VMs from a single rack failure?

<details><summary>Answers</summary>

1. Two VMs in **different availability zones** (zonal), ideally behind a zone-redundant Standard load balancer.
2. **Encryption at host.**
3. Any of: the target subscription has the **resource providers registered**; you move **dependent resources** (NIC, disks, VNet if shared) together; both subscriptions are in the **same tenant**; you have write permissions on both.
4. Partitioning, formatting and mounting inside the OS (and an `/etc/fstab` entry).
5. An **availability set** with at least 2 fault domains.
</details>

---

## Clean up

```bash
for i in 1 2; do az vm delete -g rg-hlg-onprem-chi -n vm-hlg-chi-web0$i --yes --no-wait; done
# wait until both are gone, then:
az vm availability-set delete -g rg-hlg-onprem-chi -n avset-hlg-chi-web
az snapshot delete -g rg-hlg-hub-eus -n snap-hlg-wks01-data01-01
az vm deallocate -g rg-hlg-hub-eus -n vm-hlg-hub-wks01      # auto-shutdown also handles this nightly
```
**Keep:** `vm-hlg-hub-wks01` (deallocated) and its data disk for Labs 10, 11 and 15.

## 📣 Document it

```bash
git add notes/lab-08.md screenshots/lab-08 && git commit -m "Lab 08: VM create deep-dive, encryption at host, resize vs policy, disks, availability set, RG move"
```

**LinkedIn post template:**
> Lab 08 of my AZ-104 hybrid build: virtual machines, done properly.
>
> 🖥️ Windows Server 2025 admin workstation: zone 1, Trusted launch, encryption at host, Entra ID login, no public IP, nightly auto-shutdown
> 🔐 Enabled encryption at host on an existing Linux VM (it has to be deallocated). Also learned Azure Disk Encryption retires in Sept 2028.
> 📏 Resized live (restart), then watched Azure Policy block an oversized SKU
> 💽 Data disk: attach → initialize with Run Command → expand online → convert to Premium SSD → incremental snapshot → restore
> 🏢 "Chicago" region has no availability zones, so I used an availability set with 2 fault domains and 5 update domains
> 🚚 Moved a VM between resource groups: same region, same IP, new resource ID
>
> #Azure #AZ104 #AzureVM #CloudInfrastructure #LearningInPublic
