#!/usr/bin/env bash
set -euo pipefail

: "${BUILD_CERTIFICATE_BASE64:?BUILD_CERTIFICATE_BASE64 is required}"
: "${P12_PASSWORD:?P12_PASSWORD is required}"
: "${PROVISIONING_PROFILE_BASE64:?PROVISIONING_PROFILE_BASE64 is required}"

KEYCHAIN_NAME="${KEYCHAIN_NAME:-build.keychain-db}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-ci}"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security default-keychain -s "$KEYCHAIN_NAME"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
security set-keychain-settings -lut 21600 "$KEYCHAIN_NAME"

echo "$BUILD_CERTIFICATE_BASE64" | base64 --decode > /tmp/distribution.p12
security import /tmp/distribution.p12 -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_NAME"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_NAME"
rm -f /tmp/distribution.p12

echo "$PROVISIONING_PROFILE_BASE64" | base64 --decode > /tmp/profile.mobileprovision
PROFILE_PLIST="$(mktemp)"
security cms -D -i /tmp/profile.mobileprovision > "$PROFILE_PLIST"

PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST")"
PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$PROFILE_PLIST")"

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp /tmp/profile.mobileprovision "$HOME/Library/MobileDevice/Provisioning Profiles/${PROFILE_UUID}.mobileprovision"

rm -f /tmp/profile.mobileprovision "$PROFILE_PLIST"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  echo "PROVISIONING_PROFILE_NAME=$PROFILE_NAME" >> "$GITHUB_ENV"
fi

echo "Installed provisioning profile: $PROFILE_NAME ($PROFILE_UUID)"