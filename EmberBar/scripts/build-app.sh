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

# Step 1: Build the Swift package
# Use debug mode — release builds have launch issues with ad-hoc signing on macOS.
# Switch to release once we have a proper Developer ID certificate.
echo "[1/5] Building..."
cd "$PROJECT_DIR"
swift build 2>&1 | tail -3
BINARY="$BUILD_DIR/debug/$APP_NAME"

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

# Step 3: Generate an app icon
echo "[3/5] Generating app icon..."

# Create a simple icon using sips and a Python-generated PNG
python3 -c "
import struct, zlib

def create_ember_icon(size):
    '''Create a simple ember-colored icon as PNG'''
    pixels = []
    center = size / 2
    for y in range(size):
        row = []
        for x in range(size):
            # Distance from center
            dx = (x - center) / center
            dy = (y - center) / center
            dist = (dx*dx + dy*dy) ** 0.5

            # Flame shape: wider at bottom, narrow at top
            flame_width = 0.4 + 0.3 * (y / size)  # wider at bottom
            in_flame = abs(dx) < flame_width * (1 - dist * 0.7) and dist < 0.9

            if in_flame and dist < 0.85:
                # Gradient from bright center to dark edge
                t = dist / 0.85
                if t < 0.3:
                    # Hot core - bright yellow/white
                    r, g, b = int(255), int(230 - t*200), int(150 - t*400)
                elif t < 0.6:
                    # Mid - orange
                    r, g, b = int(255), int(140 - (t-0.3)*300), int(30)
                else:
                    # Edge - deep red/ember
                    r, g, b = int(220 - (t-0.6)*300), int(50 - (t-0.6)*100), int(10)
                r = max(0, min(255, r))
                g = max(0, min(255, g))
                b = max(0, min(255, b))
                # Soft edge alpha
                edge_alpha = min(255, int((0.85 - dist) / 0.15 * 255)) if dist > 0.7 else 255
                a = edge_alpha
            else:
                r, g, b, a = 0, 0, 0, 0
            row.extend([r, g, b, a])
        pixels.append(bytes([0] + row))  # filter byte + row data

    raw = b''.join(pixels)

    def chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    header = struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)  # RGBA
    compressed = zlib.compress(raw)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', header)
    png += chunk(b'IDAT', compressed)
    png += chunk(b'IEND', b'')
    return png

# Generate multiple sizes for iconset
import os
iconset_dir = '$APP_BUNDLE/Contents/Resources/AppIcon.iconset'
os.makedirs(iconset_dir, exist_ok=True)

sizes = {
    'icon_16x16.png': 16,
    'icon_16x16@2x.png': 32,
    'icon_32x32.png': 32,
    'icon_32x32@2x.png': 64,
    'icon_128x128.png': 128,
    'icon_128x128@2x.png': 256,
    'icon_256x256.png': 256,
    'icon_256x256@2x.png': 512,
    'icon_512x512.png': 512,
    'icon_512x512@2x.png': 1024,
}

for filename, size in sizes.items():
    png_data = create_ember_icon(size)
    with open(os.path.join(iconset_dir, filename), 'wb') as f:
        f.write(png_data)

print(f'  Generated {len(sizes)} icon sizes')
" 2>&1

# Convert iconset to icns
iconutil -c icns "$APP_BUNDLE/Contents/Resources/AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>&1 && {
    rm -rf "$APP_BUNDLE/Contents/Resources/AppIcon.iconset"
    echo "  Icon: $APP_BUNDLE/Contents/Resources/AppIcon.icns"

    # Update Info.plist to reference the icon
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_BUNDLE/Contents/Info.plist"
} || {
    echo "  Warning: iconutil failed, continuing without icon"
    rm -rf "$APP_BUNDLE/Contents/Resources/AppIcon.iconset"
}

# Step 4: Ad-hoc code sign
echo "[4/5] Code signing (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements "$PROJECT_DIR/$APP_NAME/$APP_NAME.entitlements" \
    "$APP_BUNDLE" 2>&1
echo "  Signed: $(codesign -dv "$APP_BUNDLE" 2>&1 | grep 'Identifier' || echo 'ad-hoc')"

# Verify
codesign --verify --verbose "$APP_BUNDLE" 2>&1 && echo "  Verification: OK" || echo "  Verification: WARNING"

# Step 5: Create DMG (if --dmg flag passed)
if [ "${1:-}" = "--dmg" ]; then
    echo "[5/5] Creating DMG..."
    rm -f "$DMG_PATH"

    # Create a temporary directory for DMG contents
    DMG_TMP="$BUILD_DIR/dmg-tmp"
    rm -rf "$DMG_TMP"
    mkdir -p "$DMG_TMP"

    # Copy app bundle
    cp -R "$APP_BUNDLE" "$DMG_TMP/"

    # Create a symlink to /Applications
    ln -s /Applications "$DMG_TMP/Applications"

    # Create the DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_TMP" \
        -ov -format UDZO \
        "$DMG_PATH" 2>&1 | tail -2

    rm -rf "$DMG_TMP"

    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo "  DMG: $DMG_PATH ($DMG_SIZE)"
else
    echo "[5/5] Skipping DMG (pass --dmg to create)"
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
