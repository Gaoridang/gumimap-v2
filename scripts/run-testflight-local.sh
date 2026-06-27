#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SECRETS_FILE="$ROOT/Config/secrets.local.env"
if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Missing $SECRETS_FILE — copy Config/secrets.example.env and fill in values."
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$SECRETS_FILE"
set +a

for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
  if [[ -z "${!var:-}" ]]; then
    echo "Set $var in Config/secrets.local.env"
    exit 1
  fi
done

if [[ ! -f "$ASC_KEY_PATH" ]]; then
  echo "ASC key not found: $ASC_KEY_PATH"
  exit 1
fi

openssl pkey -in "$ASC_KEY_PATH" -noout >/dev/null

if [[ -f "/opt/homebrew/opt/ruby/bin/ruby" ]]; then
  export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"
fi

./scripts/generate-secrets.sh

# Mirror CI keychain setup; first run without fastlane/signing cache creates a cert once.
export CI=true
export ALLOW_CREATE_DISTRIBUTION_CERT=true
export FASTLANE_DISABLE_COLORS=1

echo "==> fastlane beta (local Mac, ALLOW_CREATE_DISTRIBUTION_CERT=true)"
bundle exec fastlane beta