#!/bin/bash
# Compila ClipStack y genera build/ClipStack.app (requiere Xcode o Command Line Tools)
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/ClipStack.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ClipStack "$APP/Contents/MacOS/ClipStack"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

# DMG con "arrastrar a Aplicaciones"
DMG="build/ClipStack.dmg"
STAGE="build/dmg"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "ClipStack" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo ""
echo "Listo: $APP"
echo "DMG para arrastrar a Aplicaciones: $DMG"
echo "Instalar:  cp -R $APP /Applications/ && open /Applications/ClipStack.app"
