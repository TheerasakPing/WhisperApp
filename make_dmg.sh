#!/bin/bash
# สร้าง .dmg สำหรับติดตั้ง (drag app ไปที่ Applications)
# ทำความสะอาดก่อนทุกครั้ง + sign ด้วย Developer ID + ไม่มี key ใดๆ
set -e
cd "$(dirname "$0")"

APP_NAME="Whisper"
APP_BUNDLE="$APP_NAME.app"
KEYCHAIN="${WHISPERAPP_KEYCHAIN:-${HOME}/Library/Keychains/login.keychain-db}"
NOTARY_PROFILE="${WHISPERAPP_NOTARY_PROFILE:-whisperapp-notary}"
RELEASE_SUFFIX="${WHISPERAPP_RELEASE_SUFFIX:-}"
REQUIRE_DEVELOPER_ID="${WHISPERAPP_REQUIRE_DEVELOPER_ID:-0}"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.0")
if [ -n "$RELEASE_SUFFIX" ]; then
    DMG_NAME="${APP_NAME}-${VERSION}-${RELEASE_SUFFIX}.dmg"
else
    DMG_NAME="${APP_NAME}-${VERSION}.dmg"
fi

echo "🔨 สร้าง release build + bundle ใหม่..."
./make_app.sh >/dev/null

# หา Developer ID
DEV_ID=$(security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep "Developer ID Application" | head -1 | sed -n 's/.*"\(.*\)".*/\1/p')
if [ -z "$DEV_ID" ] && [ "$REQUIRE_DEVELOPER_ID" = "1" ]; then
    echo "❌ Release build requires a Developer ID Application certificate in: $KEYCHAIN"
    exit 1
fi

# Notarize + staple the .app itself (ไม่ใช่แค่ DMG)
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "❌ ไม่มี credentials profile '$NOTARY_PROFILE'"
    exit 1
fi
echo "📤 Notarizing $APP_BUNDLE..."
NOTARY_ZIP="/tmp/${APP_NAME}-notary.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"
if ! xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait; then
    rm -f "$NOTARY_ZIP"
    echo "❌ Notarize .app ล้มเหลว"
    exit 1
fi
rm -f "$NOTARY_ZIP"
xcrun stapler staple "$APP_BUNDLE"
echo "✅ $APP_BUNDLE notarized + stapled"

echo "📦 เตรียม staging สำหรับ DMG..."
STAGE=$(mktemp -d)
cp -R "$APP_BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

mkdir -p "$STAGE/.background"
[ -f "assets/logo.png" ] && cp "assets/logo.png" "$STAGE/.background/background.png"

RW_DMG="/tmp/${APP_NAME}-rw.dmg"
rm -f "$RW_DMG" "$DMG_NAME"

echo "💽 สร้าง read-write DMG..."
hdiutil create -srcfolder "$STAGE" -fs HFS+ -volname "$APP_NAME" -format UDRW "$RW_DMG" >/dev/null

MOUNT_DIR="/tmp/${APP_NAME}_mnt"
rm -rf "$MOUNT_DIR"; mkdir -p "$MOUNT_DIR"
hdiutil attach "$RW_DMG" -readwrite -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null

echo "🎨 จัด layout หน้าต่าง (optional)..."
osascript <<APPLESCRIPT || echo "   (ข้าม layout — DMG ยังใช้ติดตั้งได้ปกติ)"
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 760, 440}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set position of item "$APP_NAME" of container window to {130, 140}
        set position of item "Applications" of container window to {430, 140}
        close without saving
    end tell
end tell
APPLESCRIPT

echo "🔒 ปิด mount + แปลงเป็น compressed read-only DMG..."
hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME" >/dev/null
rm -f "$RW_DMG"
rm -rf "$STAGE"

if [ -n "$DEV_ID" ]; then
    codesign --sign "$DEV_ID" --timestamp "$DMG_NAME"
    echo "✍️  sign DMG ด้วย Developer ID"
elif [ "$REQUIRE_DEVELOPER_ID" = "1" ]; then
    echo "❌ ไม่พบ Developer ID สำหรับ sign DMG"
    exit 1
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "❌ ไม่มี credentials profile '$NOTARY_PROFILE'"
    exit 1
fi
echo "📤 Notarizing $DMG_NAME..."
if ! xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait; then
    echo "❌ Notarize DMG ล้มเหลว"
    exit 1
fi
xcrun stapler staple "$DMG_NAME"
echo "✅ DMG notarized + stapled"

echo ""
echo "✅ เสร็จ: $DMG_NAME"
ls -lh "$DMG_NAME"
