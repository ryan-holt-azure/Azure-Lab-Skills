# Lab 06 — Secure Access: NSGs, ASGs, Bastion, Service Endpoints and Private Endpoints

> **Scenario:** HLG's security review found three problems. **(1)** Every VM in the EU spoke accepts traffic from anywhere in the network. **(2)** Admins want SSH/RDP without public IPs. **(3)** Shipment manifests sit in storage accounts reachable from the whole internet. You'll lock the EU web tier down to specific sources with NSGs and ASGs, add Bastion in the hub, put the EU storage account behind a service endpoint, and move HLG's shared data account behind a private endpoint with private DNS.
>
> **Time:** ~3 h · **Cost:** ~$0.60 (Bastion Basic for ~2 h + private endpoint) · **Prereqs:** Labs 03–05

## What you'll build

```
nsg-snet-app-weu (subnet NSG on vnet-hlg-spoke-weu/snet-app)
  100  Allow-Bastion-SSH        10.20.1.0/26  → any            TCP 22
  200  Allow-APAC-to-EU-Web     10.40.0.0/16  → asg-hlg-weu-web TCP 80
  4000 Deny-VNet-Inbound        VirtualNetwork → any           any      (overrides default 65000)

bas-hlg-hub-eus (Basic) ──peering──► SSH to VMs in both spokes

sthlgweu…  (West Europe) ── service endpoint Microsoft.Storage ◄── WEU snet-app only
sthlgdata… (East US)     ── private endpoint 10.20.3.x in hub snet-pe
                            privatelink.blob.core.windows.net linked to hub, WEU, SEA (not Chicago... yet)
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Implement Azure Bastion | Task 1 |
| Create and configure network security groups (NSGs) and application security groups | Task 2 |
| Evaluate effective security rules in NSGs | Task 3 |
| Configure service endpoints for Azure platform as a service (PaaS) | Task 4 |
| Configure private endpoints for Azure PaaS | Task 5 |
| Configure Azure DNS | Task 5 (private DNS zone for Private Link) |

Reuse the `rc` helper from Lab 05:
```bash
rc() { az vm run-command invoke -g "$1" -n "$2" --command-id RunShellScript --scripts "$3" --query "value[0].message" -o tsv; }
```

---

## Task 1 — Azure Bastion in the hub

1. **Create a resource → Bastion**:
   - RG `rg-hlg-hub-eus` · Name `bas-hlg-hub-eus` · Region East US
   - **Tier: Basic**
   - VNet `vnet-hlg-hub-eus`. The `AzureBastionSubnet` (/26) already exists from the Bicep.
   - Public IP: **Create new** `pip-bas-hlg-hub-eus` (Standard)
   - Create. It takes about 10 minutes. (Alternatively: `az deployment group create -g rg-hlg-hub-eus --template-file iac/bicep/bastion.bicep --parameters owner=<you>`.)
2. Connect across peering: `vm-hlg-sea-app01` → **Connect → Bastion** → username `hlgadmin`, authentication **VM Password** → **Connect**. A browser tab opens an SSH session.
3. In the session: `curl -s localhost | grep Host` and `ip -4 addr show eth0`.

> [!TIP]
> **🎯 EXAM TIP — Bastion SKUs:**
>
> | | Developer | Basic | Standard | Premium |
> |---|---|---|---|---|
> | Cost | Free (shared infra, select regions) | Hourly | Hourly | Hourly |
> | `AzureBastionSubnet` + public IP | Not needed | Required | Required | Required (or private-only) |
> | VMs in **peered** VNets | **No** | Yes | Yes | Yes |
> | Concurrent connections | One VM at a time | Yes | Yes, scalable host instances | Yes |
> | Native client (`az network bastion ssh/rdp`), IP-based connect, shareable links, file transfer | — | — | Yes | Yes |
> | Session recording, private-only deployment | — | — | — | Yes |
>
> The subnet must be named exactly **`AzureBastionSubnet`** and be **/26 or larger**. The target VMs need **no public IP**. You can upgrade a SKU but not downgrade.

> [!TIP]
> **🎯 EXAM TIP — Bastion RBAC.** To connect, a user needs **Reader** on the VM, the VM's NIC and the Bastion resource (plus the target VNet when Bastion is in a peered VNet), and valid OS credentials. If an NSG is applied to `AzureBastionSubnet` it must allow Bastion's required ports: 443 inbound from Internet and GatewayManager, and 22/3389 outbound to VirtualNetwork, among others.

> [!WARNING]
> **💲 COST.** Bastion Basic bills every hour it exists. Delete it at the end of this lab (Clean up) and redeploy it with `bastion.bicep` when a later lab needs it.

> 📸 **Checkpoint 06-01** — The Bastion SSH session to the SEA VM, showing its hostname and IP. → `screenshots/lab-06/06-01-bastion-ssh.png`

---

## Task 2 — NSG rules with an application security group

**Goal:** In the EU app subnet, only allow (a) SSH from Bastion and (b) HTTP from APAC to web servers. Deny all other VNet traffic.

1. **Create an ASG:** **Application security groups → + Create** → `asg-hlg-weu-web`, RG `rg-hlg-spoke-weu`, **West Europe**.
2. **Put the VM in it:** `vm-hlg-weu-app01` → **Networking** → **Application security groups** → **Add** → `asg-hlg-weu-web`.
3. **Rules:** `nsg-snet-app-weu` → **Inbound security rules** → **+ Add**:

   | Priority | Name | Source | Destination | Service/Port | Action |
   |---|---|---|---|---|---|
   | 100 | `Allow-Bastion-SSH` | IP `10.20.1.0/26` | Any | TCP 22 | Allow |
   | 200 | `Allow-APAC-to-EU-Web` | IP `10.40.0.0/16` | **ASG** `asg-hlg-weu-web` | TCP 80 | Allow |
   | 4000 | `Deny-VNet-Inbound` | **Service tag** `VirtualNetwork` | Any | Any | Deny |

4. Test:
   ```bash
   rc rg-hlg-spoke-sea vm-hlg-sea-app01 "curl -s -m 5 10.30.1.4 | grep Host || echo BLOCKED"   # allowed (rule 200)
   rc rg-hlg-hub-eus   vm-hlg-hub-nva01 "curl -s -m 5 10.30.1.4 | grep Host || echo BLOCKED"   # BLOCKED (rule 4000)
   ```
   Bastion SSH into `vm-hlg-weu-app01` still works (rule 100).

Why does SEA's traffic match rule 200 even though it passes through the NVA? The NVA forwards packets **without NAT**, so they arrive with source `10.40.1.4`.

> [!TIP]
> **🎯 EXAM TIP — NSG rule processing:**
> - Priority **100–4096**. **Lower number = evaluated first**, and processing **stops at the first match**.
> - Rules are **stateful**: return traffic is allowed automatically.
> - **Default rules** (priorities 65000+) can't be deleted, only overridden. Inbound: `AllowVnetInBound`, `AllowAzureLoadBalancerInBound`, `DenyAllInBound`. Outbound: `AllowVnetOutBound`, `AllowInternetOutBound`, `DenyAllOutBound`.
> - The **`VirtualNetwork` service tag** covers the VNet's address space, **peered VNets**, and **on-prem ranges connected through a gateway**. That's why it's broader than you might think.
> - An NSG must be in the **same region** as the subnet/NIC it's associated with.

> [!TIP]
> **🎯 EXAM TIP — Application security groups** let rules target "web servers" instead of IP lists. All NICs in an ASG must be in the **same VNet**, and when a rule uses ASGs as both source and destination, both ASGs must be in that same VNet. ASGs are regional resources.

> 📸 **Checkpoint 06-02** — The inbound rules list, plus the ALLOWED/BLOCKED test output. → `screenshots/lab-06/06-02-nsg-asg-rules.png`

<details><summary>CLI equivalent</summary>

```bash
az network asg create -g rg-hlg-spoke-weu -n asg-hlg-weu-web -l westeurope
az network nic ip-config update -g rg-hlg-spoke-weu --nic-name nic-vm-hlg-weu-app01 -n ipconfig1 --asgs asg-hlg-weu-web
az network nsg rule create -g rg-hlg-spoke-weu --nsg-name nsg-snet-app-weu -n Allow-APAC-to-EU-Web --priority 200 \
  --source-address-prefixes 10.40.0.0/16 --destination-asgs asg-hlg-weu-web --destination-port-ranges 80 --protocol Tcp --access Allow
