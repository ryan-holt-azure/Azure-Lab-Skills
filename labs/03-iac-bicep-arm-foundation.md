# Lab 03 — Infrastructure as Code: Deploy the Hybrid Foundation with Bicep and ARM

> **Scenario:** HLG's CTO won't accept "click-ops" networks. The four-region foundation (Chicago on-prem, East US hub, West Europe and Southeast Asia spokes) has to be reproducible from Git. You'll read, deploy, modify, export and convert the templates that build it.
>
> **Time:** ~3 h (includes ~15 min of deployment time) · **Cost:** ~$1/day while the 4 small VMs run (deallocate with `scripts/stop-all-vms.sh`) · **Prereqs:** Labs 00, 02

## What you'll build

```
                          ┌──────────────────────────────┐
                          │  vnet-hlg-hub-eus 10.20/16   │  East US
                          │  GatewaySubnet  AzureBastion │
                          │  snet-shared snet-pe snet-nva│── vm-hlg-hub-nva01 10.20.4.4
                          └───────┬──────────────┬───────┘
              global peering      │              │      global peering
       ┌──────────────────────────┘              └──────────────────────────┐
┌──────┴──────────────────────┐                        ┌────────────────────┴────────┐
│ vnet-hlg-spoke-weu 10.30/16 │ West Europe            │ vnet-hlg-spoke-sea 10.40/16 │ Southeast Asia
│ snet-app snet-web           │                        │ snet-app (+ snet-data)      │
│ snet-appsvc-int snet-pe     │                        │                             │
└── vm-hlg-weu-app01 10.30.1.4┘                        └── vm-hlg-sea-app01 10.40.1.4┘

┌─────────────────────────────┐   NOT peered — Chicago reaches Azure only through the
│ vnet-hlg-onprem-chi 10.10/16│   site-to-site VPN in Lab 07, like a real datacenter.
│ snet-servers GatewaySubnet  │   North Central US (Illinois)
└── vm-hlg-chi-srv01 10.10.1.4┘
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Interpret an Azure Resource Manager template or a Bicep file | Task 1 |
| Deploy resources by using an Azure Resource Manager template or a Bicep file | Tasks 2, 4, 6 |
| Modify an existing Bicep file | Task 5 |
| Modify an existing Azure Resource Manager template | Task 6 |
| Export a deployment as an Azure Resource Manager template or convert an Azure Resource Manager template to a Bicep file | Task 8 |
| Configure resource locks | Task 3 |

---

## Task 1 — Interpret the Bicep and its ARM output

Open these in VS Code with the Bicep extension, or in Cloud Shell's editor (`code iac/bicep/main.bicep`):

| File | What it does |
|---|---|
| [`iac/bicep/main.bicep`](../iac/bicep/main.bicep) | Subscription scope: 8 RGs, 4 VNets (via module), 4 peerings |
| [`iac/bicep/modules/vnet.bicep`](../iac/bicep/modules/vnet.bicep) | One VNet, its subnets and NSGs |
| [`iac/bicep/modules/peering.bicep`](../iac/bicep/modules/peering.bicep) | One direction of a peering, using `existing` |
| [`iac/bicep/workloads.bicep`](../iac/bicep/workloads.bicep) | 4 small Ubuntu VMs with conditional deployment |
| [`iac/bicep/modules/linux-vm.bicep`](../iac/bicep/modules/linux-vm.bicep) | NIC + VM, Trusted Launch, cloud-init |

**Answer these in your notes before opening the answers:**
1. What `targetScope` does `main.bicep` use, and why can't it be `resourceGroup`?
2. How many NSGs does the hub get, and which expression decides that?
3. Which subnets get the `defaultOutboundAccess` property, and why isn't it set on `GatewaySubnet`?
4. `peerHubToApac` has `dependsOn: [ vnetHub, peerHubToEu ]`. Why the second item?
5. What does the `existing` keyword in `peering.bicep` do? Does it create anything?
6. In `workloads.bicep`, what happens to `vm-hlg-hub-nva01` if `deployNva = false`?
7. `adminPassword` is decorated `@secure()`. What does that change, and where does its value come from?
8. When is `loadTextContent('cloudinit/web.yaml')` evaluated: at compile time or deploy time?

Now compile to ARM JSON and read the generated template:
```bash
cd ~/clouddrive/az104-hybrid-labs
az bicep build --file iac/bicep/modules/vnet.bicep --outfile /tmp/vnet.json
less /tmp/vnet.json      # find: "copy", "union(", "resourceId(", "dependsOn"
```

<details><summary>Answers</summary>

1. `subscription`, because it creates **resource groups**, which live at subscription scope. Modules then target RGs with `scope: rgHub`.
2. Two (`snet-shared`, `snet-nva`). `filter(subnets, sub => sub.nsg)` in `vnet.bicep` loops only over subnets with `nsg: true`.
3. Subnets with `workload: true`. Gateway, Bastion and private-endpoint subnets don't host VMs, so the property isn't relevant there and is left out with `union(..., s.workload ? {...} : {})`.
4. Two peerings on the **same VNet** deployed in parallel can conflict (`AnotherOperationInProgress`). The explicit `dependsOn` serializes them.
5. `existing` references a resource that's already deployed so you can use its properties (`parent: localVnet`). It creates nothing.
6. The module is conditional (`if (deployNva)`), so it's skipped: no NVA VM and no NIC.
7. `@secure()` keeps the value out of deployment history and logs. In `workloads.bicepparam` it comes from `readEnvironmentVariable('HLG_ADMIN_PASSWORD')`, so it never lives in Git.
8. **Compile time.** The file's content is embedded into the generated JSON. ARM never reads your local file.
</details>

> [!TIP]
> **🎯 EXAM TIP — ARM template anatomy.** `$schema`, `contentVersion`, `parameters`, `variables`, `functions`, `resources`, `outputs`. Only **`$schema`, `contentVersion` and `resources`** are required. Bicep compiles to exactly this. Bicep loops (`for`) become ARM **`copy`** blocks; Bicep symbolic references become `resourceId()`/`reference()` calls and implicit `dependsOn`.

> [!TIP]
> **🎯 EXAM TIP — Bicep vocabulary you'll be asked to read:** `param`, `var`, `resource <symbol> '<type>@<apiVersion>'`, `module`, `output`, `existing`, `parent:`, `scope:`, `if (...)`, `[for x in y: {...}]`, decorators `@description`, `@allowed`, `@minLength/@maxLength`, `@minValue/@maxValue`, `@secure`. In parameter files: `.bicepparam` with `using './main.bicep'`, or the older JSON `*.parameters.json`.

---

## Task 2 — What-if and deploy the foundation

1. Put your alias in the parameter files:
   ```bash
   sed -i "s/your-alias/<you>/" iac/bicep/*.bicepparam
   ```
2. **Preview** the deployment:
   ```bash
   az deployment sub what-if --name hlg-foundation --location eastus \
     --template-file iac/bicep/main.bicep --parameters iac/bicep/main.bicepparam
   ```
   Read the legend. You'll see the RGs from Lab 02 as **NoChange** or **Modify** (tags), and VNets/NSGs as **Create**.
3. **Deploy** (about 3–5 minutes):
   ```bash
   az deployment sub create --name hlg-foundation --location eastus \
     --template-file iac/bicep/main.bicep --parameters iac/bicep/main.bicepparam
   ```
4. Verify in the portal:
   - **Subscriptions → Deployments → hlg-foundation**: the nested **module** deployments are listed by name.
   - Each VNet → **Peerings**: hub ↔ WEU and hub ↔ SEA show **Connected**. The Chicago VNet has **no** peerings.
   - **Resource groups**: a new **NetworkWatcherRG** appeared, and it carries `CostCenter=CC-1001`. The Lab 02 *Add a tag* (Modify) policy did that. Without it, the Deny policy would have blocked Network Watcher.

> [!TIP]
> **🎯 EXAM TIP — Deployment scopes and commands.**
>
> | Scope | Azure CLI | PowerShell |
> |---|---|---|
> | Resource group | `az deployment group create` | `New-AzResourceGroupDeployment` |
> | Subscription | `az deployment sub create` (needs `--location`) | `New-AzSubscriptionDeployment` (alias `New-AzDeployment`) |
> | Management group | `az deployment mg create` | `New-AzManagementGroupDeployment` |
> | Tenant | `az deployment tenant create` | `New-AzTenantDeployment` |
>
> Subscription, MG and tenant deployments need a **location** because the deployment metadata has to be stored somewhere. `what-if` exists at every scope. PowerShell's equivalent is `-WhatIf` or `Get-AzResourceGroupDeploymentWhatIfResult`.

> 📸 **Checkpoint 03-01** — `what-if` output, plus the succeeded deployment with its module list. → `screenshots/lab-03/03-01-whatif-deploy.png`
> 📸 **Checkpoint 03-02** — Hub VNet peerings both **Connected**. → `screenshots/lab-03/03-02-peerings.png`

---

## Task 3 — Lock the hub VNet

```bash
az lock create --name lock-hub-vnet --lock-type CanNotDelete \
  --resource-group rg-hlg-hub-eus --resource-name vnet-hlg-hub-eus \
  --resource-type Microsoft.Network/virtualNetworks --notes "Hub network - change control required"
```
Test it: portal → `vnet-hlg-hub-eus` → **Subnets** → try deleting `snet-shared` → blocked. The lock inherits to child resources such as subnets and peerings.

> [!TIP]
> **🎯 EXAM TIP — Lock the resource, not always the RG.** A CanNotDelete lock on the hub **RG** would also stop you deleting Bastion and the VPN gateways later. Locking the VNet resource protects what matters and leaves the rest manageable.

---

## Task 4 — Deploy the workload VMs

1. Set the VM admin password in your shell only (12+ characters, mixed classes):
   ```bash
   read -rs -p "VM admin password: " HLG_ADMIN_PASSWORD; export HLG_ADMIN_PASSWORD; echo
   ```
2. Deploy:
   ```bash
   az deployment sub create --name hlg-workloads --location eastus \
     --template-file iac/bicep/workloads.bicep --parameters iac/bicep/workloads.bicepparam
   ```
   If one region fails with `SkuNotAvailable`, set `vmSize` to `Standard_B2ats_v2` or `Standard_B2als_v2` (both allowed by your Lab 02 policy) and redeploy. Deployments are idempotent, so the VMs that succeeded are left alone.
3. Each VM serves a web page on port 80. Test without any public IP or Bastion using **Run Command**:
   ```bash
   az vm run-command invoke -g rg-hlg-spoke-weu -n vm-hlg-weu-app01 \
     --command-id RunShellScript --scripts "curl -s localhost" --query "value[0].message" -o tsv
   ```
4. Look at the deployment's **Inputs** in the portal: `adminPassword` doesn't appear. That's `@secure()` working.

> [!TIP]
> **🎯 EXAM TIP — Run Command** executes a script inside a VM through the **VM agent**. No inbound ports, public IP or Bastion are needed. It needs `Microsoft.Compute/virtualMachines/runCommand/action` (Virtual Machine Contributor has it). Remember it as the fix when a question says "you can't RDP/SSH but need to run a command."

> 📸 **Checkpoint 03-03** — Run Command output showing the HLG page from `vm-hlg-weu-app01`. → `screenshots/lab-03/03-03-run-command.png`

---

## Task 5 — Modify an existing Bicep file

Make three changes to `main.bicep`:

1. **Add a subnet.** In `networks.spokeApac.subnets`, replace the `LAB 03` comment with:
   ```bicep
   { name: 'snet-data', prefix: '10.40.2.0/24', nsg: true, delegation: '', workload: true }
   ```
2. **Constrain a parameter.** Add above `param environment`:
   ```bicep
   @allowed([ 'lab', 'dev', 'prod' ])
   ```
3. **Add an output** at the bottom:
   ```bicep
   output hubVnetName string = networks.hub.name
   ```

Now prove each change:
```bash
az bicep build --file iac/bicep/main.bicep                     # compile errors show here
az deployment sub what-if --name hlg-foundation --location eastus \
  --template-file iac/bicep/main.bicep --parameters iac/bicep/main.bicepparam
```
Expected: **+ Create** `nsg-snet-data-sea`, **~ Modify** `vnet-hlg-spoke-sea` (subnets). Deploy it with the same `create` command as Task 2.

Test the `@allowed` decorator: temporarily set `param environment = 'test'` in `main.bicepparam` and run `az bicep build-params --file iac/bicep/main.bicepparam`. You get an error at **compile time**, before anything reaches Azure. Change it back.

> [!CAUTION]
> **⚠️ DRIFT TRAP (exam and real life) — Incremental mode still overwrites what's in the template.** Incremental mode leaves resources that **aren't** in the template alone. Resources that **are** in the template get exactly the properties written there. Here the subnets are an inline array on the VNet, so redeploying `main.bicep` after you've (say) associated a route table in the portal **removes that association**. The rule for the rest of the series: after Lab 05, either codify portal changes in the Bicep first, or don't redeploy `main.bicep`.

> 📸 **Checkpoint 03-04** — `what-if` showing the new subnet and NSG, plus the `@allowed` compile error. → `screenshots/lab-03/03-04-modify-bicep.png`

---

## Task 6 — Modify an existing ARM template

[`iac/arm/storage-account.json`](../iac/arm/storage-account.json) deploys HLG's shared data storage account. It's missing four things. Edit the JSON:

| # | Change | Where |
|---|---|---|
| 1 | Restrict `skuName` to `Standard_LRS`, `Standard_ZRS`, `Standard_GRS`, `Standard_RAGRS` | `parameters.skuName.allowedValues` |
| 2 | Enforce `minimumTlsVersion: "TLS1_2"`, `supportsHttpsTrafficOnly: true`, `allowBlobPublicAccess: false` | storage `properties` |
| 3 | Add a private blob container named `manifests` | new resource of type `Microsoft.Storage/storageAccounts/blobServices/containers`, name `[format('{0}/default/manifests', variables('storageAccountName'))]`, with `dependsOn` the account |
| 4 | Output the primary blob endpoint | `outputs.blobEndpoint` using `reference(...).primaryEndpoints.blob` |

Validate, preview, deploy:
```bash
az deployment group validate -g rg-hlg-data-eus --template-file iac/arm/storage-account.json
az deployment group what-if  -g rg-hlg-data-eus --template-file iac/arm/storage-account.json
az deployment group create   -g rg-hlg-data-eus --name hlg-data-storage --template-file iac/arm/storage-account.json
az deployment group show -g rg-hlg-data-eus -n hlg-data-storage --query properties.outputs
```
Test change 1: `--parameters skuName=Premium_LRS` should fail validation.

Then do it the **portal** way once: **Deploy a custom template** → **Build your own template in the editor** → **Load file** → see how parameters render as a form → **Review + create** → cancel before creating.

Check your work against [`iac/arm/storage-account.solution.json`](../iac/arm/storage-account.solution.json).

> [!TIP]
> **🎯 EXAM TIP — Template functions to recognize:** `resourceGroup().location`, `subscription().subscriptionId`, `uniqueString(...)` (deterministic 13-character hash, which is why the account name is the same on every redeploy), `concat`/`format`, `resourceId(type, name)`, `reference(resourceId, apiVersion)` (runtime properties), `parameters()`, `variables()`, `copyIndex()`.

> 📸 **Checkpoint 03-05** — The deployment's Outputs showing `blobEndpoint`, plus the `Premium_LRS` validation failure. → `screenshots/lab-03/03-05-modify-arm.png`

---

## Task 7 — Incremental vs Complete mode (safely)

`rg-hlg-sandbox` contains `nsg-hlg-tagtest` from Lab 02. [`iac/arm/sandbox-nsg.json`](../iac/arm/sandbox-nsg.json) declares only `nsg-hlg-sandbox-keep`.

```bash
az network nsg list -g rg-hlg-sandbox -o table
az deployment group what-if -g rg-hlg-sandbox --template-file iac/arm/sandbox-nsg.json                  # Incremental (default)
az deployment group what-if -g rg-hlg-sandbox --template-file iac/arm/sandbox-nsg.json --mode Complete  # shows a Delete
az deployment group create  -g rg-hlg-sandbox --template-file iac/arm/sandbox-nsg.json --mode Complete
az network nsg list -g rg-hlg-sandbox -o table   # nsg-hlg-tagtest is gone
```

> [!TIP]
> **🎯 EXAM TIP — Deployment modes.**
> - **Incremental** (default): adds and updates resources in the template and leaves others untouched.
> - **Complete**: also **deletes** resources in the RG that aren't in the template. Only for **resource-group** scope deployments. Locked resources make it fail.
> - **Deployment stacks** are the modern way to manage "delete what's no longer declared", with deny settings that block out-of-band changes.

> 📸 **Checkpoint 03-06** — The Complete-mode `what-if` with the red **Delete** line. → `screenshots/lab-03/03-06-complete-mode.png`

---

## Task 8 — Export and convert

1. **Export a resource group (portal):** `rg-hlg-spoke-sea` → **Automation → Export template**. Read the warnings for resources that can't be exported. Download it. If your portal offers a **Bicep** tab, look at it too.
2. **Export from deployment history:** `rg-hlg-data-eus` → **Deployments** → `hlg-data-storage` → **Template**. This is the exact template that was deployed, not a reconstruction of current state.
3. **CLI equivalents:**
   ```bash
   mkdir -p /tmp/export && cd /tmp/export
   az group export -n rg-hlg-spoke-sea > exported-sea.json
   az deployment group export -g rg-hlg-data-eus -n hlg-data-storage > deployed-storage.json
   az deployment sub export -n hlg-foundation > deployed-foundation.json
   ```
4. **Convert ARM → Bicep:**
   ```bash
   az bicep decompile --file exported-sea.json        # writes exported-sea.bicep (expect warnings)
   az bicep decompile --file deployed-storage.json
   ```
   Compare `exported-sea.bicep` with `modules/vnet.bicep`: hard-coded names and IDs, no parameters, every default property spelled out. Exported templates are a starting point, not a finished product.
5. **Bicep → ARM** goes the other way: `az bicep build`.

> [!TIP]
> **🎯 EXAM TIP — Export facts:**
> - **Export from RG/resource** captures current state. Limit **200 resources**; some types can't be exported; **secrets aren't included**; the result often needs clean-up before it redeploys.
> - **Export from deployment history** gives the original template and parameters.
> - `az bicep decompile` is **best effort**: review the warnings.
> - Portal paths: resource/RG → **Automation → Export template**, and RG → **Settings → Deployments** → deployment → **Template**.

> 📸 **Checkpoint 03-07** — Side-by-side: the exported JSON and the decompiled Bicep. → `screenshots/lab-03/03-07-export-decompile.png`

---

## Break-fix challenges

1. You redeploy `workloads.bicep` with `deployNva=false`. Does the existing NVA VM get deleted? Predict, then check with `what-if`.
2. After Lab 09, you delete the `snet-web` line from `networks.spokeEu` and redeploy. The deployment fails with `InUseSubnetCannotBeDeleted`. Why, and what does that tell you about inline subnets?
3. A teammate runs `az deployment group create --mode Complete` against `rg-hlg-hub-eus` with a template that only contains Bastion. What happens to `vnet-hlg-hub-eus`?

<details><summary>Answers</summary>

1. No. Incremental mode ignores resources that aren't declared, and a skipped condition means "not declared". `what-if` shows the NVA as **Ignore**. Deleting it takes Complete mode or an explicit delete.
2. The subnets are an inline array, so the template is the desired subnet list. Redeploying without `snet-web` asks Azure to delete it. Azure refuses because the scale set's NICs use it. Azure protects **in-use subnets**, but it doesn't protect subnet **properties** such as route-table or service-endpoint settings. Those are silently reset.
3. Complete mode tries to delete everything not in the template, including the VNet. The CanNotDelete lock makes that deletion fail and the deployment reports an error. ARM deployments aren't transactional, so check the RG for anything else that was removed. Never run Complete mode against a shared RG.
</details>

---

## Knowledge check

1. Which deployment command and scope do you use for a template that creates resource groups?
2. A template contains `"copy": { "name": "nicLoop", "count": 3 }` on a NIC named `[concat('nic-web-', copyIndex(1))]`. Which NIC names are created?
3. You need the exact template used for last week's deployment, not the current state of the RG. Where do you get it?
4. Which Bicep keyword references a VNet created by another team without redeploying it?
5. What does `what-if` change type **Ignore** mean?

<details><summary>Answers</summary>

1. `az deployment sub create` / `New-AzSubscriptionDeployment`, with `targetScope = 'subscription'` in Bicep.
2. `nic-web-1`, `nic-web-2`, `nic-web-3`. `copyIndex(1)` starts at 1.
3. The RG's **Deployments** history → that deployment → **Template** (or `az deployment group export`).
4. `existing`.
5. The resource exists in Azure but isn't in the template. Incremental mode will leave it alone.
</details>

---

## Clean up

Keep everything. Between sessions, run `bash scripts/stop-all-vms.sh` to deallocate the four VMs (disks still bill pennies).

> [!WARNING]
> **💲 COST.** 4 × B1s ≈ $1/day running. Global VNet peering is billed per GB of traffic in each direction, which is negligible in these labs.

## 📣 Document it

```bash
git add iac notes/lab-03.md screenshots/lab-03 && git commit -m "Lab 03: Bicep foundation (4 regions, hub-spoke), ARM modify/validate, complete mode, export/decompile"
```

**LinkedIn post template:**
> Lab 03 of my AZ-104 hybrid build: the whole 4-region network from Bicep, in one subscription-scope deployment.
>
> 🧱 8 resource groups, 4 VNets, NSGs and global hub-spoke peerings, with a simulated Chicago datacenter deliberately not peered (it gets a VPN in Lab 07)
> 🔐 VM passwords supplied via `readEnvironmentVariable()` + `@secure()`, so nothing sensitive lives in Git or deployment history
> 🔎 `what-if` before every change; modified a Bicep file and an ARM template, with `@allowed` and `allowedValues` catching bad input
> 💥 Ran Complete mode on purpose in a sandbox RG to watch it delete an undeclared resource
> 🔁 Exported a resource group and decompiled the ARM JSON to Bicep (and saw why exports aren't production-ready)
>
> Biggest lesson: Incremental mode isn't "safe mode". Inline subnet arrays overwrite portal changes on redeploy.
> #Azure #AZ104 #Bicep #InfrastructureAsCode #LearningInPublic
