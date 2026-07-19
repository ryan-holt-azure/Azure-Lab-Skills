# Lab 21 — Application Insights

**Domain:** Monitoring & Backup (10–15%) · **Extension lab** — confirmed AZ-104
objective (5.1.5 "Configure Application Insights" in the official study guide)
that never got a dedicated build in the original 18. · **Cost:** low — one B1
App Service, short-lived.

## Objectives (exam skills covered)

Configure Application Insights

## Why this lab exists

Lab 16 covers Azure Monitor, Log Analytics, and KQL — infrastructure-level
monitoring (VM CPU, failed logins, resource-level signals). Application
Insights is a different layer entirely: **application performance
monitoring** — request rates, response times, dependency calls, exceptions,
live traffic — for an app itself, not the VM or service hosting it. Both are
real, separate AZ-104 objectives; this lab closes the one Lab 16 doesn't
touch.

## Build

1. Reuse or recreate the App Service from Lab 11:
   ```bash
   az group create -n rg-lab21 -l eastus
   az appservice plan create -n plan-lab21 -g rg-lab21 --sku B1
   az webapp create -n webapp-lab21-ryan -g rg-lab21 --plan plan-lab21
   ```
2. Create an **Application Insights** resource and connect it to the web app:
   ```bash
   az monitor app-insights component create -a appi-lab21 -g rg-lab21 -l eastus
   ```
   Link it via the web app's **Application Insights** blade in the portal
   (the guided "Turn on Application Insights" flow) rather than hand-wiring
   the instrumentation key — this is how it's actually done in practice.
3. Generate real traffic: hit the deployed app's URL repeatedly (a simple
   loop in a terminal works), including at least one request to a path that
   doesn't exist (to generate a real failed-request data point).
4. In the **Application Insights** resource, explore:
   - **Live Metrics** — near-real-time request rate and response time while
     you're actively generating traffic.
   - **Failures** — the 404s you just generated, with the actual request
     details.
   - **Performance** — response time breakdown by operation.
   - **Application Map** — the visual dependency view (limited with just one
     app and no downstream dependencies, but worth seeing how it would look
     with a real multi-service app).
5. Write one **Kusto query** directly against the Application Insights data
   (same KQL skill from Lab 16, different table):
   ```kql
   requests
   | where resultCode == "404"
   | summarize count() by bin(timestamp, 5m)
   ```

## Exam facts

- Application Insights is part of **Azure Monitor** but operates at the
  **application layer** — requests, dependencies, exceptions, custom
  telemetry — distinct from **Log Analytics**, which is infrastructure/
  platform-layer logs and metrics (Lab 16).
- Connecting an app to Application Insights can be done via the
  **instrumentation key** (older) or the **connection string** (current,
  recommended — supports regional endpoints and is what the portal's guided
  flow sets up by default).
- **Live Metrics** streams data with near-zero latency for active
  troubleshooting; the rest of Application Insights (Failures, Performance)
  has the normal Azure Monitor ingestion delay.
- Application Insights data is queried with the **same KQL** used against
  Log Analytics — the skill from Lab 16 transfers directly, just against
  different tables (`requests`, `dependencies`, `exceptions` instead of
  `Perf`, `Heartbeat`).

## Job posting relevance

The HIPAA/Sophos posting's "root cause analysis" and "monitoring tools to
proactively identify... concerns" lines apply here just as much as they did
to Lab 16 — the difference is *which* problems this catches. Infrastructure
monitoring (Lab 16) tells you the VM is healthy; Application Insights tells
you the app running on that healthy VM is throwing exceptions on a specific
endpoint. A real "site is slow" complaint gets diagnosed with this tool, not
Log Analytics alone.

## Pro / interview talking point

"The server's fine" and "the app works" are different claims, and only one
of them is what a customer actually experiences. Application Insights is
what closes that gap — it's the tool that tells you the CPU is at 12% while
users are still getting 500 errors on checkout, because the two are
measuring different layers of the same system.

## Cleanup

```bash
az group delete -n rg-lab21 --yes --no-wait
```
