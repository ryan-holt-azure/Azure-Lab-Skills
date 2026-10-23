# Lab 07 — Hybrid Connectivity: Chicago HQ to Azure over Site-to-Site VPN

> **Scenario:** Chicago's datacenter needs private access to the hub and both spokes, and to the shared data account behind its private endpoint. You'll build a site-to-site IPsec VPN between the simulated Chicago network (North Central US) and the East US hub, use **gateway transit** so Chicago reaches both spokes through one tunnel, and hit the classic hybrid DNS problem with private endpoints.
>
> **Time:** ~2.5 h (about 45 min of it is gateway deployment) · **Cost:** ~$1–2 if you delete the gateways the same day · **Prereqs:** Labs 03, 05, 06

## What you'll build

```
vm-hlg-chi-srv01 10.10.1.4                                     vm-hlg-weu-app01 10.30.1.4
   │  vnet-hlg-onprem-chi (North Central US)                        ▲
   ▼                                                                │ peering: useRemoteGateways
vgw-hlg-onprem-chi ══ IPsec/IKEv2 ══ vgw-hlg-hub-eus ── hub ────────┤ peering: allowGatewayTransit
   lng-hlg-azure-hub                    lng-hlg-chicago-hq          │
   (10.20/16, 10.30/16, 10.40/16)       (10.10/16)                  ▼
                                                               vm-hlg-sea-app01 10.40.1.4
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Create and configure virtual network peering | Task 5 (gateway transit / use remote gateways) |
| Troubleshoot network connectivity | Tasks 4, 6, 7 |
| Configure Azure DNS | Task 6 (hybrid resolution for private endpoints) |
| Create and configure network security groups (NSGs) and application security groups | Task 5 (on-prem source in an NSG rule) |

> [!NOTE]
> **🧭 BEYOND THE OUTLINE.** VPN gateways, local network gateways and connections were removed from the AZ-104 skills list in earlier revisions. **Gateway transit is still tested** under peering, and hybrid DNS shows up in private endpoint questions. Build this lab for the HLG scenario and your portfolio, then delete the gateways the same day.

```bash
rc() { az vm run-command invoke -g "$1" -n "$2" --command-id RunShellScript --scripts "$3" --query "value[0].message" -o tsv; }
```

---

## Task 1 — Start the gateway deployment (then keep working)

```bash
cd ~/clouddrive/az104-hybrid-labs
export HLG_VPN_PSK="$(openssl rand -hex 20)"       # shared key — keep it in this shell only
sed -i "s/your-alias/<you>/" iac/bicep/hybrid-vpn.bicepparam
az deployment sub create --name hlg-vpn --location eastus --no-wait \
  --template-file iac/bicep/hybrid-vpn.bicep --parameters iac/bicep/hybrid-vpn.bicepparam
