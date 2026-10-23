# Lab 05 — Virtual Networks, Peering, Public IPs, User-Defined Routes and Troubleshooting

> **Scenario:** EU Operations in Amsterdam needs to reach the APAC shipment service in Singapore. Both spokes peer with the hub, yet traffic between them fails. You'll find out why (peering isn't transitive), route spoke-to-spoke traffic through a Linux router in the hub, and use Network Watcher to prove every hop. Then a heads-up from Microsoft lands: new VNets lose implicit internet access. You'll see that happen and fix it with a NAT gateway.
>
> **Time:** ~3 h · **Cost:** ~$0.10 (NAT gateway + public IP for about an hour) · **Prereqs:** Labs 03–04

## What you'll build

```
vm-hlg-weu-app01 10.30.1.4 ──rt-hlg-weu-app──► NVA 10.20.4.4 (hub) ──► vm-hlg-sea-app01 10.40.1.4
                    (10.40.0.0/16 → VirtualAppliance)      ◄──rt-hlg-sea-app── (10.30.0.0/16 → VirtualAppliance)

SEA snet-app (private subnet) ──► ng-hlg-sea (NAT gateway) ──► pip-hlg-sea-natgw ──► Internet
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Create and configure virtual networks and subnets | Tasks 1, 6 |
| Create and configure virtual network peering | Tasks 1, 2 |
| Configure public IP addresses | Task 3 |
| Configure user-defined routes | Task 4 |
| Troubleshoot network connectivity | Tasks 2, 5, 6 |

A helper you'll use all lab, which runs a shell command in a VM with no Bastion or public IP:
```bash
rc() { az vm run-command invoke -g "$1" -n "$2" --command-id RunShellScript --scripts "$3" --query "value[0].message" -o tsv; }
# usage: rc rg-hlg-spoke-weu vm-hlg-weu-app01 "curl -s -m 5 10.40.1.4"
```

---

## Task 1 — Subnets, address spaces and peering sync

1. Portal → `vnet-hlg-spoke-weu` → **Address space** and **Subnets**. For `snet-app` (a /24), note **Available IPs: 251**.
2. **Add an address space:** Address space → add `10.31.0.0/16` → Save.
3. **Add a subnet** in it: Subnets → **+ Subnet** → `snet-batch`, `10.31.1.0/24`.
4. Open **Peerings** on `vnet-hlg-spoke-weu` and on `vnet-hlg-hub-eus`. The peering shows a **sync** warning: the hub doesn't know about `10.31.0.0/16` yet. Select the peering → **Sync** on both sides.
5. **Undo it** to keep the environment matching the Bicep (Lab 03 drift rule): delete `snet-batch`, then remove `10.31.0.0/16`, then sync the peerings again.

> [!TIP]
> **🎯 EXAM TIP — Subnet arithmetic.** Azure reserves **5 IPs per subnet**: `.0` network, `.1` default gateway, `.2` and `.3` Azure DNS, and the last address (broadcast). A /24 gives 251 usable addresses, a /29 (the smallest IPv4 subnet) gives 3. Questions ask "how many VMs fit" or "what's the smallest subnet for N VMs".

> [!TIP]
> **🎯 EXAM TIP — VNet facts:**
> - A VNet lives in **one region and one subscription**. Subnets can't span VNets.
> - Peered VNets must have **non-overlapping** address spaces.
> - You **can** add or resize address space on a peered VNet without removing the peering, then **sync** the peering.
> - You can remove an address range only if no subnet uses it.
> - Changing a VNet's **custom DNS servers** only reaches existing VMs after they renew DHCP or restart.

<details><summary>CLI equivalent</summary>

```bash
az network vnet update -g rg-hlg-spoke-weu -n vnet-hlg-spoke-weu --address-prefixes 10.30.0.0/16 10.31.0.0/16
az network vnet subnet create -g rg-hlg-spoke-weu --vnet-name vnet-hlg-spoke-weu -n snet-batch --address-prefixes 10.31.1.0/24
az network vnet peering sync -g rg-hlg-hub-eus --vnet-name vnet-hlg-hub-eus -n peer-hub-to-weu
```
</details>

> 📸 **Checkpoint 05-01** — The peering showing the sync warning, then synced. → `screenshots/lab-05/05-01-peering-sync.png`

---

## Task 2 — Peering is not transitive

1. Open `peer-weu-to-hub` and read its four settings. Match each to its exam meaning:

   | Portal wording (roughly) | Property | Meaning |
   |---|---|---|
   | Allow *local* to access *remote* | `allowVirtualNetworkAccess` | Basic connectivity |
   | Allow *local* to receive forwarded traffic from *remote* | `allowForwardedTraffic` | Accept packets that didn't originate in the remote VNet (needed for NVAs) |
   | Allow gateway or route server in *local* to forward traffic to *remote* | `allowGatewayTransit` | Hub shares its VPN/ExpressRoute gateway |
   | Enable *local* to use *remote*'s remote gateway | `useRemoteGateways` | Spoke uses the hub's gateway (Lab 07) |

2. Hub → spokes (works):
   ```bash
   rc rg-hlg-hub-eus vm-hlg-hub-nva01 "curl -s -m 5 10.30.1.4 | grep Host; curl -s -m 5 10.40.1.4 | grep Host"
   ```
3. Spoke → spoke (fails):
   ```bash
   rc rg-hlg-spoke-weu vm-hlg-weu-app01 "curl -s -m 5 10.40.1.4 || echo TIMEOUT"
   ```
4. Find out why: `vm-hlg-weu-app01` → **Networking** → NIC → **Effective routes**. You see `10.30.0.0/16` (*Virtual network*), `10.20.0.0/16` (*VNet global peering*), `0.0.0.0/0` (*Internet*) and **nothing for 10.40.0.0/16**. No route means traffic falls to the default route and dies.

> [!TIP]
> **🎯 EXAM TIP — Peering facts:**
> - **Non-transitive.** A↔B and B↔C doesn't give A↔C. Fix it with direct peering, an **NVA/Azure Firewall in the hub plus UDRs** (this lab), or **Virtual WAN**.
> - **Global peering** (cross-region) works like regional peering, including gateway transit. Data transfer is billed in both directions.
> - Peering status: **Initiated** means only one side exists, **Connected** means both. **Disconnected** means one side was deleted, so delete and recreate the remaining side.
> - Peering works across subscriptions, and across tenants with the right permissions.

> 📸 **Checkpoint 05-02** — The TIMEOUT output plus the effective routes with no 10.40 route. → `screenshots/lab-05/05-02-non-transitive.png`

---

## Task 3 — Public IP addresses

Create the IP you'll attach to a NAT gateway in Task 6:

1. **Create a resource → Public IP address**:
   - Name `pip-hlg-sea-natgw` · RG `rg-hlg-spoke-sea` · Region **Southeast Asia**
   - IP version IPv4 · **SKU Standard** · Availability zone **Zone-redundant** · Tier **Regional**
   - Routing preference **Microsoft network** · assignment is **Static** (and can't be changed for Standard)
   - DNS name label: leave empty (note the `<label>.southeastasia.cloudapp.azure.com` format)
2. Open it and note **Associated to: —**, **SKU**, **Tier**, **Zones**.
3. Look at **Public IP prefixes** in the marketplace (don't create one). It reserves a contiguous block such as a /28.

> [!TIP]
> **🎯 EXAM TIP — Public IP facts:**
> - **Basic SKU public IPs were retired on 30 Sept 2025.** **Standard** is the default: always **static**, **closed to inbound by default** (an NSG must allow traffic), zone-redundant or zonal, and required by Standard Load Balancer, NAT gateway, Bastion and AZ VPN gateways.
> - **Routing preference** (*Microsoft network* vs *Internet*) and **zone** are chosen at creation and can't be changed.
> - **Global tier** is for the cross-region load balancer.
> - You can attach a public IP to a NIC IP configuration, LB frontend, NAT gateway, VPN gateway, Bastion, Application Gateway or Azure Firewall. Detach it before deleting.
> - SKUs must match: a Standard LB needs Standard public IPs.

> 📸 **Checkpoint 05-03** — The public IP overview (blur the IP if you like). → `screenshots/lab-05/05-03-public-ip.png`

---

## Task 4 — Route spoke-to-spoke traffic through the hub NVA

### 4a. Confirm the NVA can forward
1. `nic-vm-hlg-hub-nva01` → **IP configurations** → **Enable IP forwarding** is checked (set by `workloads.bicep`).
2. In the OS:
   ```bash
   rc rg-hlg-hub-eus vm-hlg-hub-nva01 "sysctl net.ipv4.ip_forward"     # expect = 1
   ```

### 4b. Route tables
1. **Create a resource → Route table**: `rt-hlg-weu-app`, RG `rg-hlg-spoke-weu`, **Region West Europe**, *Propagate gateway routes* **Yes**.
2. **Routes → + Add**: name `to-sea-via-nva`, destination type IP addresses, `10.40.0.0/16`, next hop **Virtual appliance**, `10.20.4.4`.
3. **Subnets → + Associate**: `vnet-hlg-spoke-weu` / `snet-app`.
4. Repeat for the other direction: `rt-hlg-sea-app` in **Southeast Asia**, route **`to-weu-via-nva`** `10.30.0.0/16` → Virtual appliance `10.20.4.4`, associated with `vnet-hlg-spoke-sea` / `snet-app`.

### 4c. Test
```bash
rc rg-hlg-spoke-weu vm-hlg-weu-app01 "curl -s -m 5 10.40.1.4 | grep -E 'Host|Site'"
rc rg-hlg-spoke-weu vm-hlg-weu-app01 "tracepath -n -m 5 10.40.1.4 || true"     # hop 1 should be 10.20.4.4
```
Re-open the WEU VM's **Effective routes**: `10.40.0.0/16` now shows source **User**, next hop **VirtualAppliance 10.20.4.4**.

> [!TIP]
> **🎯 EXAM TIP — Which route wins?** First **longest prefix match** (a /24 beats a /16 regardless of source). On a tie: **user-defined route > BGP route > system route**. A route table must be in the **same region and subscription** as the VNet. One subnet can have one route table; one route table can serve many subnets.

> [!TIP]
> **🎯 EXAM TIP — Next hop types:** *Virtual network gateway*, *Virtual network*, *Internet*, *Virtual appliance* (needs an IP), **None** (drops traffic, a "black hole"). For an NVA, IP forwarding must be on **in Azure (the NIC)** and **in the guest OS**. The receiving spoke's peering must **allow forwarded traffic** (set in the Bicep), because the packets originate outside the hub.

> [!CAUTION]
> **⚠️ EXAM TRAP — Propagate gateway routes = No** stops routes learned from a VPN/ExpressRoute gateway (BGP) reaching that subnet. It's used to force traffic through a firewall instead of straight to on-prem. A question that says "on-prem routes disappeared after a route table was attached" is pointing at this setting.

> 📸 **Checkpoint 05-04** — The route table with the route and subnet association, plus the successful cross-spoke curl. → `screenshots/lab-05/05-04-udr-nva.png`

<details><summary>CLI equivalent</summary>

```bash
az network route-table create -g rg-hlg-spoke-weu -n rt-hlg-weu-app -l westeurope
az network route-table route create -g rg-hlg-spoke-weu --route-table-name rt-hlg-weu-app -n to-sea-via-nva \
  --address-prefix 10.40.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.4.4
