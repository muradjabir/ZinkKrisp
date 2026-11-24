#define WIN32_LEAN_AND_MEAN

#include <stdint.h>
#include <stdio.h>
#include <windows.h>
#include <shellapi.h>
#include <windowsx.h>
#include <winsock2.h>
#include <ws2tcpip.h>

#pragma comment(lib, "ws2_32.lib")

#pragma pack(push, 4)
typedef struct {
  uint32_t magic;       // 0x5A4B4642 ('ZKFB')
  volatile int32_t seq; // Incremented atomically after each frame write
  int32_t is_dialog;    // 1 if modal/dialog, 0 if main
  int32_t img_w;        // Decoded frame width
  int32_t img_h;        // Decoded frame height
  uint32_t pixels[1];   // Raw 32-bit BGRA top-down pixels
} ZKSharedFrameBuffer;
#pragma pack(pop)

typedef HANDLE(WINAPI *PFN_GetWindowDpiAwarenessContext)(HWND);
typedef HANDLE(WINAPI *PFN_SetThreadDpiAwarenessContext)(HANDLE);

static PFN_GetWindowDpiAwarenessContext pGetWindowDpiAwarenessContext = NULL;
static PFN_SetThreadDpiAwarenessContext pSetThreadDpiAwarenessContext = NULL;

static HWND g_hOverlay = NULL;
static SOCKET g_udpSock = INVALID_SOCKET;
static sockaddr_in g_udpAddr;
static ZKSharedFrameBuffer *g_shm = NULL;
static int32_t g_lastSeq = -1;
static DWORD g_targetPid = 0;

static void SendUDP(const char *jsonStr) {
  if (g_udpSock != INVALID_SOCKET) {
    sendto(g_udpSock, jsonStr, (int)strlen(jsonStr), 0, (sockaddr *)&g_udpAddr,
           sizeof(g_udpAddr));
  }
}

static BOOL PumpMessagesAndWait(DWORD ms) {
  MSG msg;
  while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
    if (msg.message == WM_QUIT)
      return FALSE;
    TranslateMessage(&msg);
    DispatchMessageW(&msg);
  }
  MsgWaitForMultipleObjects(0, NULL, FALSE, ms, QS_ALLINPUT);
  while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
    if (msg.message == WM_QUIT)
      return FALSE;
    TranslateMessage(&msg);
    DispatchMessageW(&msg);
  }
  return TRUE;
}

static BOOL GetClientRectScreen(HWND hwnd, RECT *outRc) {
  if (!hwnd || !IsWindow(hwnd))
    return FALSE;
  RECT rc;
  BOOL ok = GetClientRect(hwnd, &rc);
  if (ok) {
    POINT tl = {rc.left, rc.top};
    POINT br = {rc.right, rc.bottom};
    ClientToScreen(hwnd, &tl);
    ClientToScreen(hwnd, &br);
    outRc->left = tl.x;
    outRc->top = tl.y;
    outRc->right = br.x;
    outRc->bottom = br.y;
  }
  return ok;
}

static BOOL GetClampedWidgetRect(HWND hEdge, RECT *outRc) {
  if (!GetClientRectScreen(hEdge, outRc))
    return FALSE;
  HWND anc = GetParent(hEdge);
  while (anc) {
    RECT ancRc;
    if (GetClientRectScreen(anc, &ancRc)) {
      if (!IntersectRect(outRc, outRc, &ancRc)) {
        return FALSE;
      }
    }
    anc = GetParent(anc);
  }
  return (outRc->right - outRc->left > 10) && (outRc->bottom - outRc->top > 10);
}

typedef struct {
  HWND hwnd;
  HWND root;
  RECT rect;
  int isDialog;
  int isForeground;
  int score;
  DWORD pid;
} ChromeCandidate;

typedef struct {
  ChromeCandidate best;
  BOOL found;
  HWND fg;
} EnumCtx;

