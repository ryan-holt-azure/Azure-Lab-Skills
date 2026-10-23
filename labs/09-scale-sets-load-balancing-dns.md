# Lab 09 — Scale Sets, Load Balancers and Azure DNS

> **Scenario:** HLG's public **shipment-tracking site** runs in West Europe and must scale with demand across zones. The **APAC orders API** must stay internal, load-balanced and reachable by name from every network. Marketing also wants `www` under a company domain. You'll build a zone-spread VM scale set behind a public Standard load balancer, an internal load balancer in Southeast Asia, public and private DNS zones, and then break the load balancer twice and fix it.
>
> **Time:** ~3.5 h · **Cost:** ~$0.80 (2–4 B1s instances, 2 load balancers, DNS zones) · **Prereqs:** Labs 03–06

## What you'll build

```
Internet ─► pip-lbe-hlg-weu-web ─► lbe-hlg-weu-web (Standard, public) ─► vmss-hlg-weu-web (Flexible, zones 1-3, 2-4 × B1s)
              ▲ www / @ alias in public zone hlg-<you>-lab.com                     snet-web (10.30.2.0/24)

hub/WEU ─► orders-api.sea.halsted.internal (private zone) ─► lbi-hlg-sea-orders 10.40.1.100 ─► vm-hlg-sea-app01 / app02
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Deploy and configure an Azure Virtual Machine Scale Sets | Tasks 2, 3 |
| Configure an internal or public load balancer | Tasks 1, 4 |
| Troubleshoot load balancing | Task 5 |
| Configure Azure DNS | Tasks 6, 7 |

```bash
rc() { az vm run-command invoke -g "$1" -n "$2" --command-id RunShellScript --scripts "$3" --query "value[0].message" -o tsv; }
```

---

## Task 1 — Public Standard load balancer

1. **Open the subnet's NSG first:** `nsg-snet-web-weu` → inbound rule **100** `Allow-Internet-HTTP`: source **Service tag Internet**, TCP **80**, Allow.
2. **Create a resource → Load balancer**:
   - RG `rg-hlg-spoke-weu` · Name `lbe-hlg-weu-web` · West Europe · **SKU Standard** · **Type Public** · **Tier Regional**
   - **Frontend IP:** `fe-public` → new public IP `pip-lbe-hlg-weu-web`, **zone-redundant**
   - **Backend pool:** `bep-web`, VNet `vnet-hlg-spoke-weu`, configuration **NIC**. Leave it empty; the scale set joins it in Task 2.
   - **Inbound rules → Load balancing rule** `lbr-http-80`: frontend `fe-public`, pool `bep-web`, TCP **80 → 80**, **new health probe** `hp-http-80` (**HTTP**, port 80, path **`/health`**, interval 5 s), session persistence **None**, idle timeout 4 min, floating IP **off**, outbound SNAT = *use outbound rules (recommended)*.
3. Create.

> [!TIP]
> **🎯 EXAM TIP — Load balancer basics:**
> - **Layer 4** (TCP/UDP) only. For HTTP routing, TLS termination or a WAF, use **Application Gateway** (regional) or **Front Door** (global).
> - **Standard** is the only SKU for new deployments (**Basic LB retired 30 Sept 2025**). Standard is **secure by default**: backends need an **NSG that allows** the client traffic.
> - Backend pool members must be in **one VNet**. Zone-redundant frontends and a 99.99% SLA are available.
> - Pieces: **frontend IP**, **backend pool**, **health probe** (TCP, HTTP, HTTPS), **load-balancing rule**, optional **inbound NAT rule** (port-forward to one instance), **outbound rule** (SNAT).
> - **Session persistence:** *None* (5-tuple hash), *Client IP* (2-tuple), *Client IP and protocol* (3-tuple).

> [!TIP]
> **🎯 EXAM TIP — Health probes come from `168.63.129.16`,** matched by the **`AzureLoadBalancer`** service tag. The default NSG rule `AllowAzureLoadBalancerInBound` (65001) allows them. Override it with a deny and every backend goes unhealthy (Task 5).

> 📸 **Checkpoint 09-01** — The LB's frontend, backend pool, probe and rule summary. → `screenshots/lab-09/09-01-public-lb.png`

---

## Task 2 — VM scale set (Flexible) behind the load balancer

1. Prepare custom data: `sed 's/__SITE__/Shipment tracker - West Europe scale set/' iac/bicep/cloudinit/web.yaml` and copy the output.
2. **Create a resource → Virtual machine scale set**:

   | Tab | Setting | Value |
   |---|---|---|
   | Basics | RG / name / region | `rg-hlg-spoke-weu` / `vmss-hlg-weu-web` / West Europe |
   | | Availability zone | **Zones 1, 2, 3** |
   | | Orchestration mode | **Flexible** |
   | | Security type / image / size | Trusted launch / Ubuntu Server 24.04 LTS Gen2 / **Standard_B1s** |
   | | Scaling | **Manual**, instance count **2** (autoscale comes in Task 3) |
   | | Auth | Password, `hlgadmin` |
   | Networking | VNet / NIC subnet | `vnet-hlg-spoke-weu` / edit the NIC → **`snet-web`**, NIC NSG **None**, public IP **Disabled** |
   | | Load balancing | **Azure load balancer** → `lbe-hlg-weu-web` → backend pool `bep-web` |
   | Management | Upgrade policy | **Manual** (read the Automatic and Rolling descriptions) |
   | Health | Application health monitoring | Optional: enable with HTTP `/health` |
   | Advanced | Custom data | Paste the cloud-init from step 1 |

3. When it's running:
   ```bash
   LB_IP=$(az network public-ip show -g rg-hlg-spoke-weu -n pip-lbe-hlg-weu-web --query ipAddress -o tsv)
   for i in $(seq 1 8); do curl -s http://$LB_IP | grep -o 'Host:</b> [^<]*'; done
   ```
   Responses alternate between instances. Each new TCP connection is a new 5-tuple.
4. LB → **Backend pools** → `bep-web` shows both instances. **Insights** shows the dependency map.

> [!TIP]
> **🎯 EXAM TIP — Flexible vs Uniform orchestration.** **Flexible** (the default) runs instances as regular VMs you can manage individually, mixes sizes, spreads across zones and fault domains, and supports most VM features. **Uniform** is identical instances managed as one resource (legacy, large stateless fleets). **Overprovisioning** is Uniform-only. Questions that say "add a specific existing VM type" or "different VM sizes in one set" point to Flexible.

> 📸 **Checkpoint 09-02** — The curl loop showing two different hostnames, plus the backend pool membership. → `screenshots/lab-09/09-02-vmss-lb.png`

---

## Task 3 — Scaling: manual, autoscale, scale-in policy

1. **Manual:** Scale set → **Scaling** → instance count **3** → Save. Watch the new instance join `bep-web`. Then set it back to **2**.
2. **Autoscale:** Scaling → **Custom autoscale**:
   - Default profile: minimum **2**, maximum **4**, default **2**
   - **Scale out:** *Percentage CPU* > **70** (average, 5 minutes) → increase count by **1**, cool down **5** min
   - **Scale in:** *Percentage CPU* < **25** (average, 10 minutes) → decrease count by **1**, cool down **5** min
   - Save. Open **Run history**.
3. **Generate load** on both instances:
   ```bash
   for n in $(az vm list -g rg-hlg-spoke-weu --query "[?starts_with(name,'vmss-hlg-weu-web')].name" -o tsv); do
     rc rg-hlg-spoke-weu "$n" "nohup timeout 900 bash -c 'yes > /dev/null' >/dev/null 2>&1 & echo started on \$(hostname)"
   done
   ```
   Within about 10 minutes, Run history shows a **scale-out** to 3 (then 4). About 15 minutes after the load stops, it **scales in**.
4. **Scale-in policy:** Scaling → **Scale-in policy** → read *Default*, *Newest VM*, *Oldest VM* → choose **Newest VM**.
5. **Instance protection:** Instances → select one → **Protect from scale-in**.

> [!TIP]
> **🎯 EXAM TIP — Autoscale rules.** Always pair a **scale-out** rule with a **scale-in** rule. Autoscale won't scale in below **minimum**, never exceeds **maximum**, and waits the **cool-down** between actions. Metrics can be host metrics (CPU, network, disk) or a schedule/date-based profile ("10 instances weekdays 08:00–18:00"). **Default** scale-in balances across zones and fault domains first, then removes the highest instance ID.

> [!CAUTION]
> **⚠️ B-series CPU credits.** Burstable VMs (B1s) run at full speed only while they have **CPU credits**. Once credits run out, the CPU is capped at its baseline, the metric drops, and autoscale may scale *in* while users still feel slow. Production autoscale belongs on non-burstable sizes.

> 📸 **Checkpoint 09-03** — Autoscale Run history showing scale-out and scale-in events. → `screenshots/lab-09/09-03-autoscale.png`

---

## Task 4 — Internal load balancer for the APAC orders API

1. Add a second SEA app server:
   ```bash
   sed 's/__SITE__/APAC Operations - Southeast Asia spoke (02)/' iac/bicep/cloudinit/web.yaml > /tmp/web-sea.yaml
   az vm create -g rg-hlg-spoke-sea -n vm-hlg-sea-app02 --image Ubuntu2404 --size Standard_B1s \
     --vnet-name vnet-hlg-spoke-sea --subnet snet-app --private-ip-address 10.40.1.5 \
     --public-ip-address "" --nsg "" --admin-username hlgadmin --admin-password "$HLG_ADMIN_PASSWORD" \
     --custom-data /tmp/web-sea.yaml --os-disk-delete-option Delete --nic-delete-option Delete
   ```
2. **Create a resource → Load balancer** → `lbi-hlg-sea-orders`, RG `rg-hlg-spoke-sea`, Southeast Asia, **Standard**, **Internal**:
   - Frontend `fe-orders`: VNet `vnet-hlg-spoke-sea`, subnet `snet-app`, **static** `10.40.1.100`
   - Backend pool `bep-orders`: add `vm-hlg-sea-app01` and `vm-hlg-sea-app02`
   - Probe `hp-http-80` (HTTP 80 `/health`), rule `lbr-http-80` (TCP 80 → 80). Note the **HA ports** checkbox, which exists only on internal LBs.
3. Test from the hub (peered) and from WEU (routed through the NVA in Lab 05):
   ```bash
   rc rg-hlg-hub-eus   vm-hlg-hub-nva01 "for i in 1 2 3 4 5 6; do curl -s -m 3 10.40.1.100 | grep -o 'Host:</b> [^<]*'; done"
   rc rg-hlg-spoke-weu vm-hlg-weu-app01 "curl -s -m 3 10.40.1.100 | grep -o 'Host:</b> [^<]*'"
   ```
4. **Hairpin test:** from a backend VM to its own ILB frontend:
   ```bash
   rc rg-hlg-spoke-sea vm-hlg-sea-app01 "for i in 1 2 3 4 5 6; do curl -s -m 2 10.40.1.100 | grep -o 'Host:</b> [^<]*' || echo FAIL; done"
   ```
   Some requests **FAIL**: the ones hashed back to the VM that sent them.

> [!CAUTION]
> **⚠️ EXAM TRAP — Internal LB hairpinning.** A backend VM that connects to its own internal load balancer's frontend fails whenever the flow is mapped back to **itself**. If backend servers must call each other through the ILB, use two ILBs, or call the other tier directly.

> [!TIP]
> **🎯 EXAM TIP — HA ports** (internal Standard LB only) is a rule for **all ports and all protocols**. It's the standard pattern for load-balancing **NVAs/firewalls** in a hub.

> 📸 **Checkpoint 09-04** — The hub curl loop alternating between `hlg-sea-app01` and `vm-hlg-sea-app02`, plus the hairpin FAILs. → `screenshots/lab-09/09-04-internal-lb.png`

---

## Task 5 — Troubleshoot load balancing (two breaks)

**Break 1, probes blocked by an NSG:**
1. `nsg-snet-web-weu` → inbound **110** `Deny-Probes-Oops`: source **Service tag AzureLoadBalancer**, any port, **Deny**.
2. Wait about a minute, then re-run the Task 2 curl loop → new connections time out.
3. Diagnose:
   - `lbe-hlg-weu-web` → **Metrics** → **Health Probe Status** (split by *Backend IP Address*) drops to 0. **Data Path Availability** stays up, so the frontend itself is fine.
   - **Insights** → instances shown unhealthy.
   - Network Watcher **IP flow verify**: instance NIC, inbound, TCP 80, remote `168.63.129.16` → **Deny** by `Deny-Probes-Oops`.
4. Fix: delete rule 110 and confirm the curl loop works again.

**Break 2, the probe path:**
1. `lbe-hlg-weu-web` → **Health probes** → `hp-http-80` → path **`/healthz`** → Save. The app returns 404 there, so instances go unhealthy.
2. Confirm from an instance: `rc rg-hlg-spoke-weu <instance> "curl -s -o /dev/null -w '%{http_code}' localhost/healthz"` → `404`.
3. Fix: path back to `/health`.

> [!TIP]
> **🎯 EXAM TIP — Load balancer troubleshooting order:**
> 1. **Health Probe Status** metric: are backends healthy? If not: app listening on the probe port/path? NSG allows `AzureLoadBalancer`? Guest firewall?
> 2. **Data Path Availability** metric: is the frontend reachable?
> 3. **NSG allows client traffic** to the backends (Standard LB is closed by default).
> 4. **SKU match**: Standard LB + Standard public IP, backends in one VNet.
> 5. Backend → own ILB frontend = **hairpin**, which fails.
> 6. Outbound problems → **outbound rules / NAT gateway**, not the inbound rule.

> 📸 **Checkpoint 09-05** — Health Probe Status at 0 with IP flow verify showing the deny, then recovered. → `screenshots/lab-09/09-05-lb-troubleshoot.png`

---

## Task 6 — Public DNS zone with alias records

1. **Create a resource → DNS zone**: RG `rg-hlg-mgmt-eus`, name **`hlg-<your-initials>-lab.com`**. (You don't need to own it to create the zone. Only resolution through the public DNS tree needs delegation.)
2. Note the four **name servers** and the auto-created **NS** and **SOA** records.
3. **+ Record set**:

   | Name | Type | Alias? | Target / value |
   |---|---|---|---|
   | `www` | A | **Yes** → Azure resource | `pip-lbe-hlg-weu-web` |
   | `@` | A | **Yes** → Azure resource | `pip-lbe-hlg-weu-web` |
   | `tracker` | CNAME | No | `placeholder.azurewebsites.net` (Lab 13 updates it) |
   | `@` | TXT | No | `hlg-lab-verification` |

4. Query Azure's name servers directly:
   ```bash
   ZONE=hlg-<your-initials>-lab.com
   NS=$(az network dns zone show -g rg-hlg-mgmt-eus -n $ZONE --query "nameServers[0]" -o tsv)
   nslookup www.$ZONE $NS ; nslookup -type=TXT $ZONE $NS
   ```
5. If you own a real domain, delegate a subdomain to try it end to end: create a zone `lab.<yourdomain>` and add **NS** records for `lab` at your registrar pointing to the four Azure name servers.

> [!TIP]
> **🎯 EXAM TIP — Azure DNS public zones:**
> - **Delegation** = set **NS records at the registrar** (or the parent zone) to Azure's name servers. A **child zone** is delegated with an NS record set in the parent zone.
> - **Alias records** (A, AAAA, CNAME) point at an **Azure resource**: public IP, Traffic Manager, Front Door, CDN endpoint, or another record set. They **update automatically** when the resource's IP changes and are the way to point the **zone apex (`@`)** at an Azure resource, because a CNAME isn't allowed at the apex.
> - Azure DNS hosts zones. It doesn't register domains (App Service Domains do).
> - Record sets have a **TTL**. Several records of the same type share one record set.

> 📸 **Checkpoint 09-06** — The zone's record sets, plus the `nslookup` result. → `screenshots/lab-09/09-06-public-dns.png`

---

## Task 7 — Private DNS zone `halsted.internal`

1. **Create a resource → Private DNS zone**: RG `rg-hlg-hub-eus`, name **`halsted.internal`**.
2. **Virtual network links → + Add**:

   | Link name | VNet | Auto registration |
   |---|---|---|
   | `link-hub` | `vnet-hlg-hub-eus` | Off |
   | `link-weu` | `vnet-hlg-spoke-weu` | **On** |
   | `link-sea` | `vnet-hlg-spoke-sea` | **On** |

3. **Recordsets:** A records appear automatically for VMs (and scale set instances) in WEU and SEA.
4. **+ Record set** → name **`orders-api.sea`**, type A, `10.40.1.100` (the internal LB).
5. Test:
   ```bash
   rc rg-hlg-spoke-weu vm-hlg-weu-app01 "getent hosts orders-api.sea.halsted.internal; curl -s -m 5 http://orders-api.sea.halsted.internal | grep -o 'Host:</b> [^<]*'"
   ```

> [!TIP]
> **🎯 EXAM TIP — Private DNS zones:**
> - Resolve only for **linked VNets** (resolution links scale to many VNets).
> - **Auto-registration** creates and deletes A records for VMs as they come and go. A VNet can be the **registration network for only one private zone**, though it can have resolution links to many.
> - Records are resolved by Azure DNS (**168.63.129.16**). VNets that use **custom DNS servers** need those servers to forward to Azure DNS, or to a Private Resolver.
> - Private zones are **global** resources, so one zone serves VNets in every region.

> 📸 **Checkpoint 09-07** — Private zone records (auto-registered + `orders-api.sea`), plus the WEU resolve-and-curl output. → `screenshots/lab-09/09-07-private-dns.png`

---

## Break-fix challenges

1. You add a VM to `bep-web` that lives in `vnet-hlg-spoke-sea`. What happens, and why?
2. Autoscale set to min 2 / max 4 sits at 2 instances under heavy load. Name three things to check.
3. A new VNet `vnet-test` is linked to `halsted.internal` with auto-registration, but it's already the registration network for `corp.internal`. What happens?

<details><summary>Answers</summary>

1. You can't. A load balancer's backend pool members must be in a single VNet (the LB's VNet).
2. The **metric and threshold** (B-series credits throttling CPU?), the **cool-down**, regional vCPU **quota**, **policy** (allowed SKUs), and whether a **schedule profile** overrides the default profile.
3. The link fails or can't enable registration. A VNet can register in only **one** private zone. Make it a resolution-only link.
</details>

---

## Knowledge check

1. You need to route `/api/*` to one pool and `/images/*` to another with TLS termination. Load Balancer or Application Gateway?
2. Every backend of a Standard public LB shows unhealthy, and the app works locally on each VM. What's the most likely cause?
3. How do you point `contoso.com` (the apex) at an Azure public IP so it follows IP changes?
4. Backend VMs in a Standard LB pool need outbound internet with a predictable IP. Name two options.
5. A VM scale set must keep instances on different hardware and survive a zone outage. Which orchestration and zone settings?

<details><summary>Answers</summary>

1. **Application Gateway** (Layer 7 path-based routing + TLS).
2. The probe is blocked: an NSG denies `AzureLoadBalancer` (`168.63.129.16`), or the probe port/path is wrong.
3. An **alias A record** at `@` targeting the public IP resource.
4. **NAT gateway** on the subnet, or **LB outbound rules** with a frontend public IP (or instance public IPs).
5. **Flexible** orchestration across **zones 1, 2, 3** (max spreading).
</details>

---

## Clean up

To pause cheaply, keep the design and stop compute:
```bash
az vmss scale -g rg-hlg-spoke-weu -n vmss-hlg-weu-web --new-capacity 0   # remove the autoscale setting first or it scales back up
az vm deallocate -g rg-hlg-spoke-sea -n vm-hlg-sea-app02
```
**Keep** both load balancers, the DNS zones and `orders-api.sea`: Lab 14 and the Lab 16 capstone use them. If you're done with Lab 09 for good and short on budget, delete `vmss-hlg-weu-web` and `lbe-hlg-weu-web`. The capstone skips faults whose resources don't exist.

## 📣 Document it

```bash
git add notes/lab-09.md screenshots/lab-09 && git commit -m "Lab 09: zone-spread VMSS + public LB, autoscale, internal LB + hairpin, LB troubleshooting, public/private DNS"
```

**LinkedIn post template:**
> Lab 09 of my AZ-104 hybrid build: scaling and load balancing.
>
> ⚖️ Public Standard LB in front of a Flexible VM scale set spread across 3 availability zones
> 📈 CPU-based autoscale (scale out at 70%, in at 25%), stress-tested with Run Command, plus scale-in policy and instance protection
> 🔒 Internal LB for an APAC API at 10.40.1.100, and a live demo of ILB hairpinning failing from a backend VM
> 🛠️ Broke it twice on purpose (NSG denying the AzureLoadBalancer tag, then a wrong probe path) and diagnosed both with Health Probe Status metrics and IP flow verify
> 🌐 Public DNS zone with alias records at the apex, and a private zone with auto-registration so orders-api.sea.halsted.internal resolves from Europe
>
> #Azure #AZ104 #LoadBalancing #AzureDNS #LearningInPublic
