# Lab 14 — Monitor and Maintain: Metrics, Logs, KQL, Alerts, Insights and Connection Monitor

> **Scenario:** HLG's operations center in Chicago needs one place to see the whole estate: CPU on every server, who deleted what, failed storage requests, whether Amsterdam can still reach Singapore, and a phone call at 3 a.m. only when it matters (never during the Saturday maintenance window). You'll build it with Azure Monitor, Log Analytics and Network Watcher.
>
> **Time:** ~3.5 h · **Cost:** ~$0.50–1 (log ingestion under a 0.5 GB/day cap, alert rules, connection monitor tests) · **Prereqs:** Labs 03, 06, 09, 10

## What you'll build

```
law-hlg-eus (Log Analytics, East US, 0.5 GB/day cap)
 ◄── Activity log (subscription)         ◄── sthlgops… blob logs     ◄── kv-hlg-… audit logs
 ◄── dcr-hlg-linux (AMA: Perf + Syslog) on 4 Linux VMs  ◄── VM insights (weu, sea)
 ◄── cm-hlg-weu (Connection monitor)     ◄── Traffic analytics (VNet flow logs on WEU)

Alerts → ag-hlg-ops (email/SMS)
  al-hlg-weu-cpu-high (metric) · al-hlg-vm-silent (log search) · al-hlg-sea-vm-deallocated (activity log)
Alert processing rules: apr-hlg-sea-maintenance (suppress Sat 01-05) · apr-hlg-sev01-route (add action group)
```

## Skills measured covered

| Study guide skill | Where |
|---|---|
| Interpret metrics in Azure Monitor | Task 2 |
| Configure log settings in Azure Monitor | Task 3 |
| Query and analyze logs in Azure Monitor | Task 4 |
| Set up alert rules, action groups, and alert processing rules in Azure Monitor | Task 5 |
| Configure and interpret monitoring of virtual machines, storage accounts, and networks by using Azure Monitor Insights | Task 6 |
| Use Azure Network Watcher and Connection monitor | Task 7 |

```bash
rc() { az vm run-command invoke -g "$1" -n "$2" --command-id RunShellScript --scripts "$3" --query "value[0].message" -o tsv; }
bash scripts/start-all-vms.sh     # monitoring needs running VMs
```

---

## Task 1 — Log Analytics workspace with a cost guard

1. **Create a resource → Log Analytics workspace**: RG `rg-hlg-mgmt-eus`, name `law-hlg-eus`, East US.
2. Workspace → **Settings → Usage and estimated costs** → **Daily cap** → **0.5 GB/day** → OK.
3. **Settings → Tables**: note the default **interactive retention** (30 days) and that **total retention** can extend to years in the long-term tier.

> [!TIP]
> **🎯 EXAM TIP — Workspace design.** Pricing is mostly **per GB ingested**. Commitment tiers discount high volume, and a **daily cap** stops ingestion (except some security data) once reached, so you **lose data** for the rest of the day. Access is controlled by **workspace-context** or **resource-context** permissions (*Log Analytics Reader/Contributor*, or table-level RBAC). Keep one central workspace unless regulation or billing requires separation.

---

## Task 2 — Interpret metrics

1. **Monitor → Metrics** → scope `vm-hlg-weu-app01` → metric **Percentage CPU**, aggregation **Avg** → **+ Add metric**: same metric with aggregation **Max** → time range **Last 4 hours**, granularity **5 minutes**.
2. New chart, scope `sthlgops…` → namespace **Account** → **Transactions** → **Apply splitting** by **Response type** → **Add filter** *API name = GetBlob*. You should see the Lab 10 403s (`AuthorizationFailure`, `AuthenticationFailed`) next to `Success`.
3. New chart, scope `lbe-hlg-weu-web` (if it still exists) → **Health Probe Status**, split by **Backend IP Address**.
4. **Pin to dashboard** → **Create new** → `HLG Ops` (shared). Open the dashboard.
5. On any chart, open **…** → **Drill into Logs** (where supported) and **New alert rule** to see how metrics link to logs and alerts.

> [!TIP]
> **🎯 EXAM TIP — Metrics vs logs.**
> - **Platform metrics** are collected automatically, are free, have about 1-minute granularity and **93 days** retention, and you view them in Metrics explorer.
> - **Guest OS** metrics (memory inside the VM, disk per mount) need the **Azure Monitor Agent** + a data collection rule.
> - **Logs** (resource logs, activity log, VM logs) go to Log Analytics only when you configure them (Task 3).
> - **Aggregations:** Avg, Min, Max, Sum, Count.
> - **Splitting** = one line per dimension value. **Filtering** = only some dimension values.
> - "Average CPU looks fine but users report spikes" → look at **Max**.