```
</details>

---

## Task 3 — Evaluate effective security rules

1. `vm-hlg-weu-app01` → **Networking** → NIC → **Effective security rules** (the VM must be running). Expand the `VirtualNetwork` tag in rule 4000 to see the prefixes it really covers, including 10.20/16 and 10.40/16 from peering.
2. **Network Watcher → NSG diagnostics**: target `vm-hlg-weu-app01`, inbound, TCP, source `10.20.4.4`, destination `10.30.1.4:80` → **Deny**, matched by `Deny-VNet-Inbound`.
3. **Add a NIC-level NSG to see two layers:**
   - Create NSG `nsg-nic-demo` (West Europe) with inbound rule priority 100, **Deny** TCP 22 from Any.
   - Associate it with `nic-vm-hlg-weu-app01` (NIC → Network security group).
   - Try Bastion SSH to the WEU VM → fails. Effective security rules now shows **two** NSGs.
   - Remove the association and delete `nsg-nic-demo`.

> [!TIP]
> **🎯 EXAM TIP — Subnet NSG + NIC NSG.** Both are evaluated and **both must allow** the traffic. **Inbound: subnet NSG first, then NIC NSG. Outbound: NIC NSG first, then subnet NSG.** A typical question gives you both rule sets and asks whether a flow succeeds. Work through them in that order.

> 📸 **Checkpoint 06-03** — Effective security rules with two NSGs listed, plus the NSG diagnostics Deny result. → `screenshots/lab-06/06-03-effective-rules.png`

---

## Task 4 — Service endpoint for the EU storage account

**Goal:** EU manifests stay in West Europe and are reachable only from the EU app subnet.

1. **Create a storage account**: `sthlgweu<random digits>`, RG `rg-hlg-spoke-weu`, **West Europe**, Standard, **LRS**. Defaults elsewhere.
2. Container `eu-manifests` (private). Upload any small JSON file as `route-ams-sin.json`. The portal upload with *Access key* auth is fine here.
3. Blob → **Generate SAS** → signing method *Account key*, permission **Read**, expiry tomorrow, HTTPS only → copy the **Blob SAS URL** into a shell variable (never into notes or screenshots):
   ```bash
   read -r -p "EU blob SAS URL: " EU_SAS; curl -s -o /dev/null -w "%{http_code}\n" "$EU_SAS"    # 200 from Cloud Shell
   ```
4. **Enable the service endpoint:** `vnet-hlg-spoke-weu` → **Subnets** → `snet-app` → **Service endpoints** → add **Microsoft.Storage** → Save.
5. **Restrict the account:** storage account → **Networking** → *Public network access* = **Enabled from selected virtual networks and IP addresses** → **+ Add existing virtual network** → `vnet-hlg-spoke-weu` / `snet-app` → Save. Leave **Allow Azure services on the trusted services list** checked; Lab 14's flow logs need it.
6. Test:
   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" "$EU_SAS"                                    # 403 from Cloud Shell
   rc rg-hlg-spoke-weu vm-hlg-weu-app01 "curl -s -o /dev/null -w '%{http_code}' '$EU_SAS'"  # 200 from the EU subnet
   ```

