# Lab 16 — Capstone: Break-Fix Tickets, Exam Readiness, Teardown and Portfolio

> **Scenario:** It's Monday at HLG. Eight tickets landed overnight after a "minor change window". You're on call. Each ticket gives only the **symptom** a user would report. Find the root cause with the tools you've learned, fix it with the least privilege and least blast radius, and write it up the way you would for a real incident. Then you'll tear the whole environment down and publish the project.
>
> **Time:** ~3 h (tickets) + 1 h (teardown and portfolio) · **Cost:** whatever is still running · **Prereqs:** as many of Labs 03–15 as you completed. The fault script skips anything that doesn't exist.

## Skills measured covered

This lab revisits skills from every domain rather than introducing new ones: **Troubleshoot network connectivity**, **Evaluate effective security rules in NSGs**, **Configure user-defined routes**, **Configure private endpoints for Azure PaaS**, **Configure Azure DNS**, **Configure resource locks**, **Interpret access assignments**, **Configure Azure Storage firewalls and virtual networks**, **Troubleshoot load balancing**.

---

## Part A — Inject the faults

```bash
cd ~/clouddrive/az104-hybrid-labs
bash scripts/start-all-vms.sh && sleep 120
az vmss scale -g rg-hlg-spoke-weu -n vmss-hlg-weu-web --new-capacity 2 2>/dev/null   # if you scaled it to 0 in Lab 09
bash scripts/capstone-break.sh
```
The script prints the ticket IDs it opened. Work only those tickets. **Don't open the answer key until you've written your diagnosis** in `notes/lab-16.md` using the incident template at the bottom of this lab.

```bash
rc() { az vm run-command invoke -g "$1" -n "$2" --command-id RunShellScript --scripts "$3" --query "value[0].message" -o tsv; }
```

> [!TIP]
> **Method.** For every ticket: **(1) reproduce** (Run Command / curl / portal as the user), **(2) narrow the layer**: DNS → route → NSG → service/app → identity/RBAC → governance (locks/policy), **(3) prove it** with a tool, **(4) fix the smallest thing**, **(5) re-test**, **(6) write it up**. Several faults can stack on the same path, so re-test after every fix.

---

## Part B — The tickets

### INC-101 · Singapore can't reach the EU tracker
> *"Since this morning, APAC staff can't load http://10.30.1.4 from vm-hlg-sea-app01. The hub team says nothing changed in the hub, and the subnet NSG rules look the same as last week."*

### INC-102 · Amsterdam and Singapore can't talk at all
> *"EU and APAC servers can't reach each other in either direction. Both can still reach the hub NVA."*

### INC-103 · 403 reading shared manifests, Singapore only
> *"vm-hlg-sea-app01 gets HTTP 403 reading manifests from the shared data account (sthlgdata…) with a valid SAS. The same SAS works from vm-hlg-weu-app01."*

### INC-104 · Nobody can restart the APAC server
> *"Wei Ling can't restart vm-hlg-sea-app01. We tried as the subscription Owner, and that fails too."*

### INC-105 · Data team's AzCopy jobs fail
> *"Every AzCopy job against sthlgops… fails with 403 'This request is not authorized to perform this operation.' The SAS tokens are new and valid, and our RBAC roles haven't changed."*

### INC-106 · Public tracker site times out
> *"http://<lbe-hlg-weu-web IP> times out. The scale set instances are running, and `curl localhost` on each one returns the page."*

### INC-107 · Wei Ling's Restart button is greyed out
> *"Wei Ling can see vm-hlg-sea-app01 in the portal, but Start/Restart/Stop are greyed out. She could do this last week."*

### INC-108 · Orders API name times out from Amsterdam
> *"The EU batch job calling http://orders-api.sea.halsted.internal times out. Calling http://10.40.1.100 directly works."*

> [!CAUTION]
> **Real-world trap built into this capstone:** a "change freeze" lock (one of the tickets) also **blocks your fixes** for other tickets in the same resource group. Notice which tickets need it lifted first, and in a real org, who has to approve that.

---

## Part C — Answer key (only after you've tried)

<details><summary>INC-101 — NIC-level NSG</summary>

