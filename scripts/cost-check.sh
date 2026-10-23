#!/usr/bin/env bash
# =============================================================================
# "What is billing me right now?" — lists the HLG lab resources that charge by
# the hour even when idle, plus running VMs. Run it at the end of every session.
# =============================================================================
set -uo pipefail
echo "== Hourly-billed resources in this subscription"
TYPES=(
  Microsoft.Network/bastionHosts
  Microsoft.Network/virtualNetworkGateways
  Microsoft.Network/natGateways
  Microsoft.Network/loadBalancers
  Microsoft.Network/azureFirewalls
  Microsoft.Network/privateEndpoints
  Microsoft.Network/dnsResolvers
  Microsoft.Network/publicIPAddresses
  Microsoft.Web/serverFarms
  Microsoft.ContainerInstance/containerGroups
  Microsoft.ContainerRegistry/registries
  Microsoft.App/managedEnvironments
  Microsoft.Compute/virtualMachineScaleSets
)
for t in "${TYPES[@]}"; do
  rows=$(az resource list --resource-type "$t" --query "[].{name:name, rg:resourceGroup, location:location, sku:sku.name}" -o tsv)
  [[ -n "$rows" ]] && { echo "-- $t"; echo "$rows" | sed 's/^/   /'; }
done
echo
echo "== Running VMs (deallocate with scripts/stop-all-vms.sh)"
az vm list -d --query "[?powerState=='VM running'].{name:name, rg:resourceGroup, size:hardwareProfile.vmSize}" -o table
echo
echo "Biggest idle costs in this lab: VPN gateways, Bastion, App Service plans (non-Free),"
echo "ACR Premium, NAT gateway. Delete them when a lab is done; IaC brings them back."