static BOOL IsModalOrDialogRoot(HWND hRoot) {
  if (!hRoot)
    return FALSE;
  WCHAR cls[64] = {0};
  GetClassNameW(hRoot, cls, 64);
  if (wcscmp(cls, L"#32770") == 0)
    return TRUE;
  LONG exStyle = GetWindowLongW(hRoot, GWL_EXSTYLE);
  if (exStyle & WS_EX_DLGMODALFRAME)
    return TRUE;
  if (GetWindow(hRoot, GW_OWNER) != NULL)
    return TRUE;
  return FALSE;
}

static void EvaluateChromeWidget(HWND hwnd, EnumCtx *ctx) {
  if (!hwnd || hwnd == g_hOverlay || !IsWindowVisible(hwnd))
    return;

  WCHAR cls[64] = {0};
  GetClassNameW(hwnd, cls, 64);
  if (wcscmp(cls, L"Chrome_WidgetWin_0") != 0)
    return;

  HWND hRoot = GetAncestor(hwnd, GA_ROOT);
  if (!hRoot || !IsWindowVisible(hRoot) || IsIconic(hRoot) ||
      !IsWindowEnabled(hRoot))
    return;

  RECT rc;
  if (!GetClampedWidgetRect(hwnd, &rc))
    return;

  int w = rc.right - rc.left;
  int h = rc.bottom - rc.top;
  if (w <= 20 || h <= 20)
    return;

  int isDlg = IsModalOrDialogRoot(hRoot) ? 1 : 0;
  int isFg = (ctx->fg && (ctx->fg == hRoot || IsChild(ctx->fg, hwnd))) ? 1 : 0;

  // Score prioritizes: foreground modal dialog > modal dialog > foreground
  // window > largest area
  int areaScore = (w * h) / 1000;
  if (areaScore > 5000)
    areaScore = 5000;
  int score = (isDlg ? 100000 : 0) + (isFg ? 50000 : 0) + areaScore;

  if (!ctx->found || score > ctx->best.score) {
    ctx->found = TRUE;
    ctx->best.hwnd = hwnd;
    ctx->best.root = hRoot;
    ctx->best.rect = rc;
    ctx->best.isDialog = isDlg;
    ctx->best.isForeground = isFg;
    ctx->best.score = score;
    GetWindowThreadProcessId(hRoot, &ctx->best.pid);
  }
}

static BOOL CALLBACK EnumChildProc(HWND hwnd, LPARAM lParam) {
  EvaluateChromeWidget(hwnd, (EnumCtx *)lParam);
  return TRUE;
}

static BOOL CALLBACK EnumTopProc(HWND hwnd, LPARAM lParam) {
  EvaluateChromeWidget(hwnd, (EnumCtx *)lParam);
  EnumChildWindows(hwnd, EnumChildProc, lParam);
  return TRUE;
}

static BOOL CALLBACK CheckHasChromeChildProc(HWND hwnd, LPARAM lParam) {
  WCHAR cls[64] = {0};
  GetClassNameW(hwnd, cls, 64);
  if (wcscmp(cls, L"Chrome_WidgetWin_0") == 0) {
    *(BOOL *)lParam = TRUE;
    return FALSE;
  }
  return TRUE;
}

typedef struct {
  DWORD pid;
  HWND foundDlg;
} NativeDlgCtx;

static BOOL CALLBACK FindVisibleNativeDlgProc(HWND hwnd, LPARAM lParam) {
  NativeDlgCtx *ctx = (NativeDlgCtx *)lParam;
  if (!IsWindowVisible(hwnd) || IsIconic(hwnd) || hwnd == g_hOverlay)
    return TRUE;
  WCHAR cls[64] = {0};
  GetClassNameW(hwnd, cls, 64);
  if (wcscmp(cls, L"#32770") == 0) {
    BOOL hasChrome = FALSE;
    EnumChildWindows(hwnd, CheckHasChromeChildProc, (LPARAM)&hasChrome);
    if (!hasChrome) {
      RECT rc;
      if (GetClientRect(hwnd, &rc) && (rc.right - rc.left > 30) && (rc.bottom - rc.top > 30)) {
        ctx->foundDlg = hwnd;
        return FALSE;
      }
    }
  }
  return TRUE;
}

static HWND FindVisibleNativeDialog(DWORD pid) {
  NativeDlgCtx ctx = {pid, NULL};
  EnumWindows(FindVisibleNativeDlgProc, (LPARAM)&ctx);
  return ctx.foundDlg;
}

