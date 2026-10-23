# Lab 12 — Containers: Azure Container Registry, Container Instances and Container Apps

> **Scenario:** HLG's developers package the shipment tracker as containers. Platform wants **one private registry** for all regions, a quick **burst job** runner in Singapore, and an **API that scales to zero** at night and handles traffic spikes in Amsterdam. You'll run the same images on ACI and Container Apps, compare their sizing and scaling models, and practise the revision traffic-splitting the exam likes.
>
> **Time:** ~2.5 h · **Cost:** ~$0.50 (ACR Basic per day, ACI per second, Container Apps within the free monthly grant; optional ACR Premium ~$5/day) · **Prereqs:** Lab 02 (policies), RG `rg-hlg-apps`

## What you'll build

```
acrhlg<digits> (East US, Basic → optional Premium + geo-replicas WEU/SEA)
 ├─ hlg/tracker-web:v1  ─►  aci-hlg-sea-tracker   (Southeast Asia, 1 vCPU/1.5 GiB → recreated 0.5/1)
 └─ hlg/tracker-api:v1  ─►  ca-hlg-tracker-api    (West Europe, env cae-hlg-weu, 0→5 replicas, HTTP rule,
                                                   multiple revisions, 80/20 traffic split)
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Create and manage an Azure Container Registry | Task 1 |
| Provision a container by using Azure Container Instances | Task 2 |
| Provision a container by using Azure Container Apps | Task 4 |
| Manage sizing and scaling for containers, including Azure Container Instances and Azure Container Apps | Tasks 3, 5, 6 |

The study guide says *"in the Azure portal"*, so do each create in the portal first. CLI is shown for comparison.

---

## Task 1 — Azure Container Registry

1. **Create a resource → Container Registry**: RG `rg-hlg-apps`, name `acrhlg<digits>`, East US, **pricing plan Basic** → Create.
2. Import two public images into it (no Docker needed):
   ```bash
   ACR=$(az acr list -g rg-hlg-apps --query "[0].name" -o tsv)
   az acr import -n $ACR --source mcr.microsoft.com/azuredocs/aci-helloworld:latest --image hlg/tracker-web:v1
   az acr import -n $ACR --source mcr.microsoft.com/k8se/quickstart:latest        --image hlg/tracker-api:v1
   az acr repository list -n $ACR -o table; az acr repository show-tags -n $ACR --repository hlg/tracker-web -o table
   ```
3. Portal → registry → **Services → Repositories** → open `hlg/tracker-web` → tag `v1` → note the **digest** (`sha256:…`) and the pull command `docker pull <acr>.azurecr.io/hlg/tracker-web:v1`.
4. **Settings → Access keys** → enable **Admin user**. The ACI portal flow in Task 2 uses it. Note the two passwords.
5. **Access control (IAM)** → **Roles** → find **AcrPull**, **AcrPush**, **AcrDelete**.
6. **Optional (~$5 for a day):** **Properties → Pricing plan → Premium** → **Services → Geo-replications** → add **West Europe** and **Southeast Asia** → wait for *Ready* → screenshot → **delete both replicas** → change the plan back to **Basic**.

> [!TIP]
> **🎯 EXAM TIP — ACR SKUs.** All tiers give a private registry, webhooks and Entra auth. **Premium** adds **geo-replication** (one registry name, replicas close to each region's workloads), **private endpoints**, **customer-managed keys**, content trust, higher throughput and storage, and more. Questions that say "pull images from the nearest region" or "no public access to the registry" need **Premium**.

> [!TIP]
> **🎯 EXAM TIP — Registry authentication.** Prefer **Entra ID**: `az acr login`, a **managed identity** with **AcrPull** (AKS, Container Apps, App Service), or service principals. The **admin user** is a single shared username/password, disabled by default, and is what some portal flows (like ACI from ACR) ask for. Name rules: 5–50 alphanumeric characters, globally unique. Login server: `<name>.azurecr.io`. `az acr build` (ACR Tasks) builds in the cloud without local Docker, but some subscription offers restrict Tasks.

> 📸 **Checkpoint 12-01** — Repositories with both images. (Optional: the geo-replication map.) → `screenshots/lab-12/12-01-acr.png`

---

## Task 2 — Azure Container Instances in Singapore

**Create a resource → Container Instances**:

| Tab | Setting | Value |
|---|---|---|
| Basics | RG / name / region | `rg-hlg-apps` / `aci-hlg-sea-tracker` / **Southeast Asia** |
| | Image source | **Azure Container Registry** → `acrhlg…` → `hlg/tracker-web` → `v1` |
| | OS type | Linux |
| | **Size** → Change size | **1 vCPU, 1.5 GiB**, no GPU |
| Networking | Type | **Public** · DNS name label `hlg-tracker-<initials>` · port **80/TCP** |
| Advanced | **Restart policy** | **Always** (read *On failure* and *Never*) |
| | Environment variables / command override | none |

Create, then:
1. Browse to `http://hlg-tracker-<initials>.southeastasia.azurecontainer.io`.
2. **Settings → Containers** → **Events**, **Properties**, **Logs**, **Connect** (`/bin/sh`, then `ls /usr/src/app`).
3. CLI views:
   ```bash
   az container show -g rg-hlg-apps -n aci-hlg-sea-tracker --query "{state:instanceView.state, ip:ipAddress.ip, fqdn:ipAddress.fqdn, cpu:containers[0].resources.requests.cpu, mem:containers[0].resources.requests.memoryInGB}" -o table
   az container logs -g rg-hlg-apps -n aci-hlg-sea-tracker
   ```

