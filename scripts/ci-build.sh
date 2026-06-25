#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="gumimap-v2"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/gumimap-v2-ci-build}"
SPM_PACKAGES_DIR="${SPM_PACKAGES_DIR:-/tmp/gumimap-v2-spm-packages}"

if [[ -n "${CI_DESTINATION:-}" ]]; then
  DESTINATION="$CI_DESTINATION"
elif [[ "${CI_USE_NAMED_DESTINATION:-}" == "1" ]]; then
  DESTINATION="platform=iOS Simulator,name=$SIMULATOR_NAME"
else
  DESTINATION="generic/platform=iOS Simulator"
fi

if [[ -n "${XCODE_BUILD_JOBS:-}" ]]; then
  BUILD_JOBS="$XCODE_BUILD_JOBS"
elif command -v sysctl >/dev/null 2>&1; then
  BUILD_JOBS="$(sysctl -n hw.ncpu)"
else
  BUILD_JOBS=4
fi

cd "$ROOT"

mkdir -p "$DERIVED_DATA" "$SPM_PACKAGES_DIR"

echo "==> Generating app secrets"
./scripts/generate-secrets.sh

echo "==> Building $SCHEME for iOS Simulator"
echo "    destination:    $DESTINATION"
echo "    derived data:   $DERIVED_DATA"
echo "    SPM packages:   $SPM_PACKAGES_DIR"
echo "    parallel jobs:  $BUILD_JOBS"

xcodebuild \
  -scheme "$SCHEME" \
  -project gumimap-v2.xcodeproj \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  -clonedSourcePackagesDirPath "$SPM_PACKAGES_DIR" \
  -jobs "$BUILD_JOBS" \
  -parallelizeTargets \
  build \
  ONLY_ACTIVE_ARCH=YES \
  COMPILER_INDEX_STORE_ENABLE=NO \
  DEBUG_INFORMATION_FORMAT=dwarf \
  MTL_ENABLE_DEBUG_INFO=NO \
  CLANG_ENABLE_MODULE_DEBUGGING=NO \
  SWIFT_COMPILATION_MODE=wholemodule

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/gumimap-v2.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: App not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Build succeeded — $APP_PATH"