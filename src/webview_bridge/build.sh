#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$DIR/../.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/app/ZinkKrisp/Payload/webview_bridge}"

mkdir -p "$OUT_DIR"

TMP_RES="$(mktemp -t mscoree_shim).res"
trap 'rm -f "$TMP_RES"' EXIT

echo "1. Compiling mscoree_shim64.dll..."
x86_64-w64-mingw32-windres "$DIR/mscoree_shim.rc" -O coff -o "$TMP_RES"
x86_64-w64-mingw32-gcc -shared -O2 \
    "$DIR/mscoree_shim.c" "$DIR/mscoree_shim.def" "$TMP_RES" \
    -o "$OUT_DIR/mscoree_shim64.dll"

echo "2. Compiling version64.dll & version32.dll..."
x86_64-w64-mingw32-gcc -shared -O2 -DZK_VERSION_PROXY \
    "$DIR/version_proxy.c" "$DIR/zk_webview_bridge.c" "$DIR/version.def" \
    -o "$OUT_DIR/version64.dll" -lpsapi -lgdi32 -luser32 -lws2_32 -ladvapi32

i686-w64-mingw32-gcc -shared -O2 -DZK_VERSION_PROXY -Wl,--kill-at -Wl,--enable-stdcall-fixup \
    "$DIR/version_proxy.c" "$DIR/zk_webview_bridge.c" "$DIR/version.def" \
    -o "$OUT_DIR/version32.dll" -lpsapi -lgdi32 -luser32 -lws2_32 -ladvapi32

echo "3. Compiling zk_bridge.dll (64-bit) & zk_bridge32.dll (32-bit)..."
x86_64-w64-mingw32-gcc -shared -O2 "$DIR/zk_webview_bridge.c" \
    -o "$OUT_DIR/zk_bridge.dll" -lpsapi -lgdi32 -luser32 -lws2_32 -ladvapi32

i686-w64-mingw32-gcc -shared -O2 "$DIR/zk_webview_bridge.c" \
    -o "$OUT_DIR/zk_bridge32.dll" -lpsapi -lgdi32 -luser32 -lws2_32 -ladvapi32

echo "4. Compiling zk_webview_overlay.exe & zk_inject32.exe..."
x86_64-w64-mingw32-g++ -O2 -mwindows -static \
    "$DIR/zk_webview_overlay.cpp" \
    -o "$OUT_DIR/zk_webview_overlay.exe" -lws2_32 -lgdi32 -luser32

i686-w64-mingw32-gcc -O2 -mwindows \
    "$DIR/zk_inject32.c" \
    -o "$OUT_DIR/zk_inject32.exe"

echo "5. Syncing zk_webview_bridge.py..."
cp -f "$DIR/zk_webview_bridge.py" "$OUT_DIR/zk_webview_bridge.py"

echo "Done: WebView2 & .NET bridges built into $OUT_DIR"
