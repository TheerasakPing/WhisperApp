#!/bin/bash
# สร้าง WhisperApp.app bundle ที่ถูกต้อง (มี Info.plist + NSMicrophoneUsageDescription)
set -e
cd "$(dirname "$0")"

APP_NAME="WhisperApp"          # SPM executable name (must match Package.swift target)
APP_BUNDLE="Whisper.app"       # name shown in /Applications
KEYCHAIN="${WHISPERAPP_KEYCHAIN:-${HOME}/Library/Keychains/login.keychain-db}"
ARCH="${WHISPERAPP_ARCH:-}"
REQUIRE_DEVELOPER_ID="${WHISPERAPP_REQUIRE_DEVELOPER_ID:-0}"

BUILD_ARGS=(-c release)
if [ -n "$ARCH" ]; then
    BUILD_ARGS+=(--arch "$ARCH")
fi

echo "🔨 Building release${ARCH:+ for $ARCH}..."
swift build "${BUILD_ARGS[@]}"
BIN_DIR=$(swift build "${BUILD_ARGS[@]}" --show-bin-path)

echo "📦 Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# App icon
if [ -f "assets/Icon.icns" ]; then
    cp "assets/Icon.icns" "$APP_BUNDLE/Contents/Resources/Icon.icns"
    echo "🎨 เพิ่ม app icon"
fi

# Logo (for the About window)
if [ -f "assets/logo.png" ]; then
    cp "assets/logo.png" "$APP_BUNDLE/Contents/Resources/logo.png"
fi

# Embed Sparkle.framework (universal) for auto-update
SPARKLE_FW=$(find .build/artifacts -type d -name "Sparkle.framework" -path "*macos-arm64_x86_64*" 2>/dev/null | head -1)
if [ -n "$SPARKLE_FW" ]; then
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    rm -rf "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    cp -R "$SPARKLE_FW" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    install_name_tool -add_rpath @loader_path/../Frameworks "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || true
    echo "🪄 Embed Sparkle.framework"
else
    echo "⚠️  ไม่พบ Sparkle.framework — รัน 'swift build' ก่อน make_app.sh"
fi

# Code signing:
# - ถ้ามี "Developer ID Application" → sign ด้วย cert นี้
# - local build ยัง fallback ad-hoc ได้
# - CI release ตั้ง WHISPERAPP_REQUIRE_DEVELOPER_ID=1 เพื่อห้าม ad-hoc โดยเด็ดขาด
DEV_ID=$(security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep "Developer ID Application" | head -1 | sed -n 's/.*"\(.*\)".*/\1/p')

if [ -n "$DEV_ID" ]; then
    if [ -d "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework" ]; then
        codesign --force --deep --sign "$DEV_ID" --options runtime --timestamp \
            "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    fi
    echo "✍️  Code signing ด้วย Developer ID: $DEV_ID"
    codesign --force --options runtime --timestamp \
        --entitlements WhisperApp.entitlements \
        --sign "$DEV_ID" "$APP_BUNDLE"
elif [ "$REQUIRE_DEVELOPER_ID" = "1" ]; then
    echo "❌ Release build requires a Developer ID Application certificate in: $KEYCHAIN"
    exit 1
else
    echo "✍️  Code signing (ad-hoc) — แนะนำให้ติดตั้ง Developer ID cert เพื่อสิทธิ์คงที่"
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "✅ เสร็จ: $APP_BUNDLE"
echo "   เปิดด้วย: open $APP_BUNDLE"
