#!/usr/bin/env bash
# =============================================================================
# Lab 00 preflight — run in Azure Cloud Shell (Bash) or any shell with az CLI.
# Checks: signed-in account, subscription type, resource providers,
# EncryptionAtHost feature, and VM size availability + vCPU quota per region.
#   bash scripts/preflight.sh                # checks Standard_B1s
#   bash scripts/preflight.sh Standard_B2s   # check another size
#   bash scripts/preflight.sh --register     # also registers missing providers
# =============================================================================
set -uo pipefail
SIZE="Standard_B1s"; REGISTER=false
for a in "$@"; do [[ "$a" == "--register" ]] && REGISTER=true || SIZE="$a"; done
REGIONS=(northcentralus eastus westeurope southeastasia northeurope)
PROVIDERS=(Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.KeyVault
  Microsoft.OperationalInsights Microsoft.Insights Microsoft.AlertsManagement
  Microsoft.RecoveryServices Microsoft.DataProtection Microsoft.ContainerRegistry
  Microsoft.ContainerInstance Microsoft.App Microsoft.Web Microsoft.PolicyInsights
  Microsoft.Management Microsoft.CostManagement Microsoft.Advisor Microsoft.Migrate)

echo "== Signed-in context"
az account show --query "{subscription:name, user:user.name, offer:subscriptionPolicies.quotaId}" -o table \
  || { echo "Not signed in. Run: az login"; exit 1; }
OFFER=$(az account show --query subscriptionPolicies.quotaId -o tsv)
if [[ "$OFFER" == FreeTrial* ]]; then
  echo "  ! Free Trial subscription detected. Expect low vCPU quotas and some blocked SKUs."
  echo "    Upgrading to Pay-As-You-Go keeps your remaining credit and removes most limits."
fi

echo; echo "== Resource providers"
for p in "${PROVIDERS[@]}"; do
  s=$(az provider show -n "$p" --query registrationState -o tsv 2>/dev/null || echo "Unknown")
  printf "  %-34s %s\n" "$p" "$s"
  if [[ "$s" != "Registered" && "$REGISTER" == true ]]; then
    az provider register -n "$p" -o none && echo "    -> registering $p"
  fi
done

echo; echo "== Encryption at host (Lab 08) — must be 'Registered'"
state=$(az feature show --namespace Microsoft.Compute --name EncryptionAtHost --query properties.state -o tsv 2>/dev/null)
echo "  EncryptionAtHost: ${state:-NotRegistered}"
if [[ "$state" != "Registered" && "$REGISTER" == true ]]; then
  az feature register --namespace Microsoft.Compute --name EncryptionAtHost -o none
  echo "  -> registration requested. Re-run later, then: az provider register -n Microsoft.Compute"
fi

echo; echo "== VM size $SIZE: availability and regional vCPU quota"
for r in "${REGIONS[@]}"; do
  restr=$(az vm list-skus -l "$r" --size "$SIZE" --resource-type virtualMachines \
          --query "[?name=='$SIZE'].restrictions[].reasonCode | join(',', @)" -o tsv 2>/dev/null)
  quota=$(az vm list-usage -l "$r" --query "[?name.value=='cores'] | [0].[currentValue, limit]" -o tsv 2>/dev/null | tr '\t' '/')
  printf "  %-15s restrictions: %-28s vCPUs used/limit: %s\n" "$r" "${restr:-none}" "${quota:-?}"
done
echo
echo "If a region shows NotAvailableForSubscription, change that location in the .bicepparam files."
