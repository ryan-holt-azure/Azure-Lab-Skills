#!/usr/bin/env bash
# End-of-session ritual. Run in Cloud Shell (or any shell with az CLI logged in)
# after every lab session, no exceptions.
#
# Usage: ./cleanup.sh rg-lab01 [rg-lab02 ...]
#   No args: just lists what currently exists (dry run / audit mode).

set -euo pipefail

if [ "$#" -eq 0 ]; then
  echo "No resource groups given — audit mode. Existing groups:"
  az group list -o table
  exit 0
fi

echo "Existing resource groups before cleanup:"
az group list -o table

for rg in "$@"; do
  echo "Deleting $rg ..."
  az group delete -n "$rg" --yes --no-wait
done

echo
echo "Delete requests submitted (--no-wait, so they run in the background)."
echo "Re-run with no args in a few minutes to confirm they're gone."
echo "Then: Cost Management -> Cost analysis -> confirm today's spend ~ \$0."
