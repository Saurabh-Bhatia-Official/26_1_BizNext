#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-build/macos/Build/Products/Release/biz_next.app}"
OUTPUT_FILE="${2:-BizNext-macOS.dmg}"
VOL_NAME="${3:-BizNext}"

if [ ! -d "$APP_PATH" ]; then
  # Check if BizNext.app exists instead
  if [ -d "build/macos/Build/Products/Release/BizNext.app" ]; then
    APP_PATH="build/macos/Build/Products/Release/BizNext.app"
  else
    echo "Error: macOS application bundle not found at $APP_PATH. Please run 'flutter build macos --release' first."
    exit 1
  fi
fi

echo "==> Packaging macOS DMG from $APP_PATH into $OUTPUT_FILE..."
mkdir -p "$(dirname "$OUTPUT_FILE")"
rm -f "$OUTPUT_FILE"

# Attempt professional create-dmg if available
if command -v create-dmg >/dev/null 2>&1; then
  echo "Using create-dmg utility..."
  set +e
  create-dmg \
    --volname "$VOL_NAME" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 128 \
    --text-size 14 \
    --icon "$(basename "$APP_PATH")" 180 170 \
    --hide-extension "$(basename "$APP_PATH")" \
    --app-drop-link 480 170 \
    --no-internet-enable \
    "$OUTPUT_FILE" \
    "$APP_PATH"
  STATUS=$?
  set -e
  if [ $STATUS -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    echo "==> Successfully created DMG using create-dmg: $OUTPUT_FILE"
    exit 0
  else
    echo "create-dmg exited with status $STATUS. Falling back to native hdiutil..."
  fi
fi

# Native hdiutil fallback (guaranteed on any macOS runner)
echo "Using native hdiutil with Applications symlink..."
STAGING_DIR="build/dmg_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

cp -R "$APP_PATH" "$STAGING_DIR/BizNext.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_FILE"

rm -rf "$STAGING_DIR"
echo "==> Successfully created DMG using hdiutil: $OUTPUT_FILE"
