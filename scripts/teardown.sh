#!/usr/bin/env bash
# =============================================================================
# Teardown — deletes every rg-hlg-* resource group (removing locks first).
#   bash scripts/teardown.sh               # resource groups only
#   bash scripts/teardown.sh --governance  # also policy assignments + management groups
#
# Recovery Services / Backup vaults with protected items or soft-deleted data
# BLOCK resource group deletion. Do the Lab 15 cleanup steps first.
# =============================================================================
set -uo pipefail
GOV=false; [[ "${1:-}" == "--governance" ]] && GOV=true

RGS=$(az group list --query "[?starts_with(name,'rg-hlg-')].name" -o tsv)
if [[ -z "$RGS" ]]; then echo "No rg-hlg-* resource groups found."; else
  echo "Resource groups to delete:"; echo "$RGS" | sed 's/^/  /'
  read -r -p "Type DELETE to continue: " c; [[ "$c" == "DELETE" ]] || { echo "Aborted."; exit 1; }

  for rg in $RGS; do
    for id in $(az lock list -g "$rg" --query "[].id" -o tsv); do
      az lock delete --ids "$id" && echo "  unlocked $rg ($(basename "$id"))"
    done
    vaults=$(az resource list -g "$rg" --query "[?type=='Microsoft.RecoveryServices/vaults' || type=='Microsoft.DataProtection/backupVaults'].name" -o tsv)
    [[ -n "$vaults" ]] && echo "  ! $rg has vault(s): $vaults — deletion fails until protection is stopped and data deleted (Lab 15 Cleanup)."
  done
  for rg in $RGS; do az group delete -n "$rg" --yes --no-wait && echo "  deleting $rg"; done
fi

if [[ "$GOV" == true ]]; then
  echo; echo "Removing HLG policy assignments and management groups..."
  for mg in mg-hlg mg-hlg-landingzones mg-hlg-platform mg-hlg-sandbox; do
    for a in $(az policy assignment list --scope "/providers/Microsoft.Management/managementGroups/$mg" \
               --query "[?starts_with(displayName,'HLG')].name" -o tsv 2>/dev/null); do
      az policy assignment delete --name "$a" --scope "/providers/Microsoft.Management/managementGroups/$mg" && echo "  - assignment $a ($mg)"
    done
  done
  SUB=$(az account show --query id -o tsv)
  TENANT=$(az account show --query tenantId -o tsv)
  az account management-group subscription add --name "$TENANT" --subscription "$SUB" -o none 2>/dev/null \
    && echo "  subscription moved back to Tenant Root Group"
  for mg in mg-hlg-landingzones mg-hlg-platform mg-hlg-sandbox mg-hlg; do
    az account management-group delete --name "$mg" 2>/dev/null && echo "  - management group $mg"
  done
  echo "  (Custom policy/initiative definitions stored at mg-hlg are deleted with it, or remove them first if deletion fails.)"
fi

echo
echo "Still yours to remove by hand (not in resource groups):"
echo "  - NetworkWatcherRG (auto-created per region; free unless you added flow logs)"
echo "  - Conditional Access policies, named locations, SSPR settings (Entra admin center)"
echo "  - Lab users and groups:  pwsh identity/Remove-HlgStaff.ps1"
echo "  - Budgets and cost alerts (Cost Management)"
echo "  - Your Cloud Shell storage account, if you don't want to keep it"