> 📸 **Checkpoint 14-01** — The storage Transactions chart split by response type, plus the HLG Ops dashboard. → `screenshots/lab-14/14-01-metrics.png`

---

## Task 3 — Configure log settings (diagnostic settings, DCR, AMA)

### 3a. Activity log → workspace
**Monitor → Activity log → Export Activity Logs** → **+ Add diagnostic setting** → `ds-hlg-activity-to-law` → select **all categories** → **Send to Log Analytics workspace** `law-hlg-eus` → Save.

### 3b. Storage resource logs
`sthlgops…` → **Monitoring → Diagnostic settings** → **blob** → **+ Add diagnostic setting** → `ds-hlg-blob-to-law` → **StorageRead, StorageWrite, StorageDelete** (+ *Transaction* metrics) → LAW → Save.

### 3c. Key Vault audit
`kv-hlg-…` → **Diagnostic settings** → **audit** category group → LAW → Save.

### 3d. VM guest data: Data collection rule + Azure Monitor Agent
**Monitor → Settings → Data Collection Rules → + Create**:
- Name `dcr-hlg-linux`, RG `rg-hlg-mgmt-eus`, region **East US** (same as the workspace), platform **Linux**
- **Resources:** add `vm-hlg-chi-srv01`, `vm-hlg-hub-nva01`, `vm-hlg-weu-app01`, `vm-hlg-sea-app01`. The portal enables a managed identity and **installs the Azure Monitor Agent**.
- **Collect and deliver:**
  - **Performance counters** → *Basic* (CPU, memory, disk, network), sample every 60 s → destination `law-hlg-eus`
  - **Linux syslog** → `LOG_WARNING` minimum for auth, authpriv, daemon, syslog → `law-hlg-eus`
- Create. VMs → **Extensions** shows `AzureMonitorLinuxAgent`.

### 3e. VM insights
**Monitor → Virtual Machines → Not monitored** → `vm-hlg-weu-app01` → **Enable** → create a VM insights data collection rule targeting `law-hlg-eus` (processes and dependencies off) → Configure. Repeat for `vm-hlg-sea-app01`.

> [!TIP]
> **🎯 EXAM TIP — Where data comes from and how it gets there:**
>
> | Data | Collected by | How to enable |
> |---|---|---|
> | Platform metrics | Automatic | Nothing |
> | **Activity log** (control-plane events) | Automatic, **90 days** in the portal | **Diagnostic setting** on the subscription to keep or analyse it |
> | **Resource logs** (data-plane: blob reads, Key Vault access, NSG events) | **Not collected by default** | **Diagnostic setting** per resource (up to **5** per resource) |
> | Guest OS perf, syslog, Windows events | **Azure Monitor Agent** | **Data collection rule (DCR)** associated with the VMs |
>
> Diagnostic setting destinations: **Log Analytics** (query/alert), **Storage account** (cheap archive), **Event Hub** (stream to a SIEM or third party), partner solutions. The legacy **Log Analytics agent (MMA/OMS)** was **retired 31 Aug 2024**. On a current exam the answer is **AMA + DCR**.

> 📸 **Checkpoint 14-02** — The diagnostic setting for blob logs, plus the DCR's Resources tab with 4 VMs. → `screenshots/lab-14/14-02-log-settings.png`

---

## Task 4 — Query and analyze logs (KQL)

Wait 10–15 minutes for data. Then **law-hlg-eus → Logs** (switch to **KQL mode**) and run queries from [`kql/hlg-queries.kql`](../kql/hlg-queries.kql):

| # | Query | What to look for |
|---|---|---|
| 1 | Heartbeat by computer | Four Linux VMs reporting |
| 3 | `InsightsMetrics` CPU timechart | VM insights data for WEU and SEA |
| 5 | Successful deletes in the Activity log | Your Lab 11–13 cleanups, with **Caller** |
| 6 | `RequestDisallowedByPolicy` | Lab 02 policy denials, if you repeat a denied deployment now |
| 7 | Role assignment changes | Lab 04 (if within the retention window) |
| 8 | `StorageBlobLogs` failures | Generate some: `curl -s https://$OPS.blob.core.windows.net/manifests/route-chi-ams.json` (anonymous → 409/403) |