> [!TIP]
> **🎯 EXAM TIP — Service endpoint facts:**
> - Enabled **per subnet, per service**. Traffic to the service uses the Azure backbone with the subnet's **private** source IP.
> - The PaaS resource **keeps its public endpoint and public IP**. You restrict it with a **virtual network rule**.
> - `Microsoft.Storage` reaches accounts in the **same region**. **`Microsoft.Storage.Global`** reaches accounts in **any region**. A subnet can have only one of the two.
> - Once a subnet has the endpoint, **IP rules for that subnet's public IPs stop matching**. Use the VNet rule.
> - **Service endpoint policies** restrict *which* storage accounts the subnet can reach (data exfiltration control).
> - It doesn't work from on-premises or from peered VNets. Each subnet needs its own endpoint.

> [!CAUTION]
> **⚠️ EXAM TRAP — Storage IP rules don't apply to requests from the same Azure region as the account.** Those use private Azure addresses. To allow an Azure VM in the same region, use a VNet rule (service endpoint) or a private endpoint, not its outbound public IP.

> 📸 **Checkpoint 06-04** — The storage Networking blade with the VNet rule, plus 403 vs 200. Blur everything after `?` in any URL. → `screenshots/lab-06/06-04-service-endpoint.png`

---

## Task 5 — Private endpoint and private DNS for HLG's shared data

