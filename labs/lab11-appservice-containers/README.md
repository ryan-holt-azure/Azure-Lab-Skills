# Lab 11 — App Service, Slots, Containers

**Domain:** Compute (20–25%) · **Week:** 2 · **Cost:** low — B1 App Service plan
+ ACR Basic, short-lived

## Objectives (exam skills covered)

Create an App Service plan · Create an App Service · Configure deployment
settings · Configure sizing/scaling and container groups for Azure Container
Instances

## Build

1. Create a **B1 App Service plan** + web app, deploy the sample app.
2. Create a **STAGING slot**, change the app visibly (e.g. edit the homepage
   text), then **swap** — witness the zero-downtime deploy. Don't map a custom
   domain (avoids DNS cost); just read the custom-domain + TLS blade so the
   flow is familiar.
3. Create an **ACR (Basic)** → build and push the hello-world image:
   ```bash
   az acr build --registry <acrName> --image hello-world:v1 .
   ```
4. Run the image in **ACI**, then in **Container Apps** with a scale rule of
   **min 0**.

## Exam facts

- **Deployment slots** require **Standard tier or higher**. Swap exchanges
  content and a *subset* of config — some settings are "slot-sticky" and don't
  swap.
- **One App Service plan** can host many apps — they share the underlying
  compute.
- **ACI multi-container groups are Linux only.**
- **Container Apps scale to zero; ACI does not.**
- **ACR tiers**: Basic / Standard / Premium (Premium adds private link +
  geo-replication).

## Pro / interview talking point

Slot-swap is how professionals ship without 2 a.m. deploy windows — worth
remembering the feeling of watching a zero-downtime swap happen, because it's
the argument for the practice in any future job that still does manual
cutover deploys.

## Cleanup

```bash
az group delete -n rg-lab11 --yes --no-wait
```