static BOOL FindBestChromeWidget(ChromeCandidate *outBest) {
  HWND hNativeDlg = FindVisibleNativeDialog(0);
  if (hNativeDlg) {
    BringWindowToTop(hNativeDlg);
    return FALSE;
  }
  EnumCtx ctx = {0};
  ctx.fg = GetForegroundWindow();
  EnumWindows(EnumTopProc, (LPARAM)&ctx);
  if (ctx.found) {
    *outBest = ctx.best;
    return TRUE;
  }
  return FALSE;
}

static BOOL IsProcessAlive(DWORD pid) {
  if (!pid)
    return TRUE;
  HANDLE h = OpenProcess(SYNCHRONIZE, FALSE, pid);
  if (!h)
    return FALSE;
  DWORD r = WaitForSingleObject(h, 0);
  CloseHandle(h);
  return (r == WAIT_TIMEOUT);
}

static void InjectDeadlockGuard(DWORD pid) {
  if (!pid)
    return;
  HANDLE hProc =
      OpenProcess(PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION |
                      PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ,
                  FALSE, pid);
  if (!hProc)
    return;
  BOOL isWow64 = FALSE;
  IsWow64Process(hProc, &isWow64);
  if (isWow64) {
    CloseHandle(hProc);
    WCHAR selfPath[MAX_PATH] = {0};
    GetModuleFileNameW(NULL, selfPath, MAX_PATH);
    WCHAR *lastSlash = wcsrchr(selfPath, L'\\');
    if (lastSlash) {
      wcscpy(lastSlash + 1, L"zk_inject32.exe");
      WCHAR cmdLine[MAX_PATH + 32];
      wsprintfW(cmdLine, L"\"%s\" %lu", selfPath, pid);
      STARTUPINFOW si = {0};
      si.cb = sizeof(si);
      PROCESS_INFORMATION pi = {0};
      if (CreateProcessW(NULL, cmdLine, NULL, NULL, FALSE, CREATE_NO_WINDOW,
                         NULL, NULL, &si, &pi)) {
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
      }
    }
    return;
  }
  const WCHAR *dllPath = L"C:\\windows\\system32\\zk_deadlock_guard64.dll";
  SIZE_T sz = (wcslen(dllPath) + 1) * sizeof(WCHAR);
  LPVOID remoteMem =
      VirtualAllocEx(hProc, NULL, sz, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
  if (remoteMem) {
    if (WriteProcessMemory(hProc, remoteMem, dllPath, sz, NULL)) {
      HMODULE hK32 = GetModuleHandleW(L"kernel32.dll");
      LPTHREAD_START_ROUTINE pLoadLib =
          (LPTHREAD_START_ROUTINE)GetProcAddress(hK32, "LoadLibraryW");
      if (pLoadLib) {
        HANDLE hThread =
            CreateRemoteThread(hProc, NULL, 0, pLoadLib, remoteMem, 0, NULL);
        if (hThread)
          CloseHandle(hThread);
      }
    }
  }
  CloseHandle(hProc);
}

LRESULT CALLBACK OverlayWndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
  switch (msg) {
  case WM_ERASEBKGND:
    return 1;

  case WM_PAINT: {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);
    if (g_shm && g_shm->magic == 0x5A4B4642 && g_shm->img_w > 0 &&
        g_shm->img_h > 0) {
      RECT rc;
      GetClientRect(hwnd, &rc);
      int clientW = rc.right - rc.left;
      int clientH = rc.bottom - rc.top;

      BITMAPINFO bmi = {0};
      bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
      bmi.bmiHeader.biWidth = g_shm->img_w;
      bmi.bmiHeader.biHeight = -g_shm->img_h;
      bmi.bmiHeader.biPlanes = 1;
      bmi.bmiHeader.biBitCount = 32;
      bmi.bmiHeader.biCompression = BI_RGB;

      SetStretchBltMode(hdc, HALFTONE);
      SetBrushOrgEx(hdc, 0, 0, NULL);
      StretchDIBits(hdc, 0, 0, clientW, clientH, 0, 0, g_shm->img_w,
                    g_shm->img_h, g_shm->pixels, &bmi, DIB_RGB_COLORS, SRCCOPY);
    }
    EndPaint(hwnd, &ps);
    return 0;
  }

  case WM_MOUSEMOVE: {
    int x = GET_X_LPARAM(lp);
    int y = GET_Y_LPARAM(lp);
    RECT rc;
    GetClientRect(hwnd, &rc);
    char buf[256];
    snprintf(
        buf, sizeof(buf),
        "{\"type\":\"mouseMoved\",\"x\":%d,\"y\":%d,\"winW\":%ld,\"winH\":%ld}",
        x, y, rc.right - rc.left, rc.bottom - rc.top);
    SendUDP(buf);
    return 0;
  }

  case WM_LBUTTONDOWN: {
    SetCapture(hwnd);
    int x = GET_X_LPARAM(lp);
    int y = GET_Y_LPARAM(lp);
    RECT rc;
    GetClientRect(hwnd, &rc);
    char buf[256];
    snprintf(buf, sizeof(buf),
             "{\"type\":\"mousePressed\",\"x\":%d,\"y\":%d,\"winW\":%ld,"
             "\"winH\":%ld}",
             x, y, rc.right - rc.left, rc.bottom - rc.top);
    SendUDP(buf);
    return 0;
  }

  case WM_LBUTTONUP: {
    ReleaseCapture();
    int x = GET_X_LPARAM(lp);
    int y = GET_Y_LPARAM(lp);
    RECT rc;
    GetClientRect(hwnd, &rc);
    char buf[256];
    snprintf(buf, sizeof(buf),
             "{\"type\":\"mouseReleased\",\"x\":%d,\"y\":%d,\"winW\":%ld,"
             "\"winH\":%ld}",
             x, y, rc.right - rc.left, rc.bottom - rc.top);
    SendUDP(buf);
    return 0;
  }

  case WM_MOUSEWHEEL: {
    int delta = GET_WHEEL_DELTA_WPARAM(wp);
    POINT pt = {GET_X_LPARAM(lp), GET_Y_LPARAM(lp)};
    ScreenToClient(hwnd, &pt);
    RECT rc;
    GetClientRect(hwnd, &rc);
    char buf[256];
    snprintf(buf, sizeof(buf),
             "{\"type\":\"mouseWheel\",\"x\":%ld,\"y\":%ld,\"deltaY\":%d,"
             "\"winW\":%ld,\"winH\":%ld}",
             pt.x, pt.y, -delta, rc.right - rc.left, rc.bottom - rc.top);
    SendUDP(buf);
    return 0;
  }

  case WM_KEYDOWN: {
    char buf[256];
    snprintf(buf, sizeof(buf),
             "{\"type\":\"dispatchKeyEvent\",\"params\":{\"type\":\"keyDown\","
             "\"windowsVirtualKeyCode\":%d}}",
             (int)wp);
    SendUDP(buf);
    return 0;
  }

  case WM_KEYUP: {
    char buf[256];
    snprintf(buf, sizeof(buf),
             "{\"type\":\"dispatchKeyEvent\",\"params\":{\"type\":\"keyUp\","
             "\"windowsVirtualKeyCode\":%d}}",
             (int)wp);
    SendUDP(buf);
    return 0;
  }

  case WM_CHAR: {
    if (wp >= 32 && wp < 127) {
      char ch = (char)wp;
      char buf[256];
      snprintf(buf, sizeof(buf), "{\"type\":\"insertText\",\"text\":\"%c\"}",
               ch);
      SendUDP(buf);
    }
    return 0;
  }

  case WM_DESTROY:
    PostQuitMessage(0);
    return 0;
  }
  return DefWindowProcW(hwnd, msg, wp, lp);
}

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmdLine,
                   int nShow) {
  int udpPort = 9223;
  wchar_t shmPath[MAX_PATH] = L"Z:\\tmp\\zk_webview_fb.bin";

  int argc = 0;
  LPWSTR *argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (argv) {
    for (int i = 1; i < argc; i++) {
      if (_wcsicmp(argv[i], L"--udp-port") == 0 && i + 1 < argc) {
        udpPort = _wtoi(argv[++i]);
      } else if (_wcsicmp(argv[i], L"--shm-path") == 0 && i + 1 < argc) {
        wcsncpy(shmPath, argv[++i], MAX_PATH - 1);
        shmPath[MAX_PATH - 1] = L'\0';
      }
    }
    LocalFree(argv);
  }

  HMODULE hUser32 = GetModuleHandleW(L"user32.dll");
  if (hUser32) {
    pGetWindowDpiAwarenessContext =
        (PFN_GetWindowDpiAwarenessContext)GetProcAddress(
            hUser32, "GetWindowDpiAwarenessContext");
    pSetThreadDpiAwarenessContext =
        (PFN_SetThreadDpiAwarenessContext)GetProcAddress(
            hUser32, "SetThreadDpiAwarenessContext");
  }

  WSADATA wsa;
  WSAStartup(MAKEWORD(2, 2), &wsa);
  g_udpSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  g_udpAddr.sin_family = AF_INET;
  g_udpAddr.sin_port = htons(udpPort);
  g_udpAddr.sin_addr.s_addr = inet_addr("127.0.0.1");

  HANDLE hFile = CreateFileW(shmPath, GENERIC_READ | GENERIC_WRITE,
                             FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
                             OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);

  if (hFile == INVALID_HANDLE_VALUE) {
    hFile = CreateFileW(L"C:\\zk_webview_fb.bin", GENERIC_READ | GENERIC_WRITE,
                        FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS,
                        FILE_ATTRIBUTE_NORMAL, NULL);
  }

  HANDLE hMap = NULL;
  if (hFile != INVALID_HANDLE_VALUE) {
    hMap = CreateFileMappingW(hFile, NULL, PAGE_READWRITE, 0, 16 * 1024 * 1024,
                              NULL);
    if (hMap) {
      g_shm = (ZKSharedFrameBuffer *)MapViewOfFile(hMap, FILE_MAP_ALL_ACCESS, 0,
                                                   0, 16 * 1024 * 1024);
    }
  }

  WNDCLASSEXW wc = {0};
  wc.cbSize = sizeof(wc);
  wc.lpfnWndProc = OverlayWndProc;
  wc.hInstance = hInst;
  wc.hCursor = LoadCursor(NULL, IDC_ARROW);
  wc.hbrBackground = NULL;
  wc.lpszClassName = L"ZK_WebView2_SHM_Overlay";
  RegisterClassExW(&wc);

  // Independent WS_POPUP at normal window level (no WS_EX_TOPMOST so other
  // macOS apps are never covered)
  g_hOverlay = CreateWindowExW(0, L"ZK_WebView2_SHM_Overlay",
                               L"WebView2 Live SHM Overlay", WS_POPUP, 0, 0,
                               100, 100, NULL, NULL, hInst, NULL);

  int curX = -1, curY = -1, curW = -1, curH = -1;
  DWORD lastGeomCheck = 0;
  DWORD lastGeomSend = 0;
  DWORD lastAliveCheck = 0;
  HWND cachedEdge = NULL;
  HWND cachedRoot = NULL;
  HWND lastFg = NULL;
  int cachedIsDialog = 0;
  BOOL overlayShown = FALSE;
  BOOL wasTopmost = FALSE;

  while (PumpMessagesAndWait(16)) {
    DWORD now = GetTickCount();

    if (g_targetPid && (now - lastAliveCheck >= 1000)) {
      lastAliveCheck = now;
      if (!IsProcessAlive(g_targetPid))
        break;
    }

    // Fast foreground check every tick so HWND_TOPMOST <-> HWND_NOTOPMOST is
    // instant
    HWND curFg = GetForegroundWindow();
    BOOL wineIsActive = (curFg != NULL);

    HWND hNativeDlg = FindVisibleNativeDialog(0);
    if (hNativeDlg) {
      if (overlayShown) {
        ShowWindow(g_hOverlay, SW_HIDE);
        overlayShown = FALSE;
        wasTopmost = FALSE;
      }
    } else if (overlayShown) {
      if (wineIsActive && !wasTopmost) {
        SetWindowPos(g_hOverlay, HWND_TOPMOST, curX, curY, curW, curH,
                     SWP_NOACTIVATE | SWP_SHOWWINDOW);
        RedrawWindow(g_hOverlay, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW);
        wasTopmost = TRUE;
      } else if (!wineIsActive && wasTopmost) {
        SetWindowPos(g_hOverlay, HWND_NOTOPMOST, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
        wasTopmost = FALSE;
      }
    }

    if (now - lastGeomCheck >= 250) {
      lastGeomCheck = now;
      BOOL needEnum = FALSE;
      RECT rc;

      if (!cachedEdge || !IsWindow(cachedEdge) ||
          !IsWindowVisible(cachedEdge) || !cachedRoot ||
          !IsWindow(cachedRoot) || !IsWindowVisible(cachedRoot) ||
          IsIconic(cachedRoot) || !IsWindowEnabled(cachedRoot) ||
          curFg != lastFg) {
        needEnum = TRUE;
      } else if (!GetClampedWidgetRect(cachedEdge, &rc)) {
        needEnum = TRUE;
      }

      if (needEnum) {
        lastFg = curFg;
        ChromeCandidate cand;
        if (FindBestChromeWidget(&cand)) {
          cachedEdge = cand.hwnd;
          cachedRoot = cand.root;
          cachedIsDialog = cand.isDialog;
          rc = cand.rect;
          if (!g_targetPid && cand.pid) {
            g_targetPid = cand.pid;
            InjectDeadlockGuard(g_targetPid);
          }
        } else {
          cachedEdge = NULL;
          cachedRoot = NULL;
          if (overlayShown) {
            ShowWindow(g_hOverlay, SW_HIDE);
            overlayShown = FALSE;
            wasTopmost = FALSE;
          }
        }
      }

      if (cachedEdge) {
        int tw = rc.right - rc.left;
        int th = rc.bottom - rc.top;
        BOOL geomChanged =
            (rc.left != curX || rc.top != curY || tw != curW || th != curH);

        if (!overlayShown || geomChanged) {
          curX = rc.left;
          curY = rc.top;
          curW = tw;
          curH = th;
          overlayShown = TRUE;
          if (wineIsActive) {
            SetWindowPos(g_hOverlay, HWND_TOPMOST, curX, curY, curW, curH,
                         SWP_NOACTIVATE | SWP_SHOWWINDOW);
            RedrawWindow(g_hOverlay, NULL, NULL,
                         RDW_INVALIDATE | RDW_UPDATENOW);
            wasTopmost = TRUE;
          } else {
            SetWindowPos(g_hOverlay, HWND_NOTOPMOST, curX, curY, curW, curH,
                         SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW);
            wasTopmost = FALSE;
          }
        }

        if (geomChanged || (now - lastGeomSend >= 1000)) {
          lastGeomSend = now;
          char buf[256];
          snprintf(buf, sizeof(buf),
                   "{\"type\":\"windows\",\"active\":{\"w\":%d,\"h\":%d,"
                   "\"isDialog\":%d}}",
                   tw, th, cachedIsDialog);
          SendUDP(buf);
        }
      } else if (overlayShown) {
        overlayShown = FALSE;
        wasTopmost = FALSE;
        ShowWindow(g_hOverlay, SW_HIDE);
      }
    }

    // Pure RAM seq check: 0 wineserver syscalls when frame is unchanged
    if (overlayShown && g_shm && g_shm->magic == 0x5A4B4642) {
      int32_t seq = g_shm->seq;
      if (seq != g_lastSeq) {
        g_lastSeq = seq;
        RedrawWindow(g_hOverlay, NULL, NULL, RDW_INVALIDATE | RDW_UPDATENOW);
      }
    }
  }

  if (g_shm)
    UnmapViewOfFile(g_shm);
  if (hMap)
    CloseHandle(hMap);
  if (hFile != INVALID_HANDLE_VALUE)
    CloseHandle(hFile);
  if (g_udpSock != INVALID_SOCKET)
    closesocket(g_udpSock);
  WSACleanup();
  return 0;
}