```
This builds **two VpnGw1AZ gateways** and their Standard public IPs: one in the hub, one in Chicago. Expect **30–45 minutes**. Watch progress under **Subscriptions → Deployments → hlg-vpn**.

> [!NOTE]
> North Central US has **no availability zones** today. Microsoft lets you create AZ SKUs there, and the gateway stays regional until the region gets zones. That's why `onpremZones` is empty. If your subscription rejects the AZ SKU in North Central US, change `onpremLocation` to `centralus` in the Bicep, `.bicepparam` and `main.bicep` (Central US is in Iowa, and the story still works).

While it deploys, do Task 2.

---

## Task 2 — Learn the pieces (portal walkthrough, don't create)

Open **Create a resource → Virtual network gateway** and read every field, then cancel:

| Field | What to know |
|---|---|
| Gateway type | **VPN** or **ExpressRoute**. One of each can coexist in a VNet. |
| SKU | VpnGw1–5**AZ** (zone-redundant capable). **Non-AZ VpnGw1–5 can't be created anymore.** Legacy Standard/HighPerformance are retired. **Basic** still exists (CLI/PowerShell only) but has no BGP, no active-active and limited P2S. |
| Generation | Gen1 / Gen2: throughput tiers within the SKU family |
| VNet | Must contain a subnet named exactly **`GatewaySubnet`** (**/27 or larger** recommended) |
| Public IP | **Standard**, static. Zone-redundant for AZ SKUs where the region supports it. |
| Active-active | Two instances, two public IPs, both tunnels up |
| BGP | Dynamic routing and an ASN. Needed for ExpressRoute coexistence failover and for many multi-site designs. |

Then open **Local network gateway** create (cancel too): it's just **the other side's public IP (or FQDN)** plus **the address prefixes behind it**.

> [!TIP]
> **🎯 EXAM TIP — Connection types:**
> - **Site-to-site (IPsec):** your on-prem VPN device ↔ VPN gateway, over the internet. Needs a local network gateway.
> - **VNet-to-VNet:** VPN gateway ↔ VPN gateway, no local network gateway needed.
> - **Point-to-site:** individual clients. Auth by certificate, **Microsoft Entra ID** (OpenVPN) or RADIUS. Protocols: OpenVPN, IKEv2, SSTP.
> - **ExpressRoute:** private circuit through a provider, **not over the internet**. Gateway type ExpressRoute.
>
> **Route-based** VPNs are required for P2S, VNet-to-VNet, multiple S2S tunnels and ExpressRoute coexistence. **Policy-based** is the legacy single-tunnel option.

> [!CAUTION]
> **⚠️ EXAM TRAP — GatewaySubnet rules.** Don't associate an **NSG** with GatewaySubnet (it can break the gateway). Don't add a UDR with `0.0.0.0/0` → anything on it. Don't deploy VMs into it. The name is case-sensitive and must be exact.

---

## Task 3 — Create the local network gateways

When the deployment finishes, get both gateway IPs:
```bash
HUB_GW_IP=$(az network public-ip show -g rg-hlg-hub-eus    -n pip-vgw-hlg-hub-eus    --query ipAddress -o tsv)
CHI_GW_IP=$(az network public-ip show -g rg-hlg-onprem-chi -n pip-vgw-hlg-onprem-chi --query ipAddress -o tsv)
echo "hub=$HUB_GW_IP  chicago=$CHI_GW_IP"
```

**Create a resource → Local network gateway**, twice:

| Name | RG / Region | IP address | Address space(s) | Meaning |
|---|---|---|---|---|
| `lng-hlg-chicago-hq` | `rg-hlg-hub-eus` / East US | `$CHI_GW_IP` | `10.10.0.0/16` | "Chicago is over there" (used by the hub) |
| `lng-hlg-azure-hub` | `rg-hlg-onprem-chi` / North Central US | `$HUB_GW_IP` | `10.20.0.0/16`, `10.30.0.0/16`, `10.40.0.0/16` | "Azure is over there" (used by Chicago) |

> [!TIP]
> **🎯 EXAM TIP — The local network gateway's address space is what gets routed into the tunnel.** If Chicago's side lists only the hub (`10.20.0.0/16`), Chicago can never reach the spokes, even with gateway transit configured. On a real on-prem firewall, these are the "remote networks" or "encryption domain".

---

## Task 4 — Create the connections and bring the tunnel up

1. `vgw-hlg-hub-eus` → **Connections** → **+ Add**:
   - Type **Site-to-site (IPsec)** · Name `cn-hlg-hub-to-chicago`
   - Local network gateway `lng-hlg-chicago-hq`
   - Authentication **Shared key (PSK)**: paste `echo $HLG_VPN_PSK` (don't screenshot it) · IKE protocol **IKEv2**
2. `vgw-hlg-onprem-chi` → **Connections** → **+ Add**: `cn-hlg-chicago-to-hub` with `lng-hlg-azure-hub` and the **same** shared key.
3. Within a few minutes both connections show **Status: Connected**. Open one and note **Data in / Data out**.
4. First test, Chicago → hub:
   ```bash
   rc rg-hlg-onprem-chi vm-hlg-chi-srv01 "ping -c 3 10.20.4.4"
   ```
5. Then Chicago → spokes (this should **fail**, and that's expected):
   ```bash
   rc rg-hlg-onprem-chi vm-hlg-chi-srv01 "curl -s -m 5 10.40.1.4 | grep Host || echo NO-ROUTE"
   ```

> 📸 **Checkpoint 07-01** — Both connections **Connected**, plus the successful ping. Blur public IPs. → `screenshots/lab-07/07-01-s2s-connected.png`

---

## Task 5 — Gateway transit so Chicago reaches both spokes

1. **Hub side:** `vnet-hlg-hub-eus` → **Peerings** → `peer-hub-to-weu` → check **Allow gateway or route server in 'vnet-hlg-hub-eus' to forward traffic to 'vnet-hlg-spoke-weu'** → Save. Repeat for `peer-hub-to-sea`.
2. **Spoke side:** `vnet-hlg-spoke-weu` → **Peerings** → `peer-weu-to-hub` → check **Enable 'vnet-hlg-spoke-weu' to use 'vnet-hlg-hub-eus''s remote gateway or route server** → Save. Repeat on `vnet-hlg-spoke-sea`.
3. Test Chicago → APAC:
   ```bash
   rc rg-hlg-onprem-chi vm-hlg-chi-srv01 "curl -s -m 5 10.40.1.4 | grep Host"
   ```
   ✅ Works.
4. Test Chicago → EU:
   ```bash
   rc rg-hlg-onprem-chi vm-hlg-chi-srv01 "curl -s -m 5 10.30.1.4 | grep Host || echo BLOCKED"
   ```
   ❌ **BLOCKED**. Routing is fine: rule **4000 Deny-VNet-Inbound** from Lab 06 blocks it, because `VirtualNetwork` includes on-prem ranges learned through the gateway. Add to `nsg-snet-app-weu`:

   | Priority | Name | Source | Destination | Port | Action |
   |---|---|---|---|---|---|
   | 300 | `Allow-Chicago-to-EU-Web` | `10.10.0.0/16` | ASG `asg-hlg-weu-web` | TCP 80 | Allow |

   Re-test: ✅
5. `vm-hlg-weu-app01` → NIC → **Effective routes**: `10.10.0.0/16` with next hop **Virtual network gateway** (source *Virtual network gateway*). Your UDR for `10.40.0.0/16` is still there. Both coexist.

> [!TIP]
> **🎯 EXAM TIP — Gateway transit:**
> - **Hub** peering: *Allow gateway transit* (`allowGatewayTransit`). **Spoke** peering: *Use remote gateways* (`useRemoteGateways`).
> - The hub gateway must exist before a spoke can enable *use remote gateways*.
> - A spoke that has **its own** gateway can't use remote gateways.
> - Works across **global** peering.
> - Without transit, each spoke would need its own gateway and tunnel.

> [!CAUTION]
> **⚠️ EXAM TRAP — "The VPN is connected but on-prem can't reach a spoke."** Check in this order: **(1)** gateway transit + use remote gateways on the peerings, **(2)** the on-prem LNG/firewall includes the spoke's prefix, **(3)** a UDR or *Propagate gateway routes = No* on the spoke's route table, **(4)** NSGs, where `VirtualNetwork` *does* include on-prem.

> 📸 **Checkpoint 07-02** — Peering settings with the transit boxes checked, plus the WEU VM's effective routes showing 10.10.0.0/16 via VirtualNetworkGateway. → `screenshots/lab-07/07-02-gateway-transit.png`

---

## Task 6 — The hybrid DNS problem with private endpoints

Get the data account host and a Read SAS URL again (Lab 06 Task 5):
```bash
read -r -p "Data blob SAS URL: " DATA_SAS; DATA_HOST=$(echo "$DATA_SAS" | sed -E 's#https://([^/]+)/.*#\1#')
rc rg-hlg-onprem-chi vm-hlg-chi-srv01 "getent hosts $DATA_HOST; curl -s -o /dev/null -w '%{http_code}\n' '$DATA_SAS'"
```
Result: a **public** IP and **403**. The tunnel is up and the private endpoint (10.20.3.4) is reachable from Chicago. The problem is that Chicago's DNS doesn't know about `privatelink.blob.core.windows.net`, so the name resolves publicly and the request hits the disabled public endpoint.

**Fix A (lab-only, proves the network path):**
```bash
rc rg-hlg-onprem-chi vm-hlg-chi-srv01 "echo '10.20.3.4 $DATA_HOST' >> /etc/hosts; getent hosts $DATA_HOST; curl -s -o /dev/null -w '%{http_code}\n' '$DATA_SAS'"
```
✅ `200` over the VPN. Remove the hosts entry afterwards: `sed -i '/blob.core.windows.net/d' /etc/hosts`.

**Fix B (how it's done for real), optional stretch:**
1. Add subnet `snet-dns-in` (`10.20.5.0/28`) to the hub, delegated to `Microsoft.Network/dnsResolvers`.
2. Create an **Azure DNS Private Resolver** in the hub with an **inbound endpoint** in that subnet. It gets an IP such as `10.20.5.4`.
3. On-prem DNS servers get a **conditional forwarder** for **`blob.core.windows.net`** → `10.20.5.4`. The resolver answers from the linked private zone.
4. Test from Chicago: `nslookup $DATA_HOST 10.20.5.4` → `10.20.3.4`.

> [!WARNING]
> **💲 COST.** Each Private Resolver endpoint bills hourly (it's one of the pricier items in this series). Delete it within the hour if you try Fix B.

> [!TIP]
> **🎯 EXAM TIP — Why on-prem can't just use Azure DNS.** Azure's resolver at **168.63.129.16** is only reachable **from inside Azure**. On-prem DNS must forward to something inside a VNet: a **DNS Private Resolver inbound endpoint** (managed) or a DNS forwarder VM. Forward the **public** zone (`blob.core.windows.net`), not `privatelink.…`. Clients resolve the public name, and Azure DNS follows the CNAME into the private zone.

> 📸 **Checkpoint 07-03** — Chicago resolving the public IP and getting 403, then 200 with the private IP. → `screenshots/lab-07/07-03-hybrid-dns.png`

---

## Task 7 — Troubleshoot the tunnel

1. **Break it:** `cn-hlg-chicago-to-hub` → **Authentication type / Shared key** → change one character → Save. Within minutes both connections leave *Connected*.
2. **Network Watcher → VPN troubleshoot** → select `vgw-hlg-hub-eus` → pick any storage account that allows public access (your Cloud Shell account works) → **Start troubleshooting**. Read the result and the log files it writes. Look for the authentication/IKE failure.
3. **Fix it** (paste the correct key back) and confirm **Connected**.
4. Also look at `vgw-hlg-hub-eus` → **Monitoring → Metrics → Tunnel Ingress Bytes** and **Tunnel Egress Bytes**, plus **Connections → Data in/out**.

> [!TIP]
> **🎯 EXAM TIP — S2S checklist:** matching **shared key**, matching **IKE version/IPsec policy**, correct **public IPs** in both LNGs, **non-overlapping** address spaces, route-based on both ends, and **GatewaySubnet** sized /27+. VPN troubleshoot needs a storage account for its logs.

> 📸 **Checkpoint 07-04** — VPN troubleshoot output showing the failure. → `screenshots/lab-07/07-04-vpn-troubleshoot.png`

---

## Task 8 (optional) — Codify what you built

```bash
sed -i 's/deployConnections = false/deployConnections = true/; s/configurePeeringTransit = false/configurePeeringTransit = true/' iac/bicep/hybrid-vpn.bicepparam
az deployment sub what-if --name hlg-vpn --location eastus \
  --template-file iac/bicep/hybrid-vpn.bicep --parameters iac/bicep/hybrid-vpn.bicepparam