Then:
1. Edit query 1: add `| where MinutesSilent > 5` and `| project Computer, MinutesSilent`. Run it.
2. **Save → Save as query** → name `HLG - Silent VMs`, category *HLG* (saves to a query pack).
3. **Export → CSV**. Look at **Share → Copy link to query**.

> [!TIP]
> **🎯 EXAM TIP — Read KQL fast.** `Table | where … | summarize agg() by col, bin(TimeGenerated, 5m) | project … | order by … | take N | render timechart`.
> - `where` filters **rows**. `project` picks **columns**. `extend` **adds** a column. `summarize` **aggregates** (`count()`, `avg()`, `max()`, `dcount()`, `arg_max()`).
> - `ago(1h)` = relative time. `has` matches whole terms (fast). `contains` matches substrings (slow).
> - Expect a query on screen and a question like "what does it return?" or "which line do you change to get X?".
> - Tables to recognize: **Heartbeat**, **Perf**, **InsightsMetrics**, **Syslog**, **Event**, **AzureActivity**, **AzureDiagnostics** (legacy shared table), resource-specific tables such as **StorageBlobLogs**.

> 📸 **Checkpoint 14-03** — A KQL result with a timechart, plus the saved query in the query pack. → `screenshots/lab-14/14-03-kql.png`

---

## Task 5 — Alert rules, action groups and alert processing rules

### 5a. Action group
**Monitor → Alerts → Action groups → + Create** → RG `rg-hlg-mgmt-eus`, name `ag-hlg-ops`, display `HLG Ops` → **Notifications**: *Email/SMS message/Push/Voice* → email (and SMS if you like) → **Actions**: scroll through the types (Automation runbook, Azure Function, Event Hub, ITSM, Logic App, Webhook, Secure webhook) and add none → Create → **Test action group**.

### 5b. Metric alert
**Alerts → + Create → Alert rule** → scope `vm-hlg-weu-app01` → signal **Percentage CPU** → threshold **Static**, **Greater than 80**, aggregation **Average**, granularity **5 min**, frequency **1 min** → action group `ag-hlg-ops` → severity **2 - Warning** → name `al-hlg-weu-cpu-high`.
Fire it:
```bash
rc rg-hlg-spoke-weu vm-hlg-weu-app01 "nohup timeout 600 bash -c 'yes > /dev/null' >/dev/null 2>&1 & echo load started"
```
You'll get a **Fired** email in about 5–10 minutes, and a **Resolved** email after the load stops. Metric alerts are **stateful**.

### 5c. Log search alert
**+ Create → Alert rule** → scope `law-hlg-eus` → signal **Custom log search** → paste query #2 (silent VMs) → measurement **Table rows**, aggregation **Count**, threshold **> 0**, frequency **5 min**, lookback **15 min** → `ag-hlg-ops` → severity **1 - Error** → name `al-hlg-vm-silent`.
Test: `az vm deallocate -g rg-hlg-onprem-chi -n vm-hlg-chi-srv01` → wait about 15–20 minutes → alert. Start the VM again.

### 5d. Activity log alert
**+ Create → Alert rule** → scope **`rg-hlg-spoke-sea`** → signal **Deallocate Virtual Machine (Virtual Machines)** → `ag-hlg-ops` → name `al-hlg-sea-vm-deallocated`.
Test: `az vm deallocate -g rg-hlg-spoke-sea -n vm-hlg-sea-app01` → email within a few minutes. Start it again.

### 5e. Alert processing rule: maintenance window suppression
**Alerts → Alert processing rules → + Create**:
- Scope **`rg-hlg-spoke-sea`** · filter: none
- Rule settings: **Suppress notifications**
- Scheduling: **Recurring → Weekly → Saturday 01:00–05:00** (your time zone). **Also add** a one-time window **from now for 1 hour** so you can test it.
- Name `apr-hlg-sea-maintenance`.

Test: deallocate `vm-hlg-sea-app01` again → the alert **appears in Alerts** (fired), but **no email arrives**. Then remove the one-time window and start the VM.

### 5f. Alert processing rule: route by severity
**+ Create** → scope **subscription** → filter **Severity = Sev0, Sev1** → rule setting **Apply action group** → `ag-hlg-ops` → name `apr-hlg-sev01-route`. Now any Sev0/Sev1 alert notifies Ops, even from rules created without an action group.

