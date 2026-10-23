#!/usr/bin/env bash
# =============================================================================
# Lab 16 — Capstone break-fix. Injects up to 8 realistic faults into your
# HLG environment. Each fault is skipped if the resource it needs doesn't exist.
# Diagnose them from the ticket symptoms in labs/16-capstone-break-fix.md.
#
#   bash scripts/capstone-break.sh          # inject every fault it can
#   bash scripts/capstone-break.sh 1 3 5    # inject only faults 1, 3 and 5
#
# Every fault is reversible; the fixes are in the lab's answer key.
# =============================================================================
set -uo pipefail
WANT=("$@"); [[ ${#WANT[@]} -eq 0 ]] && WANT=(1 2 3 4 5 6 7 8)
STATE="$(cd "$(dirname "$0")/.." && pwd)/.capstone-state"
: > "$STATE"
want() { for w in "${WANT[@]}"; do [[ "$w" == "$1" ]] && return 0; done; return 1; }
done_ticket() { echo "INC-10$1" >> "$STATE"; echo "  ticket INC-10$1 opened"; }
skip() { echo "  (fault $1 skipped: $2)"; }

echo "Injecting faults..."

if want 1; then  # NIC-level NSG silently blocking APAC -> EU web traffic
  nic=$(az vm show -g rg-hlg-spoke-weu -n vm-hlg-weu-app01 --query "networkProfile.networkInterfaces[0].id" -o tsv 2>/dev/null)
  if [[ -n "$nic" ]]; then
    az network nsg create -g rg-hlg-spoke-weu -n nsg-nic-weu-app01 -l "$(az group show -n rg-hlg-spoke-weu --query location -o tsv)" -o none
    az network nsg rule create -g rg-hlg-spoke-weu --nsg-name nsg-nic-weu-app01 -n Allow-Partner-Range \
      --priority 100 --direction Inbound --access Deny --protocol Tcp \
      --source-address-prefixes 10.40.0.0/16 --destination-port-ranges 80 -o none
    az network nic update --ids "$nic" --network-security-group nsg-nic-weu-app01 -o none
    done_ticket 1
  else skip 1 "vm-hlg-weu-app01 not found"; fi
fi

if want 2; then  # UDR pointing at a next hop that doesn't exist
  if az network route-table route show -g rg-hlg-spoke-sea --route-table-name rt-hlg-sea-app -n to-weu-via-nva -o none 2>/dev/null; then
    az network route-table route update -g rg-hlg-spoke-sea --route-table-name rt-hlg-sea-app -n to-weu-via-nva \
      --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.4.5 -o none
    done_ticket 2
  else skip 2 "rt-hlg-sea-app/to-weu-via-nva not found (Lab 05)"; fi
fi

if want 3; then  # Private DNS zone link removed for the APAC spoke
  link=$(az network private-dns link vnet list -g rg-hlg-hub-eus -z privatelink.blob.core.windows.net \
         --query "[?contains(virtualNetwork.id,'vnet-hlg-spoke-sea')].name | [0]" -o tsv 2>/dev/null)
  if [[ -n "$link" && "$link" != "None" ]]; then
    az network private-dns link vnet delete -g rg-hlg-hub-eus -z privatelink.blob.core.windows.net -n "$link" --yes -o none
    done_ticket 3
  else skip 3 "no SEA link on privatelink.blob.core.windows.net (Lab 06)"; fi
fi

if want 4; then  # "Change freeze" ReadOnly lock
  if az group show -n rg-hlg-spoke-sea -o none 2>/dev/null; then
    az lock create -g rg-hlg-spoke-sea -n change-freeze --lock-type ReadOnly --notes "Q4 change freeze" -o none
    done_ticket 4
  else skip 4 "rg-hlg-spoke-sea not found"; fi
fi

if want 5; then  # Storage firewall flipped to Deny with no rules
  acct=$(az storage account list -g rg-hlg-data-eus --query "[?starts_with(name,'sthlgops')].name | [0]" -o tsv 2>/dev/null)
  if [[ -n "$acct" && "$acct" != "None" ]]; then
    az storage account update -g rg-hlg-data-eus -n "$acct" --public-network-access Enabled --default-action Deny -o none
    done_ticket 5
  else skip 5 "sthlgops* storage account not found (Lab 10)"; fi
fi

if want 6; then  # LB health probe on the wrong port
  if az network lb probe show -g rg-hlg-spoke-weu --lb-name lbe-hlg-weu-web -n hp-http-80 -o none 2>/dev/null; then
    az network lb probe update -g rg-hlg-spoke-weu --lb-name lbe-hlg-weu-web -n hp-http-80 --port 8080 -o none
    done_ticket 6
  else skip 6 "lbe-hlg-weu-web/hp-http-80 not found (Lab 09)"; fi
fi

if want 7; then  # RBAC downgrade for APAC operations
  gid=$(az ad group show --group grp-hlg-apac-ops --query id -o tsv 2>/dev/null)
  scope="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-hlg-spoke-sea"
  if [[ -n "$gid" ]]; then
    az role assignment delete --assignee "$gid" --role "Virtual Machine Contributor" --scope "$scope" -o none 2>/dev/null
    az role assignment create --assignee-object-id "$gid" --assignee-principal-type Group --role Reader --scope "$scope" -o none
    done_ticket 7
  else skip 7 "grp-hlg-apac-ops not found (Lab 01)"; fi
fi

if want 8; then  # Private DNS record pointing at the wrong IP
  if az network private-dns record-set a show -g rg-hlg-hub-eus -z halsted.internal -n orders-api.sea -o none 2>/dev/null; then
    az network private-dns record-set a remove-record -g rg-hlg-hub-eus -z halsted.internal -n orders-api.sea -a 10.40.1.100 --keep-empty-record-set -o none 2>/dev/null
    az network private-dns record-set a add-record -g rg-hlg-hub-eus -z halsted.internal -n orders-api.sea -a 10.40.1.200 -o none
    done_ticket 8
  else skip 8 "halsted.internal/orders-api.sea not found (Lab 09)"; fi
fi

echo
echo "Open tickets: $(tr '\n' ' ' < "$STATE")"
echo "Work them from the symptoms in labs/16-capstone-break-fix.md. No peeking at the answer key until you've tried."
