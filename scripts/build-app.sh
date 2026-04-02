#!/bin/bash
set -euo pipefail

# EmberBar — Build, Bundle, Sign, and Package
# Usage: ./scripts/build-app.sh [--dmg]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="EmberBar"
BUNDLE_ID="com.emberbar.app"
VERSION="1.0.0"
BUILD_NUMBER="1"

# Output paths
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

echo "=== EmberBar Build Script ==="
echo "Version: $VERSION ($BUILD_NUMBER)"
echo ""

# Step 1: Build the Swift package (release mode for distribution)
echo "[1/5] Building (release)..."
cd "$PROJECT_DIR"
swift build -c release 2>&1 | tail -3
BINARY="$BUILD_DIR/release/$APP_NAME"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi
echo "  Binary: $BINARY ($(du -h "$BINARY" | cut -f1))"

# Step 2: Create the .app bundle structure
echo "[2/5] Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/$APP_NAME/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy entitlements (for reference, not embedded in ad-hoc)
cp "$PROJECT_DIR/$APP_NAME/$APP_NAME.entitlements" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Copy resources (asset catalog compiled outputs if any)
if [ -d "$BUILD_DIR/release/EmberBar_EmberBar.bundle" ]; then
    cp -R "$BUILD_DIR/release/EmberBar_EmberBar.bundle" "$APP_BUNDLE/Contents/Resources/"
fi

echo "  Bundle: $APP_BUNDLE"

# Step 3: App icon
echo "[3/5] Adding app icon..."
ICON_SRC="$PROJECT_DIR/$APP_NAME/Assets/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    echo "  Using pre-built icon"
else
    echo "  Generating icon with Python fallback..."
    python3 "$SCRIPT_DIR/generate-icon.py" "$APP_BUNDLE/Contents/Resources/AppIcon.iconset" 2>&1

    # Convert iconset to icns (fallback path)
    iconutil -c icns "$APP_BUNDLE/Contents/Resources/AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>&1 || echo "  Warning: iconutil failed"
    rm -rf "$APP_BUNDLE/Contents/Resources/AppIcon.iconset"
fi
echo "  Icon: $APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Update Info.plist to reference the icon
/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_BUNDLE/Contents/Info.plist"

# Step 4: Ad-hoc code sign
# Use the project entitlements but strip any Xcode-only variables first
# Code signing identity
SIGN_IDENTITY="Developer ID Application: Adam Earles (5SMUM7H28D)"
NOTARY_PROFILE="EmberBar"

echo "[4/6] Code signing with Developer ID..."
codesign --force --deep --sign "$SIGN_IDENTITY" \
    --options runtime \
    --entitlements "$PROJECT_DIR/$APP_NAME/$APP_NAME.entitlements" \
    "$APP_BUNDLE" 2>&1
echo "  Signed: $(codesign -dv "$APP_BUNDLE" 2>&1 | grep 'TeamIdentifier' || echo 'unknown')"

# Verify
codesign --verify --verbose "$APP_BUNDLE" 2>&1 && echo "  Verification: OK" || echo "  Verification: WARNING"

# Step 5: Create DMG (if --dmg flag passed)
if [ "${1:-}" = "--dmg" ]; then
    echo "[5/5] Creating styled DMG..."
    rm -f "$DMG_PATH"

    if command -v create-dmg &>/dev/null; then
        # Use create-dmg for a polished installer with icon layout
        create-dmg \
            --volname "$APP_NAME" \
            --window-pos 200 120 \
            --window-size 540 380 \
            --icon-size 96 \
            --icon "$APP_NAME.app" 140 170 \
            --app-drop-link 400 170 \
            --no-internet-enable \
            "$DMG_PATH" \
            "$APP_BUNDLE" 2>&1 | tail -3
    else
        # Fallback: simple DMG with Applications symlink
        DMG_TMP="$BUILD_DIR/dmg-tmp"
        rm -rf "$DMG_TMP"
        mkdir -p "$DMG_TMP"
        cp -R "$APP_BUNDLE" "$DMG_TMP/"
        ln -s /Applications "$DMG_TMP/Applications"
        hdiutil create -volname "$APP_NAME" \
            -srcfolder "$DMG_TMP" \
            -ov -format UDZO \
            "$DMG_PATH" 2>&1 | tail -2
        rm -rf "$DMG_TMP"
    fi

    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo "  DMG: $DMG_PATH ($DMG_SIZE)"

    # Step 6: Notarise the DMG
    echo "[6/6] Notarising with Apple..."
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait 2>&1

    echo "  Stapling notarisation ticket..."
    xcrun stapler staple "$DMG_PATH" 2>&1

    echo "  Notarisation complete"
else
    echo "[5/6] Skipping DMG (pass --dmg to create)"
    echo "[6/6] Skipping notarisation (no DMG)"
fi

APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo ""
echo "=== Build Complete ==="
echo "App:     $APP_BUNDLE ($APP_SIZE)"
[ -f "$DMG_PATH" ] && echo "DMG:     $DMG_PATH ($(du -h "$DMG_PATH" | cut -f1))"
echo ""
echo "To run:       open \"$APP_BUNDLE\""
echo "To install:   Drag $APP_NAME.app to /Applications, then run:"
echo "              open /Applications/$APP_NAME.app"
echo ""
echo "Note: On first launch, macOS may block the app. Right-click > Open to bypass."