**Goal:** `sthlgdata…` (East US, from Lab 03) gets a private IP in the hub, and its public endpoint is switched off.

1. Upload a test blob first, while public access is still on: container `manifests` → upload `route-chi-ams.json` (Entra auth works now that you have the Lab 04 data role). Generate a **Read** SAS URL for it:
   ```bash
   read -r -p "Data blob SAS URL: " DATA_SAS
   DATA_HOST=$(echo "$DATA_SAS" | sed -E 's#https://([^/]+)/.*#\1#'); echo $DATA_HOST
   ```
2. Storage account → **Networking** → **Private endpoint connections** → **+ Private endpoint**:
   - Name `pe-hlg-sthlgdata-blob` · Region **East US**
   - Resource: target sub-resource **blob**
   - VNet `vnet-hlg-hub-eus` / subnet `snet-pe` · dynamic IP
   - DNS: **Integrate with private DNS zone = Yes** → `privatelink.blob.core.windows.net` in `rg-hlg-hub-eus`
3. Open **Private DNS zones** → `privatelink.blob.core.windows.net`:
   - **Recordsets**: an **A** record `sthlgdata…` → `10.20.3.4`
   - **Virtual network links**: the hub link was created for you. **+ Add** `link-hlg-spoke-weu` (vnet-hlg-spoke-weu) and `link-hlg-spoke-sea` (vnet-hlg-spoke-sea). Leave **auto registration off**.
4. Test name resolution and access from a spoke:
   ```bash
   rc rg-hlg-spoke-sea vm-hlg-sea-app01 "getent hosts $DATA_HOST; curl -s -o /dev/null -w '%{http_code}' '$DATA_SAS'"
   ```
   Expect `10.20.3.4` and `200`. Compare `nslookup $DATA_HOST` in **Cloud Shell**: a public IP via a `privatelink` CNAME.
