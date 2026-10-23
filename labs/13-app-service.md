# Lab 13 — Azure App Service: Plans, Scaling, Slots, Networking, TLS, Custom Domains and Backup

> **Scenario:** The **Shipment Tracker** web app goes to production in West Europe. Releases must be zero-downtime and reversible, the app must call the EU app server **privately**, partners must reach it at `tracker.<your domain>` over TLS, and Operations wants backups. You'll start on the Free tier, hit its limits, and grow into Standard.
>
> **Time:** ~3.5 h · **Cost:** ~$0.50 (S1 for ~3 h + private endpoint). Delete or scale down the plan right after. · **Prereqs:** Labs 03, 05, 06, 09 (DNS zone), 10 (storage)

## What you'll build

```
asp-hlg-weu-linux (Linux, F1 → S1, 2 instances, autoscale)
└─ app-hlg-tracker-<digits>  (Node.js "Shipment Tracker")
    ├─ slots: production (APP_ENV=production, sticky) ⇄ staging (APP_ENV=staging, sticky)
    ├─ outbound: VNet integration → vnet-hlg-spoke-weu/snet-appsvc-int ──► vm-hlg-weu-app01 10.30.1.4
    ├─ inbound:  access restrictions · private endpoint 10.30.4.x (privatelink.azurewebsites.net)
    ├─ TLS: HTTPS only, TLS ≥ 1.2, certificate options, custom domain tracker.hlg-<you>-lab.com
    └─ backups: automatic (hourly) + custom → sthlgops…/appsvc-backups
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Provision an App Service plan | Task 1 |
| Create an App Service | Task 2 |
| Configure scaling for an App Service plan | Task 3 |
| Configure deployment slots for an App Service | Task 4 |
| Configure networking settings for an App Service | Task 5 |
| Configure certificates and Transport Layer Security (TLS) for an App Service | Task 6 |
| Map an existing custom DNS name to an App Service | Task 7 |
| Configure backup for an App Service | Task 8 |

```bash
cd ~/clouddrive/az104-hybrid-labs
rc() { az vm run-command invoke -g "$1" -n "$2" --command-id RunShellScript --scripts "$3" --query "value[0].message" -o tsv; }
```

---

## Task 1 — App Service plan (start Free)

**Create a resource → App Service plan**: RG `rg-hlg-apps`, name `asp-hlg-weu-linux`, **Linux**, **West Europe** → **Explore pricing plans**. Compare the tiers before choosing **Free F1**:

| Tier | Highlights for the exam |
|---|---|
| **Free F1 / Shared D1** | Shared compute, quotas, **no scale-out**, **no slots**. Custom domains from **Shared** up; no TLS bindings. |
| **Basic B1–B3** | Dedicated VMs, **manual** scale up to **3** instances, custom domains + TLS, **VNet integration**, **private endpoints**, backups. **No autoscale, no slots.** |
| **Standard S1–S3** | **Autoscale** (up to **10** instances), **5 deployment slots** |
| **Premium v3** (and newer Premium tiers where offered) | Faster hardware, up to **30** instances, more slots, **zone redundancy**, automatic (elastic) scaling |
| **Isolated v2** | **App Service Environment**: single-tenant, inside your VNet, up to 100 instances |

> [!TIP]
> **🎯 EXAM TIP — The plan is the compute.** Apps in the same plan **share its instances** and scale together. **Scale up** = change tier/size (more CPU/RAM, more features). **Scale out** = more instances. Region, OS and tier belong to the plan. Moving an app to another plan requires the **same region and resource group** (and a compatible OS).

---

## Task 2 — Create the web app and deploy v1

1. **Create a resource → Web App**:
   - RG `rg-hlg-apps` · name `app-hlg-tracker-<digits>` (if offered, *secure unique default hostname* is fine)
   - **Publish: Code** · runtime **Node 22 LTS** (or the newest LTS offered) · **Linux** · West Europe · plan `asp-hlg-weu-linux`
   - Deployment: no GitHub Actions for now · Networking: public access **on** · Monitoring: Application Insights **off**
2. Deploy the code:
   ```bash
   bash scripts/package-app.sh v1
   APP=$(az webapp list -g rg-hlg-apps --query "[?starts_with(name,'app-hlg-tracker')].name | [0]" -o tsv)
   az webapp deploy -g rg-hlg-apps -n $APP --src-path tracker-web-v1.zip --type zip
   ```
3. **Settings → Environment variables → App settings**:
   - `APP_ENV` = `production` → ✅ **Deployment slot setting**
   - `FEATURE_BANNER` = `classic` (not a slot setting)
   - Apply. Browse to the app: a blue **v1** banner showing both settings.

> [!TIP]
> **🎯 EXAM TIP — App settings** become **environment variables** for the app and override values in code or config files. **Connection strings** are a separate section with typed prefixes. Both can be marked **deployment slot setting** (sticky). Changing app settings **restarts** the app.

> 📸 **Checkpoint 13-01** — The app's v1 page plus the Environment variables blade (values visible are fine, they're not secrets). → `screenshots/lab-13/13-01-app-v1.png`

---

## Task 3 — Scale up, scale out, autoscale

1. Open **Deployment slots** on the app → you're prompted to **upgrade**: Free has no slots.
2. Plan → **Scale up (App Service plan)** → **Standard S1** → Select. The app stays online.
3. Plan → **Scale out** → **Manual** → **2** instances → Save.
4. App → **Configuration → General settings** → **Session affinity: Off** (the ARR cookie otherwise pins you to one instance) → Save. Then:
   ```bash
   for i in $(seq 1 8); do curl -s https://$APP.azurewebsites.net | grep -o 'Instance</b></td><td>[^<]*'; done
   ```
   Two different instance names.
5. **Scale out → Rules Based** (custom autoscale): min **1**, max **3**, default **1**. Rule *CPU Percentage > 70 (10 min) → +1*, rule *< 30 (10 min) → −1*. Save. Note the **Automatic** scaling option and which tiers offer it.

> [!TIP]
> **🎯 EXAM TIP — Scaling limits by tier:** Free/Shared: none. **Basic: manual, max 3.** **Standard: autoscale, max 10.** **Premium v3: max 30**, plus automatic (elastic) scaling. **Isolated: max 100.** Autoscale needs **Standard or higher**. Always define both scale-out and scale-in rules.

> 📸 **Checkpoint 13-02** — The curl loop showing two instances, plus the autoscale rules. → `screenshots/lab-13/13-02-scale.png`

---

## Task 4 — Deployment slots: stage, swap, route traffic

1. App → **Deployment slots** → **+ Add slot** → `staging`, **clone settings from** the production app.
2. **Staging slot** → **Environment variables**: set `APP_ENV` = `staging` (still marked *slot setting*) and `FEATURE_BANNER` = `new-look`. Apply.
3. Deploy **v2** (green banner) to staging only:
   ```bash
   bash scripts/package-app.sh v2
   az webapp deploy -g rg-hlg-apps -n $APP --slot staging --src-path tracker-web-v2.zip --type zip
   ```
   Browse `https://$APP-staging.azurewebsites.net`: **v2**, `APP_ENV=staging`, `FEATURE_BANNER=new-look`.
