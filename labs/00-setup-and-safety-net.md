# Lab 00 — Setup, Tooling and a Cost Safety Net

> **Scenario:** Halsted Logistics Group (HLG) is a fictional Chicago freight forwarder. Its datacenter is in Chicago, and it has operations hubs in Amsterdam and Singapore. Leadership wants a hybrid Azure footprint: an **East US hub**, a **West Europe spoke** and a **Southeast Asia spoke**, connected back to Chicago. You are the new Azure administrator. Before you build anything, you set up a lab tenant you can break safely, tooling you can repeat, and guardrails that stop a forgotten gateway from costing you $200.
>
> **Time:** ~1.5 h · **Cost:** $0 · **Prereqs:** an Azure subscription you own

## What you'll set up

| Item | Why |
|---|---|
| A dedicated **cloud admin account** in your tenant | Entra trials and Conditional Access behave better with a work account than a personal Microsoft account. You'll also need it for MFA-enforced portal sign-in. |
| **Microsoft Entra ID P2 trial** (30 days) | Dynamic groups, group-based licensing, Conditional Access (Lab 01) |
| **Cloud Shell** + this repo | One place to run every CLI step |
| **Preflight check** | Catch quota, region and provider problems before a 40-minute deployment fails |
| **Budget alert** | A safety net. Lab 02 teaches budgets properly. |
| **Your GitHub repo** + secret-scan hook | Post your work publicly without leaking IDs or keys |

## Skills measured covered

Lab 00 is groundwork. It touches **Manage subscriptions** (resource providers, quotas) and **Manage costs by using alerts, budgets, and Azure Advisor recommendations** (first budget), both covered fully in Lab 02.

---

## Task 1 — Check your subscription type

**Why it matters:** Free Trial subscriptions have low vCPU quotas and block some SKUs. Several labs (VMSS, VPN, ASR) will hit those limits.

1. Portal → **Subscriptions** → your subscription → **Overview**. Note the **Offer** (for example *Free Trial* or *Pay-As-You-Go*).
2. If it's a Free Trial, choose **Upgrade** when you're ready. Your remaining credit carries over, and you only pay for what you leave running.

> [!TIP]
> **🎯 EXAM TIP — Spending limits.** Only credit-based offers (Free Trial, Visual Studio/MSDN credits) have a **spending limit** that suspends resources when the credit runs out. Pay-As-You-Go has no spending limit. A **budget** never stops resources; it only alerts you (Lab 02).

> 📸 **Checkpoint 00-01** — Subscription overview showing the offer type. Blur the subscription ID. → `screenshots/lab-00/00-01-subscription-offer.png`

---

## Task 2 — Create a cloud-only lab admin account

**Why it matters:** If your subscription was created with a personal Microsoft account (outlook.com, gmail.com), you are a *guest-like* external identity in your own "Default Directory". Entra P2 trial sign-up often refuses that account. A native `@<tenant>.onmicrosoft.com` admin avoids the problem.

1. Portal → **Microsoft Entra ID** → **Overview**. Note your **Primary domain** (`<something>.onmicrosoft.com`).
2. **Users** → **New user** → **Create new user**:
   - User principal name: `labadmin@<tenant>.onmicrosoft.com`
   - Display name: `Lab Admin`
   - Auto-generate a password and copy it somewhere safe (not into the repo).
3. **Assignments** tab → **Add role** → **Global Administrator**. Create the user.
4. Give it Azure access: **Subscriptions** → your subscription → **Access control (IAM)** → **Add role assignment** → **Owner** → select `Lab Admin`. (On the Conditions tab, choose *Allow user to assign all roles except privileged administrator roles…* or the unconstrained option; this is your lab.)
5. Open an InPrivate/Incognito window, sign in to <https://portal.azure.com> as `labadmin`, change the password, and **register MFA** with Microsoft Authenticator.

> [!TIP]
> **🎯 EXAM TIP — Entra roles vs Azure roles.** *Global Administrator* is an **Entra ID role**: it manages the directory (users, groups, licenses). It grants **no** access to Azure resources by itself. *Owner* is an **Azure RBAC role** on a scope (management group, subscription, resource group, resource). Expect questions that hinge on this split. (A Global Admin *can* elevate to User Access Administrator at root scope "/"; see Lab 04.)