5. **Close the public door:** Networking → *Public network access* = **Disabled** → Save. Then:
   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" "$DATA_SAS"      # 403 from Cloud Shell
   ```
   SEA still gets `200` through the private endpoint.
6. Notice the side effect: the portal's **Storage browser** for this account now fails from your PC too. Portal data operations run from **your browser's network**.

> [!TIP]
> **🎯 EXAM TIP — Private endpoint vs service endpoint:**
>
> | | Service endpoint | Private endpoint (Private Link) |
> |---|---|---|
> | What you get | Optimized route + VNet rule | A **NIC with a private IP** for one sub-resource |
> | PaaS public endpoint | Still exists (restricted by rules) | Can be **disabled** entirely |
> | Reachable from peered VNets / on-prem (VPN/ER) | No | **Yes** |
> | DNS changes needed | No | **Yes**: `privatelink.*` zone (or on-prem forwarding) |
> | Cost | Free | Hourly + per GB |
> | Granularity | Whole service in region (or global) | **Per resource, per sub-resource** (blob, file, dfs, queue, table, web…) |

> [!TIP]
> **🎯 EXAM TIP — Private DNS for Private Link.** Clients keep using the **public FQDN** (`acct.blob.core.windows.net`). Azure DNS answers with a CNAME to `acct.privatelink.blob.core.windows.net`, and the private zone resolves that to the private IP. The zone must be **linked to every VNet** whose clients resolve the name. Zone names to recognize: `privatelink.blob.core.windows.net`, `privatelink.file.core.windows.net`, `privatelink.vaultcore.azure.net`, `privatelink.azurewebsites.net`, `privatelink.database.windows.net`, `privatelink.azurecr.io`.

> [!NOTE]
> **Chicago can't use this yet.** `vnet-hlg-onprem-chi` isn't linked to the private zone, which is how a real on-prem DNS server behaves, and there's no VPN yet. Lab 07 connects Chicago and shows the classic hybrid DNS problem and its fix.

> 📸 **Checkpoint 06-05** — The private DNS zone's A record and its three VNet links, plus `getent hosts` returning 10.20.3.4. → `screenshots/lab-06/06-05-private-endpoint.png`

---

## Break-fix challenges

1. Remove `link-hlg-spoke-sea` from the private zone. Re-run the SEA test. What IP does it resolve to now, and what HTTP code do you get? Restore the link.
2. Add an NSG rule on `nsg-snet-app-weu` at priority **150** that **denies** TCP 80 from `10.40.0.0/16`. Does SEA → WEU still work? Use NSG diagnostics to prove it. Delete the rule afterwards.
3. Elena (Lab 04) says *"The storage browser says I'm not authorized, but my role hasn't changed."* What changed?

<details><summary>Fixes</summary>

1. It resolves to the account's **public** IP (no private zone for that VNet), and the request returns **403** because public access is disabled. DNS, not RBAC, is the usual first suspect with private endpoints.
2. Blocked. Priority 150 is evaluated before 200, and the first match wins.
3. Public network access was disabled. Her browser is on the internet, so data-plane calls from the portal are refused. Real fixes: access from a network that reaches the private endpoint, or add her IP as a firewall rule with public access set to *selected networks*.
</details>

---

## Knowledge check

1. NSG1 (subnet) allows TCP 80 inbound from Any at priority 200. NSG2 (NIC) has only default rules. Can an internet client reach port 80 on the VM's public IP?
2. You need an Azure SQL logical server reachable from on-premises over ExpressRoute with no public endpoint. Service endpoint or private endpoint?
3. Users in a peered VNet can't reach a storage account that has a service endpoint rule for the hub subnet only. Why?
4. Which subnet name and minimum size does Bastion Basic require?
5. A private endpoint was created, but clients still resolve the public IP. Name two likely causes.

<details><summary>Answers</summary>

1. **No.** NSG2's default `DenyAllInBound` blocks internet traffic (`AllowVnetInBound` doesn't match internet sources). Both NSGs must allow.
2. **Private endpoint.** Service endpoints don't extend to on-prem.
3. Service endpoints and VNet rules are **per subnet**. The peered VNet's subnet needs its own endpoint and rule, or use a private endpoint.
4. `AzureBastionSubnet`, **/26 or larger**.
5. The private DNS zone isn't **linked** to the client's VNet. The client uses a **custom DNS server** that doesn't forward to Azure DNS (168.63.129.16). Or the A record/zone group is missing.
</details>

---

## Clean up

```bash
az network bastion delete -g rg-hlg-hub-eus -n bas-hlg-hub-eus
az network public-ip delete -g rg-hlg-hub-eus -n pip-bas-hlg-hub-eus
bash scripts/cost-check.sh
```
**Keep:** NSG rules, ASG, service endpoint and `sthlgweu…`, the private endpoint and the DNS zone. Labs 07, 13, 14 and 16 build on them.

## 📣 Document it

```bash
git add notes/lab-06.md screenshots/lab-06 && git commit -m "Lab 06: NSG + ASG least-access, effective rules, Bastion over peering, service vs private endpoints"
```

**LinkedIn post template:**
> Lab 06 of my AZ-104 hybrid build: closing doors.
>
> 🛡️ EU web tier: only SSH from Bastion and HTTP from APAC (targeted with an application security group), with an explicit deny overriding the default allow-VNet rule
> 🔍 Effective security rules + NSG diagnostics with a subnet NSG and a NIC NSG at the same time (inbound: subnet first, then NIC)
> 🧱 One Bastion in the hub reaching VMs in both spokes over peering. No public IPs on any VM.
> 🔌 Service endpoint: EU storage reachable only from the EU app subnet (403 from anywhere else)
> 🔒 Private endpoint + private DNS for the shared data account, public access disabled, resolving to 10.20.3.4 from both spokes
>
> Lesson: with private endpoints, "access denied" is usually DNS. Remove one VNet link and the name quietly resolves to the public IP again.
> #Azure #AZ104 #NetworkSecurity #PrivateLink #LearningInPublic
