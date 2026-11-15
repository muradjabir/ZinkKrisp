#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARENT_ROOT="$(cd "$ROOT_DIR/.." && pwd)"

VERSION="${VERSION:-v0.1.0}"
MESA_ARM64_DIR="${MESA_ARM64_DIR:-$PARENT_ROOT/mesa-install-arm64}"
MESA_WIN64_DIR="${MESA_WIN64_DIR:-$PARENT_ROOT/mesa-install-win64-arm64ec}"

PKG_NAME="zink-kk-macos-arm64ec-${VERSION}"
STAGE_DIR="$ROOT_DIR/dist/$PKG_NAME"
OUT_TARBALL="$ROOT_DIR/dist/${PKG_NAME}.tar.gz"

echo "Staging release package: $PKG_NAME"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/bin-win64-arm64ec" "$STAGE_DIR/lib-macos-arm64" "$STAGE_DIR/profiles" "$STAGE_DIR/patches"

for dll in opengl32.dll libgallium_wgl.dll libz-1.dll; do
    if [[ ! -f "$MESA_WIN64_DIR/bin/$dll" ]]; then
        echo "ERROR: Missing $MESA_WIN64_DIR/bin/$dll" >&2
        exit 1
    fi
    cp -L "$MESA_WIN64_DIR/bin/$dll" "$STAGE_DIR/bin-win64-arm64ec/"
done

KK_DYLIB="$MESA_ARM64_DIR/lib/libvulkan_kosmickrisp.dylib"
if [[ ! -f "$KK_DYLIB" ]]; then
    echo "ERROR: Missing $KK_DYLIB" >&2
    exit 1
fi
cp -L "$KK_DYLIB" "$STAGE_DIR/lib-macos-arm64/libvulkan_kosmickrisp.dylib"
chmod 755 "$STAGE_DIR/lib-macos-arm64/libvulkan_kosmickrisp.dylib"

# Bundle any non-system (/opt/homebrew or /usr/local) dylib dependencies next to libvulkan_kosmickrisp.dylib
while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    dep_name="$(basename "$dep")"
    if [[ ! -f "$STAGE_DIR/lib-macos-arm64/$dep_name" ]]; then
        cp -L "$dep" "$STAGE_DIR/lib-macos-arm64/$dep_name"
        chmod 755 "$STAGE_DIR/lib-macos-arm64/$dep_name"
        install_name_tool -id "@loader_path/$dep_name" "$STAGE_DIR/lib-macos-arm64/$dep_name"
    fi
    install_name_tool -change "$dep" "@loader_path/$dep_name" "$STAGE_DIR/lib-macos-arm64/libvulkan_kosmickrisp.dylib"
done < <(otool -L "$KK_DYLIB" | awk 'NR>1 && ($1 ~ /^\/opt\/homebrew\// || $1 ~ /^\/usr\/local\//) {print $1}')

install_name_tool -id "@loader_path/libvulkan_kosmickrisp.dylib" "$STAGE_DIR/lib-macos-arm64/libvulkan_kosmickrisp.dylib"

for dylib in "$STAGE_DIR/lib-macos-arm64"/*.dylib; do
    codesign --force --sign - "$dylib"
done

cat > "$STAGE_DIR/lib-macos-arm64/kosmickrisp_mesa_icd.aarch64.json" << 'EOF'
{
    "ICD": {
        "api_version": "1.4.368",
        "library_path": "./libvulkan_kosmickrisp.dylib"
    },
    "file_format_version": "1.0.1"
}
EOF

cp -R "$ROOT_DIR/profiles/." "$STAGE_DIR/profiles/"
cp -R "$ROOT_DIR/patches/." "$STAGE_DIR/patches/"
cp "$ROOT_DIR/gl46-mac" "$STAGE_DIR/gl46-mac"
chmod +x "$STAGE_DIR/gl46-mac"
cp "$ROOT_DIR/README.md" "$STAGE_DIR/README.md"
cp "$ROOT_DIR/LICENSE" "$STAGE_DIR/LICENSE"

echo "Verifying staged dylib linkages:"
otool -L "$STAGE_DIR/lib-macos-arm64/libvulkan_kosmickrisp.dylib"

tar -C "$ROOT_DIR/dist" -czf "$OUT_TARBALL" "$PKG_NAME"
echo "Created archive: $OUT_TARBALL ($(du -h "$OUT_TARBALL" | awk '{print $1}'))"
