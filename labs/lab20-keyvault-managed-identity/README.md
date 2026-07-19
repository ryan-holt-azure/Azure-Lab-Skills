# Lab 20 — Key Vault + Managed Identity

**Domain:** Compute / Storage (crosses both) · **Extension lab** — a real gap
surfaced by outside AZ-104 study research, not part of the original 18 or
Lab 19/Lighthouse. · **Cost:** ~$0 — Key Vault and Managed Identity are free;
only a B1s VM has any cost.

## Objectives

Create and configure a Key Vault · Assign a System-Assigned Managed Identity
to a VM · Grant that identity access to a secret · Retrieve the secret from
inside the VM with no credential ever hardcoded anywhere

## Why this lab exists

Every other lab in this portfolio uses `az` CLI credentials or portal login —
none of them show how an **application** authenticates to another Azure
service **without a human typing a password or embedding a key in code**.
That's the actual, everyday pattern behind "hardcoded creds" — one of the
"boring misconfigurations, not hacks" categories flagged earlier in this
portfolio — and it's a gap in the original 18 labs, not something covered
elsewhere.

## Build

1. Create the sandbox and a Key Vault:
   ```bash
   az group create -n rg-lab20 -l eastus
   az keyvault create -n kv-lab20ryan -g rg-lab20 -l eastus
   ```
2. Store a secret (simulating a database connection string or API key):
   ```bash
   az keyvault secret set --vault-name kv-lab20ryan \
     --name "db-connection-string" --value "super-secret-value-nobody-should-hardcode"
   ```
3. Create a B1s VM with a **System-Assigned Managed Identity** enabled at
   creation:
   ```bash
   az vm create -n vm-lab20 -g rg-lab20 -l eastus \
     --image Ubuntu2404 --size Standard_B1s \
     --admin-username azureuser --generate-ssh-keys \
     --assign-identity
   ```
4. **Grant the VM's identity access to the secret.** Two models exist —
   build it both ways to see the difference:
   - **Access policies** (the older model): Key Vault → Access policies →
     add the VM's managed identity, grant `Get` on secrets.
   - **Azure RBAC** (the modern, recommended model): assign the built-in
     **Key Vault Secrets User** role to the VM's identity, scoped to the
     vault.
5. SSH into the VM. Get an access token from the VM's identity endpoint,
   then use it to read the secret — no username/password, no key file:
   ```bash
   curl -H Metadata:true \
     "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" \
     | jq -r .access_token
   ```
   Use that token in a call to the Key Vault secret endpoint and confirm the
   secret comes back — proof the VM authenticated as itself, not as you.
6. **Negative test**: from your own machine (not the VM), try to read the
   secret using only the VM's identity context (you can't — it only exists
   inside the VM). Confirm that without the RBAC/access-policy grant, even
   the VM itself gets a 403.

## Exam facts

- **System-assigned** managed identity is tied to the resource's lifecycle —
  deleted when the resource is deleted. **User-assigned** managed identity
  exists independently and can be shared across multiple resources.
- Key Vault access can be controlled by **legacy access policies** (per-vault,
  vault-scoped) or **Azure RBAC** (integrates with the same role system used
  everywhere else in Azure) — a vault uses one model or the other, set via
  the vault's "Permission model" setting, not both simultaneously.
- The **Instance Metadata Service endpoint** (`169.254.169.254`) is how any
  Azure compute resource retrieves its own managed identity token — it's
  only reachable from inside the resource itself, which is why the negative
  test above fails from your own machine.
- Key Vault soft-delete and purge protection exist so a deleted vault (and
  its secrets) can be recovered within a retention window — relevant to the
  same "backups depend on someone remembering" theme from Lab 06/18, applied
  to secrets instead of data.

## Job posting relevance

This is the direct fix for the "hardcoded creds" breach category named
explicitly in the security-misconfiguration framing used across this
portfolio — and it's the real mechanism the Cloud Engineer repo's Ops
Inventory API project (Phase 1.3) already assumes exists ("secrets in Key
Vault") without this repo ever having built it hands-on until now. Any
infrastructure or security-hardening line item in either researched posting
implicitly depends on this pattern being second nature, not something
looked up mid-interview.

## Pro / interview talking point

"No credential, anywhere, ever" is a stronger security posture than "the
credential is rotated regularly" — a managed identity can't be phished,
leaked in a git commit, or reused after an employee leaves, because it never
existed as a secret a human could see or copy in the first place.

## Cleanup

```bash
az group delete -n rg-lab20 --yes --no-wait
```
Key Vault has soft-delete on by default — the vault name may stay reserved
for a retention period after deletion. If reusing the name for a future
session fails, purge it explicitly: `az keyvault purge -n kv-lab20ryan`.
