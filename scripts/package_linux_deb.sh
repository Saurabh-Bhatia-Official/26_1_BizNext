#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
# Strip leading 'v' if present (e.g. v1.0.0 -> 1.0.0)
VERSION="${VERSION#v}"
OUTPUT_FILE="${2:-BizNext-Linux-x64.deb}"

BUNDLE_DIR="build/linux/x64/release/bundle"
STAGING_DIR="build/debian_staging"

if [ ! -d "$BUNDLE_DIR" ]; then
  echo "Error: Bundle directory $BUNDLE_DIR not found. Please run 'flutter build linux --release' first."
  exit 1
fi

echo "==> Packaging BizNext Linux .deb version ${VERSION}..."

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/DEBIAN"
mkdir -p "$STAGING_DIR/opt/biznext"
mkdir -p "$STAGING_DIR/usr/bin"
mkdir -p "$STAGING_DIR/usr/share/applications"
mkdir -p "$STAGING_DIR/usr/share/icons/hicolor/256x256/apps"

# Copy application bundle
cp -R "$BUNDLE_DIR"/* "$STAGING_DIR/opt/biznext/"

# Create executable launcher in /usr/bin
cat << 'EOF' > "$STAGING_DIR/usr/bin/biznext"
#!/bin/sh
exec /opt/biznext/biz_next "$@"
EOF
chmod 755 "$STAGING_DIR/usr/bin/biznext"
chmod 755 "$STAGING_DIR/opt/biznext/biz_next"

# Desktop launcher entry
cat << EOF > "$STAGING_DIR/usr/share/applications/biznext.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=BizNext
GenericName=POS & ERP Business Management System
Comment=Production-ready POS & ERP Business Management System
Exec=/usr/bin/biznext %U
Icon=biznext
Terminal=false
StartupNotify=true
Categories=Office;Finance;Spreadsheet;
StartupWMClass=biz_next
EOF
chmod 644 "$STAGING_DIR/usr/share/applications/biznext.desktop"

# Application icon
if [ -f "assets/logo.png" ]; then
  cp "assets/logo.png" "$STAGING_DIR/usr/share/icons/hicolor/256x256/apps/biznext.png"
  chmod 644 "$STAGING_DIR/usr/share/icons/hicolor/256x256/apps/biznext.png"
fi

# Debian control metadata
INSTALLED_SIZE=$(du -sk "$STAGING_DIR" | cut -f1)
cat << EOF > "$STAGING_DIR/DEBIAN/control"
Package: biznext
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: amd64
Installed-Size: ${INSTALLED_SIZE}
Maintainer: Saurabh Bhatia Official <admin@biznext.com>
Depends: libc6, libgtk-3-0, libglib2.0-0, liblzma5
Homepage: https://github.com/Saurabh-Bhatia-Official/26_1_BizNext
Description: BizNext POS & ERP Business Management System
 BizNext is a high-performance, offline-capable POS and ERP system
 designed for retail stores, supermarkets, and wholesale businesses.
EOF
chmod 644 "$STAGING_DIR/DEBIAN/control"

# Build .deb archive
mkdir -p "$(dirname "$OUTPUT_FILE")"
dpkg-deb --build --root-owner-group "$STAGING_DIR" "$OUTPUT_FILE"

echo "==> Successfully created Debian package: $OUTPUT_FILE"
dpkg-deb -I "$OUTPUT_FILE"
