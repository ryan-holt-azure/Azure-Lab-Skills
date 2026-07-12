# Lab 16 — Azure Monitor + KQL + Alerts

**Domain:** Monitoring & Backup (10–15%) · **Week:** 4 · **Cost:** Log Analytics
workspace (pennies) + one lab VM, short-lived

## Objectives (exam skills covered)

Configure and interpret metrics · Configure Azure Monitor logs · Query and
analyze logs · Set up alerts and actions

## Build

1. Create a **Log Analytics workspace**. Create a **Data Collection Rule (DCR)**
   sending a VM's perf counters + syslog/event data to it.
2. Run KQL queries:
   ```kql
   Heartbeat
   | summarize by Computer

   Perf
   | where CounterName == '% Processor Time'
   | summarize avg(CounterValue) by bin(TimeGenerated, 5m)
   ```
3. Create a **metric alert**: CPU > 80% → routes to **`ag-email-ryan`** (the
   action group built in **Lab 04** — reuse it, don't rebuild). Stress the VM
   and confirm the alert email actually arrives.
4. Add an **alert processing rule** that suppresses notifications at night.

## Exam facts

- **Metrics** = fast numeric time-series data. **Logs** = KQL queries over the
  Log Analytics workspace.
- **DCRs** target Log Analytics workspaces.
- Alert flow: **rule → action group → (optional) processing rule** to
  suppress or route.
- **Dynamic thresholds** learn a baseline instead of using a fixed number.

## Pro / interview talking point

KQL is T-SQL's cousin — that's the fastest way to get productive in it fast.
Being the person on a team who can actually write the query instead of
clicking through a dashboard is a real differentiator.

## Cleanup

```bash
az group delete -n rg-lab16 --yes --no-wait
```
Keep the Log Analytics workspace if other labs (17) will reuse it in the same
session; otherwise delete it too — it's pennies, not free.
