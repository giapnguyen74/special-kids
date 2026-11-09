#!/usr/bin/env bash
# Creates the Android release signing key (once). Every update of an app must be signed with the SAME key,
# otherwise Android refuses to update it (parents would have to uninstall and lose the child's progress).
#
#   keystore  ~/.special-kids/android-release.jks   (outside the repo — BACK IT UP, e.g. in a password manager)
#   password  macOS Keychain, service "special-kids-android-keystore"
set -euo pipefail
KEYSTORE="${SK_KEYSTORE:-$HOME/.special-kids/android-release.jks}"
SERVICE=special-kids-android-keystore
ALIAS=release

if [[ -f "$KEYSTORE" ]]; then
  echo "Keystore already exists: $KEYSTORE (not touching it)."
  exit 0
fi
J="$(/usr/libexec/java_home -v 17 2>/dev/null || echo /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home)"
mkdir -p "$(dirname "$KEYSTORE")"
chmod 700 "$(dirname "$KEYSTORE")"
PASS="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-28)"
"$J/bin/keytool" -genkeypair -v -keystore "$KEYSTORE" -storetype PKCS12 -alias "$ALIAS" \
  -keyalg RSA -keysize 4096 -validity 36500 -storepass "$PASS" -keypass "$PASS" \
  -dname "CN=Special Kids, O=Giap Nguyen, C=VN" >/dev/null 2>&1
chmod 600 "$KEYSTORE"
security add-generic-password -a "$USER" -s "$SERVICE" -w "$PASS" -U
echo "Created $KEYSTORE; password saved in the Keychain ($SERVICE)."
echo
echo "BACK UP NOW (both are needed to ship updates):"
echo "  1. the file  $KEYSTORE"
echo "  2. the password:  security find-generic-password -s $SERVICE -w"
