#!/usr/bin/env bash
# =============================================================================
# LAB 02 — CLI path for the HLG governance baseline.
# Do the PORTAL steps in the lab first. Use this to rebuild quickly, or to
# compare your portal work with the CLI equivalent.
#
# Looks up built-in policy IDs by display name (never hard-code GUIDs you
# haven't verified), builds an initiative, and assigns it at mg-hlg.
#
# Usage:  bash policy/deploy-hlg-policies.sh
# =============================================================================
set -euo pipefail

MG="mg-hlg"
MG_LZ="mg-hlg-landingzones"
LOCATIONS='["eastus","northcentralus","westeurope","southeastasia"]'
VM_SKUS='["Standard_B1s","Standard_B1ms","Standard_B2s","Standard_B2ms","Standard_B2als_v2","Standard_B2as_v2","Standard_B2ats_v2","Standard_D2s_v5","Standard_D2as_v5"]'
MI_LOCATION="eastus"

builtin() {
  # $1 = exact display name of a built-in policy definition
  local id
  id=$(az policy definition list --query "[?displayName=='$1' && policyType=='BuiltIn'].id | [0]" -o tsv)
  if [[ -z "$id" ]]; then echo "ERROR: built-in policy '$1' not found" >&2; exit 1; fi
  echo "$id"
}

echo "Looking up built-in policy definitions..."
ALLOWED_LOC=$(builtin "Allowed locations")
ALLOWED_RG_LOC=$(builtin "Allowed locations for resource groups")
REQ_RG_TAG=$(builtin "Require a tag on resource groups")
ADD_RG_TAG=$(builtin "Add a tag to resource groups")
INHERIT_TAG=$(builtin "Inherit a tag from the resource group if missing")
ALLOWED_SKUS=$(builtin "Allowed virtual machine size SKUs")

MG_SCOPE="/providers/Microsoft.Management/managementGroups/$MG"
LZ_SCOPE="/providers/Microsoft.Management/managementGroups/$MG_LZ"

echo "1) Allowed locations (resources + resource groups) at $MG"
az policy assignment create --name hlg-allowed-locations --display-name "HLG - Allowed locations" \
  --scope "$MG_SCOPE" --policy "$ALLOWED_LOC" \
  --params "{\"listOfAllowedLocations\":{\"value\":$LOCATIONS}}" -o none
az policy assignment create --name hlg-allowed-rg-locations --display-name "HLG - Allowed locations for resource groups" \
  --scope "$MG_SCOPE" --policy "$ALLOWED_RG_LOC" \
  --params "{\"listOfAllowedLocations\":{\"value\":$LOCATIONS}}" -o none

echo "2) Tagging initiative: require CostCenter on RGs (Deny), auto-add it when missing (Modify),"
echo "   and copy it from the RG onto resources (Modify). Modify runs BEFORE Deny — that's the lesson."
cat > /tmp/hlg-tagging-defs.json <<JSON
[
  { "policyDefinitionReferenceId": "requireCostCenterOnRg",
    "policyDefinitionId": "$REQ_RG_TAG",
    "parameters": { "tagName": { "value": "[parameters('tagName')]" } } },
  { "policyDefinitionReferenceId": "addCostCenterToRg",
    "policyDefinitionId": "$ADD_RG_TAG",
    "parameters": { "tagName":  { "value": "[parameters('tagName')]" },
                    "tagValue": { "value": "[parameters('defaultTagValue')]" } } },
  { "policyDefinitionReferenceId": "inheritCostCenter",
    "policyDefinitionId": "$INHERIT_TAG",
    "parameters": { "tagName": { "value": "[parameters('tagName')]" } } }
]
JSON
cat > /tmp/hlg-tagging-params.json <<'JSON'
{ "tagName": { "type": "String", "defaultValue": "CostCenter",
    "metadata": { "displayName": "Tag name", "description": "Tag required on RGs and inherited by resources" } },
  "defaultTagValue": { "type": "String", "defaultValue": "CC-1001",
    "metadata": { "displayName": "Default tag value", "description": "Added to RGs that are created without the tag (e.g. NetworkWatcherRG)" } } }
JSON
az policy set-definition create --name hlg-tagging-standard --display-name "HLG - Tagging standard" \
  --management-group "$MG" --definitions /tmp/hlg-tagging-defs.json --params /tmp/hlg-tagging-params.json -o none

# Modify effect needs a managed identity with Contributor-level rights to fix tags.
az policy assignment create --name hlg-tagging --display-name "HLG - Tagging standard" \
  --scope "$MG_SCOPE" \
  --policy-set-definition "$MG_SCOPE/providers/Microsoft.Authorization/policySetDefinitions/hlg-tagging-standard" \
  --mi-system-assigned --location "$MI_LOCATION" --role Contributor --identity-scope "$MG_SCOPE" -o none

echo "3) Allowed VM sizes at $MG_LZ"
az policy assignment create --name hlg-allowed-vm-skus --display-name "HLG - Allowed VM sizes (cost control)" \
  --scope "$LZ_SCOPE" --policy "$ALLOWED_SKUS" \
  --params "{\"listOfAllowedSKUs\":{\"value\":$VM_SKUS}}" -o none

echo "Done. Compliance results start appearing in ~30 minutes. Force a scan with:"
echo "  az policy state trigger-scan --no-wait"
