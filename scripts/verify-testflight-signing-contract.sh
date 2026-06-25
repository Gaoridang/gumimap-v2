#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep -q 'actions/cache/restore@v4' .github/workflows/testflight.yml \
  || fail "testflight.yml must use actions/cache/restore@v4"
grep -q 'actions/cache/save@v4' .github/workflows/testflight.yml \
  || fail "testflight.yml must use actions/cache/save@v4"
grep -q "if: always() && steps.signing-cache-valid.outputs.valid != 'true'" .github/workflows/testflight.yml \
  || fail "testflight.yml save step must skip when signing cache is already valid"
grep -q 'signing-v3-' .github/workflows/testflight.yml \
  || fail "testflight.yml must use signing-v3 cache key"

grep -q 'ENV\["ALLOW_CREATE_DISTRIBUTION_CERT"\] == "true"' fastlane/Fastfile \
  || fail "Fastfile must gate cert creation on ALLOW_CREATE_DISTRIBUTION_CERT==true"
grep -q 'UI.user_error!(missing_distribution_cert_instructions)' fastlane/Fastfile \
  || fail "Fastfile must emit missing_distribution_cert_instructions on cache miss"

cert_count=$(grep -c 'cert(' fastlane/Fastfile || true)
if [[ "$cert_count" -lt 1 ]]; then
  fail "Fastfile must call cert() inside bootstrap path"
fi
if grep -n 'cert(' fastlane/Fastfile | grep -qv 'create_and_cache_distribution_cert'; then
  if grep -n 'cert(' fastlane/Fastfile | grep -q 'install_api_signing'; then
    fail "cert() must not be called directly from install_api_signing"
  fi
fi

grep -A5 'sigh(' fastlane/Fastfile | grep -q 'api_key: api_key' || fail "sigh must pass api_key"
grep -A5 'sigh(' fastlane/Fastfile | grep -q 'app_identifier: BUNDLE_IDENTIFIER' || fail "sigh must pass app_identifier"
grep -A5 'sigh(' fastlane/Fastfile | grep -q 'force: false' || fail "sigh must pass force"
if grep -A8 'sigh(' fastlane/Fastfile | grep -q 'keychain_path'; then
  fail "sigh must not pass keychain_path"
fi

echo "OK: TestFlight signing contract checks passed"