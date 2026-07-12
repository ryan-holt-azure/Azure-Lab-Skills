# Lab 15 — DNS and Load Balancing

**Domain:** Networking (15–20%) · **Week:** 3 · **Cost:** low — two small
web VMs + a Standard LB, short-lived

## Objectives (exam skills covered)

Configure Azure DNS, including private/public DNS zones · Configure an internal
or public load balancer · Troubleshoot load balancing

## Build

1. Create a **private DNS zone** linked to VNet A (from Lab 12) with
   **auto-registration** enabled. Confirm VM DNS records appear automatically.
2. Create a **Standard public Load Balancer**: backend pool = two IIS/nginx
   VMs, **health probe on port 80**, an LB rule forwarding traffic to the pool.
3. **Kill the web service on one VM** and watch the health probe pull it out of
   rotation.
4. Read (don't build) the **outbound-rules** and **NAT-rule** blades so the
   flow is familiar.

## Exam facts

- **Standard LB**: zone-redundant, SLA-backed, **secure by default** (needs an
  explicit NSG allow rule). **Basic**: none of that, and it's being retired.
- Load balancers are **regional**. Cross-region failover needs **Traffic
  Manager** (DNS-based) or **Front Door** (HTTP-based).
- **Health probe failure removes the instance from rotation — it does not heal
  it.**
- Private DNS **auto-registration only works via linked VNets** on private
  zones.

## Pro / interview talking point

The probe-pull moment — watching an unhealthy instance actually get removed in
real time — is exactly how real outages self-heal, or don't, when someone
forgot to open the probe port in the NSG. Having watched it happen beats
describing it from memory.

## Cleanup

```bash
az group delete -n rg-lab15 --yes --no-wait
```
