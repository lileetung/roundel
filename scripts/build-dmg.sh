#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
BUILD_DIR="$PROJECT_DIR/.build/dmg"
STAGING_DIR="$BUILD_DIR/staging"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$BUILD_DIR/Build/Products/Release/Roundel.app"
RELEASE_VERSION="${ROUNDEL_VERSION:-0.1.0}"
DMG_PATH="$DIST_DIR/Roundel-$RELEASE_VERSION.dmg"
ZIP_PATH="$BUILD_DIR/Roundel-$RELEASE_VERSION.zip"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ -n "$NOTARY_PROFILE" && -z "$SIGNING_IDENTITY" ]]; then
  print -u2 "NOTARY_PROFILE requires a Developer ID Application SIGNING_IDENTITY."
  exit 2
fi

rm -rf "$BUILD_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"

xcodebuild \
  -project "$PROJECT_DIR/Roundel.xcodeproj" \
  -scheme Roundel \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --entitlements "$PROJECT_DIR/Roundel/Resources/Roundel.entitlements" \
    --sign "$SIGNING_IDENTITY" \
    "$APP_PATH"
else
  print -u2 "Warning: SIGNING_IDENTITY is unset; creating an ad-hoc signed local-test DMG."
  codesign \
    --force \
    --options runtime \
    --entitlements "$PROJECT_DIR/Roundel/Resources/Roundel.entitlements" \
    --sign - \
    "$APP_PATH"
fi

codesign --verify --strict --verbose=2 "$APP_PATH"

# Notarize the app before packaging so its ticket can be stapled into the bundle.
# A stapled app launches offline; without it the first launch needs a network
# round-trip to Apple.
if [[ -n "$NOTARY_PROFILE" ]]; then
  ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
fi

ditto "$APP_PATH" "$STAGING_DIR/Roundel.app"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "Roundel" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

# Sign the disk image itself. An unsigned DMG fails Gatekeeper's open
# assessment even when the app inside it is notarized.
if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

(cd "$DIST_DIR" && shasum -a 256 "${DMG_PATH:t}") > "$DMG_PATH.sha256"
print "Created $DMG_PATH"
