#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT/.ci-signing-export"
BUNDLE_ID="com.ijaejun.gumimap-v2"

mkdir -p "$OUTPUT_DIR"

echo "==> Distribution identities in login keychain"
security find-identity -v -p codesigning login.keychain-db || security find-identity -v -p codesigning

echo
echo "==> App Store profiles for $BUNDLE_ID"
PROFILE_PATH=""
while IFS= read -r -d '' profile; do
  if /usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' /dev/stdin \
    <<<"$(security cms -D -i "$profile")" 2>/dev/null | rg -q "$BUNDLE_ID"; then
    PROFILE_PATH="$profile"
    PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' /dev/stdin <<<"$(security cms -D -i "$profile")")"
    echo "  $PROFILE_NAME"
    echo "  $profile"
  fi
done < <(find \
  "$HOME/Library/MobileDevice/Provisioning Profiles" \
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
  -name "*.mobileprovision" -print0 2>/dev/null)

if [[ -z "$PROFILE_PATH" ]]; then
  echo "No App Store profile found for $BUNDLE_ID."
  echo "Create one in Xcode: Product > Archive, or download from developer.apple.com."
  exit 1
fi

cp "$PROFILE_PATH" "$OUTPUT_DIR/profile.mobileprovision"
base64 < "$OUTPUT_DIR/profile.mobileprovision" | tr -d '\n' > "$OUTPUT_DIR/PROVISIONING_PROFILE_BASE64.txt"

echo
echo "==> Export distribution certificate (.p12)"
echo "Run this command and enter your Mac login password when prompted:"
echo
echo "  security export -k login.keychain-db -t identities -f pkcs12 -o \"$OUTPUT_DIR/distribution.p12\" -P \"<choose-a-password-for-ci>\""
echo
echo "Then create GitHub secrets from:"
echo "  base64 < \"$OUTPUT_DIR/distribution.p12\" | tr -d '\\n'  -> BUILD_CERTIFICATE_BASE64"
echo "  <the password you chose>                                  -> P12_PASSWORD"
echo "  contents of PROVISIONING_PROFILE_BASE64.txt               -> PROVISIONING_PROFILE_BASE64"
echo
echo "Profile base64 already written to:"
echo "  $OUTPUT_DIR/PROVISIONING_PROFILE_BASE64.txt"