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

# Icono: Resources/AppIcon.png (1024px) -> AppIcon.icns
if [ -f Resources/AppIcon.png ]; then
    ICONSET="build/AppIcon.iconset"
    rm -rf "$ICONSET"; mkdir -p "$ICONSET" "$APP/Contents/Resources"
    for s in 16 32 128 256 512; do
        sips -z $s $s Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
        sips -z $((s*2)) $((s*2)) Resources/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
fi
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
