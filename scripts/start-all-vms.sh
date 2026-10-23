#!/usr/bin/env bash
# Start every deallocated VM in rg-hlg-* resource groups.
set -uo pipefail
ids=$(az vm list -d --query "[?powerState!='VM running'].[id]" -o tsv | grep -i '/resourceGroups/rg-hlg-' || true)
[[ -z "$ids" ]] && { echo "Nothing to start."; exit 0; }
echo "$ids" | sed 's#.*/##' | sed 's/^/  starting /'
az vm start --no-wait --ids $ids