> [!TIP]
> **🎯 EXAM TIP — Alert building blocks:**
> - **Alert rule** = scope + **condition (signal)** + actions + severity (**Sev0 Critical … Sev4 Verbose**).
> - Signal types: **metric**, **log search**, **activity log** (including **Service Health** and **Resource Health**), Prometheus, smart detection.
> - **Action group** = **who** is notified (email, SMS, push, voice) + **what runs** (runbook, Function, Logic App, webhook, ITSM, Event Hub). It's reusable across alert rules. **Rate limits:** SMS and voice at most once every 5 minutes per number, email at most 100 per hour per address.
> - **Alert processing rule** = acts on **fired alerts** at a scope. It can **suppress** notifications (maintenance windows) or **add action groups**, with filters (severity, resource type, alert rule, monitor service) and schedules. It **doesn't** stop alerts from firing.
> - **Monitor condition** (Fired/Resolved) is set by the system. **Alert state** (New/Acknowledged/Closed) is set by people.

> 📸 **Checkpoint 14-04** — Alerts list showing the fired alerts, the processing rule's schedule, and the email (blur your address). → `screenshots/lab-14/14-04-alerts.png`

---

## Task 6 — Insights: VMs, storage, networks (interpret them)

1. **Monitor → Virtual Machines → Performance**: compare CPU and **available memory** across WEU and SEA. Which VM had the spike, and when? (Task 5b.)
2. **Monitor → Storage accounts** (Storage insights) → `sthlgops…` → **Failures**: which API had errors and with what status? **Performance**: E2E vs server latency. **Capacity**: by blob/file.
3. **Monitor → Networks** (Network insights) → **Topology** (pick the hub and spoke RGs) and **Connectivity** (fills in after Task 7).
4. Load balancer → **Insights** (if `lbe-hlg-weu-web` exists): dependency view and metrics dashboard.
5. Key Vault → **Insights**: operations and failures from your Lab 10 key work.

Answer in your notes: *Which VM is closest to its memory limit? What share of `sthlgops…` requests failed in the last 24 hours, and why?*

> [!TIP]
> **🎯 EXAM TIP — Insights are curated workbooks over metrics and logs.** **VM insights** needs AMA + its DCR (performance; the **Map** needs the Dependency agent). **Storage insights** works from platform metrics with no setup. **Network insights** shows topology, health and Connection monitor/Traffic analytics results. When a question says "see the performance of all VMs in one place" or "find which storage accounts have availability problems", the answer is the matching insight.

> 📸 **Checkpoint 14-05** — VM insights performance plus Storage insights failures. → `screenshots/lab-14/14-05-insights.png`

---

## Task 7 — Network Watcher: Connection monitor and VNet flow logs

