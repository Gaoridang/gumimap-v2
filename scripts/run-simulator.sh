#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="gumimap-v2"
BUNDLE_ID="com.ijaejun.gumimap-v2"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/gumimap-v2-derived-data}"

cd "$ROOT"

echo "==> Building $SCHEME for $SIMULATOR_NAME"
xcodebuild \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  | xcpretty 2>/dev/null || xcodebuild \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/gumimap-v2.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: App not found at $APP_PATH" >&2
  exit 1
fi

UDID="$(xcrun simctl list devices available | grep "$SIMULATOR_NAME (" | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')"

if [[ -z "$UDID" ]]; then
  echo "ERROR: Simulator '$SIMULATOR_NAME' not found" >&2
  exit 1
fi

echo "==> Booting simulator $SIMULATOR_NAME ($UDID)"
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

echo "==> Installing and launching $BUNDLE_ID"
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl launch "$UDID" "$BUNDLE_ID"

echo "==> Done — $BUNDLE_ID launched on $SIMULATOR_NAME"