#!/usr/bin/env bash
set -euo pipefail

: "${BUILD_CERTIFICATE_BASE64:?BUILD_CERTIFICATE_BASE64 is required}"
: "${P12_PASSWORD:?P12_PASSWORD is required}"
: "${PROVISIONING_PROFILE_BASE64:?PROVISIONING_PROFILE_BASE64 is required}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGNING_DIR="$ROOT/fastlane/signing"

mkdir -p "$SIGNING_DIR"

echo "$BUILD_CERTIFICATE_BASE64" | base64 --decode > "$SIGNING_DIR/distribution.p12"
printf '%s' "$P12_PASSWORD" > "$SIGNING_DIR/.p12-pass"
echo "$PROVISIONING_PROFILE_BASE64" | base64 --decode > "$SIGNING_DIR/profile.mobileprovision"

PROFILE_PLIST="$(mktemp)"
security cms -D -i "$SIGNING_DIR/profile.mobileprovision" > "$PROFILE_PLIST"
PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$PROFILE_PLIST")"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST")"
rm -f "$PROFILE_PLIST"

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$SIGNING_DIR/profile.mobileprovision" \
  "$HOME/Library/MobileDevice/Provisioning Profiles/${PROFILE_UUID}.mobileprovision"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "PROVISIONING_PROFILE_NAME=$PROFILE_NAME" >> "$GITHUB_ENV"
fi

echo "Seeded signing cache for fastlane: $SIGNING_DIR"
echo "Provisioning profile: $PROFILE_NAME ($PROFILE_UUID)"