> [!NOTE]
> **🧭 Mandatory MFA.** Microsoft enforces MFA for Azure portal, Entra admin center and Intune admin center sign-ins (phase 1). Phase 2 extends it to Azure CLI, PowerShell, IaC tools and REST create/update/delete operations, with a gradual rollout from October 2025 (tenants could postpone to July 2026). Plan on every human account needing MFA, including break-glass accounts. Workload identities (managed identities, service principals) aren't affected.

From here on, **do every lab signed in as `labadmin`**.

---

## Task 3 — Activate the Microsoft Entra ID P2 trial

1. Sign in to the **Microsoft Entra admin center** (<https://entra.microsoft.com>) as `labadmin`.
2. Go to **Billing** → **Licenses** → **All products** → **+ Try / Buy** → **Microsoft Entra ID P2** → **Free trial** → **Activate**. (In some tenants the trial is offered under the Microsoft 365 admin center → **Marketplace** instead.)
3. Back in **Licenses** → **All products**, confirm *Microsoft Entra ID P2* appears with available licenses.

> [!WARNING]
> **💲 COST / TIMING — The trial lasts 30 days.** Lab 01 needs it for dynamic groups, group-based licensing and Conditional Access. Do Lab 01 inside the window. Set a calendar reminder for day 28.

> [!TIP]
> **🎯 EXAM TIP — What needs P1/P2.** Dynamic groups, group-based licensing, Conditional Access and SSPR **writeback** need **P1** (or a bundle such as Microsoft 365 E3/Business Premium). **P2** adds Identity Protection (risk-based policies) and **PIM**. Entra ID Free gives you users, groups, basic SSO and security defaults.

> 📸 **Checkpoint 00-02** — Licenses → All products showing the P2 trial. → `screenshots/lab-00/00-02-entra-p2-trial.png`

---

## Task 4 — Cloud Shell and this repo

1. In the portal (as `labadmin`), open **Cloud Shell** (`>_` icon) → **Bash**.
2. When prompted, choose **Mount storage account** and let it create one in a new resource group. That gives you a persistent `~/clouddrive` file share so the repo survives between sessions.
3. Get the repo into Cloud Shell. If you've already pushed it to GitHub (Task 7):
   ```bash
   cd ~/clouddrive
   git clone https://github.com/<your-github-user>/az104-hybrid-labs.git
   cd az104-hybrid-labs
   ```
   Otherwise, upload the zip with **Manage files → Upload** and `unzip` it.
4. Check your tools:
   ```bash
   az version --query '"azure-cli"' -o tsv
   az bicep version || az bicep install
   azcopy --version
   ```
5. Switch to **PowerShell** once (top-left dropdown) and run `Get-Module -ListAvailable Az.Accounts, Microsoft.Graph.Authentication | Select Name, Version`.

Optional local tools: Azure CLI, Az PowerShell module, VS Code + **Bicep** extension, **Azure Storage Explorer** (Lab 11), Git.

> [!TIP]
> **🎯 EXAM TIP — Cloud Shell facts.** Cloud Shell runs in a Microsoft-managed container. Files persist only in the **Azure Files share** it mounts as `clouddrive` (plus your `$HOME` image stored in that share). Sessions time out after about 20 minutes without interaction. Bash and PowerShell share the same storage. You can also run Cloud Shell **ephemerally** with no storage account, but then nothing persists.

> 📸 **Checkpoint 00-03** — Cloud Shell showing `az version` and `az bicep version`. → `screenshots/lab-00/00-03-cloud-shell-tools.png`

---

## Task 5 — Preflight: providers, features, quotas, regions

**Why it matters:** "The subscription is not registered to use namespace Microsoft.X" and "Operation could not be completed as it results in exceeding approved Total Regional Cores quota" are the two most common reasons a lab deployment fails.

1. Run the preflight and let it register anything missing:
   ```bash
   bash scripts/preflight.sh --register
   ```
2. Read the output:
   - **Resource providers** should all show `Registered` (re-run after a few minutes if some show `Registering`).
   - **EncryptionAtHost** must show `Registered` before Lab 08. Feature registration can take 15+ minutes. Starting it now is the point.
   - **VM size Standard_B1s**: every region should show `restrictions: none`. If one says `NotAvailableForSubscription`, change that region in the `.bicepparam` files (West Europe is the usual offender; use `northeurope` or `swedencentral`).
   - **vCPUs used/limit**: you need about **4 vCPUs per region** for the core labs, and 6–8 in West Europe for Lab 09 (the scale set).
3. If a quota is too low: portal → **Quotas** → **Compute** → filter the region → select **Total Regional vCPUs** or **Standard BS Family vCPUs** → **New quota request**.

> [!TIP]
> **🎯 EXAM TIP — Resource providers.** Each Azure service is delivered by a **resource provider** (`Microsoft.Compute`, `Microsoft.Network`, …). A subscription must be **registered** for a provider before you can deploy that resource type. Register in the portal (**Subscription → Resource providers → Register**), with `az provider register -n Microsoft.X`, or `Register-AzResourceProvider -ProviderNamespace Microsoft.X`. Registering needs a role with `*/register/action`, such as Contributor or Owner at subscription scope.

> [!TIP]
> **🎯 EXAM TIP — Quotas are per region and per VM family.** A quota error for *Standard DSv5 Family vCPUs* in East US says nothing about West Europe or B-series. Requests go through **Quotas** (or a support request for some types).

> 📸 **Checkpoint 00-04** — Preflight output. Blur the subscription name if it identifies you. → `screenshots/lab-00/00-04-preflight.png`

---

## Task 6 — A budget safety net

You'll build budgets properly in Lab 02. This one just catches a mistake early.

1. Portal → **Cost Management + Billing** → **Cost Management** → **Budgets** → scope = your subscription → **+ Add**.
2. Name `budget-hlg-safety-net`, reset period **Monthly**, amount **$50** (or what you're comfortable with).
3. Alert conditions: **Actual 50%**, **Actual 90%**, **Forecasted 100%**. Alert recipients: your real email address.
4. Create.

> [!CAUTION]
> **⚠️ EXAM TRAP — Budgets don't stop spending.** A budget alert sends email (and can trigger an action group) when spend crosses a threshold. It does **not** stop or delete anything unless you wire an action group to automation that does. Cost data also lags by several hours, so a budget can't catch a spike in real time.

> 📸 **Checkpoint 00-05** — The budget's alert conditions. → `screenshots/lab-00/00-05-budget.png`

---

## Task 7 — Create your portfolio repo

1. On GitHub, create a **public** repository named `az104-hybrid-labs` (no README; you already have one).
2. On your PC (or Cloud Shell):
   ```bash
   unzip az104-hybrid-labs.zip && cd az104-hybrid-labs
   git init && git branch -M main
   bash scripts/install-hooks.sh          # blocks commits that contain IDs/keys
   bash scripts/secret-scan.sh            # should print: secret-scan: clean
   git add . && git commit -m "Lab 00: scaffold AZ-104 hybrid lab series"
   git remote add origin https://github.com/<your-github-user>/az104-hybrid-labs.git
   git push -u origin main
   ```
3. Read [`docs/screenshot-guide.md`](../docs/screenshot-guide.md) before your first screenshot. It covers naming, what to blur and how to keep images small.
4. Copy [`notes/TEMPLATE.md`](../notes/TEMPLATE.md) to `notes/lab-00.md` and start your notes.

> [!IMPORTANT]
> **🔒 DON'T POST THIS — The list you'll check before every screenshot:** subscription ID, tenant ID, object IDs, your home public IP, email addresses, access keys, SAS URLs (anything with `sig=`), connection strings, VPN shared keys, passwords. The secret-scan hook catches text but not images, so you have to check images yourself.

---

## Naming and tagging standard (used in every lab)

| Resource | Prefix | Example |
|---|---|---|
| Resource group | `rg-` | `rg-hlg-spoke-weu` |
| Virtual network / subnet | `vnet-` / `snet-` | `vnet-hlg-hub-eus` / `snet-app` |
| NSG / ASG | `nsg-` / `asg-` | `nsg-snet-app-weu` / `asg-hlg-weu-web` |
| Route table | `rt-` | `rt-hlg-sea-app` |
| Public IP | `pip-` | `pip-lbe-hlg-weu-web` |
| VM / NIC / OS disk | `vm-` / `nic-` / `osdisk-` | `vm-hlg-weu-app01` |
| VPN gateway / local network gateway / connection | `vgw-` / `lng-` / `cn-` | `vgw-hlg-hub-eus` |
| Bastion | `bas-` | `bas-hlg-hub-eus` |
| Load balancer (external / internal) | `lbe-` / `lbi-` | `lbe-hlg-weu-web` |
| Storage account / Key Vault | `st` / `kv-` | `sthlgops<unique>` / `kv-hlg-<unique>` |
| Log Analytics / action group / alert processing rule | `law-` / `ag-` / `apr-` | `law-hlg-eus` |
| Recovery Services vault / Backup vault | `rsv-` / `bvault-` | `rsv-hlg-weu` |
| Container registry / instance / app env / app | `acr` / `aci-` / `cae-` / `ca-` | `acrhlg<unique>` |
| App Service plan / app | `asp-` / `app-` | `asp-hlg-weu-linux` |

Region codes: `chi` = simulated Chicago on-prem (North Central US), `eus` = East US, `weu` = West Europe, `sea` = Southeast Asia, `neu` = North Europe (DR).

**Tags on every resource group:** `Project=az104-hybrid`, `Company=Halsted Logistics`, `CostCenter=CC-1001`, `Environment=lab`, `Owner=<you>`. Lab 02 makes `CostCenter` mandatory with Azure Policy.

---

## Knowledge check

1. Your Free Trial deployment fails with *"exceeding approved Standard BS Family vCPUs quota"* in West Europe. East US has plenty of quota. What do you do?
   - A. Register the Microsoft.Compute provider again
   - B. Request a quota increase for that VM family in West Europe, or deploy a different family/region
   - C. Create a budget for West Europe
   - D. Move the subscription to another management group
2. A user is a Global Administrator but sees no resources in the subscription. Why?
3. Which feature stops Azure resources when a threshold is reached: a budget, a spending limit, or an Advisor recommendation?
4. Where do Cloud Shell files persist between sessions?
5. A deployment fails with *"The subscription is not registered to use namespace 'Microsoft.ContainerInstance'"*. Which role, at minimum, can fix it, and how?

<details><summary>Answers</summary>

1. **B.** Quotas are per region and per VM family.
2. Global Administrator is an Entra role with no Azure RBAC permissions. They need an Azure role (for example Reader or Owner) on a scope, or must temporarily elevate access to User Access Administrator at root scope.
3. A **spending limit**, and only on credit-based subscriptions. Budgets only alert.
4. In the Azure Files share Cloud Shell mounts (`clouddrive`) in the storage account you chose.
5. Contributor (or Owner) at subscription scope, using `az provider register -n Microsoft.ContainerInstance` or Subscription → Resource providers → Register.
</details>

---

## 📣 Document it

**GitHub:** commit `notes/lab-00.md` and the five screenshots.
```bash
git add notes/lab-00.md screenshots/lab-00 && git commit -m "Lab 00: tenant, tooling, preflight and budget guardrail"
```

**LinkedIn post template:**
> I'm studying for AZ-104 by building a multi-region hybrid Azure environment from scratch: a simulated Chicago datacenter connected to an East US hub, with spokes in West Europe and Southeast Asia.
>
> Day 0 was guardrails before infrastructure:
> ✅ Dedicated cloud admin account with MFA
> ✅ Preflight script checking providers, regional vCPU quotas and SKU availability across 5 regions
> ✅ Budget alerts (budgets alert, they don't stop spend: a classic exam trap)
> ✅ A pre-commit hook that blocks subscription IDs, keys and SAS tokens from reaching GitHub
>
> Repo: <link> · Next up: identities and Conditional Access for 10 staff across 3 continents.
> #Azure #AZ104 #CloudEngineering #HomeLab #LearningInPublic
