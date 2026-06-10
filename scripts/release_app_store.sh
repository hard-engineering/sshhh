#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APP_STORE_ENV_FILE="${APP_STORE_ENV_FILE:-$REPO_DIR/.env}"

if [[ -f "$APP_STORE_ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$APP_STORE_ENV_FILE"
  set +a
fi

usage() {
  echo "Usage: $0 [export|upload]" >&2
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage
  exit 64
fi

APP_NAME="${APP_NAME:-sshhh}"
PROJECT="${PROJECT:-sshhh.xcodeproj}"
SCHEME="${SCHEME:-sshhh AppStore}"
CONFIGURATION="${CONFIGURATION:-AppStore}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-DerivedData/AppStore}"
BUILD_ROOT="${BUILD_ROOT:-build/app-store}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$BUILD_ROOT/$APP_NAME.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$BUILD_ROOT/export}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-9MXC88C783}"
APP_STORE_DESTINATION="${1:-export}"
AUTHENTICATION_KEY_PATH="${AUTHENTICATION_KEY_PATH:-}"
AUTHENTICATION_KEY_ID="${AUTHENTICATION_KEY_ID:-}"
AUTHENTICATION_KEY_ISSUER_ID="${AUTHENTICATION_KEY_ISSUER_ID:-}"
PRODUCT_BUNDLE_IDENTIFIER="${PRODUCT_BUNDLE_IDENTIFIER:-com.sshhh.app}"
MARKETING_VERSION="${MARKETING_VERSION:-0.2.6}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"

if [[ -z "$DEVELOPMENT_TEAM" ]]; then
  echo "Set DEVELOPMENT_TEAM to your Apple Developer team ID." >&2
  exit 64
fi

if [[ "$APP_STORE_DESTINATION" != "export" && "$APP_STORE_DESTINATION" != "upload" ]]; then
  usage
  echo "Destination must be either export or upload." >&2
  exit 64
fi

has_auth_placeholders=false
if [[ "$AUTHENTICATION_KEY_PATH" == *"<KEY_ID>"* ||
      "$AUTHENTICATION_KEY_ID" == "<KEY_ID>" ||
      "$AUTHENTICATION_KEY_ISSUER_ID" == "<ISSUER_ID>" ]]; then
  has_auth_placeholders=true
fi

if [[ "$has_auth_placeholders" == "true" ]]; then
  if [[ "$APP_STORE_DESTINATION" == "upload" ]]; then
    echo "Replace placeholders in $APP_STORE_ENV_FILE before uploading." >&2
    exit 64
  fi
  AUTHENTICATION_KEY_PATH=""
  AUTHENTICATION_KEY_ID=""
  AUTHENTICATION_KEY_ISSUER_ID=""
fi

auth_args=()
if [[ -n "$AUTHENTICATION_KEY_PATH" || -n "$AUTHENTICATION_KEY_ID" || -n "$AUTHENTICATION_KEY_ISSUER_ID" ]]; then
  if [[ -z "$AUTHENTICATION_KEY_PATH" || -z "$AUTHENTICATION_KEY_ID" || -z "$AUTHENTICATION_KEY_ISSUER_ID" ]]; then
    echo "Set AUTHENTICATION_KEY_PATH, AUTHENTICATION_KEY_ID, and AUTHENTICATION_KEY_ISSUER_ID together." >&2
    exit 64
  fi
  auth_args+=(
    -authenticationKeyPath "$AUTHENTICATION_KEY_PATH"
    -authenticationKeyID "$AUTHENTICATION_KEY_ID"
    -authenticationKeyIssuerID "$AUTHENTICATION_KEY_ISSUER_ID"
  )
fi

mkdir -p "$BUILD_ROOT"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  "${auth_args[@]}" \
  clean archive \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  ENABLE_HARDENED_RUNTIME=YES \
  PRODUCT_BUNDLE_IDENTIFIER="$PRODUCT_BUNDLE_IDENTIFIER" \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION"

export_options="$BUILD_ROOT/ExportOptions.plist"
cat > "$export_options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>$APP_STORE_DESTINATION</string>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>$DEVELOPMENT_TEAM</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
PLIST

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$export_options" \
  -allowProvisioningUpdates \
  "${auth_args[@]}"

echo "App Store export path: $EXPORT_PATH"
if [[ "$APP_STORE_DESTINATION" == "upload" ]]; then
  echo "Upload requested; check App Store Connect build processing."
fi
