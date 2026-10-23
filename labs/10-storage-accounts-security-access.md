# Lab 10 — Storage Accounts: Redundancy, Encryption, Keys, SAS, Firewalls and Identity-Based Azure Files

> **Scenario:** HLG's operations data (shipment manifests, partner exchanges, finance shares) moves to a new storage account, `sthlgops…`. The CISO wants customer-managed keys, an isolated encryption scope for Finance, rotating access keys, partner access that can be **revoked instantly**, network restrictions, and a Finance file share secured by **Entra identities**, not shared keys.
>
> **Time:** ~3.5 h · **Cost:** < $0.50 (storage, Key Vault operations) · **Prereqs:** Labs 01, 04, 08 (`vm-hlg-hub-wks01`)

## What you'll build

```
sthlgops<digits> (East US, GPv2)       kv-hlg-<digits> (RBAC, purge protection)
 ├─ Redundancy LRS → GRS → RA-GRS → LRS  └─ key cmk-sthlgops  ◄── storage system-assigned identity
 ├─ Encryption: CMK + encryption scope "scope-finance" → container finance-reports
 ├─ Containers: manifests (stored access policy pol-partner-read)
 ├─ Keys: rotated, rotation reminder, key access disabled/re-enabled
 ├─ SAS: account · service · user delegation
 ├─ Firewall: selected networks (your IP + hub snet-shared) → reverted
 └─ File share "finance": Microsoft Entra Kerberos, share-level RBAC for Finance/Auditors
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Create and configure storage accounts | Task 1 |
| Configure Azure Storage redundancy | Task 2 |
| Configure storage account encryption | Task 3 |
| Manage access keys | Task 4 |
| Create and use shared access signature (SAS) tokens | Task 5 |
| Configure stored access policies | Task 6 |
| Configure Azure Storage firewalls and virtual networks | Task 7 |
| Configure identity-based access for Azure Files | Task 8 |

---

## Task 1 — Create the account (read every tab)

**Create a resource → Storage account**:

| Tab | Setting | Value | Exam note |
|---|---|---|---|
| Basics | Name / RG / region | `sthlgops<digits>` / `rg-hlg-data-eus` / East US | 3–24 chars, lowercase letters and digits, globally unique |
| | Performance | **Standard** | **Premium** = *Block blobs*, *File shares* or *Page blobs* account types, LRS/ZRS only |
| | Redundancy | **LRS** (you'll change it in Task 2) | |
| Advanced | Require secure transfer | ✅ | HTTPS only for REST, SMB 3.x encryption for Files |
| | Allow anonymous access on containers | ❌ | Account-level kill switch for public blobs |
| | Enable storage account key access | ✅ (Task 4 turns it off) | |
| | Default to Microsoft Entra authorization in the portal | ✅ | |
| | Minimum TLS version | 1.2 | |
| | Hierarchical namespace | ❌ | ADLS Gen2. **Can't use object replication** (Lab 11) |
| | Access tier | **Hot** | Default for new blobs. Hot/Cool/Cold, never Archive. |
| | Large file shares | ✅ | Shares up to 100 TiB |
| Networking | Public network access | Enable from all networks (Task 7 restricts it) | |
| Data protection | Soft delete for blobs / containers / file shares | ✅ 7 days each | |
| | Versioning, change feed, point-in-time restore | ❌ for now (Lab 11) | |
| Encryption | Encryption type | Microsoft-managed keys (Task 3 switches) | |
| | **Enable support for customer-managed keys** | **All service types (blobs, files, tables, queues)** | **Only settable at creation.** Default covers blobs and files only. |
| | **Enable infrastructure encryption** | ❌ (note it) | Double encryption. **Only at creation.** |

After it's created:
1. **Access control (IAM)** → give yourself **Storage Blob Data Contributor** on this account.
2. Seed some data from Cloud Shell:
   ```bash
   OPS=$(az storage account list -g rg-hlg-data-eus --query "[?starts_with(name,'sthlgops')].name | [0]" -o tsv); echo $OPS
   az storage container create --account-name $OPS -n manifests --auth-mode login
   mkdir -p ~/manifests && for r in chi-ams chi-sin ams-sin sin-chi ams-chi; do
     echo "{\"route\":\"$r\",\"carrier\":\"HLG\",\"pallets\":$RANDOM}" > ~/manifests/route-$r.json; done
   az storage blob upload-batch --account-name $OPS -d manifests -s ~/manifests --auth-mode login
   ```

> [!TIP]
> **🎯 EXAM TIP — Settings you can only choose at creation:** account **name**, **performance** (Standard/Premium), **account kind** (Premium types), **infrastructure encryption**, **CMK support for queues/tables**, and **hierarchical namespace**. HNS can be upgraded once and never reverted. Questions that ask "what must you do first" often expect "create a new account".

> 📸 **Checkpoint 10-01** — The Review tab, plus the five blobs in `manifests`. → `screenshots/lab-10/10-01-storage-create.png`

---

## Task 2 — Redundancy

1. Account → **Data management → Redundancy**. Note the primary location and that there's no secondary.
2. Change to **GRS** → Save. A **secondary location** appears: **West US**, East US's paired region.
3. Change to **RA-GRS** → Save. Account → **Endpoints**: there's now a **`-secondary`** blob endpoint (`<acct>-secondary.blob.core.windows.net`) you can read from. The Redundancy blade shows **Last sync time**.
4. Open the **ZRS** option and look at what it offers: a **conversion** that runs in the background (it can take a long time), not an instant switch. Don't start it.
5. Look at **Prepare for failover** (customer-managed failover) and read the warnings. Don't run it.
6. Set the account back to **LRS** to save cost.

> [!TIP]
> **🎯 EXAM TIP — Redundancy options:**
>
> | Option | Copies | Survives | Secondary readable? |
> |---|---|---|---|
> | **LRS** | 3 in one datacenter | Disk/rack failure | — |
> | **ZRS** | 3 across **zones** in the region | Datacenter (zone) loss | — |
> | **GRS** | LRS + 3 in the **paired region** | Regional disaster (after failover) | No |
> | **RA-GRS** | GRS | Same | **Yes**, `-secondary` endpoint |
> | **GZRS** | ZRS + LRS in paired region | Zone **and** region | No |
> | **RA-GZRS** | GZRS | Same | **Yes** |
>
> **Premium** accounts support **LRS and ZRS only**. The **Archive** tier works only with **LRS, GRS and RA-GRS**, not ZRS/GZRS/RA-GZRS. Geo-replication is **asynchronous**: check **Last sync time** before failing over, because recent writes may be lost.

> 📸 **Checkpoint 10-02** — The Redundancy blade at RA-GRS showing the secondary region and last sync time. → `screenshots/lab-10/10-02-redundancy.png`

---

## Task 3 — Encryption: customer-managed keys and an encryption scope

1. **Key Vault:** create `kv-hlg-<digits>` in `rg-hlg-data-eus`, East US, Standard, soft delete 90 days, **Purge protection: Enable**, access configuration **Azure role-based access control**.
2. Vault → **Access control (IAM)** → give **yourself** **Key Vault Crypto Officer**. As Owner, you still can't create keys without a data-plane role.
3. Vault → **Keys** → **+ Generate** → `cmk-sthlgops`, RSA 3072.
4. Storage account → **Security + networking → Identity** → **System assigned: On**.
5. Vault → IAM → **Key Vault Crypto Service Encryption User** → assign to the **storage account's managed identity**.
6. Storage account → **Encryption** → **Customer-managed keys** → **Select from key vault** → `kv-hlg-…` / `cmk-sthlgops` (don't pin a version, so it auto-updates on rotation) → identity **System-assigned** → Save.
7. **Encryption scopes → + Add** → `scope-finance`, Microsoft-managed keys → Create.
8. Create container `finance-reports` → **Advanced** → encryption scope `scope-finance` → ✅ *Use this encryption scope for all blobs in the container*.

> [!TIP]
> **🎯 EXAM TIP — Storage encryption:**
> - **Always on** with AES-256 and can't be disabled. The only choice is **who manages the key**: Microsoft-managed, **customer-managed** (Key Vault or Managed HSM), or **customer-provided** (per request, Blob only).
> - CMK requirements: the vault needs **soft delete + purge protection**, and the storage account's managed identity needs **wrap/unwrap rights** (*Key Vault Crypto Service Encryption User*). If you disable the key, the data becomes inaccessible until it's re-enabled.
> - **Infrastructure encryption** adds a second encryption layer. Creation-time only.
> - **Encryption scopes** let different containers or blobs in one account use different keys. That's the answer to "one account, separate keys per tenant/department".

> [!CAUTION]
> **⚠️ EXAM TRAP — Key Vault permission models.** With **Azure RBAC** (now the default), Owner/Contributor on the vault **can't** read keys or secrets. You need **Key Vault Crypto Officer / Secrets Officer / Administrator** or the matching *User* roles. With the older **access policies** model, you grant permissions per principal in the vault's *Access policies* blade instead.

> 📸 **Checkpoint 10-03** — The Encryption blade showing CMK with the key URI, plus the scope list. → `screenshots/lab-10/10-03-cmk-scope.png`

---

## Task 4 — Manage access keys

1. **Security + networking → Access keys**. Two keys exist so you can rotate without downtime.
2. **Rotation drill:** switch your apps to **key2** (nothing to switch in this lab) → **Rotate key** on **key1** → move apps back to key1 → rotate **key2**.
3. **Set rotation reminder** → every **90 days**. This creates a key expiration policy, and Azure Advisor/Policy can flag overdue keys.
4. **Disable key-based auth:** **Configuration** → *Allow storage account key access* = **Disabled** → Save. Then:
   - **Storage browser** with *Access key* authentication → fails. With Entra auth → works.
   - Any **account or service SAS** you generate now fails. A **user delegation SAS** still works (Task 5c).
5. Turn key access back **On**. Tasks 5–6 need it.

> [!TIP]
> **🎯 EXAM TIP — Access keys** grant **full** control of the account's data (everything except Entra-only operations). Anyone with `listKeys` (Owner, Contributor, Storage Account Contributor) effectively has data access. Best practice: **Entra ID + RBAC** for apps, keys disabled, keys rotated through Key Vault if you must keep them. Rotating a key **invalidates every SAS signed with it**, which is the emergency revocation for account and service SAS.

> 📸 **Checkpoint 10-04** — Access keys blade showing the rotation reminder (keys hidden). → `screenshots/lab-10/10-04-access-keys.png`

---

## Task 5 — Shared access signatures (three kinds)

> [!IMPORTANT]
> **🔒 DON'T POST THIS.** A SAS URL is a bearer credential. Anything after `?` is a secret. Store it in a shell variable, never in notes, and blur it in screenshots.

### 5a. Account SAS
1. **Security + networking → Shared access signature**: services **Blob**; resource types **Service, Container, Object**; permissions **Read, List**; expiry 2 hours; **HTTPS only**; signing key **key1** → **Generate**.
2. Copy the **SAS token** (starts with `?sv=`):
   ```bash
   read -r -p "Account SAS token (?sv=...): " ACCT_SAS
   curl -s "https://$OPS.blob.core.windows.net/manifests?restype=container&comp=list&${ACCT_SAS#\?}" | grep -o '<Name>[^<]*</Name>'
   ```

### 5b. Service SAS (one blob)
`manifests` → `route-chi-ams.json` → **Generate SAS** → signing method **Account key**, permission **Read**, expiry 1 hour → copy the **Blob SAS URL** → `curl -s "$URL"`.

### 5c. User delegation SAS (signed with your Entra identity)
Portal: same **Generate SAS** dialog → signing method **User delegation key**. Or the CLI:
```bash
END=$(date -u -d '+1 hour' '+%Y-%m-%dT%H:%MZ')
UD_URL=$(az storage blob generate-sas --account-name $OPS -c manifests -n route-chi-sin.json \
  --permissions r --expiry $END --auth-mode login --as-user --full-uri -o tsv)
