#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${FASTLANE_VERIFY_SCRATCH:-/tmp/fastlane-verify}"
mkdir -p "$SCRATCH"

export FASTLANE_VERIFY_SCRATCH="$SCRATCH"

echo "==> Runtime xcodeproj resolution (objectVersion 77)"
ruby "$ROOT/fastlane/spec/get_version_number_runtime_spec.rb" -v 2>&1 | tee "$SCRATCH/get_version_number_runtime_spec.log"

echo "==> Fastfile structure contract"
ruby "$ROOT/fastlane/spec/marketing_version_spec.rb" -v 2>&1 | tee "$SCRATCH/marketing_version_spec.log"

if command -v bundle >/dev/null && [[ "$(uname -s)" == "Darwin" ]]; then
  echo "==> fastlane run get_version_number (macOS CI)"
  (
    cd "$ROOT"
    bundle exec fastlane run get_version_number \
      xcodeproj:"gumimap-v2.xcodeproj" \
      target:"gumimap-v2" 2>&1 | tee "$SCRATCH/fastlane_run_get_version_number.log"
  )
  if ! grep -q "0.0.1" "$SCRATCH/fastlane_run_get_version_number.log"; then
    echo "FAIL: fastlane run get_version_number did not return 0.0.1"
    exit 1
  fi
fi

echo "Marketing version verification passed. Logs in $SCRATCH"