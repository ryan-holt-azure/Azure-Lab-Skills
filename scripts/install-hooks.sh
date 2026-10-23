#!/usr/bin/env bash
# Install a git pre-commit hook that runs secret-scan.sh on staged files.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$ROOT/.git/hooks/pre-commit"
[[ -d "$ROOT/.git" ]] || { echo "Run 'git init' first."; exit 1; }
cat > "$HOOK" <<'H'
#!/usr/bin/env bash
bash "$(git rev-parse --show-toplevel)/scripts/secret-scan.sh" --staged
H
chmod +x "$HOOK"
echo "pre-commit hook installed: commits are blocked if secret-scan finds something."
