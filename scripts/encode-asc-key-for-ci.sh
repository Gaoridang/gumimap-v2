#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/AuthKey_XXXXX.p8"
  exit 1
fi

KEY_FILE="$1"
if [[ ! -f "$KEY_FILE" ]]; then
  echo "File not found: $KEY_FILE"
  exit 1
fi

openssl pkey -in "$KEY_FILE" -noout -text > /dev/null

echo "==> Local key is valid."
echo "==> Copy this base64 value into GitHub secret ASC_KEY_CONTENT_BASE64:"
echo
base64 < "$KEY_FILE" | tr -d '\n'
echo
echo
echo "==> Optional: set via gh CLI"
echo "gh secret set ASC_KEY_CONTENT_BASE64 --repo Gaoridang/gumimap-v2 < <(base64 < \"$KEY_FILE\" | tr -d '\\n')"