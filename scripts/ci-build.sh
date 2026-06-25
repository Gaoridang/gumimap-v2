#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="gumimap-v2"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/gumimap-v2-ci-build}"

cd "$ROOT"

echo "==> Generating app secrets"
./scripts/generate-secrets.sh

echo "==> Building $SCHEME for iOS Simulator ($SIMULATOR_NAME)"
xcodebuild \
  -scheme "$SCHEME" \
  -project gumimap-v2.xcodeproj \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/gumimap-v2.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: App not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Build succeeded — $APP_PATH"