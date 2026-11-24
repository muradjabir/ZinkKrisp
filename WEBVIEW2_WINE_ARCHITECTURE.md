# Running Microsoft Edge WebView2 on Wine / macOS (ZinkKrisp)

## 1. The Core Problem

Modern Windows installers and desktop applications embed **Microsoft Edge WebView2 (`msedgewebview2.exe`)** inside native Win32/MFC windows. Under Wine (`winemac.drv`) on Apple Silicon macOS, WebView2 presents four distinct classes of failures:

1. **Blank / Uncomposited Viewport**: Chromium's DirectComposition / `Intermediate D3D Window` / cross-process swapchain surfaces do not composite into Wine's `winemac.drv` Cocoa window backing store, leaving the embedded `Chrome_WidgetWin_0` area blank white even though the renderer is running.
2. **Legacy IE `window.event.srcElement` Script Failures**: Applications migrated from `mshtml.dll` / `CHtmlView` to WebView2 frequently rely on the non-standard global `window.event.srcElement` inside inline handlers, which fails when events are dispatched synthetically without populating `window.event.srcElement`.
3. **Multi-Window & Modal Dialog Z-Order / Geometry Clamping**: WebView2 apps spawn secondary modal popup dialogs (`Chrome_WidgetWin_0` inside `#32770`) as well as native Win32 `#32770` modal dialogs. A naive topmost overlay either stretches across the wrong window or covers native Win32 dialogs, making the app appear frozen.
4. **Win32 `send_inter_thread_message` Deadlocks**: Synchronous cross-thread `SendMessageW`/`SendMessageA` and `HWND_BROADCAST` calls in Wine use `TIMEOUT_INFINITE`. Any helper process that doesn't pump its message queue, or any AB-BA wait between a worker thread and UI thread, freezes the application indefinitely.

---

## 2. End-to-End Architecture

All fixes are **100% generic and application-agnostic** across three layers:

```text
+-------------------------------------------------------------------+
|  macOS Cocoa Window (Wine winemac.drv)                            |
|  - Hosts native Win32 frame + ZK_WebView2_SHM_Overlay (WS_POPUP)  |
+-------------------------------------------------------------------+
         ^                                         |
         | 16MB Shared Memory (/tmp/zk_webview_fb.bin)
         | (BGRA pixels + seq + dimensions)        | UDP 127.0.0.1:9223
         |                                         | (mouse/key/geometry)
+--------+-----------------------------------------+----------------+
|  zk_webview_bridge.py (CDP Client)               v                |
|  - Connects to WebView2 --remote-debugging-port=9222              |
|  - Page.startScreencast -> BGRA SHM frames                        |
|  - Page.addScriptToEvaluateOnNewDocument (IE event polyfill)      |
|  - Input.dispatchMouseEvent / dispatchKeyEvent / insertText       |
|  - Matches CDP page targets to active HWND by (innerWidth/Height) |
+-------------------------------------------------------------------+
         ^
         | Chrome DevTools Protocol (ws://127.0.0.1:9222)
         v
+-------------------------------------------------------------------+
|  msedgewebview2.exe + Target Win32 App                            |
|  - Wrapped by version64.dll / version32.dll (zk_webview_bridge.c) |
|  - DeadlockGuard: SendMessageW/A -> SendMessageTimeoutW/A (2000ms)|
+-------------------------------------------------------------------+
```

---

## 3. How Each Problem Was Solved

### 3.1 Live Framebuffer & Input Pipeline (`zk_webview_bridge.py` + `zk_webview_overlay.cpp`)
- **Launch Flags**: WebView2 is launched with `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS` enabling `--remote-debugging-port=9222 --no-sandbox --in-process-gpu --disable-direct-composition --disable-features=RemoveRedirectionBitmap,DirectComposition,CalculateNativeWinOcclusion --edge-webview-disable-mojo-ipcz`.
- **CDP Screencast to Shared Memory**: [zk_webview_bridge.py](src/webview_bridge/zk_webview_bridge.py) attaches to the active CDP `page` target, starts `Page.startScreencast`, decodes frames via native macOS ImageIO/CoreGraphics to 32-bit BGRA, and writes them into `/tmp/zk_webview_fb.bin` (`ZKSharedFrameBuffer` with `magic = 0x5A4B4642` and atomic `seq`).
- **Win32 Overlay Rendering & Input Forwarding**: [zk_webview_overlay.cpp](src/webview_bridge/zk_webview_overlay.cpp) creates a `WS_POPUP` window (`ZK_WebView2_SHM_Overlay`) positioned over the active `Chrome_WidgetWin_0`, blits frames via `StretchDIBits` on `seq` changes, and forwards `WM_MOUSEMOVE`, `WM_LBUTTONDOWN`, `WM_LBUTTONUP`, `WM_MOUSEWHEEL`, `WM_KEYDOWN`, `WM_KEYUP`, and `WM_CHAR` over UDP (`127.0.0.1:9223`).
- **Standard Native CDP Dispatch**: Mouse events are dispatched using the standard 3-step CDP sequence (`mouseMoved` → `mousePressed` → `mouseReleased`) via `Input.dispatchMouseEvent` rather than duplicating synthetic DOM `el.click()` calls.