- **Root cause:** a new NSG `nsg-nic-weu-app01` is associated with the **NIC** of `vm-hlg-weu-app01`. It has a rule misleadingly named `Allow-Partner-Range` that **denies** TCP 80 from `10.40.0.0/16`. The subnet NSG still allows it, but **both must allow**.
- **Prove it:** VM → NIC → **Effective security rules** (two NSGs listed), or Network Watcher **IP flow verify** inbound TCP 80 from 10.40.1.4 → *Deny, nsg-nic-weu-app01/Allow-Partner-Range*.
- **Fix:**
  ```bash
  az network nic update -g rg-hlg-spoke-weu -n nic-vm-hlg-weu-app01 --remove networkSecurityGroup
  az network nsg delete -g rg-hlg-spoke-weu -n nsg-nic-weu-app01
  ```
- **Objectives:** Evaluate effective security rules in NSGs · Troubleshoot network connectivity. Lesson: **rule names lie, rule actions don't.**
</details>

<details><summary>INC-102 — Wrong UDR next hop</summary>

- **Root cause:** `rt-hlg-sea-app` / `to-weu-via-nva` points at **10.20.4.5**, which doesn't exist. The NVA is 10.20.4.4. SEA → WEU packets die, and WEU → SEA replies die too because SEA returns traffic through the same route.
- **Prove it:** Network Watcher **Next hop** from `vm-hlg-sea-app01` to 10.30.1.4 → *VirtualAppliance 10.20.4.5*. **Connection troubleshoot** fails at the first hop.
- **Fix** (after INC-104's lock is removed, since this route table is in `rg-hlg-spoke-sea`):
  ```bash
  az network route-table route update -g rg-hlg-spoke-sea --route-table-name rt-hlg-sea-app -n to-weu-via-nva \
    --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.4.4
  ```
- **Objectives:** Configure user-defined routes · Troubleshoot network connectivity.
</details>

<details><summary>INC-103 — Private DNS zone link removed</summary>

- **Root cause:** the `privatelink.blob.core.windows.net` zone lost its link to `vnet-hlg-spoke-sea`. SEA now resolves the account's **public** IP, and public network access is disabled → 403.
- **Prove it:** `rc rg-hlg-spoke-sea vm-hlg-sea-app01 "getent hosts <acct>.blob.core.windows.net"` → public IP (WEU returns 10.20.3.4). Zone → **Virtual network links** → no SEA link.
- **Fix:**
  ```bash
  az network private-dns link vnet create -g rg-hlg-hub-eus -z privatelink.blob.core.windows.net \
    -n link-hlg-spoke-sea -v "$(az network vnet show -g rg-hlg-spoke-sea -n vnet-hlg-spoke-sea --query id -o tsv)" -e false
  ```
- **Objectives:** Configure private endpoints for Azure PaaS · Configure Azure DNS.
</details>

<details><summary>INC-104 — ReadOnly "change freeze" lock</summary>

- **Root cause:** a **ReadOnly** lock `change-freeze` on `rg-hlg-spoke-sea`. Restart is a **POST** action, which ReadOnly blocks for **everyone**, Owners included.
- **Prove it:** the error message mentions `ScopeLocked`. RG → **Locks**. Activity log → *Create management lock*, showing who and when.
- **Fix** (Owner or User Access Administrator only; in real life, after approval):
  ```bash
  az lock delete -g rg-hlg-spoke-sea -n change-freeze
  ```
- **Objectives:** Configure resource locks. Lesson: ReadOnly isn't a "safe" freeze for running workloads. CanNotDelete usually is.
</details>

<details><summary>INC-105 — Storage firewall default action flipped to Deny</summary>

- **Root cause:** `sthlgops…` network access changed to **Enabled from selected networks** with **no rules**, so every client is refused before authorization is checked.
- **Prove it:** Networking blade. The 403 error code is **AuthorizationFailure** (network), not **AuthenticationFailed** (SAS/key). Storage insights → **Failures** shows the spike. Activity log → *Update storage account*.
- **Fix:**
  ```bash
  az storage account update -g rg-hlg-data-eus -n <sthlgops…> --default-action Allow
  ```
  (Or, better, add the data team's IPs/VNets as rules and keep Deny.)
- **Objectives:** Configure Azure Storage firewalls and virtual networks.
</details>

<details><summary>INC-106 — Health probe on the wrong port</summary>

- **Root cause:** `hp-http-80` now probes **port 8080**. Nothing listens there, so all instances are unhealthy and the LB sends no new flows.
- **Prove it:** LB **Metrics → Health Probe Status** = 0 while **Data Path Availability** is up. **Health probes** blade shows port 8080.
- **Fix:**
  ```bash
  az network lb probe update -g rg-hlg-spoke-weu --lb-name lbe-hlg-weu-web -n hp-http-80 --port 80
  ```
- **Objectives:** Troubleshoot load balancing.
</details>

<details><summary>INC-107 — RBAC downgraded to Reader</summary>

- **Root cause:** `grp-hlg-apac-ops` now has **Reader** on `rg-hlg-spoke-sea`. Its **Virtual Machine Contributor** assignment was removed.
- **Prove it:** RG → **Access control (IAM) → Check access** → Wei Ling → only Reader. Activity log → *Delete role assignment* / *Create role assignment*.
- **Fix:**
  ```bash
  GID=$(az ad group show --group grp-hlg-apac-ops --query id -o tsv)
  SCOPE=$(az group show -n rg-hlg-spoke-sea --query id -o tsv)
  az role assignment create --assignee-object-id $GID --assignee-principal-type Group --role "Virtual Machine Contributor" --scope $SCOPE
  az role assignment delete --assignee $GID --role Reader --scope $SCOPE
  ```
- **Objectives:** Interpret access assignments · Assign roles at different scopes.
</details>

<details><summary>INC-108 — Private DNS record points to the wrong IP</summary>

- **Root cause:** `orders-api.sea.halsted.internal` resolves to **10.40.1.200**. The internal LB frontend is **10.40.1.100**.
- **Prove it:** `rc rg-hlg-spoke-weu vm-hlg-weu-app01 "getent hosts orders-api.sea.halsted.internal"` → 10.40.1.200. Zone record set shows the same.
- **Fix:**
  ```bash
  az network private-dns record-set a remove-record -g rg-hlg-hub-eus -z halsted.internal -n orders-api.sea -a 10.40.1.200 --keep-empty-record-set
  az network private-dns record-set a add-record    -g rg-hlg-hub-eus -z halsted.internal -n orders-api.sea -a 10.40.1.100
  ```
- **Objectives:** Configure Azure DNS.
</details>

> 📸 **Checkpoint 16-01** — For two tickets of your choice: the proof (tool output) and the re-test after the fix. → `screenshots/lab-16/16-01-*.png`

---

## Part D — Exam readiness gates

You're ready to book when **all** of these are true:

| Gate | Target |
|---|---|
| Microsoft Learn **free practice assessment** for AZ-104 | ≥ 80%, **twice**, on different days |
| [`docs/exam-tips-cram-sheet.md`](../docs/exam-tips-cram-sheet.md) | You can explain every tip without reading the detail |
| Knowledge checks in Labs 00–15 | ≥ 90% from memory |
| Capstone tickets | 6 of 8 diagnosed without the answer key |
| Rebuild | `main.bicep` + `workloads.bicep` deployed from a clean subscription in < 30 min, without notes |
| Exam sandbox | You've tried the question types in Microsoft's exam sandbox (link in the study guide) |

The exam needs **700** to pass. Weighting (skills measured as of 17 April 2026): identities and governance 20–25%, storage 15–20%, compute 20–25%, networking 15–20%, monitoring and backup 10–15%. Spend your remaining time in proportion, plus extra on your weakest knowledge-check domain.

---

## Part E — Teardown

1. **Resource groups** (removes locks first, warns about vaults):
   ```bash
   bash scripts/teardown.sh                 # all rg-hlg-*
   bash scripts/teardown.sh --governance    # also HLG policy assignments + management groups
   ```
   If a group won't delete, it's almost always a **Recovery Services/Backup vault** with soft-deleted items (Lab 15 Cleanup) or a lingering **lock**.
2. **Entra objects:**
   ```powershell
   ./identity/Remove-HlgStaff.ps1            # add -Purge to skip the 30-day recycle bin
   ```
   Then delete the CA policies (CA001–CA003), named locations, the guest user and `grp-hlg-eu-partners`. Revert SSPR scope if you like.
3. **Leftovers outside rg-hlg-*:** `NetworkWatcherRG` (free unless flow logs exist), the Cloud Shell storage RG (keep it if you'll keep using Cloud Shell), budgets and cost alerts, Advisor alerts, the dashboard.
4. **Verify:**
   ```bash
   bash scripts/cost-check.sh
   az group list --query "[?starts_with(name,'rg-hlg-')].name" -o tsv    # empty
   ```
5. **Final cost report:** Cost Management → Cost analysis → group by **Resource group** and **Tag: CostCenter** for the whole project period → download CSV → compare with the Lab 02 baseline. Put the total in your README. Employers like seeing that you track spend.

> 📸 **Checkpoint 16-02** — The final cost analysis by resource group (blur the subscription). → `screenshots/lab-16/16-02-final-cost.png`

---

## Part F — Publish the portfolio

1. In `README.md`, fill in the **Results** section: labs completed, total cost, biggest lessons, and a link to your best write-up.
2. Run `python3 scripts/build-cram-sheet.py` so the cram sheet includes any tips you added.
3. Run `bash scripts/secret-scan.sh`, then check every screenshot by eye.
4. Commit, push, and **pin** the repo on your GitHub profile.
5. Write a **"what I'd change in production"** section in `notes/lab-16.md`:
   - Azure Firewall (or a load-balanced NVA pair with HA ports) instead of a single Linux NVA
   - Azure Virtual WAN or Azure Virtual Network Manager for hub-spoke at scale
   - DNS Private Resolver plus on-prem conditional forwarders (Lab 07 Fix B) as standard
   - PIM for eligible admin roles, and access reviews for guests
   - Policy-as-code and IaC deployed from a pipeline with `what-if` gates, plus deployment stacks
   - GRS vaults with Cross Region Restore, recovery plans with runbooks
   - Defender for Cloud and Microsoft Sentinel on the Log Analytics workspace

**Final LinkedIn post template:**
> I finished my AZ-104 hands-on series: 17 labs building a multi-region hybrid Azure environment for a fictional logistics company, from an empty tenant to a monitored, backed-up, DR-tested estate. Then I tore it all down.
>
> 🌐 Chicago "datacenter" ↔ East US hub over S2S VPN, spokes in West Europe and Southeast Asia, NVA routing, private endpoints and private DNS
> 🔐 Entra ID identities, dynamic groups, B2B, SSPR, Conditional Access, least-privilege RBAC at 4 scopes
> 🏛️ Management groups, Azure Policy (including the Modify-before-Deny lesson), locks, budgets
> 🧱 Everything reproducible with Bicep and ARM
> 🖥️ VMs, scale sets, load balancers, containers (ACR/ACI/Container Apps), App Service with slots and private endpoints
> 📦 Storage security (CMK, SAS, stored access policies, Entra Kerberos for Azure Files), lifecycle, object replication
> 📈 Azure Monitor, KQL, alert processing rules, Connection monitor, Backup and Site Recovery test failover
> 🛠️ Finished with an 8-ticket break-fix capstone
>
> Total cloud spend: $<X>. Every step, screenshot and template is on GitHub: <link>
> #Azure #AZ104 #CloudEngineering #HybridCloud #LearningInPublic

---

## Incident write-up template (copy into `notes/lab-16.md` per ticket)

```markdown
### INC-10X — <title>
- **Reported symptom:**
- **Impact / scope:** who, what, since when
- **Hypotheses tried:** (in order, with the evidence that ruled each out)
- **Root cause:**
- **Proof:** tool + output (screenshot ref)
- **Fix applied:** command/portal steps, who approved
- **Verification:** re-test result
- **Prevention:** (policy, lock type, alert, IaC change, runbook)
- **AZ-104 objective(s):**
```
