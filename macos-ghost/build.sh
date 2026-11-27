#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/ChameleonPiP.app"
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
  <string>ChameleonPiP</string>
  <key>CFBundleIdentifier</key>
  <string>com.chameleonpip.macos</string>
  <key>CFBundleName</key>
  <string>ChameleonPiP</string>
  <key>CFBundleDisplayName</key>
  <string>ChameleonPiP 变色龙画中画</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>5.5.0</string>
  <key>CFBundleVersion</key>
  <string>8</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSCameraUsageDescription</key>
  <string>ChameleonPiP 仅在您手动开启「AI 背后防偷窥雷达」时于本地内存中运行 Apple Vision 人脸计数检测（检测到背后 ≥2 人时自动触发老板键隐藏）。摄像头画面实时丢弃，绝不录制、存储或上传。</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>com.chameleonpip.macos.url</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>chameleonpip</string>
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

echo "Stopping any old running ChameleonPiP / GeckoGhost process..."
pkill -x ChameleonPiP >/dev/null 2>&1 || true
pkill -x GeckoGhost >/dev/null 2>&1 || true
rm -rf "$ROOT_DIR/GeckoGhost.app"

echo "Compiling ChameleonPiP v5.5 native macOS binary (Metal Biomimetic Chameleon + Vision Anti-Peek + Built-in Web Player)..."
swiftc -O -swift-version 5 \
  -framework Cocoa \
  -framework QuartzCore \
  -framework WebKit \
  -framework Network \
  -framework ScreenCaptureKit \
  -framework Carbon \
  -framework CoreGraphics \
  -framework AVFoundation \
  -framework Vision \
  -framework CoreMedia \
  -framework CoreVideo \
  "$ROOT_DIR/macos-ghost/ChameleonPiP.swift" \
  -o "$MACOS_DIR/ChameleonPiP"

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

# Register chameleonpip:// (+ legacy geckoghost://) custom URL schemes in macOS LaunchServices
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREG" ]; then
  if [ -d "/Applications/GeckoGhost.app" ]; then
    "$LSREG" -u "/Applications/GeckoGhost.app" >/dev/null 2>&1 || true
  fi
  if [ -d "$HOME/Applications/GeckoGhost.app" ]; then
    "$LSREG" -u "$HOME/Applications/GeckoGhost.app" >/dev/null 2>&1 || true
  fi
  "$LSREG" -f "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

if [ -w "/Applications" ]; then
  rm -rf "/Applications/GeckoGhost.app" "$HOME/Applications/GeckoGhost.app" "/Applications/ChameleonPiP.app"
  cp -R "$APP_BUNDLE" "/Applications/ChameleonPiP.app"
  codesign --force --deep --sign - "/Applications/ChameleonPiP.app" >/dev/null 2>&1 || true
  if [ -x "$LSREG" ]; then
    "$LSREG" -f "/Applications/ChameleonPiP.app" >/dev/null 2>&1 || true
  fi
  echo "OK: Built & installed to /Applications/ChameleonPiP.app (+ LaunchServices chameleonpip://)"
elif [ -d "$HOME/Applications" ] || mkdir -p "$HOME/Applications" 2>/dev/null; then
  rm -rf "$HOME/Applications/GeckoGhost.app" "$HOME/Applications/ChameleonPiP.app"
  cp -R "$APP_BUNDLE" "$HOME/Applications/ChameleonPiP.app"
  codesign --force --deep --sign - "$HOME/Applications/ChameleonPiP.app" >/dev/null 2>&1 || true
  if [ -x "$LSREG" ]; then
    "$LSREG" -f "$HOME/Applications/ChameleonPiP.app" >/dev/null 2>&1 || true
  fi
  echo "OK: Built & installed to ~/Applications/ChameleonPiP.app (+ LaunchServices chameleonpip://)"
else
  echo "OK: Built & registered chameleonpip:// scheme: $APP_BUNDLE"
fi