az network vnet subnet update -g rg-hlg-spoke-weu --vnet-name vnet-hlg-spoke-weu -n snet-app --route-table rt-hlg-weu-app
```
</details>

---

## Task 5 — Troubleshoot with Network Watcher

Portal → **Network Watcher**. It's enabled per region automatically (that's what created `NetworkWatcherRG` in Lab 03).

1. **Next hop:** VM `vm-hlg-weu-app01`, source `10.30.1.4`, destination `10.40.1.4` → **VirtualAppliance 10.20.4.4**, plus the route table ID.
2. **IP flow verify:** VM `vm-hlg-sea-app01`, **Inbound**, TCP, local `10.40.1.4:80`, remote `10.30.1.4:50000` → **Access allowed**, rule `AllowVnetInBound`.
3. **Connection troubleshoot:** source VM `vm-hlg-weu-app01` → destination IP `10.40.1.4`, port 80. Accept the **Network Watcher agent** extension install if prompted. Result: *Reachable*, with the hop list.
4. **Topology:** select the WEU and hub RGs. Export the diagram.
5. **Break it:** NVA NIC → IP configurations → **uncheck** IP forwarding → Save. Re-run connection troubleshoot → it fails at the NVA hop. Re-enable it.

> [!TIP]
> **🎯 EXAM TIP — Match the Network Watcher tool to the question:**
>
> | Question says… | Tool |
> |---|---|
> | "Is traffic allowed or denied by an NSG, and by which rule?" | **IP flow verify** / **NSG diagnostics** |
> | "Where does traffic from this VM to X go?" | **Next hop** (or the NIC's **Effective routes**) |
> | "Test TCP connectivity VM → VM/FQDN/IP and show hops and latency" | **Connection troubleshoot** (one-off) |
> | "Continuously monitor connectivity and alert" | **Connection monitor** (Lab 14) |
> | "Capture packets" | **Packet capture** (needs the agent extension) |
> | "Why is my S2S VPN down?" | **VPN troubleshoot** (Lab 07) |
> | "Log all flows through the VNet" | **VNet flow logs** + Traffic analytics (Lab 14) |
> | "Diagram my network" | **Topology** |

> 📸 **Checkpoint 05-05** — Next hop result, plus connection troubleshoot failing with IP forwarding off. → `screenshots/lab-05/05-05-network-watcher.png`

---

## Task 6 — Default outbound access goes away: private subnets and NAT gateway

**Background:** Azure VMs used to get an implicit, Microsoft-owned public IP for outbound internet ("default outbound access"). For **new VNets created with API versions after 31 March 2026, subnets are private by default**, so VMs can't reach the internet unless you add an explicit method. Existing VNets aren't changed. The lab's Bicep sets `defaultOutboundAccess: true` explicitly on workload subnets so the labs behave the same everywhere. Now you'll turn it off and fix it properly.

1. Baseline:
   ```bash
   rc rg-hlg-spoke-sea vm-hlg-sea-app01 "curl -s -m 8 https://api.ipify.org; echo"   # some Microsoft IP
   ```
2. `vnet-hlg-spoke-sea` → **Subnets** → `snet-app` → check **Enable private subnet (no default outbound access)** → Save.
3. Run step 1 again. It **still works**: existing VMs keep their default outbound IP until they're **deallocated**.
   ```bash
   az vm deallocate -g rg-hlg-spoke-sea -n vm-hlg-sea-app01 && az vm start -g rg-hlg-spoke-sea -n vm-hlg-sea-app01
   rc rg-hlg-spoke-sea vm-hlg-sea-app01 "curl -s -m 8 https://api.ipify.org || echo NO-OUTBOUND"
   ```
4. **Create a NAT gateway**: `ng-hlg-sea`, RG `rg-hlg-spoke-sea`, Southeast Asia, no zone, TCP idle timeout 4 → **Outbound IP**: `pip-hlg-sea-natgw` → **Subnet**: `vnet-hlg-spoke-sea` / `snet-app`.
5. Test again. The IP returned is **your** `pip-hlg-sea-natgw` address.
6. **Clean up the cost:** NAT gateway → Subnet → disassociate → delete `ng-hlg-sea` and `pip-hlg-sea-natgw`. Uncheck **private subnet** on SEA `snet-app`, then deallocate and start `vm-hlg-sea-app01` so it gets default outbound back. (Lab 14's monitoring agent needs outbound.)

> [!TIP]
> **🎯 EXAM TIP — Explicit outbound methods:** **NAT gateway** (recommended), **Load Balancer outbound rules**, a **public IP on the NIC**, or routing through **Azure Firewall/NVA**. A NAT gateway associates with one or more subnets **in a single VNet**, uses Standard public IPs or prefixes (up to 16 IPs), and **takes precedence over other outbound methods** for those subnets. Inbound connections to a VM's own public IP still work.

> [!CAUTION]
> **⚠️ EXAM TRAP — "VMs in a new VNet can't download updates, but VMs in the old VNet can."** The new VNet's subnets are private by default. The fix is an explicit outbound method, not an NSG rule (NSG outbound to Internet is allowed by default).

> 📸 **Checkpoint 05-06** — `NO-OUTBOUND`, then the NAT gateway's IP returned by ipify. → `screenshots/lab-05/05-06-nat-gateway.png`

---

## Break-fix challenges

1. You try to associate `rt-hlg-weu-app` with the **SEA** subnet and it isn't in the list. Why?
2. A new peering from a test VNet `10.30.128.0/17` to the hub fails. Why?
3. After creating the route tables, the hub NVA itself can still reach both spokes, but WEU → SEA times out. IP forwarding is on in Azure. What do you check next?

<details><summary>Fixes</summary>

1. Route tables are **regional**. `rt-hlg-weu-app` is in West Europe, so it can only attach to West Europe subnets.
2. `10.30.128.0/17` **overlaps** WEU's `10.30.0.0/16`, which is already peered with the hub. The hub can't hold overlapping ranges.
3. **OS-level forwarding** on the NVA (`sysctl net.ipv4.ip_forward`), then **Allow forwarded traffic** on the receiving spoke's peering, then NSGs on both ends (IP flow verify).
</details>

---

## Knowledge check

1. VNet1 peers with VNet2, and VNet2 peers with VNet3. VM1 in VNet1 can't reach VM3 in VNet3. Give two fixes.
2. A route table has `10.0.0.0/8 → Virtual appliance 10.20.4.4` and the system has `10.40.0.0/16 → VNet peering`. Where does traffic to 10.40.1.4 go?
3. What's the smallest subnet that can hold 27 VMs?
4. Which Network Watcher tool tells you which NSG rule blocked a specific flow?
5. You need all outbound traffic from a subnet to come from one predictable public IP. What do you deploy?

<details><summary>Answers</summary>

1. Peer VNet1↔VNet3 directly, **or** add an NVA/firewall in VNet2 with UDRs in VNet1 and VNet3 and *allow forwarded traffic* on the peerings (or use Virtual WAN).
2. **The peering route.** `/16` is a longer prefix than `/8`, and longest prefix match wins before source precedence.
3. **/27**: 32 − 5 reserved = 27 usable.
4. **IP flow verify** (or NSG diagnostics).
5. A **NAT gateway** with a Standard public IP, associated with the subnet.
</details>

---

## Clean up

- Done in Task 6: NAT gateway and its public IP deleted, private subnet turned off.
- **Keep** both route tables and the NVA. Labs 06, 07 and 16 use them.
- Run `bash scripts/cost-check.sh` to confirm no NAT gateway remains.

> [!NOTE]
> **Drift check.** You've now associated route tables in the portal. Redeploying `main.bicep` would remove those associations (Lab 03 Task 5). To codify them, add a `routeTable` property to those subnets in the Bicep. That's a good stretch exercise.

## 📣 Document it

```bash
git add notes/lab-05.md screenshots/lab-05 && git commit -m "Lab 05: non-transitive peering, NVA + UDR spoke-to-spoke, Network Watcher, private subnets + NAT gateway"
```

**LinkedIn post template:**
> Lab 05 of my AZ-104 hybrid build: making West Europe talk to Southeast Asia through an East US hub.
>
> 🔁 Proved peering isn't transitive: hub ↔ spokes works, spoke ↔ spoke times out, and effective routes show why
> 🧭 Linux NVA in the hub + user-defined routes in each spoke. Needs IP forwarding on the NIC and in the OS, plus "allow forwarded traffic" on the peering
> 🔍 Network Watcher: Next hop, IP flow verify, Connection troubleshoot. Then broke IP forwarding on purpose and watched the hop fail
> 🌐 Default outbound access retirement: made a subnet private, showed existing VMs keep egress until deallocated, then fixed it with a NAT gateway
>
> #Azure #AZ104 #AzureNetworking #NetworkWatcher #LearningInPublic