> [!TIP]
> **🎯 EXAM TIP — ACI concepts:**
> - The **container group** is the unit of deployment: one or more containers (multi-container groups are **Linux only**) sharing a lifecycle, IP, ports, network and storage (for example an **Azure Files volume**).
> - Deploy with the portal, CLI, **YAML** (needed for multi-container groups via CLI) or ARM/Bicep.
> - **Restart policies:** *Always* (web servers), *OnFailure* (batch that should retry), *Never* (run once).
> - Billed **per second** for requested vCPU and memory.
> - Can run inside a **VNet** (delegated subnet, private IP).

> 📸 **Checkpoint 12-02** — The ACI page in the browser, plus the Containers → Events view. → `screenshots/lab-12/12-02-aci.png`

---

## Task 3 — ACI sizing: what can and can't change

1. Try to **resize in place** by re-running create with the same name and bigger resources:
   ```bash
   PW=$(az acr credential show -n $ACR --query "passwords[0].value" -o tsv)
   az container create -g rg-hlg-apps -n aci-hlg-sea-tracker -l southeastasia --os-type Linux \
     --image $ACR.azurecr.io/hlg/tracker-web:v1 --registry-login-server $ACR.azurecr.io \
     --registry-username $ACR --registry-password "$PW" \
     --cpu 2 --memory 2 --ports 80 --dns-name-label hlg-tracker-<initials>
   ```
   It **fails**: changing CPU/memory requires deleting the container group first.
2. Now change something that **is** updatable in place: same command with the original `--cpu 1 --memory 1.5` plus `--environment-variables HLG_SITE=Singapore`. That succeeds (an env var is updatable).
3. **Delete and recreate** smaller: `az container delete -g rg-hlg-apps -n aci-hlg-sea-tracker --yes`, then run the create with `--cpu 0.5 --memory 1`.
4. Find the **scale** settings for ACI in the portal. There aren't any. To handle more load you'd run more container groups.

> [!TIP]
> **🎯 EXAM TIP — ACI updates.** These need **delete + redeploy**: **OS type, CPU, memory, GPU, restart policy, network profile**. You can redeploy in place to change things like the **image tag, environment variables or DNS label**. **ACI has no autoscaling.** Choose **Container Apps** (or AKS) when a question needs scale rules, revisions or scale-to-zero.

> 📸 **Checkpoint 12-03** — The CLI error message about deleting before changing CPU/memory. → `screenshots/lab-12/12-03-aci-resize-error.png`

---

## Task 4 — Azure Container Apps in Amsterdam

**Create a resource → Container App**:

