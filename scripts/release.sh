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

# Make sure it is signed with the release key (must positively find our certificate).
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 17 2>/dev/null || echo /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home)}"
APKSIGNER="$(ls -d "$ANDROID_HOME"/build-tools/*/apksigner | sort | tail -1)"
CERTS="$("$APKSIGNER" verify --print-certs "$APK")" || { echo "✗ APK signature does not verify" >&2; exit 1; }
if ! grep -q "CN=Special Kids" <<<"$CERTS"; then
  echo "✗ APK is not signed with the release key:" >&2
  echo "$CERTS" >&2
  exit 1
fi
echo "✓ signed with the release key"

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
