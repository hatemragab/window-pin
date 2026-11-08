#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "Building Window Pin for Apple silicon (arm64)…"
swift build -c release --arch arm64

BIN="$ROOT/.build/arm64-apple-macosx/release/WindowPin"
if [[ ! -x "$BIN" ]]; then
  BIN="$ROOT/.build/release/WindowPin"
fi
if [[ ! -x "$BIN" ]]; then
  echo "Release binary was not produced." >&2
  exit 1
fi

APP="$ROOT/dist/Window Pin.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WindowPin"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/WindowPin"

echo "Drawing app icon…"
swiftc -O -framework AppKit "$ROOT/scripts/MakeIcon.swift" -o "$ROOT/scripts/.make-icon"
"$ROOT/scripts/.make-icon" "$APP/Contents/Resources/AppIcon.icns"
rm -f "$ROOT/scripts/.make-icon"

echo "Signing for this Mac…"
IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: Hatem Ragab[^"]*\)".*/\1/p' | head -1)"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="-"
  echo "No Developer ID found. Using an ad-hoc signature."
else
  echo "Using $IDENTITY"
fi
codesign --force --sign "$IDENTITY" --timestamp=none "$APP"
codesign --verify --strict --verbose=2 "$APP"

STAGING="$ROOT/dist/dmg-root"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/Window Pin.app"
ln -s /Applications "$STAGING/Applications"

if mount | grep -q "on /Volumes/Window Pin "; then
  hdiutil detach "/Volumes/Window Pin" -force || true
fi

DMG="$ROOT/dist/WindowPin-arm64.dmg"
rm -f "$DMG"
hdiutil create -volname "Window Pin" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

echo
echo "Built:"
echo "  $APP"
echo "  $DMG"
file "$APP/Contents/MacOS/WindowPin"
