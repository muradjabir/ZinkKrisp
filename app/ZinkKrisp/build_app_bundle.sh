#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MESA_ARM64_DIR="${MESA_ARM64_DIR:-$REPO_ROOT/mesa-install-arm64}"
MESA_WIN64_DIR="${MESA_WIN64_DIR:-$REPO_ROOT/mesa-install-win64-arm64ec}"

PAYLOAD_DIR="$SCRIPT_DIR/Payload"
WIN_PAYLOAD="$PAYLOAD_DIR/win64-arm64ec"
MAC_PAYLOAD="$PAYLOAD_DIR/macos-arm64"

echo "1. Populating Payload/ from Mesa build outputs..."
mkdir -p "$WIN_PAYLOAD" "$MAC_PAYLOAD"

for dll in opengl32.dll libgallium_wgl.dll libz-1.dll; do
    if [[ ! -f "$MESA_WIN64_DIR/bin/$dll" ]]; then
        echo "ERROR: Missing $MESA_WIN64_DIR/bin/$dll" >&2
        exit 1
    fi
    cp -fL "$MESA_WIN64_DIR/bin/$dll" "$WIN_PAYLOAD/"
done

KK_DYLIB="$MESA_ARM64_DIR/lib/libvulkan_kosmickrisp.dylib"
if [[ ! -f "$KK_DYLIB" ]]; then
    echo "ERROR: Missing $KK_DYLIB" >&2
    exit 1
fi
cp -fL "$KK_DYLIB" "$MAC_PAYLOAD/libvulkan_kosmickrisp.dylib"
chmod 755 "$MAC_PAYLOAD/libvulkan_kosmickrisp.dylib"

# Bundle any Homebrew /usr/local dylib dependencies alongside libvulkan_kosmickrisp.dylib
while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    dep_name="$(basename "$dep")"
    cp -fL "$dep" "$MAC_PAYLOAD/$dep_name"
    chmod 755 "$MAC_PAYLOAD/$dep_name"
    install_name_tool -id "@loader_path/$dep_name" "$MAC_PAYLOAD/$dep_name"
    install_name_tool -change "$dep" "@loader_path/$dep_name" "$MAC_PAYLOAD/libvulkan_kosmickrisp.dylib"
done < <(otool -L "$KK_DYLIB" | awk 'NR>1 && ($1 ~ /^\/opt\/homebrew\// || $1 ~ /^\/usr\/local\//) {print $1}')

install_name_tool -id "@loader_path/libvulkan_kosmickrisp.dylib" "$MAC_PAYLOAD/libvulkan_kosmickrisp.dylib"

echo "2. Building ZinkKrisp release binary (arm64)..."
cd "$SCRIPT_DIR"
SWIFTC_ARGS=()
XCODE_PLUGINS="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
if [[ -d "$XCODE_PLUGINS" ]]; then
    SWIFTC_ARGS=(-Xswiftc -plugin-path -Xswiftc "$XCODE_PLUGINS")
fi
swift build -c release --arch arm64 "${SWIFTC_ARGS[@]}"
BIN_PATH="$(swift build -c release --arch arm64 "${SWIFTC_ARGS[@]}" --show-bin-path)/ZinkKrisp"

echo "3. Assembling ZinkKrisp.app bundle..."
OUT_DIR="$SCRIPT_DIR/dist"
APP_BUNDLE="$OUT_DIR/ZinkKrisp.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/ZinkKrisp"
chmod +x "$APP_BUNDLE/Contents/MacOS/ZinkKrisp"

cp -R "$PAYLOAD_DIR" "$APP_BUNDLE/Contents/Resources/Payload"
cp "$PAYLOAD_DIR/THIRD_PARTY_LICENSES.txt" "$APP_BUNDLE/Contents/Resources/THIRD_PARTY_LICENSES.txt"
if [[ -f "$PAYLOAD_DIR/AppIcon.icns" ]]; then
    cp "$PAYLOAD_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ZinkKrisp</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.zinkkrisp.manager</string>
    <key>CFBundleName</key>
    <string>ZinkKrisp</string>
    <key>CFBundleDisplayName</key>
    <string>ZinkKrisp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>0.2.1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSMultipleInstancesProhibited</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Windows Executable</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>exe</string>
                <string>msi</string>
                <string>zip</string>
                <string>bat</string>
                <string>cmd</string>
                <string>reg</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
EOF

echo "4. Ad-hoc codesigning ZinkKrisp.app..."
for dylib in "$APP_BUNDLE/Contents/Resources/Payload/macos-arm64"/*.dylib; do
    codesign --force --sign - "$dylib"
done
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_BUNDLE" >/dev/null 2>&1 || true
codesign -dv "$APP_BUNDLE" 2>&1

echo "Done: $APP_BUNDLE"
