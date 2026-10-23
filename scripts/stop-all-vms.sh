#!/usr/bin/env bash
# Deallocate (stop billing for compute) every running VM in rg-hlg-* resource groups.
set -uo pipefail
ids=$(az vm list -d --query "[?powerState=='VM running'].[id]" -o tsv | grep -i '/resourceGroups/rg-hlg-' || true)
[[ -z "$ids" ]] && { echo "No running HLG VMs."; exit 0; }
echo "$ids" | sed 's#.*/##' | sed 's/^/  deallocating /'
az vm deallocate --no-wait --ids $ids
echo "Deallocation requested. Disks still bill (pennies); compute stops."
echo "Note: VM Scale Set instances may be recreated by autoscale — scale the set to 0 instead."