4. **Swap:** Deployment slots → **Swap** → source `staging` → target `production`. Expand **Config changes**: `FEATURE_BANNER` moves, `APP_ENV` doesn't. Note **Perform swap with preview**. **Swap**.
5. Production now shows **v2** + `APP_ENV=production` + `FEATURE_BANNER=new-look`. Staging holds **v1**, ready for an instant rollback.
6. **Traffic routing:** Deployment slots → set `staging` **Traffic % = 20** → Save, then:
   ```bash
   for i in $(seq 1 20); do curl -s https://$APP.azurewebsites.net | grep -o 'Tracker v[12]'; done | sort | uniq -c
   curl -s "https://$APP.azurewebsites.net/?x-ms-routing-name=self" | grep -o 'Tracker v[12]'   # always production
   ```
   Set it back to **0%**.

> [!TIP]
> **🎯 EXAM TIP — What swaps and what doesn't.**
> - **Swapped (moves with the code):** app settings and connection strings *not* marked as slot settings, language/framework versions, handler mappings, public certificates, WebJobs content.
> - **Not swapped (stays with the slot):** **slot settings**, **custom domains**, **TLS/SSL bindings and private certificates**, **scale settings**, **IP restrictions**, **Always On**, **CORS**, **managed identities**, **VNet integration**, diagnostic settings, publishing endpoints.
> - Slots need **Standard+** (Standard = 5 slots).
> - **Auto swap isn't supported on Linux** or Web App for Containers.
> - Swap = warm-up then routing switch, so **no downtime**. Rollback = swap again.