```
Because you used the same names, `what-if` should show mostly **NoChange/Modify** rather than **Create**. Anything flagged is drift between your portal work and the code. Fix your naming or the template until they match. Set both flags back to `false` before teardown.

---

## Break-fix challenges

1. Remove `10.30.0.0/16` from `lng-hlg-azure-hub`. What breaks, and for whom?
2. On `rt-hlg-sea-app`, set **Propagate gateway routes = No**. Test Chicago → SEA. Explain, then revert.
3. A colleague enables *Use remote gateways* on a new spoke before the hub gateway exists. What happens?

<details><summary>Fixes</summary>

1. Chicago's gateway no longer sends EU traffic into the tunnel. Chicago → WEU fails, while Chicago → SEA and → hub still work.
2. SEA's subnet loses the `10.10.0.0/16` gateway route. Return traffic to Chicago falls back to the default route and is lost. Typical when someone "forces traffic through a firewall" but forgets the on-prem route.
3. The peering update fails validation. The remote VNet must already have a gateway (and *allow gateway transit*).
</details>

---

## Knowledge check

1. Three spoke VNets must reach on-prem through a hub's VPN gateway. What do you configure on each peering?
2. Which resource represents your on-prem VPN device in Azure, and what two pieces of information does it hold?
3. Users connect from home laptops and sign in with Entra ID. Which VPN type, protocol and auth method?
4. Why does a hub NSG rule with source `VirtualNetwork` allow traffic from on-prem?
5. On-prem clients resolve `acct.blob.core.windows.net` to a public IP despite a private endpoint. Where do you configure the fix?

<details><summary>Answers</summary>

1. Hub → spoke: **allow gateway transit**. Spoke → hub: **use remote gateways**.
2. The **local network gateway**: the device's **public IP (or FQDN)** and the **on-prem address prefixes** (plus BGP settings if used).
3. **Point-to-site**, **OpenVPN** protocol, **Microsoft Entra ID** authentication.
4. The `VirtualNetwork` service tag includes on-prem address spaces connected through a gateway.
5. On-prem DNS: a conditional forwarder for `blob.core.windows.net` to an Azure-side resolver (DNS Private Resolver inbound endpoint or a forwarder VM) that can see the private zone.
</details>

---

## Clean up (same day: this is the most expensive lab to leave running)

Order matters:
1. Spoke peerings → **uncheck** *Use remote gateway* (WEU and SEA).
2. Hub peerings → **uncheck** *Allow gateway transit*.
3. Delete both **connections**.
4. Delete both **gateways** (about 10 minutes each; run them in parallel):
   ```bash
   az network vnet-gateway delete -g rg-hlg-hub-eus    -n vgw-hlg-hub-eus    --no-wait
   az network vnet-gateway delete -g rg-hlg-onprem-chi -n vgw-hlg-onprem-chi --no-wait
   ```
5. When they're gone, delete `pip-vgw-hlg-hub-eus`, `pip-vgw-hlg-onprem-chi` and both **local network gateways**.
6. `bash scripts/cost-check.sh`: no `virtualNetworkGateways` should remain.

Keep the NSG rule `Allow-Chicago-to-EU-Web`. It's harmless and Lab 16 can reuse the VPN.

## 📣 Document it

```bash
git add notes/lab-07.md screenshots/lab-07 && git commit -m "Lab 07: S2S VPN Chicago<->hub, gateway transit to both spokes, hybrid DNS for private endpoints"
```

**LinkedIn post template:**
> Lab 07 of my AZ-104 hybrid build: connecting "Chicago HQ" to Azure.
>
> 🔐 Site-to-site IPsec/IKEv2 between two VPN gateways (the on-prem one simulated in North Central US, which is in Illinois)
> 🧭 Gateway transit: one tunnel into the hub gives Chicago reach into West Europe and Southeast Asia
> 🧱 Found that the NSG "VirtualNetwork" tag includes on-prem ranges, so my deny rule blocked Chicago until I added an explicit allow
> 🌐 Hit the classic hybrid DNS problem: Chicago resolved the private-endpoint storage account to its public IP and got a 403. Proved the path with a hosts entry, then documented the real fix (DNS Private Resolver + conditional forwarder for blob.core.windows.net)
> 🛠️ Broke the shared key on purpose and diagnosed it with Network Watcher VPN troubleshoot
>
> Then I deleted both gateways the same day, because hybrid labs are where budgets go to die.
> #Azure #AZ104 #HybridCloud #VPN #AzureNetworking #LearningInPublic
