# AZ-104 Lab Portfolio

Hands-on Azure Administrator (AZ-104) lab work, built against an 18-lab curriculum
mapped to the official Microsoft skills outline. Exam target: August 2026.

This repo is proof of work, not just study notes. Each lab folder has:

- **README.md** — the runbook: what to build, why, the exact exam facts it tests, and
  the interview-ready "pro" talking point.
- **RESULTS.md** — a fill-in-the-blank log filled out *after* actually running the lab
  in Azure: commands run, output, screenshots, gotchas hit, cost check.

Commit after every lab. The log entries are the portfolio — they show real hands-on
work, not just that a study guide was read.

## Domains (weighted by exam %)

| Domain | Weight | Labs |
|---|---|---|
| Identity & Governance | 20–25% | 1–4 |
| Storage | 15–20% | 5–7 |
| Compute | 20–25% | 8–11 |
| Networking | 15–20% | 12–15 |
| Monitoring & Backup | 10–15% | 16–18 |

## Credit protection rules (non-negotiable)

The Azure free credit ($200) expires 30 days after activation. These rules exist so
labs get done without accidentally burning the whole credit on an idle VM:

1. **One resource group per lab** (`rg-lab01`, `rg-lab02`, …). End every session with
   `scripts/cleanup.sh` or its PowerShell equivalent — nothing survives overnight
   except Log Analytics (pennies).
2. **VMs: B1s/B2s only**, and always **deallocate** — not just stop from inside the
   OS. A stopped-but-allocated VM still bills.
3. **Set the $50 budget alert on day one** — that's Lab 4. Do it before building
   anything else.
4. **Bastion bills ~$4.50/day idle.** Deploy it, use it, delete it the same session
   (or use the Developer SKU if offered). Same discipline for VPN gateways and Site
   Recovery replication.
5. **Azure Firewall (Lab 19) bills ~$1.25/day idle**, same discipline as Bastion —
   deploy, use, delete, in that session.
6. **End-of-session ritual, every time:**
   ```
   az group list -o table          # what still exists?
   az group delete -n rg-labXX --yes --no-wait
   # then: Cost Management -> Cost analysis -> confirm today's spend ~ $0
   ```

Estimated total spend if the rules are followed: **$25–45 of the $200**. The surplus
is margin for re-running weak-domain labs — not an invitation to leave VMs running.

## Naming conventions

- Resource groups: `rg-lab01`, `rg-lab02`, …
- Test users: `test.nurse1`, `test.billing1`
- Groups: `grp-clinic-assigned`, `grp-clinic-dynamic`

Consistent naming means cleanup-by-pattern is possible and nothing survives to eat
the credit. It's also a real governance habit, not just lab hygiene.

## The 30-day burn-down

| Days | Focus |
|---|---|
| 1–7 | Labs 1–4 (identity/governance — weakest domain gets the freshest energy; Lab 4's budget guards the rest) |
| 8–14 | Labs 8–11 (compute + IaC) |
| 15–22 | Labs 12–15, then 5–7 (networking on strength week; storage rides along — Lab 5's firewall reuses Lab 12's VNet) |
| 23–27 | Labs 16–18 (monitoring + backup; keep ASR inside its 31-day free window) |
| 28–30 | No new builds. Microsoft's free practice assessment daily until ≥85% steady. Re-run any lab tied to a weak domain. |

Every session ends with `az group delete`. Every week ends with a commit.

## Lab index

| # | Lab | Domain |
|---|---|---|
| [01](labs/lab01-identity-users-groups-sspr/README.md) | Entra users, groups, SSPR | Identity |
| [02](labs/lab02-rbac-scopes/README.md) | RBAC at every scope | Identity |
| [03](labs/lab03-governance-policy-locks-tags/README.md) | Policy, locks, tags, management groups | Identity |
| [04](labs/lab04-cost-budgets-advisor/README.md) | Budgets, alerts, Advisor | Identity |
| [05](labs/lab05-storage-sas-firewall/README.md) | Storage accounts, keys, SAS, firewall | Storage |
| [06](labs/lab06-blob-tiers-lifecycle/README.md) | Blob tiers, lifecycle, versioning | Storage |
| [07](labs/lab07-files-storageexplorer-azcopy/README.md) | Azure Files, Storage Explorer, AzCopy | Storage |
| [08](labs/lab08-arm-bicep/README.md) | ARM & Bicep round-trip | Compute |
| [09](labs/lab09-vm-operations/README.md) | VM operations end to end | Compute |
| [10](labs/lab10-scale-sets/README.md) | Scale sets | Compute |
| [11](labs/lab11-appservice-containers/README.md) | App Service, slots, containers | Compute |
| [12](labs/lab12-vnets-peering/README.md) | VNets and peering | Networking |
| [13](labs/lab13-nsg-asg-bastion/README.md) | NSG, ASG, Bastion, effective rules | Networking |
| [14](labs/lab14-udr-endpoints/README.md) | UDRs, service endpoints, private endpoints | Networking |
| [15](labs/lab15-dns-loadbalancing/README.md) | DNS and load balancing | Networking |
| [16](labs/lab16-monitor-kql-alerts/README.md) | Azure Monitor + KQL + alerts | Monitoring |
| [17](labs/lab17-network-watcher/README.md) | Network Watcher | Monitoring |
| [18](labs/lab18-backup-siterecovery/README.md) | Backup and Site Recovery | Monitoring |

## Extensions beyond the core 18

The 18 labs above are the original curriculum, unchanged. These two were added
afterward for a specific reason each — not part of "the 18-lab curriculum" claim
above, called out separately so that claim stays accurate:

| Lab | Why it's here |
|---|---|
| [19 — Azure Firewall](labs/lab19-azure-firewall/README.md) | Closes a real gap: Azure Firewall is a genuine AZ-104 objective (4.2.4) that never got a dedicated hands-on lab in the original 18 |
| [Bonus — Azure Lighthouse (MSP Multi-Customer)](labs/bonus-lighthouse-msp/README.md) | **Not** an AZ-104 exam objective — added because a real job posting required "prior experience handling multiple customers at an IT consultancy or MSP," and Lighthouse is the direct Azure-native answer to that |

## Gotchas that will cost you an evening

- Greyed-out Dynamic membership → no P1/P2 license. Activate the trial (Lab 0 setup).
- License assignment fails → the user has no Usage Location set.
- Dynamic group looks empty → be patient, wait 5–10 minutes.
- Policy "isn't working" → wait 10–15 minutes after assignment.
- Can't create a management group → elevate access first (Entra ID → Properties →
  Access management for Azure resources → Yes). Turn it back off when done.
- Can't delete a resource group → there's a lock on it.
- Cleanup command fails silently → run `az group list -o table` and look for survivors.

## Setup (once)

1. Sign in at portal.azure.com, note the tenant name (`yourname.onmicrosoft.com`).
2. Open Cloud Shell (Bash), confirm subscription with `az account show --output table`.
3. Activate the Entra ID P2 free trial (Entra ID → Licenses → All products → Try/Buy) —
   without it, dynamic groups are greyed out and Lab 1 stalls.
4. Adopt the naming convention above before creating anything.