> 📸 **Checkpoint 13-03** — The swap dialog's Config changes, plus production showing v2 with `APP_ENV=production`. → `screenshots/lab-13/13-03-slot-swap.png`

---

## Task 5 — Networking: outbound, inbound restrictions, private endpoint

### 5a. Outbound: VNet integration
1. App → **Settings → Networking** → **Outbound traffic configuration → Virtual network integration** → **Add** → `vnet-hlg-spoke-weu` / **`snet-appsvc-int`** (already delegated to `Microsoft.Web/serverFarms` by the Bicep) → Connect.
2. Test the app's built-in probe:
   ```bash
   curl -s "https://$APP.azurewebsites.net/net?target=10.30.1.4"
   ```
   **FAILED**. The app's traffic now enters the VNet from `10.30.3.x`, and **Lab 06's rule 4000** denies it.
3. Add to `nsg-snet-app-weu`: priority **210** `Allow-AppSvc-to-EU-Web`, source `10.30.3.0/26`, destination ASG `asg-hlg-weu-web`, TCP 80, Allow. Re-test → **REACHED 10.30.1.4**.

### 5b. Inbound: access restrictions
1. Networking → **Inbound traffic configuration → Public network access** → *Enabled from select virtual networks and IP addresses* → **+ Add** rule `Allow-MyIP`, priority 100, IPv4 `<your IP>/32` → unmatched action **Deny** → Save.
2. Your browser ✅. Cloud Shell: `curl -s -o /dev/null -w "%{http_code}\n" https://$APP.azurewebsites.net` → **403**.
3. Look at the **Advanced tool site** (SCM/Kudu) tab and the *use main site rules* option.
4. Set public access back to **Enabled from all networks**.

### 5c. Inbound: private endpoint
1. Networking → **Private endpoints** → **+ Add → Express** → name `pe-hlg-app-tracker`, VNet `vnet-hlg-spoke-weu`, subnet **`snet-pe`**, **integrate with private DNS zone: Yes**.
2. From inside the EU spoke:
   ```bash
   rc rg-hlg-spoke-weu vm-hlg-weu-app01 "getent hosts $APP.azurewebsites.net; curl -s https://$APP.azurewebsites.net | grep -o 'Tracker v[12]'"
   ```
   It resolves to **10.30.4.x** and returns the page privately.
3. Set **Public network access: Disabled** → Cloud Shell gets **403**. The VM still works. Turn public access back **on** for Tasks 6–8.

> [!TIP]
> **🎯 EXAM TIP — App Service networking directions:**
>
> | Direction | Feature | Use |
> |---|---|---|
> | **Outbound** (app → your network) | **VNet integration** (delegated subnet, Basic+), **Hybrid Connections** (one TCP endpoint on-prem, through a relay), NAT gateway on the integration subnet | Reach private VMs, databases, on-prem via VPN |
> | **Inbound** (clients → app) | **Access restrictions** (IP/service tag/VNet rules, priority-ordered), **private endpoint** (private IP, Basic+), **App Service Environment** | Lock down who can reach the app |
>
> VNet integration doesn't give the app an inbound private IP. That's what the private endpoint is for. Exam questions mix them up on purpose.

> 📸 **Checkpoint 13-04** — `/net` FAILED then REACHED after the NSG rule, plus the private endpoint resolving to 10.30.4.x. → `screenshots/lab-13/13-04-networking.png`

---

## Task 6 — TLS and certificates

1. App → **Settings → Configuration → General settings**:
   - **HTTPS Only: On**
   - **Minimum inbound TLS version: 1.2** (read the 1.3 option)
   - **Client certificate mode:** read *Ignore / Optional / Required*
