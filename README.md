# ZinkKrisp

[![Technical Deep-Dive](https://img.shields.io/badge/Blog-Architecture_%26_Technical_Deep--Dive-0A66C2?style=for-the-badge)](https://muradjabir.com/blog/post-rosetta-opengl-apple-silicon)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg?style=for-the-badge)](https://www.gnu.org/licenses/agpl-3.0)
[![Platform: macOS arm64](https://img.shields.io/badge/macOS-Apple_Silicon_(arm64)-black?style=for-the-badge&logo=apple)](https://muradjabir.com/blog/post-rosetta-opengl-apple-silicon)

> **Read the Full Engineering Write-Up:**  
> **[Post-Rosetta OpenGL 4.6 on Apple Silicon: Bridging x86_64 Windows Applications to Native ARM64 Metal via FEX, ARM64EC Zink, and KosmicKrisp](https://muradjabir.com/blog/post-rosetta-opengl-apple-silicon)**  
> *Covers the single-process `ARM64EC` architecture, `-ffixed-x28` Darwin TEB handling, WGL Kopper 16-bit swapchain fallbacks, Metal texture-view validation, and CAD wireframe optimizations.*

**Native ARM64EC Mesa Zink + ARM64 KosmicKrisp runtime and macOS manager app for running `x86_64` Windows OpenGL 4.6 (WGL) workstation & CAD apps on Apple Silicon (Metal 4) without Rosetta 2 or a VM.**

---

## Architecture

```text
Windows x86_64 App (.exe)
   └─ FEX ARM64EC JIT (libarm64ecfex.dll via MetalSharp-Wine 6.5+)
         └─ Native COFF-ARM64EC opengl32.dll + libgallium_wgl.dll (Mesa 27.0 Zink)
               └─ Wine winevulkan thunk (guest ARM64EC → host arm64)
                     └─ Native macOS arm64 libvulkan_kosmickrisp.dylib (Mesa KosmicKrisp)
                           └─ Apple Metal 4 (CAMetalLayer + MTLDevice)
```

Everything heavy executes natively on Apple Silicon (`arm64` / `ARM64EC`):
- **Single-process Vulkan/Metal:** No `virgl_test_server` IPC, no VM, no Rosetta 2 on the 3D pipeline.
- **ARM64EC ABI compatible (`-ffixed-x28`):** Built with `llvm-mingw` reserving `x28` for Wine's macOS arm64 TEB/TLS register.
- **OpenGL 4.6 Compatibility & Core Profiles:** Bypasses macOS's deprecated OpenGL 4.1 cap cleanly inside Windows WGL.
- **Persistent Host Shader Cache:** Wired into `kk_physical_device.c` (`~/.cache/mesa_shader_cache_db`), eliminating second-launch stutter even while Mesa's Win32 `disk_cache_os.c` is unimplemented.

---

## What's New in v0.2.0

### 1. ZinkKrisp macOS App ([`app/ZinkKrisp`](app/ZinkKrisp))
A native SwiftUI macOS manager app featuring:
- **Container → Application Hierarchy**: Isolated APFS Copy-on-Write containers, per-container offline sandboxing, and automatic `.app` bundle wrappers in `~/Applications/`.
- **APFS Instant Restore Points**: Sub-second container snapshots before/after installing software or prerequisites.
- **Background Startup Processes**: Automatic per-container service management (such as local license daemons) with PID/TCP reuse.
- **Legal On-Demand Prerequisites**: `PrerequisiteManager` downloads third-party Windows runtimes (`.NET Framework 4.8`, Visual C++ 2015–2022, Edge WebView2) directly from official vendor URLs when required — nothing proprietary is bundled.
- **Data-Driven Software Profiles**: Generic `SoftwareProfile` definitions (DLL overrides, env vars, prerequisites, startup services, and GPU `AllowList` registry entries) without hardcoding software-specific logic into the engine.

### 2. WebView2 & .NET 4.8 Compatibility Bridges ([`src/webview_bridge`](src/webview_bridge))
- **WebView2 Offscreen Overlay & Input Bridge** ([architecture notes](WEBVIEW2_WINE_ARCHITECTURE.md)): CDP screencast framebuffer shared-memory overlay (`zk_webview_bridge.py` + `zk_webview_overlay.cpp`) with legacy IE `window.event.srcElement` polyfill and modal `#32770` dialog Z-order handling.
- **DeadlockGuard & Version Proxy** (`zk_webview_bridge.c` + `version_proxy.c`): Cross-thread `SendMessageTimeout` protection and WinINet/Winsock host filtering (`ZK_BLOCK_HOSTS`).
- **Version-Independent `.NET 4.8` Forwarding Shim** (`mscoree_shim.c` + `mscoree_shim.def`): Dynamic `GetProcAddress` resolution and exact Windows ordinals (`@17..@142`) forwarding to native `mscoreei.dll`.
- Build all helper Windows binaries from source with `./src/webview_bridge/build.sh` (requires `mingw-w64`).

### 3. Software Compatibility List & GitHub Issue Forms
- [`compatibility.csv`](compatibility.csv): Machine-readable compatibility table with canonical kebab-case Software IDs (matching `SoftwareProfile.id`).
- [`COMPATIBILITY.md`](COMPATIBILITY.md): Status definitions, CSV column guide, and instructions for referencing Software IDs in bug reports.
- [`.github/ISSUE_TEMPLATE/`](.github/ISSUE_TEMPLATE): Structured GitHub Issue Forms for reporting compatibility bugs (`software_issue.yml`) and submitting new entries (`compatibility_report.yml`).

---

## Quick Start (Drop-In Runtime Tarball)

### Prerequisites
- Apple Silicon Mac (M1–M4) running macOS with Metal support
- [MetalSharp-Wine](https://github.com/MetalSharp/MetalSharp-Wine) (external signed `.app` bundle with FEX ARM64EC support; tested with MetalSharp-Wine 6.5 / Wine 11.20)

### 1. Download & Extract Release
Download `zink-kk-macos-arm64ec-v0.1.0.tar.gz` from [Releases](../../releases) and extract it:

```bash
tar -xzf zink-kk-macos-arm64ec-v0.1.0.tar.gz
cd zink-kk-macos-arm64ec-v0.1.0
```

### 2. Install into Your Wine Prefix
```bash
# CAD / workstation apps
./gl46-mac install --prefix ~/.wine-cad --profile cad-workstation

# OpenGL 4.6 games & benchmarks
./gl46-mac install --prefix ~/.wine-games --profile opengl-game
```

### 3. Generate a Double-Clickable `.app` Wrapper
```bash
./gl46-mac wrap \
  --prefix ~/.wine-cad \
  --exe "C:\Path\To\YourApp.exe" \
  --name "My CAD App" \
  --profile cad-workstation
```

To toggle Apple's native Metal HUD when launching:
```bash
open --env ZINKKRISP_HUD=1 -a "/Applications/My CAD App.app"
```

---

## Runtime Environment Toggles & Profiles

| Variable | Default | Purpose |
| --- | --- | --- |
| `KK_SPOOF_SMOOTH_LINES` | `1` | Reports `VkPhysicalDeviceVulkan14Features::smoothLines = true` to avoid expensive line geometry shaders in CAD viewports. |
| `KK_CLAMP_VIEW_MISMATCH` | `1` | Clamps mismatched VkImage/VkImageView texel block sizes in `kk_image_view_init` to prevent `_mtlValidateArgumentsForTextureViewOnDevice` aborts. |
| `ZINKKRISP_HUD` / `SWONMAC_HUD` | `0` | Set to `1` in launchers to enable `MTL_HUD_ENABLED=1` (native Metal FPS, frame time, resolution, GPU ms). |
| `FEX_TSOENABLED` | `0` | Disables strict x86 TSO memory ordering barriers on M-series cores for higher throughput under FEX ARM64EC. |
| `mesa_glthread` | `true` | Enables Mesa GL command threading inside Zink. |

---

## Included Patches

- [`patches/mesa_kosmickrisp_zink.patch`](patches/mesa_kosmickrisp_zink.patch):
  - `src/util/detect_arch.h`: Treat `__arm64ec__` / `_M_ARM64EC` as `DETECT_ARCH_AARCH64`.
  - `src/kosmickrisp/vulkan/kk_physical_device.c`: Enable `EXT_custom_border_color`, `EXT_border_color_swizzle`, runtime-toggled `smoothLines`, host-side `disk_cache_create("kosmickrisp", ...)`, and sysmem `DEVICE_LOCAL` memory type.
  - `src/kosmickrisp/vulkan/kk_image_view.c`: Runtime-toggled texel-blocksize mismatch guard (`KK_CLAMP_VIEW_MISMATCH`).
  - `src/kosmickrisp/vulkan/kk_image.c`: Preserve all memory types on Apple Silicon unified memory for `HOST_TRANSFER`.
  - `src/gallium/drivers/zink/zink_screen.c` & `zink_kopper.c`: Guard `< 32`-bit display targets and sync `B8G8R8A8_UNORM` swapchain fallback format.

---

## Building from Source

- **Mesa + KosmicKrisp + Zink**: See [`.github/workflows/build.yml`](.github/workflows/build.yml) and `./scripts/package-release.sh`.
- **WebView2 & .NET Bridges**: Run `./src/webview_bridge/build.sh` (requires `x86_64-w64-mingw32` and `i686-w64-mingw32` from `mingw-w64`).
- **ZinkKrisp macOS App**: Run `./app/ZinkKrisp/build_app_bundle.sh` on Apple Silicon macOS 14+ with Xcode / Swift toolchain.

---

## License

* **ZinkKrisp Application, Scripts, & Build Tooling:** Licensed under the **GNU Affero General Public License v3.0 (`AGPL-3.0-only`)**. Any fork, derivative work, or application incorporating this code must be distributed in full source form under the same `AGPL-3.0` license. See [LICENSE](LICENSE).
* **Mesa 3D Patches & Pre-built Driver Binaries (`opengl32.dll`, `libgallium_wgl.dll`, `libvulkan_kosmickrisp.dylib`):** Derived from [Mesa 3D](https://www.mesa3d.org/) and licensed under the **MIT License**. See [app/ZinkKrisp/Payload/THIRD_PARTY_LICENSES.txt](app/ZinkKrisp/Payload/THIRD_PARTY_LICENSES.txt) for full copyright notices and third-party license texts.

Copyright © 2026 Murad Jabir. All rights reserved.

---

## Trademark & Licensing Disclaimer

ZinkKrisp is an independent open-source project and is not affiliated with, sponsored by, or endorsed by Dassault Systèmes, Microsoft Corporation, Apple Inc., or any listed software vendor. All trademarks and product names belong to their respective owners. Users are responsible for supplying their own valid software licenses and official installers.
