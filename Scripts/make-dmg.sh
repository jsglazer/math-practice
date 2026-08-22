#!/bin/bash
#
# make-dmg.sh — archive MathPractice.xcodeproj, export it Developer-ID-signed
# with hardened runtime, wrap it in a drag-to-Applications DMG, sign, notarize
# and staple both the app and the DMG. Uses only xcodebuild, hdiutil, and
# xcrun (all built into Xcode).
#
# Unlike a bare-binary SwiftPM tool, MathPractice is an Xcode app target with
# App Sandbox + CloudKit entitlements, so packaging goes through a real
# archive + export (xcodebuild -exportArchive with a "developer-id" export
# options plist) rather than hand-assembling the .app bundle.
#
# Override detection:
#   NOTARY_PROFILE="app-router-notary"   notarytool keychain profile (default: app-router-notary,
#                                        which is verified working for this Developer ID team)
#   SKIP_NOTARIZE=1                      archive + export + sign, but don't notarize
#
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

APP_NAME="MathPractice"
PROJECT="$APP_NAME.xcodeproj"
SCHEME="$APP_NAME"
EXPORT_OPTIONS="Scripts/ExportOptions-developer-id.plist"

# `|| true`: awk's early `exit` closes the pipe while xcodebuild is still writing,
# which raises SIGPIPE in xcodebuild; under `pipefail` that would abort the script.
VERSION="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings -configuration Release 2>/dev/null | awk -F'= ' '/ MARKETING_VERSION /{print $2; exit}' || true)"
[ -n "$VERSION" ] || { echo "could not resolve MARKETING_VERSION" >&2; exit 1; }

DIST="$ROOT/dist"
ARCHIVE="$DIST/$APP_NAME.xcarchive"
EXPORT_DIR="$DIST/export"
APP="$EXPORT_DIR/$APP_NAME.app"
DMG="$DIST/${APP_NAME}-${VERSION}.dmg"
mkdir -p "$DIST"

echo "==> $APP_NAME packager (version $VERSION)"

# 1. Regenerate the Xcode project so any project.yml or asset changes are picked up.
echo "==> xcodegen generate"
xcodegen generate

# 2. Archive (Release) — xcodebuild resolves automatic signing/provisioning itself.
echo "==> xcodebuild archive"
rm -rf "$ARCHIVE"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -archivePath "$ARCHIVE" -allowProvisioningUpdates archive

# 3. Export with Developer ID signing + hardened runtime (per Scripts/ExportOptions-developer-id.plist).
echo "==> xcodebuild -exportArchive (Developer ID)"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$EXPORT_OPTIONS" -allowProvisioningUpdates
[ -d "$APP" ] || { echo "export produced no app at $APP" >&2; exit 1; }

# same SIGPIPE/pipefail hazard as the VERSION extraction above.
SIGN_IDENTITY="$(codesign -dvvv "$APP" 2>&1 | awk -F'=' '/^Authority=/{print $2; exit}' || true)"
echo "==> signed: $SIGN_IDENTITY"
codesign --verify --strict --verbose=2 "$APP"

# 4. Notarize the app — the DMG needs the app inside already notarized+stapled
#    for the extracted app to validate offline.
NOTARY_PROFILE="${NOTARY_PROFILE:-app-router-notary}"
NOTARIZED=0
have_profile() {
    xcrun notarytool history --keychain-profile "$1" >/dev/null 2>&1
}
if [ -z "${SKIP_NOTARIZE:-}" ] && [ -n "$NOTARY_PROFILE" ] && have_profile "$NOTARY_PROFILE"; then
    echo "==> notarizing the app via profile '$NOTARY_PROFILE' (submits to Apple, waits)"
    ZIP="$DIST/$APP_NAME-notarize.zip"
    /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
    NOTARIZED=1
else
    echo "==> skipping app notarization (SKIP_NOTARIZE set, or no notary profile '$NOTARY_PROFILE')"
fi

# 5. Build the drag-to-Applications DMG.
echo "==> building DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
[ -f "$DMG" ] || { echo "hdiutil produced no DMG at $DMG" >&2; exit 1; }

# 5b. Sign the disk image itself. hdiutil emits an *unsigned* image, so without this the
#     app inside is notarized but the container assesses as
#     "rejected / source=no usable signature". Must run before step 6 (a signature
#     invalidates a stapled ticket, so sign first, notarize second).
echo "==> signing the DMG: $SIGN_IDENTITY"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
codesign --verify --strict --verbose=2 "$DMG"

# 6. Notarize + staple the DMG itself — its own submission, not covered by the app's.
if [ "$NOTARIZED" = 1 ]; then
    echo "==> notarizing the DMG (submits to Apple, waits)"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
fi

# 7. Gatekeeper assessment — what another Mac will actually do with these artifacts.
echo
echo "==> Gatekeeper assessment"
spctl -a -vvv -t exec "$APP" 2>&1 | sed 's/^/    app  /' || true
spctl -a -vvv -t open --context context:primary-signature "$DMG" 2>&1 | sed 's/^/    dmg  /' || true

echo
echo "==> DONE"
echo "    App: $APP"
echo "    DMG: $DMG"
if [ "$NOTARIZED" = 1 ]; then
    echo "    Signing: Developer ID + notarized + stapled (clean double-click install)"
else
    echo "    Signing: Developer ID, NOT notarized (Gatekeeper still warns off-machine)"
fi