2. App → **Certificates**: read the tabs. **Managed certificates** (free, need a custom domain), **Bring your own certificates (.pfx)**, **Import from Key Vault**, and **Public key certificates (.cer)**.
3. Practise the upload flow with a throwaway self-signed certificate (lab only):
   ```bash
   ZONE=hlg-<your-initials>-lab.com
   openssl req -x509 -newkey rsa:2048 -nodes -days 30 -subj "/CN=tracker.$ZONE" -keyout /tmp/k.pem -out /tmp/c.pem
   read -rs -p "PFX password: " PFXPW; echo
   openssl pkcs12 -export -out /tmp/tracker.pfx -inkey /tmp/k.pem -in /tmp/c.pem -passout pass:$PFXPW
   ```
   Download `/tmp/tracker.pfx` through Cloud Shell's *Manage files* → **Bring your own certificates → Upload certificate**. It appears in the list but can't be bound until the domain exists (Task 7).

> [!TIP]
> **🎯 EXAM TIP — App Service certificates and TLS:**
> - **App Service Managed Certificate:** **free**, auto-renewing, **Basic tier or higher**, **no wildcard**, **not exportable**, needs the custom domain mapped first.
> - **Uploaded PFX:** password-protected, includes the private key.
> - **Key Vault import:** the app's identity needs access to the vault.
> - **Bindings:** **SNI SSL** (many certificates on one IP; the norm) vs **IP-based SSL** (dedicated IP).
> - **HTTPS Only** redirects HTTP → HTTPS. Minimum TLS version applies to inbound requests.

---

## Task 7 — Map a custom DNS name

1. App → **Custom domains** → **+ Add custom domain** → domain provider *All other domain services* → certificate **App Service Managed Certificate** → TLS type **SNI SSL** → domain **`tracker.hlg-<your-initials>-lab.com`**.
2. The dialog lists **two records** to create. Make them in your Azure DNS zone (`rg-hlg-mgmt-eus`, Lab 09):
   - **CNAME** `tracker` → `<app>.azurewebsites.net` (edit the placeholder from Lab 09)
   - **TXT** `asuid.tracker` → the **Custom Domain Verification ID** shown in the dialog
3. **Validate**:
   - **If your zone is delegated** from a real registrar (Lab 09 Task 6 step 5), validation passes → **Add** → the managed certificate is issued and bound with SNI. Browse `https://tracker.<zone>`.
   - **If it isn't delegated**, validation fails because the public DNS tree can't find your records. Screenshot that and stop. You've done everything an admin controls. (An **App Service Domain**, about $12/year, gives you a delegated domain in a few clicks if you want the full flow.)

> [!TIP]
> **🎯 EXAM TIP — Custom domain records:**
>
> | Domain | Records |
> |---|---|
> | Subdomain (`www`, `tracker`) | **CNAME** → `<app>.azurewebsites.net` + **TXT** `asuid.<sub>` = verification ID |
> | Apex (`contoso.com`) | **A** → the app's **inbound IP** + **TXT** `asuid` = verification ID |
>
> The `asuid` TXT record proves you own the domain. It also lets you validate **before** moving live traffic, so you can migrate without downtime. Custom domains need **Shared (D1) or higher**; TLS bindings need **Basic or higher**. Custom domains **don't swap** between slots.

> 📸 **Checkpoint 13-05** — The Add custom domain dialog with the records, plus the DNS zone record sets (and the validation result). → `screenshots/lab-13/13-05-custom-domain.png`

---

## Task 8 — Backup and restore

1. App → **Backups**. **Automatic backups** are already on (Basic+): **hourly**, kept **30 days**, no storage account needed. After an hour or so you'll see entries.
2. **Restore drill:** pick a backup → **Restore** → target **staging** slot (✅ restore site configuration if offered) → Restore. The **target is stopped during restore**. Restoring to a slot and then swapping keeps production online.
3. **Custom backups:** **Configure custom backups**:
   - Storage: `sthlgops…` → new container `appsvc-backups`
   - Schedule: every **12 hours**, retention **7 days**, keep at least one backup
   - Save → **Backup now**. Check the container for the `.zip` and `.xml` files.
4. Read about **partial backups**: a `_backup.filter` file in `wwwroot` lists paths to exclude.

> [!TIP]
> **🎯 EXAM TIP — App Service backup:**
>
> | | Automatic | Custom |
> |---|---|---|
> | Tiers | Basic, Standard, Premium, Isolated | Basic, Standard, Premium, Isolated |
> | Storage account | Not needed | **Required** (SAS-based; firewall-protected storage only over VNet integration) |
> | Frequency / retention | Hourly / 30 days, fixed | Every 2 h+ (up to 12/day) / 0–30 days or indefinite |
> | Size limit | 30 GB | 10 GB (4 GB of it linked databases) |
> | Linked databases | No | Yes, but deprecated (removed from custom backups by 2028) |
> | Partial backups | No | Yes |
>
> Basic tier backs up **only the production slot**. Restores don't bring back custom domains, TLS, identities, networking or scale settings.