curl -s "$UD_URL"
```
Decode the parameters in your notes (not the values): `sv`, `ss`, `srt`, `sr`, `sp`, `st`, `se`, `spr`, `sip`, `skoid`/`sktid` (user delegation key), `sig`.

> [!TIP]
> **🎯 EXAM TIP — SAS types:**
>
> | Type | Signed with | Scope | Revoke by |
> |---|---|---|---|
> | **Account SAS** | Account key | One or more **services** (blob, file, queue, table) and service-level operations | Rotating the key |
> | **Service SAS** | Account key | One service's resource (container, blob, share, file, queue, table) | Rotating the key, or a **stored access policy** |
> | **User delegation SAS** | **Entra credentials** (user delegation key) | **Blob/Data Lake** | `revoke-delegation-keys`, or removing the user's RBAC role; **max 7 days** |
>
> Microsoft recommends **user delegation SAS** where possible, because no account key is involved. Always use **HTTPS only**, short expiry, least permissions, and optionally an IP range.

> 📸 **Checkpoint 10-05** — The three `curl` results (no tokens visible), plus the Generate SAS dialog showing *User delegation key*. → `screenshots/lab-10/10-05-sas.png`

---

## Task 6 — Stored access policy for Northbridge Freight (revocable partner access)

1. `manifests` → **Access policy** → **+ Add policy**: identifier **`pol-partner-read`**, permissions **Read + List**, start now, expiry +7 days → **OK** → **Save**.
2. `manifests` → **Shared access tokens** → signing method **Account key** → **Stored access policy: `pol-partner-read`**. Permissions and expiry grey out because they come from the policy. **Generate**.
   ```bash
   read -r -p "Container SAS URL: " PARTNER_URL
   curl -s "${PARTNER_URL%%\?*}?restype=container&comp=list&${PARTNER_URL#*\?}" | grep -c '<Blob>'    # 5
   ```
3. **Revoke:** Access policy → delete `pol-partner-read` (or set its expiry in the past) → Save → wait ~30 s → repeat the curl → **403 AuthenticationFailed**. No key rotation needed, and other SAS tokens keep working.

> [!TIP]
> **🎯 EXAM TIP — Stored access policies:** defined **on a container, file share, queue or table**. Up to **5** per resource. Work only with **service SAS** (not account or user delegation SAS). Changing or deleting the policy **revokes or changes every SAS bound to it** within about 30 seconds. That's the answer to "revoke a partner's SAS without affecting other users".

> 📸 **Checkpoint 10-06** — The access policy list, plus the 403 after revocation. → `screenshots/lab-10/10-06-stored-access-policy.png`

---

## Task 7 — Firewall and virtual networks

1. Start the hub workstation: `az vm start -g rg-hlg-hub-eus -n vm-hlg-hub-wks01`.
2. **Networking → Public network access: Enabled from selected virtual networks and IP addresses**:
   - **Virtual networks → + Add existing** → `vnet-hlg-hub-eus` / `snet-shared`. The portal offers to enable the **Microsoft.Storage service endpoint** on that subnet. Accept.
   - **Firewall → Add your client IP address** ✅
   - **Exceptions:** keep *Allow Azure services on the trusted services list*. Look at *read access to logging/metrics*.
   - **Resource instances:** open the picker (resource type + instance, for things like Synapse, Data Factory or a Logic App identity). Don't add anything.
   - Save.
3. Test (re-run Task 5c first if `$UD_URL` has expired):
   - Your PC: Storage browser → `manifests` → works (your IP is allowed).
   - The workstation (hub `snet-shared`, VNet rule):
     ```bash
     az vm run-command invoke -g rg-hlg-hub-eus -n vm-hlg-hub-wks01 --command-id RunPowerShellScript \
       --scripts "(Invoke-WebRequest -UseBasicParsing '$UD_URL').StatusCode" --query "value[0].message" -o tsv   # 200
     ```
   - Cloud Shell: `curl -s -o /dev/null -w "%{http_code}\n" "$UD_URL"` → **403** (not on the list).
4. **Revert** to *Enabled from all networks*. Lab 11 uses Cloud Shell and AzCopy against this account.

> [!TIP]
> **🎯 EXAM TIP — Storage network rules:**
> - Rule types: **IP rules** (public IPv4 addresses/ranges, no private ranges), **virtual network rules** (subnets with a service endpoint), **resource instance rules**, and **trusted service exceptions**.
> - **IP rules don't work for clients in the same Azure region** as the account. Use VNet rules or private endpoints for those.
> - Network rules and authorization are separate: an allowed network still needs a valid key, SAS or RBAC role.
> - **Disabled** public network access means **private endpoints only**.

> 📸 **Checkpoint 10-07** — The Networking blade with the VNet rule and IP rule, plus 200 vs 403. → `screenshots/lab-10/10-07-storage-firewall.png`

---

## Task 8 — Identity-based access for the Finance file share

### 8a. Core path (everyone does this)
1. **Data storage → File shares → + File share** → `finance`, tier **Transaction optimized**, quota 100 GiB.
2. On the **File shares** blade, select **Identity-based access: Not configured** → read the three sources:

   | Source | Identities | Clients | Infrastructure |
   |---|---|---|---|
   | **Active Directory Domain Services (AD DS)** | On-prem AD users **synced** to Entra | Domain-joined, line of sight to a DC | Storage account **joined to AD** (AzFilesHybrid `Join-AzStorageAccount`) |
   | **Microsoft Entra Domain Services** | Entra users (cloud or synced) | Joined to the managed domain | Entra DS managed domain |
   | **Microsoft Entra Kerberos** | **Hybrid identities, and cloud-only identities (GA May 2026)** | **Entra-joined or hybrid-joined** Windows (Windows 11 / Server 2025 for cloud-only) | No DC needed. Works over the internet. |

3. Choose **Microsoft Entra Kerberos** → **Set up** → ✅ enable → Save.
4. **Admin consent:** **Entra ID → App registrations → All applications** → `[Storage Account] sthlgops….file.core.windows.net` → **API permissions** → **Grant admin consent** (openid, profile, User.Read).
5. **Cloud-only identities:** same app → **Manifest** → add `"kdc_enable_cloud_group_sids"` to the `tags` array → Save. Without it, cloud-only sign-ins fail.
6. **Conditional Access:** Entra Kerberos for Azure Files **doesn't support MFA**. Add this storage app as an **exclusion** to any CA policy that targets **All resources** for the users who'll mount the share. (CA001 targets admins only, so Finance isn't affected. Note it anyway.)
7. **Share-level permissions:** `finance` share → **Access control (IAM)**:
   - **Storage File Data SMB Share Contributor** → `grp-hlg-finance`
   - **Storage File Data SMB Share Reader** → `grp-hlg-auditors`
8. **Default share-level permissions** (Identity-based access page): read the option *Enable permissions for all authenticated users and groups*. Leave it off.
9. **Directory/file level:** after share-level RBAC, **NTFS ACLs** decide access to folders and files. For Entra-only shares, the portal can manage those ACLs for Entra users and groups (**finance** share → browse → *Manage access*, where offered).
10. **Prove the network path** with the storage key (super-user access that bypasses identity, which is why you lock it away):
    ```bash
    az vm run-command invoke -g rg-hlg-hub-eus -n vm-hlg-hub-wks01 --command-id RunPowerShellScript \
      --scripts "Test-NetConnection -ComputerName $OPS.file.core.windows.net -Port 445 | Select ComputerName,TcpTestSucceeded" \
      --query "value[0].message" -o tsv
    ```

### 8b. Stretch: mount as Dana with her Entra identity
Requirements: an **Entra-joined** Windows 11 (24H2+, latest cumulative update) or **Windows Server 2025** client. `vm-hlg-hub-wks01` qualifies thanks to *Login with Microsoft Entra ID* in Lab 08.
1. Enable cloud Kerberos ticket retrieval on the client, then reboot:
   ```bash
   az vm run-command invoke -g rg-hlg-hub-eus -n vm-hlg-hub-wks01 --command-id RunPowerShellScript --scripts \
     "reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters /v CloudKerberosTicketRetrievalEnabled /t REG_DWORD /d 1 /f"
   az vm restart -g rg-hlg-hub-eus -n vm-hlg-hub-wks01
   ```
2. Give Dana **Virtual Machine User Login** on the VM.
3. Sign in to the VM **as Dana with her Entra account**. That takes an RDP path that supports Entra authentication, such as Bastion **Standard/Premium** with the native client, or RDP's *Use a web account to sign in* over a temporary public IP restricted to your IP.
4. In Dana's session: `net use Z: \\<acct>.file.core.windows.net\finance` (no password) → `klist` shows a `cifs/<acct>.file.core.windows.net` ticket → create a file. As Grace, the same mount is read-only.

> [!TIP]
> **🎯 EXAM TIP — Azure Files authorization layers:**
> 1. **Share-level** = Azure RBAC: **SMB Share Reader**, **SMB Share Contributor**, **SMB Share Elevated Contributor** (can also change NTFS ACLs), or a **default share-level permission** for all authenticated identities.
> 2. **Directory/file-level** = **Windows ACLs (NTFS)**.
>
> Both must allow. The **storage account key** bypasses both (super-user), which is why the key is only for admins and break-glass. Only **one** AD source can be enabled per account. SMB uses **TCP 445**: if a client "can't map the drive", check whether the ISP or corporate firewall blocks 445.

> 📸 **Checkpoint 10-08** — The identity-based access page showing Entra Kerberos enabled, plus the share's IAM role assignments. (Stretch: `klist` in Dana's session.) → `screenshots/lab-10/10-08-azure-files-identity.png`

---

## Break-fix challenges

1. A partner's SAS stopped working the moment you rotated **key2**, but another partner's didn't. Explain.
2. The finance team gets *"System error 5: Access is denied"* mapping the share as Entra users. Share-level RBAC looks right. Name two causes.
3. Enabling CMK fails with *"The operation failed because the key vault doesn't have purge protection enabled"*. Fix it without creating a new vault.

<details><summary>Answers</summary>

1. That partner's SAS was **signed with key2**. SAS tokens are bound to the key that signed them. The other partner's SAS was signed with key1 (or was a user delegation SAS).
2. **NTFS ACLs** deny them (share RBAC isn't enough), the **client** isn't Entra-joined or lacks the Kerberos setting, **admin consent** or the **cloud-group tag** is missing, or **Conditional Access MFA** applies to the storage app (error 1327).
3. Enable **purge protection** on the existing vault (it's one-way and can't be turned off afterwards).
</details>

---

## Knowledge check

1. You need users to read a blob for 24 hours, and you must be able to revoke that access without affecting anyone else. What do you create?
2. Which redundancy option lets you read data from the secondary region without a failover, and survives a zone outage in the primary?
3. Your organization forbids storage account keys. How do apps authenticate, and what SAS type remains possible?
4. A VM in East US can't reach a storage account in East US even though you added the VM's public IP to the storage firewall. Why?
5. Finance users must get **Change** on a share, and only the Finance manager may edit NTFS permissions. Which share-level roles?

<details><summary>Answers</summary>

1. A **stored access policy** on the container plus a service SAS that references it (or a short user delegation SAS, revoked by revoking delegation keys, which affects everyone's user delegation SAS).
2. **RA-GZRS.**
3. **Microsoft Entra ID + RBAC** (managed identities). **User delegation SAS** still works.
4. Same-region traffic doesn't use public IPs, so **IP rules don't apply**. Use a VNet rule with a service endpoint, or a private endpoint.
5. **Storage File Data SMB Share Contributor** for Finance users, **SMB Share Elevated Contributor** for the manager.
</details>

---

## Clean up

- Leave `sthlgops…` on **LRS** with public access **from all networks** (Lab 11 needs it).
- Keep the Key Vault. CMK on the account depends on it. **Deleting the key or vault makes the data unreadable**, and with purge protection you can't purge the vault early. That's expected.
- Deallocate the workstation: `az vm deallocate -g rg-hlg-hub-eus -n vm-hlg-hub-wks01`.
- Delete Bastion Standard if you created it for the stretch.

## 📣 Document it

```bash
git add notes/lab-10.md screenshots/lab-10 && git commit -m "Lab 10: storage redundancy, CMK + encryption scopes, key rotation, 3 SAS types, stored access policy, firewall, Entra Kerberos for Azure Files"
```

**LinkedIn post template:**
> Lab 10 of my AZ-104 hybrid build: securing a storage account end to end.
>
> 🔁 Redundancy: LRS → GRS → RA-GRS (secondary endpoint + last sync time), and why Archive tier doesn't work with ZRS/GZRS
> 🔑 Customer-managed key in Key Vault (RBAC + purge protection), plus an encryption scope so Finance's container uses its own key
> ♻️ Access-key rotation drill, rotation reminders, then disabled key access entirely to see what breaks (account/service SAS) and what doesn't (user delegation SAS)
> 🤝 Partner access through a stored access policy, revoked in 30 seconds without rotating a single key
> 🧱 Storage firewall with a VNet rule, and the trap that IP rules don't apply to same-region Azure traffic
> 🗂️ Azure Files with Microsoft Entra Kerberos: share-level RBAC for Finance and Auditors, now GA for cloud-only identities
>
> #Azure #AZ104 #AzureStorage #KeyVault #LearningInPublic
