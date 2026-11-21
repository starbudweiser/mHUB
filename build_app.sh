#!/bin/zsh
# Construit mHUB, le signe (certificat local stable) et l'installe dans ~/Applications/Applications Personnelles.
#   ./build_app.sh          version locale installée : mHUB.app (fr.stephan.mhub)
#   DEV=1 ./build_app.sh    version de développement : « mHUB Dev.app » (fr.stephan.mhub.dev), dans le dossier du projet, sans installation
#   TEST=1 ./build_app.sh   édition de test vierge : « mHUB Test.app » (fr.stephan.mhub.test), données et dossier d'installation
#                           à part (~/Library/Application Support/mHUB Test), remis à zéro à chaque build, sans installation
# NO_INSTALL=1 : ne pas installer ; NO_OPEN=1 : ne pas lancer.
set -euo pipefail
cd "$(dirname "$0")"
python3 tools/gen_catalogue.py >/dev/null
if [ -n "${TEST:-}" ]; then APP="mHUB Test.app"; EXE="mHUB"; DEV=""
elif [ -n "${DEV:-}" ]; then APP="mHUB Dev.app"; EXE="mHUB"; else APP="mHUB.app"; EXE="mHUB"; fi
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
if [ -n "${TEST:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier fr.stephan.mhub.test" -c "Set :CFBundleName mHUB Test" -c "Set :CFBundleDisplayName mHUB Test" "$APP/Contents/Info.plist"
  # Premier lancement d'un acheteur : aucune donnée, aucun réglage, aucune appli installée.
  pkill -f "mHUB Test.app/Contents/MacOS" 2>/dev/null || true
  defaults delete fr.stephan.mhub.test 2>/dev/null || true
  rm -rf "$HOME/Library/Application Support/mHUB Test" "$HOME/Library/Preferences/fr.stephan.mhub.test.plist"
  NO_INSTALL=1
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
