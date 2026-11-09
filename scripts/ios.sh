#!/usr/bin/env bash
# iPhone/iPad builds (called by `make testflight`).
#   testflight  archive a release build and upload it to App Store Connect for TestFlight.
#               The app record must exist in App Store Connect first (bundle id com.specialkids.<app>).
# The version is the app's VERSION; the build number is the current time, so every upload is newer.
# In: APP DIR TEAM_ID VERSION ASC_KEY_ID ASC_ISSUER_ID
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-}"
BUILD="$(date +%Y%m%d%H%M)"
PBX="$DIR/ios/Runner.xcodeproj/project.pbxproj"

case "$MODE" in
testflight)
  # Sign with the paid team (same as ../darksurf).
  sed -i '' "s/DEVELOPMENT_TEAM = [A-Z0-9]*;/DEVELOPMENT_TEAM = $TEAM_ID;/" "$PBX"
  PLIST="$(mktemp -t export).plist"
  cat >"$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PL
  (cd "$DIR" && flutter build ipa --release --build-name="$VERSION" --build-number="$BUILD" \
     --export-options-plist="$PLIST" | tail -3)
  IPA="$(ls "$DIR"/build/ios/ipa/*.ipa | head -1)"
  xcrun altool --upload-app -t ios -f "$IPA" --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "Uploaded $APP $VERSION ($BUILD) to App Store Connect. It appears in TestFlight after processing."
  ;;
*)
  echo "usage: scripts/ios.sh testflight" >&2
  exit 1
  ;;
esac
