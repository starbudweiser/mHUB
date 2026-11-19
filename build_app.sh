#!/bin/zsh
# Construit mHUB, le signe (certificat local stable) et l'installe dans ~/Applications/Applications Personnelles.
#   ./build_app.sh          version locale installée : mHUB.app (fr.stephan.mhub)
#   DEV=1 ./build_app.sh    version de développement : « mHUB Dev.app » (fr.stephan.mhub.dev), dans le dossier du projet, sans installation
# NO_INSTALL=1 : ne pas installer ; NO_OPEN=1 : ne pas lancer.
set -euo pipefail
cd "$(dirname "$0")"
python3 tools/gen_catalogue.py >/dev/null
if [ -n "${DEV:-}" ]; then APP="mHUB Dev.app"; EXE="mHUB"; else APP="mHUB.app"; EXE="mHUB"; fi
DEST="$HOME/Applications/Applications Personnelles"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos15 -o "$APP/Contents/MacOS/$EXE" Sources/*.swift

cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/catalogue.json "$APP/Contents/Resources/catalogue.json"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -n "${DEV:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier fr.stephan.mhub.dev" -c "Set :CFBundleName mHUB Dev" -c "Set :CFBundleDisplayName mHUB Dev" "$APP/Contents/Info.plist"
fi

SIGN="/Volumes/SKYRIM/TOOLS/MAC/_tools/sign_app.sh"
if [ -x "$SIGN" ]; then "$SIGN" "$APP"; else codesign --force --deep -s - "$APP"; fi

if [ -z "${DEV:-}" ] && [ -z "${NO_INSTALL:-}" ]; then
  mkdir -p "$DEST"
  pkill -x mHUB 2>/dev/null || true
  rm -rf "$DEST/$APP"
  cp -R "$APP" "$DEST/$APP"
  echo "Installée : $DEST/$APP"
fi
echo "OK : $APP"
