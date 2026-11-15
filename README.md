# ZinkKrisp

**Native ARM64EC Mesa Zink + ARM64 KosmicKrisp runtime for running `x86_64` Windows OpenGL 4.6 (WGL) workstation & CAD apps on Apple Silicon (Metal 4) without Rosetta 2 or a VM.**

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

## Quick Start (Drop-In Runtime Tarball)

### Prerequisites
- Apple Silicon Mac (M1–M4) running macOS with Metal support
- [MetalSharp-Wine](https://github.com/MetalSharp/MetalSharp-Wine) (signed `.app` bundle with FEX ARM64EC support; tested with MetalSharp-Wine 6.5 / Wine 11.20)

### 1. Download & Extract Release
Download `zink-kk-macos-arm64ec-v0.1.0.tar.gz` from [Releases](../../releases) and extract it:

```bash
tar -xzf zink-kk-macos-arm64ec-v0.1.0.tar.gz
cd zink-kk-macos-arm64ec-v0.1.0
```

### 2. Install into Your Wine Prefix
```bash
# CAD / workstation apps (SOLIDWORKS, Rhino, FreeCAD, CloudCompare)
./gl46-mac install --prefix ~/.wine-cad --profile cad-workstation

# Optional: import SOLIDWORKS 2024 AllowList + Retina/Performance Pipeline keys
./gl46-mac install --prefix ~/.wine-cad --profile cad-workstation --reg profiles/solidworks.reg

# OpenGL 4.6 games & benchmarks (Unigine, FurMark, idTech, Minecraft)
./gl46-mac install --prefix ~/.wine-games --profile opengl-game
```

### 3. Generate a Double-Clickable `.app` in `/Applications`
```bash
./gl46-mac wrap \
  --prefix ~/.wine-cad \
  --exe "C:\Program Files\SOLIDWORKS\SLDWORKS.exe" \
  --name "SOLIDWORKS 2024" \
  --profile cad-workstation
```

Now launch **SOLIDWORKS 2024** directly from Spotlight, Launchpad, or `/Applications`!

To toggle Apple's native Metal HUD when launching:
```bash
open --env ZINKKRISP_HUD=1 -a "/Applications/SOLIDWORKS 2024.app"
```

---

## Runtime Environment Toggles & Profiles

The prebuilt binaries expose runtime environment variables so one build works for both CAD viewports and OpenGL games:

| Variable | Default | Purpose |
| --- | --- | --- |
| `KK_SPOOF_SMOOTH_LINES` | `1` | Reports `VkPhysicalDeviceVulkan14Features::smoothLines = true` to avoid expensive libpoly line Geometry Shaders in CAD edge/sketch rendering (`1` for `cad-workstation`, `0` for `opengl-game`). |
| `KK_CLAMP_VIEW_MISMATCH` | `1` | Clamps mismatched VkImage/VkImageView texel block sizes in `kk_image_view_init` to prevent `_mtlValidateArgumentsForTextureViewOnDevice` aborts. |
| `ZINKKRISP_HUD` / `SWONMAC_HUD` | `0` | Set to `1` in `gl46-mac wrap` launchers to enable `MTL_HUD_ENABLED=1` (native Metal FPS, frame time, resolution, GPU ms). |
| `FEX_TSOENABLED` | `0` | Disables strict x86 TSO memory ordering barriers on M-series cores for dramatically higher CPU/draw throughput under FEX ARM64EC. |
| `mesa_glthread` | `true` | Enables Mesa GL command threading inside Zink (`false` to benchmark direct ARM64EC dispatch). |

---

## Included Patches

- [`patches/mesa_kosmickrisp_zink.patch`](patches/mesa_kosmickrisp_zink.patch):
  - `src/util/detect_arch.h`: Treat `__arm64ec__` / `_M_ARM64EC` as `DETECT_ARCH_AARCH64` (upstreamable patch also split in `patches/upstream/`).
  - `src/kosmickrisp/vulkan/kk_physical_device.c`: Enable `EXT_custom_border_color`, `EXT_border_color_swizzle`, runtime-toggled `smoothLines`, host-side `disk_cache_create("kosmickrisp", ...)`, and sysmem `DEVICE_LOCAL` memory type.
  - `src/kosmickrisp/vulkan/kk_image_view.c`: Runtime-toggled texel-blocksize mismatch guard (`KK_CLAMP_VIEW_MISMATCH`).
  - `src/kosmickrisp/vulkan/kk_image.c`: Preserve all memory types on Apple Silicon unified memory for `HOST_TRANSFER`.
  - `src/gallium/drivers/zink/zink_screen.c` & `zink_kopper.c`: Guard `< 32`-bit display targets and sync `B8G8R8A8_UNORM` swapchain fallback format cleanly.

---

## Building from Source

See [`.github/workflows/build.yml`](.github/workflows/build.yml) for the complete automated build steps on `macos-15` (`arm64`) using `llvm-mingw` (`-ffixed-x28`) and Meson, followed by `./scripts/package-release.sh`.