---

### 3.2 Generic Legacy IE `window.event.srcElement` Polyfill
- Whenever the CDP daemon attaches to **any** `page` target (and on `Page.frameNavigated`), it calls `Page.enable`, `Page.addScriptToEvaluateOnNewDocument`, and `Runtime.evaluate` with `IE_EVENT_POLYFILL_JS`.
- The polyfill captures DOM events in the capture phase, wraps `EventTarget.prototype.dispatchEvent`, and exposes `window.event` with `srcElement` mapped to `e.target`.

---

### 3.3 Generic Multi-Window, Modal Dialog & Native `#32770` Handling
To handle both secondary WebView2 popup dialogs and native Win32 modal dialogs without hardcoding URLs or window titles:

1. **Generic `Chrome_WidgetWin_0` Enumeration & Clamping**:
   - `zk_webview_overlay.cpp` enumerates all visible `Chrome_WidgetWin_0` HWNDs via `EnumWindows` / `EnumChildWindows`, prioritizing foreground `#32770` modal dialogs, then any modal dialog, then the active foreground window.
   - It synchronizes DPI context per window using `GetWindowDpiAwarenessContext` / `SetThreadDpiAwarenessContext`, converts client rects via `ClientToScreen`, and clamps to all ancestor client rects via `IntersectRect`.
2. **Dynamic CDP Target Matching**:
   - `zk_webview_overlay.exe` sends active `(w, h, isDialog)` geometry over UDP to `zk_webview_bridge.py`, which probes `page` targets for `{innerW: window.innerWidth, innerH: window.innerHeight, focus: document.hasFocus()}` and attaches to the best-matching target.
3. **Native Win32 `#32770` Dialog Visibility**:
   - In `EvaluateChromeWidget()` and `FindBestChromeWidget()`, the overlay checks `!IsWindowEnabled(hRoot)` and `FindVisibleNativeDialog(pid)` (any visible `#32770` without a `Chrome_WidgetWin_0` child).
   - Whenever a native Win32 dialog opens, the topmost WebView2 overlay automatically hides (`SW_HIDE`) and brings the native dialog to the front.

---

### 3.4 Preventing Win32 `send_inter_thread_message` Deadlocks (`DeadlockGuard`)
1. **Non-Blocking Message Queue Pumping in Helper Binaries**:
   - In `zk_webview_overlay.cpp`, message waits pump the queue via `MsgWaitForMultipleObjects(0, NULL, FALSE, ms, QS_ALLINPUT)` + `PeekMessageW` so the overlay never stalls `HWND_BROADCAST` or cross-process messages.
2. **Generic `SendMessageTimeout` IAT & Delay-Import Hook**:
   - In [zk_webview_bridge.c](src/webview_bridge/zk_webview_bridge.c), `Hooked_SendMessageW` and `Hooked_SendMessageA` are patched into loaded modules' IAT and delay-import tables for both 64-bit (`version64.dll`) and 32-bit (`version32.dll`) processes via [build.sh](src/webview_bridge/build.sh).
   - Same-thread `SendMessageW`/`A` calls pass directly through at full speed; cross-thread and `HWND_BROADCAST` calls are bounded with `SendMessageTimeoutW`/`A(..., SMTO_ABORTIFHUNG | SMTO_NORMAL, 2000, ...)`.

---

## 4. Packaging into ZinkKrisp

- [EngineManager.swift](app/ZinkKrisp/Sources/ZinkKrispCore/Services/EngineManager.swift) and [MacAppGenerator.swift](app/ZinkKrisp/Sources/ZinkKrispCore/Services/MacAppGenerator.swift) manage the WebView2 bridge helpers built from `src/webview_bridge/`.
- [build_app_bundle.sh](app/ZinkKrisp/build_app_bundle.sh) builds and ad-hoc codesigns `dist/ZinkKrisp.app`.
