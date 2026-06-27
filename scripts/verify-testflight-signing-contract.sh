#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

ruby fastlane/spec/signing_decision_spec.rb \
  || fail "SigningDecision unit tests failed"

grep -q 'actions/cache/restore@v4' .github/workflows/testflight.yml \
  || fail "testflight.yml must use actions/cache/restore@v4"
grep -q 'actions/cache/save@v4' .github/workflows/testflight.yml \
  || fail "testflight.yml must use actions/cache/save@v4"
grep -q "if: always() && steps.signing-cache-valid.outputs.valid != 'true'" .github/workflows/testflight.yml \
  || fail "testflight.yml save step must skip when signing cache is already valid"
grep -q 'signing-v3-' .github/workflows/testflight.yml \
  || fail "testflight.yml must use signing-v3 cache key"
grep -q 'signing_controlled_error_check' .github/workflows/testflight.yml \
  || fail "testflight.yml must run signing_controlled_error_check on workflow_dispatch"

grep -q 'SigningDecision.resolve' fastlane/Fastfile \
  || fail "Fastfile must use SigningDecision.resolve"
grep -q 'allow_create == "true"' fastlane/lib/signing_decision.rb \
  || fail "SigningDecision must gate create on allow_create == true exactly"
grep -q 'UI.user_error!(SigningDecision.controlled_error_message)' fastlane/Fastfile \
  || fail "Fastfile must emit SigningDecision.controlled_error_message on cache miss"
grep -q 'No reusable Distribution certificate is available for CI' fastlane/lib/signing_decision.rb \
  || fail "controlled error must mention missing reusable Distribution certificate"
if grep -A25 'CONTROLLED_ERROR_MESSAGE' fastlane/lib/signing_decision.rb | \
   grep -q 'Could not create another Distribution certificate'; then
  fail "controlled error must not contain Apple quota phrase"
fi

cert_count=$(grep -c 'cert(' fastlane/Fastfile || true)
if [[ "$cert_count" -lt 1 ]]; then
  fail "Fastfile must call cert() inside bootstrap path"
fi
if grep -n 'cert(' fastlane/Fastfile | grep -qv 'create_and_cache_distribution_cert'; then
  if grep -n 'cert(' fastlane/Fastfile | grep -q 'install_api_signing'; then
    fail "cert() must not be called directly from install_api_signing"
  fi
fi
if grep -n 'cert(' fastlane/Fastfile | grep -q 'signing_controlled_error_check'; then
  fail "cert() must not be called from signing_controlled_error_check"
fi

grep -A5 'sigh(' fastlane/Fastfile | grep -q 'api_key: api_key' || fail "sigh must pass api_key"
grep -A5 'sigh(' fastlane/Fastfile | grep -q 'app_identifier: BUNDLE_IDENTIFIER' || fail "sigh must pass app_identifier"
grep -A5 'sigh(' fastlane/Fastfile | grep -q 'force: false' || fail "sigh must pass force"
if grep -A8 'sigh(' fastlane/Fastfile | grep -q 'keychain_path'; then
  fail "sigh must not pass keychain_path"
fi

echo "CONTROLLED_PATH_OK: SigningDecision unit tests + Fastfile dispatch verified"
echo "CONTROLLED_PATH_MESSAGE: No reusable Distribution certificate is available for CI"
echo "OK: TestFlight signing contract checks passed"