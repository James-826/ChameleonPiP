#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/GeckoGhost.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

mkdir -p "$MACOS_DIR" "$RES_DIR"

cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>GeckoGhost</string>
  <key>CFBundleIdentifier</key>
  <string>com.geckopip.ghost</string>
  <key>CFBundleName</key>
  <string>GeckoGhost</string>
  <key>CFBundleDisplayName</key>
  <string>变色龙画中画 ChameleonPiP</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>5.0.0</string>
  <key>CFBundleVersion</key>
  <string>5</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>com.geckopip.ghost.url</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>geckoghost</string>
      </array>
    </dict>
  </array>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
  </dict>
</dict>
</plist>
EOF

cp "$ROOT_DIR/macos-ghost/ghost-view.html" "$RES_DIR/ghost-view.html"
cp "$ROOT_DIR/desktop/menubar.html" "$RES_DIR/menubar.html"
cp "$ROOT_DIR/demo/arena.html" "$RES_DIR/arena.html"
cp "$ROOT_DIR/demo/arena.html" "$ROOT_DIR/extension/arena.html"
cp "$ROOT_DIR/demo/index.html" "$RES_DIR/index.html"
cp "$ROOT_DIR/extension/gecko-core.js" "$RES_DIR/gecko-core.js"
cp "$ROOT_DIR/extension/chameleon-stats.js" "$RES_DIR/chameleon-stats.js"
cp "$ROOT_DIR/web/store-config.js" "$RES_DIR/store-config.js"
cp "$ROOT_DIR/web/store-config.js" "$ROOT_DIR/extension/store-config.js"
cp "$ROOT_DIR/extension/gecko-core.js" "$ROOT_DIR/macos-ghost/gecko-core.js"
cp "$ROOT_DIR/extension/chameleon-stats.js" "$ROOT_DIR/macos-ghost/chameleon-stats.js"
cp "$ROOT_DIR/extension/icons/icon128.png" "$RES_DIR/icon128.png"
if [ -f "$ROOT_DIR/macos-ghost/assets/AppIcon.icns" ]; then
  cp "$ROOT_DIR/macos-ghost/assets/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi
mkdir -p "$CONTENTS/extension/icons"
cp "$ROOT_DIR/extension/gecko-core.js" "$CONTENTS/extension/gecko-core.js"
cp "$ROOT_DIR/extension/chameleon-stats.js" "$CONTENTS/extension/chameleon-stats.js"
cp "$ROOT_DIR/extension/icons/"*.png "$CONTENTS/extension/icons/"

# Sync shared assets into cross-platform Electron desktop/ folder (for Mac + Windows)
mkdir -p "$ROOT_DIR/desktop/icons"
cp "$ROOT_DIR/macos-ghost/ghost-view.html" "$ROOT_DIR/desktop/ghost-view.html"
cp "$ROOT_DIR/demo/arena.html" "$ROOT_DIR/desktop/arena.html"
cp "$ROOT_DIR/extension/gecko-core.js" "$ROOT_DIR/desktop/gecko-core.js"
cp "$ROOT_DIR/extension/chameleon-stats.js" "$ROOT_DIR/desktop/chameleon-stats.js"
cp "$ROOT_DIR/extension/icons/"*.png "$ROOT_DIR/desktop/icons/"

echo "Stopping any old running GeckoGhost process..."
pkill -x GeckoGhost >/dev/null 2>&1 || true

echo "Compiling ChameleonPiP v5.0 native macOS arm64 binary..."
swiftc -O -swift-version 5 \
  -framework Cocoa \
  -framework QuartzCore \
  -framework WebKit \
  -framework Network \
  -framework ScreenCaptureKit \
  -framework Carbon \
  -framework CoreGraphics \
  "$ROOT_DIR/macos-ghost/GeckoGhost.swift" \
  -o "$MACOS_DIR/GeckoGhost"

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

# Register geckoghost:// custom URL scheme in macOS LaunchServices so Chrome can auto-launch it!
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREG" ]; then
  "$LSREG" -f "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

echo "✅ Built & registered geckoghost:// scheme: $APP_BUNDLE"
