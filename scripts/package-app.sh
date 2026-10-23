#!/usr/bin/env bash
# Lab 13 — zip the tracker app for zip deploy.
#   bash scripts/package-app.sh v1   -> tracker-web-v1.zip
#   bash scripts/package-app.sh v2   -> sets APP_VERSION='v2' + green banner, zips tracker-web-v2.zip
set -euo pipefail
VER="${1:-v1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
cp "$ROOT/apps/tracker-web/server.js" "$ROOT/apps/tracker-web/package.json" "$WORK/"
if [[ "$VER" == "v2" ]]; then
  sed -i "s/const APP_VERSION = 'v1';/const APP_VERSION = 'v2';/; s/#1f6feb/#2da44e/" "$WORK/server.js"
fi
(cd "$WORK" && zip -q "$ROOT/tracker-web-$VER.zip" server.js package.json)
rm -rf "$WORK"
echo "Created $ROOT/tracker-web-$VER.zip"
