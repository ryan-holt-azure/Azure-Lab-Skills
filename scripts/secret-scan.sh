#!/usr/bin/env bash
# =============================================================================
# Scan text files for things you must not publish to GitHub/LinkedIn:
# subscription/tenant IDs (GUIDs), SAS signatures, account keys, connection
# strings, private keys, VPN shared keys and passwords.
#   bash scripts/secret-scan.sh            # scan the repo
#   bash scripts/secret-scan.sh --staged   # scan only staged files (pre-commit hook)
# Screenshots can't be scanned — redact them by hand (docs/screenshot-guide.md).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
if [[ "${1:-}" == "--staged" ]]; then
  FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -Ev '\.(png|jpg|jpeg|gif|zip)$' || true)
else
  FILES=$(git ls-files 2>/dev/null | grep -Ev '\.(png|jpg|jpeg|gif|zip)$' || find . -type f -not -path './.git/*' | grep -Ev '\.(png|jpg|jpeg|gif|zip)$')
fi
FILES=$(echo "$FILES" | grep -v '^scripts/secret-scan.sh$' || true)   # don't flag our own patterns
[[ -z "$FILES" ]] && exit 0

# GUIDs that are safe to publish (well-known Microsoft IDs referenced in the labs).
ALLOW='a6aa9161-5291-40bb-8c5c-923b567bee3b|00000000-0000-0000-0000-000000000000'

hits=0
check() { # label regex
  local out
  out=$(echo "$FILES" | xargs -r grep -nEI -e "$2" 2>/dev/null | grep -vE "$ALLOW" | grep -vE '__PASSWORD__|<[A-Z-]+>|placeholder|readEnvironmentVariable' || true)
  # ignore assignments whose value is just a variable/parameter name (e.g. Bicep "sharedKey: sharedKey")
  [[ "$1" == Password* ]] && out=$(echo "$out" | grep -vE "(password|passwd|sharedKey|psk)[[:space:]]*[:=][[:space:]]*[A-Za-z_][A-Za-z0-9_.]*[[:space:]]*$" || true)
  if [[ -n "$out" ]]; then echo "!! $1"; echo "$out" | sed 's/^/   /' | head -20; hits=$((hits+1)); fi
}
check "GUID (subscription/tenant/object ID?)"  '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
check "SAS signature"                          'sig=[A-Za-z0-9%+/=]{20,}'
check "Storage account key / connection string" 'AccountKey=|DefaultEndpointsProtocol=https;AccountName='
check "Private key"                            '-----BEGIN [A-Z ]*PRIVATE KEY-----'
check "Password or shared key assignment"      '(password|passwd|sharedKey|psk)[[:space:]]*[:=][[:space:]]*["'"'"']?[^[:space:]"'"'"']{8,}'

if [[ $hits -gt 0 ]]; then
  echo; echo "Found $hits category(ies) of possible secrets. Remove or redact before committing."
  exit 1
fi
echo "secret-scan: clean"