| Tab | Setting | Value |
|---|---|---|
| Basics | RG / name / region | `rg-hlg-apps` / `ca-hlg-tracker-api` / **West Europe** |
| | Container Apps environment | **Create new** → `cae-hlg-weu` · *Workload profiles* (includes the **Consumption** profile) · zone redundancy off · **Monitoring**: *Don't save logs* (or pick a Log Analytics workspace) · **Networking**: public, no custom VNet |
| Container | Quickstart image | ❌ untick |
| | Image source | **Azure Container Registry** → `acrhlg…` → `hlg/tracker-api` → `v1` |
| | Authentication | **Managed identity** if offered (the portal grants AcrPull); otherwise admin credentials |
| | Workload profile / CPU & memory | Consumption / **0.25 vCPU, 0.5 Gi** |
| Ingress | Ingress | ✅ · **Accepting traffic from anywhere** · HTTP · target port **80** |

Create, then open the **Application URL**.

> [!TIP]
> **🎯 EXAM TIP — Container Apps concepts:**
> - **Environment** = the secure boundary (shared VNet, logging, Dapr). Apps in one environment can talk to each other.
> - **Workload profiles:** *Consumption* (serverless, pay per use) and *Dedicated* (reserved compute sizes).
> - **Ingress:** external or internal, HTTP or TCP, target port.
> - **Revisions:** immutable snapshots of a version of the app.
> - Use Container Apps for microservices, APIs and event-driven jobs without managing Kubernetes.

> 📸 **Checkpoint 12-04** — The container app overview showing the URL and environment. → `screenshots/lab-12/12-04-container-app.png`

---

## Task 5 — Container Apps scaling: HTTP rule, scale to zero, sizing

1. **Application → Scale** (or *Revisions and replicas → Edit and deploy → Scale*): **min replicas 0**, **max replicas 5** → **+ Add** scale rule `http-rule`, type **HTTP scaling**, **concurrent requests 10** → Create. That creates a new revision.
   ```bash
   # CLI equivalent
   az containerapp update -g rg-hlg-apps -n ca-hlg-tracker-api --min-replicas 0 --max-replicas 5 \
     --scale-rule-name http-rule --scale-rule-type http --scale-rule-http-concurrency 10
   ```
2. **Load test** from Cloud Shell and watch replicas climb:
   ```bash
   URL=https://$(az containerapp show -g rg-hlg-apps -n ca-hlg-tracker-api --query properties.configuration.ingress.fqdn -o tsv)
   seq 1 3000 | xargs -P 100 -I{} curl -s -o /dev/null "$URL" &
   watch -n 5 "az containerapp replica list -g rg-hlg-apps -n ca-hlg-tracker-api --query 'length(@)'"
   ```
   Press `Ctrl+C` when you see several replicas. Leave it idle for about 5 minutes: replicas drop to **0**. The next request has a short **cold start**.
3. **Resize:** Edit and deploy → container → **0.5 vCPU / 1 Gi** → Create. A new revision appears.

> [!TIP]
> **🎯 EXAM TIP — Container Apps scaling:**
> - Scale rules: **HTTP** (concurrent requests), **TCP** (concurrent connections), **custom/KEDA** (Service Bus, Event Hubs, Kafka, cron, …) and **CPU/memory**.
> - **min replicas 0** = **scale to zero** (not possible with CPU/memory rules alone, because a stopped replica has no CPU to measure).
> - Replicas scale between min and max.
> - **Revision-scope changes** (image, env vars, CPU/memory, scale rules) **create a new revision**. **Application-scope changes** (ingress, secrets, revision mode) don't.
> - CPU/memory come in **fixed combinations** on Consumption (for example 0.25/0.5Gi, 0.5/1Gi, … up to 4/8Gi).

> 📸 **Checkpoint 12-05** — The replica count during load, then 0 after idle. → `screenshots/lab-12/12-05-scale-rule.png`

---

## Task 6 — Revisions and traffic splitting

1. **Revisions and replicas** → **Choose revision mode** → **Multiple** → Apply.
2. **Edit and deploy** → revision suffix `v2` → container → add env var `FEATURE=green` → Create.
3. In **Revisions**, both are active. Set **traffic**: older revision **80%**, `--v2` **20%** → Save.
4. Give `v2` a **label** `canary` and open its label URL to hit it directly.
5. Move traffic to 100% `v2`, then **deactivate** the old revision.

