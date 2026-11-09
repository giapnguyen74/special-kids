#!/usr/bin/env bash
# Builds the signed release APK + update feed for one app (called by `make release`).
# In: APP DIR NAME VERSION FEED_URL KEYSTORE KEY_SERVICE DOWNLOAD_PREFIX
set -euo pipefail
cd "$(dirname "$0")/.."

# Build number: increases with the version (Android refuses updates with a lower or equal number).
IFS=. read -r MA MI PA <<<"$VERSION"
BUILD=$((MA * 10000 + MI * 100 + PA))
OUT="dist/$APP/$VERSION"
APK="$OUT/$NAME-$VERSION.apk"
mkdir -p "$OUT"

echo "› tests"
make -s test

echo "› build $NAME $VERSION ($BUILD)"
export SK_KEYSTORE="$KEYSTORE"
SK_KEYSTORE_PASSWORD="$(security find-generic-password -s "$KEY_SERVICE" -w)"
export SK_KEYSTORE_PASSWORD
(cd "$DIR" && flutter build apk --release \
  --build-name="$VERSION" --build-number="$BUILD" \
  --dart-define=SK_FEED_URL="$FEED_URL" | tail -1)
cp "$DIR/build/app/outputs/flutter-apk/app-release.apk" "$APK"

# Make sure it is signed with the release key, not the debug key.
APKSIGNER="$(ls -d "$ANDROID_HOME"/build-tools/*/apksigner | sort | tail -1)"
if "$APKSIGNER" verify --print-certs "$APK" | grep -q "CN=Android Debug"; then
  echo "✗ APK is debug-signed" >&2
  exit 1
fi

SHA="$(shasum -a 256 "$APK" | cut -d' ' -f1)"
cat >"$OUT/latest.json" <<JSON
{
  "version": "$VERSION",
  "build": $BUILD,
  "apk": "$DOWNLOAD_PREFIX$NAME-$VERSION.apk",
  "sha256": "$SHA",
  "notes": ""
}
JSON
echo "✓ $APK ($(du -h "$APK" | cut -f1)), feed $OUT/latest.json"