### 7a. Connection monitor
**Network Watcher → Connection monitor → + Create**:
- Name `cm-hlg-weu`, region **West Europe** (the source VM's region), workspace `law-hlg-eus`
- **Test group** `tg-weu-outbound`:
  - **Sources:** Azure VM `vm-hlg-weu-app01` (the Network Watcher agent installs automatically)
  - **Test configurations:** `tcp-80` (TCP 80, every 30 s), `tcp-443` (TCP 443), `icmp`
  - **Destinations:**
    - `vm-hlg-sea-app01` → `tcp-80`. Should pass (through the NVA).
    - External address `www.bing.com` → `tcp-443`. Should pass.
    - IP `10.10.1.4` (Chicago) → `tcp-80`. **Should fail** if you deleted the Lab 07 VPN. That's a good failing test to read.
- Optionally create an alert from the wizard: *Checks failed % > 20*.
- Create, wait about 5 minutes, then open the monitor: **checks failed %**, **round-trip time**, and the **topology** per test, including the hop where Chicago fails.

### 7b. VNet flow logs + Traffic analytics
**Network Watcher → Flow logs → + Create**:
- Flow log type **Virtual network** → target `vnet-hlg-spoke-weu`
- Storage account **`sthlgweu…`** (it **must be in the same region** as the VNet; Lab 06 left the trusted-services exception on) → retention **7 days**
- **Traffic analytics:** on → workspace `law-hlg-eus` → processing interval **10 min**
- Create. After 20–30 minutes: **Traffic analytics** shows flows between 10.40/16 and 10.30/16, and the storage container `insights-logs-flowlogflowevent` fills.

> [!TIP]
> **🎯 EXAM TIP — Connection monitor vs connection troubleshoot.** **Connection troubleshoot** is a **one-time** check (Lab 05). **Connection monitor** is **continuous** monitoring from sources (Azure VMs and scale sets with the Network Watcher agent, or on-prem machines with AMA) to destinations (VMs, URLs, FQDNs, IPs) over TCP/HTTP/ICMP, with **alerts** and results in Log Analytics. Connection monitor replaces the retired *Network Performance Monitor* and the classic connection monitor.

> [!TIP]
> **🎯 EXAM TIP — Flow logs.** **NSG flow logs retire on 30 September 2027 and new ones can't be created.** Use **VNet flow logs** (VNet, subnet or NIC scope), which also log traffic that NSGs don't evaluate. The storage account **must be in the same region** as the target. **Traffic analytics** processes flow logs into Log Analytics for maps and top talkers.

> 📸 **Checkpoint 14-06** — The connection monitor with passing SEA/Bing tests and the failing Chicago test with its topology. → `screenshots/lab-14/14-06-connection-monitor.png`

---

## Break-fix challenges

1. Blob reads appear in Metrics but `StorageBlobLogs` is empty. What's missing?
2. The `al-hlg-vm-silent` alert fired during the Saturday maintenance window and woke someone up. You have an alert processing rule for that window. Why didn't it suppress?
3. Connection monitor won't let you pick `vm-hlg-sea-app01` as a source in `cm-hlg-weu`. Why?

<details><summary>Answers</summary>

1. A **diagnostic setting** on the storage account's **blob** service sending StorageRead to the workspace. Or ingestion delay, or the daily cap was hit.
2. `apr-hlg-sea-maintenance` is scoped to **rg-hlg-spoke-sea**. `al-hlg-vm-silent` is a log search alert on the **workspace** (in `rg-hlg-mgmt-eus`), and alert processing rules match the alert's **target resource scope**. Scope the processing rule to the workspace or subscription, or filter by alert rule.
3. Connection monitor sources must be in the **monitor's region** (West Europe). Create a second monitor in Southeast Asia for SEA sources.
</details>

---

## Knowledge check

1. You need to keep activity log data for 2 years and query it. What do you configure?
2. A VM's memory usage must trigger an alert. The VM has no agent. What's needed first?
3. Notifications must not be sent during a planned maintenance window, but alerts must still be recorded. What do you create?
4. Which KQL operator adds a calculated column without removing others?
5. You must stream resource logs to a third-party SIEM in near real time. Which diagnostic setting destination?

<details><summary>Answers</summary>

1. A subscription **diagnostic setting** sending the activity log to a **Log Analytics workspace** (with retention set to 2 years) or to a **storage account** for archive.
2. The **Azure Monitor Agent** with a **data collection rule** collecting memory counters (or VM insights). Memory inside the guest isn't a basic platform metric.
3. An **alert processing rule** with **Suppress notifications** on a schedule.
4. **`extend`.**
5. **Event Hub.**
</details>

---

## Clean up

```bash
az network watcher connection-monitor delete --location westeurope --name cm-hlg-weu
az network watcher flow-log delete --location westeurope --name "$(az network watcher flow-log list --location westeurope --query '[0].name' -o tsv)"
bash scripts/stop-all-vms.sh
```
**Keep:** the workspace (daily cap on), DCRs, diagnostic settings, alert rules, the action group and processing rules. Lab 15 sends backup reports to the same workspace. Disable `al-hlg-vm-silent` if deallocated VMs make it noisy (a log search alert evaluating every 5 minutes costs about a dollar a month).

## 📣 Document it

```bash
git add notes/lab-14.md screenshots/lab-14 && git commit -m "Lab 14: metrics, diagnostic settings, AMA + DCR, KQL, metric/log/activity alerts, alert processing rules, insights, connection monitor, VNet flow logs"
```

**LinkedIn post template:**
> Lab 14 of my AZ-104 hybrid build: an operations center for a 4-region network.
>
> 📊 Metrics explorer: split storage transactions by response type to find the 403s from my own security lab
> 🧾 Diagnostic settings for the activity log, blob and Key Vault logs, and Azure Monitor Agent + a data collection rule on 4 Linux VMs
> 🔎 KQL: silent VMs, who deleted what, policy denials, failed blob reads
> 🚨 Metric, log search and activity log alerts into one action group, plus alert processing rules that suppress the Saturday maintenance window and route Sev0/1 to Ops
> 🌐 Connection monitor Amsterdam → Singapore and Bing (pass) and → Chicago with the VPN gone (fail), showing the exact failing hop
> 🔁 VNet flow logs + Traffic analytics, because NSG flow logs are retiring
>
> #Azure #AZ104 #AzureMonitor #KQL #Observability #LearningInPublic