> 📸 **Checkpoint 13-06** — The Backups blade (automatic and custom), plus the backup files in the container. → `screenshots/lab-13/13-06-backup.png`

---

## Break-fix challenges

1. `/net?target=10.40.1.100` (the APAC ILB) fails even after 5a. VNet integration works for 10.30.1.4. Why? Fix it.
2. You try to scale the plan back to **Free** and the portal refuses. Why?
3. After a swap, the production site loses its custom domain certificate binding. True or false?

<details><summary>Answers</summary>

1. The integration subnet `snet-appsvc-int` has **no route** to 10.40.0.0/16 (the UDR from Lab 05 is only on `snet-app`), and the peering isn't transitive. Associate `rt-hlg-weu-app` with `snet-appsvc-int` too. SEA's NSG allows VNet traffic.
2. The app has a **deployment slot**, and Free doesn't support slots (or scale-out/autoscale settings exist). Delete the staging slot and remove autoscale first.
3. **False.** Custom domains and TLS bindings **stay with the slot**. Production keeps them.
</details>

---

## Knowledge check

1. You need deployment slots and autoscale at the lowest cost. Which tier?
2. Which setting keeps a database connection string pointing at the staging database after a swap?
3. An app must reach an on-prem SQL Server over the existing S2S VPN. Which App Service feature?
4. Clients on the internet must not reach the app, but users on the corporate network (via VPN) must. What do you configure?
5. You map `www.contoso.com`. Which two DNS records?

<details><summary>Answers</summary>

1. **Standard (S1).**
2. Mark the connection string as a **deployment slot setting**.
3. **VNet integration** to a VNet that has gateway transit to the VPN (or **Hybrid Connections** for a single endpoint).
4. A **private endpoint** with **public network access disabled**, plus on-prem DNS resolution for `privatelink.azurewebsites.net`.
5. **CNAME** `www` → `<app>.azurewebsites.net` and **TXT** `asuid.www` = verification ID.
</details>

---

## Clean up (do it today; S1 bills hourly)

```bash
az network private-endpoint delete -g rg-hlg-apps -n pe-hlg-app-tracker
az webapp deployment slot delete -g rg-hlg-apps -n $APP --slot staging
az monitor autoscale delete -g rg-hlg-apps -n "$(az monitor autoscale list -g rg-hlg-apps --query '[0].name' -o tsv)"
az appservice plan update -g rg-hlg-apps -n asp-hlg-weu-linux --sku F1 --number-of-workers 1
# or delete everything: az webapp delete -g rg-hlg-apps -n $APP && az appservice plan delete -g rg-hlg-apps -n asp-hlg-weu-linux --yes
```
Delete the custom backup schedule or the `appsvc-backups` container if you scale down to Free. Keep the NSG rule (harmless).

## 📣 Document it

```bash
git add notes/lab-13.md screenshots/lab-13 && git commit -m "Lab 13: App Service F1->S1, autoscale, slot swap + sticky settings, VNet integration, access restrictions, private endpoint, TLS, custom domain, backups"
```

**LinkedIn post template:**
> Lab 13 of my AZ-104 hybrid build: production-grade App Service.
>
> 📶 Started on Free, hit the limits (no slots, no scale-out), scaled up to Standard and out to 2 instances, then autoscale
> 🔄 Blue/green with deployment slots: v2 in staging, swap, and a "sticky" APP_ENV that stays with its slot while the feature flag moves with the code. Then a 20% canary via traffic routing.
> 🔌 VNet integration (outbound) to reach a private VM, which my own Lab 06 NSG blocked until I allowed the integration subnet
> 🔒 Access restrictions, then a private endpoint with public access disabled (inbound)
> 🌐 Custom domain with CNAME + asuid TXT validation in Azure DNS, managed certificate, TLS 1.2 minimum
> 💾 Automatic hourly backups vs custom backups to storage, restored to a slot so production stays up
>
> #Azure #AZ104 #AppService #DevOps #LearningInPublic
