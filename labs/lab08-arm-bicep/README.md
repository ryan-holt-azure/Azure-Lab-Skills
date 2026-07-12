# Lab 08 — ARM & Bicep Round-Trip

**Domain:** Compute (20–25%) · **Week:** 2 · **Cost:** one B1s VM, short-lived

## Objectives (exam skills covered)

Modify ARM template · Configure a VHD template · Deploy from template · Save a
deployment as an ARM template

## Build

1. Deploy a **B1s VM** in the portal. **Export the template** (VM's Automation
   → Export template) and read every section.
2. **Decompile** it to Bicep:
   ```bash
   az bicep decompile --file template.json
   ```
3. Parameterize `vmName` and `size` in the Bicep file. Redeploy to a **new
   resource group** with a `what-if` preview first:
   ```bash
   az deployment group what-if -g rg-lab08b -f main.bicep
   az deployment group create -g rg-lab08b -f main.bicep
   ```
4. In a **sacrificial resource group** containing an extra, unrelated resource,
   run one deployment in **Complete mode** and watch the extra resource get
   **removed**.
   ```bash
   az deployment group create -g rg-lab08-sacrificial -f main.bicep --mode Complete
   ```

## Exam facts

- **Incremental** is the default deployment mode — it adds/updates, never
  deletes anything not in the template. **Complete** mode deletes anything in
  the resource group that isn't in the template.
- Template sections: `parameters`, `variables`, `resources`, `outputs`.
- `what-if` previews the changes a deployment would make before it runs.
- Exporting from the portal captures current state **including defaults**, not
  just what was explicitly configured.

## Pro / interview talking point

This is the on-ramp to declarative infrastructure generally — same
export → decompile → parameterize → what-if → deploy mindset carries directly
into Terraform or any other IaC tool later; only the syntax changes.

## Cleanup

```bash
az group delete -n rg-lab08 --yes --no-wait
az group delete -n rg-lab08b --yes --no-wait
az group delete -n rg-lab08-sacrificial --yes --no-wait
```
