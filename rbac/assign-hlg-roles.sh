#!/usr/bin/env bash
# =============================================================================
# LAB 04 — CLI equivalent of the HLG role-assignment plan.
# Do the portal steps first; use this to compare or to rebuild.
# Looks up group object IDs by display name.
# =============================================================================
set -euo pipefail
SUB_ID=$(az account show --query id -o tsv)
SUB="/subscriptions/$SUB_ID"
MG="/providers/Microsoft.Management/managementGroups/mg-hlg"

gid() { az ad group show --group "$1" --query id -o tsv; }

assign() { # principalId role scope [type]
  az role assignment create --assignee-object-id "$1" --assignee-principal-type "${4:-Group}" \
    --role "$2" --scope "$3" -o none && echo "  + $2 -> $3"
}

echo "Assigning HLG roles..."
assign "$(gid grp-hlg-auditors)"      "Reader"                       "$MG"
assign "$(gid grp-hlg-network-ops)"   "Network Contributor"          "$SUB/resourceGroups/rg-hlg-hub-eus"
assign "$(gid grp-hlg-network-ops)"   "Network Contributor"          "$SUB/resourceGroups/rg-hlg-onprem-chi"
assign "$(gid grp-hlg-eu-ops)"        "Contributor"                  "$SUB/resourceGroups/rg-hlg-spoke-weu"
assign "$(gid grp-hlg-apac-ops)"      "Virtual Machine Contributor"  "$SUB/resourceGroups/rg-hlg-spoke-sea"
DATA_SA_ID=$(az storage account list -g rg-hlg-data-eus --query "[?starts_with(name,'sthlgdata')].id | [0]" -o tsv)
if [[ -n "$DATA_SA_ID" ]]; then
  # Data role for blobs + Reader so the account is visible in the portal (control plane).
  assign "$(gid grp-hlg-data-analysts)" "Storage Blob Data Reader" "$DATA_SA_ID"
  assign "$(gid grp-hlg-data-analysts)" "Reader"                   "$DATA_SA_ID"
else
  echo "  ! sthlgdata* storage account not found (deploy it in Lab 03 Task 6) - skipping analysts"
fi
assign "$(gid grp-hlg-eu-partners)"   "Reader"                       "$SUB/resourceGroups/rg-hlg-spoke-weu"

echo "Done. List everything assigned at or below the subscription:"
echo "  az role assignment list --all --include-inherited -o table"