> [!TIP]
> **🎯 EXAM TIP — Revision modes.** **Single** (default): only the latest revision is active, and a new one replaces the old. **Multiple**: several active revisions with **traffic weights**, used for blue/green and canary releases. Labels give a stable URL to a specific revision.

> 📸 **Checkpoint 12-06** — The traffic split 80/20 in the Revisions blade. → `screenshots/lab-12/12-06-revisions-traffic.png`

---

## Which container service? (memorize this table)

| Need | Choose |
|---|---|
| Run a container **now**, no orchestration, per-second billing, batch or simple tasks | **Azure Container Instances** |
| Microservices/APIs with **autoscale (incl. to zero)**, revisions, KEDA, Dapr, no Kubernetes to manage | **Azure Container Apps** |
| Full **Kubernetes** API control, custom operators, node pools | **AKS** |
| Web app hosting with slots, custom domains, TLS, backups (container or code) | **App Service** (Lab 13) |
| Private image storage, geo-replicated | **ACR** (Premium for geo/private link) |

---

## Break-fix challenges

1. The ACI portal create fails with *"admin user is not enabled on the registry"*. Fix it two ways.
2. `ca-hlg-tracker-api` never scales above 1 replica under load. Name two settings to check.
3. A teammate changed the container app's **ingress target port** and wonders why no new revision appeared. Explain.

<details><summary>Answers</summary>

1. Enable **Admin user** on the registry (Access keys), **or** deploy via CLI/ARM using a **managed identity** with **AcrPull**.
2. **Max replicas** (maybe 1), the **scale rule** type/threshold (HTTP concurrency too high), and whether the load is actually reaching the app.
3. Ingress is an **application-scope** setting. Those don't create revisions.
</details>

---

## Knowledge check

1. A nightly job runs a container for 10 minutes and must retry on failure. Which service and restart policy?
2. You must serve images from the registry closest to West Europe and Southeast Asia. Which ACR SKU and feature?
3. You need to send 10% of traffic to a new version of an API in Container Apps. What do you configure?
4. Can an ACI container group's memory be increased without deleting it?
5. An API must cost nothing when idle and scale out on HTTP load. Which service and what minimum replica count?

<details><summary>Answers</summary>

1. **Azure Container Instances** with restart policy **OnFailure** (or a Container Apps *job*).
2. **Premium**, **geo-replication**.
3. **Multiple revision mode** + a **traffic split** (90/10) between revisions.
4. **No.** Delete and recreate.
5. **Azure Container Apps**, **min replicas = 0** with an HTTP scale rule.
</details>

---

## Clean up

```bash
az container delete -g rg-hlg-apps -n aci-hlg-sea-tracker --yes
az containerapp update -g rg-hlg-apps -n ca-hlg-tracker-api --min-replicas 0     # idle = no replica cost
# If you upgraded ACR: delete replicas, then:  az acr update -n $ACR --sku Basic
az acr update -n $ACR --admin-enabled false   # turn the shared admin user back off
```
Keep the registry (Basic costs cents per day) or delete it. Nothing later depends on it.

## 📣 Document it

```bash
git add notes/lab-12.md screenshots/lab-12 && git commit -m "Lab 12: ACR (import, auth, geo-replication), ACI sizing limits, Container Apps scale-to-zero, revisions + traffic split"
```

**LinkedIn post template:**
> Lab 12 of my AZ-104 hybrid build: same container images, three hosting models.
>
> 📦 Private Azure Container Registry; imported images with `az acr import` (no local Docker); tried Premium geo-replication to Europe and Singapore
> ⚡ Azure Container Instances in Singapore, then hit the wall: CPU/memory changes require deleting the container group, and ACI has no autoscale
> 📈 Azure Container Apps in Amsterdam: HTTP scale rule 0→5 replicas under load, back to zero when idle
> 🔀 Multiple-revision mode with an 80/20 canary split and a label URL for direct testing
>
> Takeaway: ACI is "run this container now". Container Apps is "run my service and scale it for me".
> #Azure #AZ104 #Containers #AzureContainerApps #LearningInPublic
