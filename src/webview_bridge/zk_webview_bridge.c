#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <windowsx.h>
#include <psapi.h>
#include <msiquery.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ZK_SHM_MAGIC 0x5A4B5756 // 'ZKWV'
#define ZK_MAX_SURFACES 4
#define ZK_MAX_W 3840
#define ZK_MAX_H 2160

#pragma pack(push, 4)
typedef struct {
    uint32_t active;
    uint32_t host_hwnd;
    uint32_t child_hwnd;
    int32_t  width;
    int32_t  height;
    volatile LONG frame_seq;
    uint32_t pixels[ZK_MAX_W * ZK_MAX_H];
} ZKSurfaceSlot;

typedef struct {
    uint32_t magic;
    uint32_t num_slots;
    ZKSurfaceSlot slots[ZK_MAX_SURFACES];
} ZKWebViewShm;
#pragma pack(pop)

static HANDLE g_hMap = NULL;
static ZKWebViewShm *g_shm = NULL;

static void log_msg(const char *fmt, ...) {
    FILE *f = fopen("C:\\zk_bridge.log", "a");
    if (!f) return;
    va_list va;
    va_start(va, fmt);
    vfprintf(f, fmt, va);
    va_end(va);
    fclose(f);
}

static void init_shm(void) {
    if (g_shm) return;
    g_hMap = CreateFileMappingW(INVALID_HANDLE_VALUE, NULL, PAGE_READWRITE, 0, sizeof(ZKWebViewShm), L"Local\\ZK_WebView2_Bridge");
    if (!g_hMap) {
        log_msg("[Bridge] CreateFileMappingW failed: %lu\n", GetLastError());
        return;
    }
    g_shm = (ZKWebViewShm *)MapViewOfFile(g_hMap, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(ZKWebViewShm));
    if (g_shm) {
        if (g_shm->magic != ZK_SHM_MAGIC) {
            memset(g_shm, 0, sizeof(ZKWebViewShm));
            g_shm->magic = ZK_SHM_MAGIC;
        }
        log_msg("[Bridge] SHM initialized at %p (PID %lu, size %zu)\n", g_shm, GetCurrentProcessId(), sizeof(ZKWebViewShm));
    }
}

// Forward declarations
#ifdef ZK_VERSION_PROXY
void load_real_version(void);
#else
static inline void load_real_version(void) {}
#endif

// ----------------------------------------------------------------------------
// Producer Role (inside msedgewebview2.exe / msedge.dll)
// ----------------------------------------------------------------------------
typedef BOOL (WINAPI *PFN_BitBlt)(HDC, int, int, int, int, HDC, int, int, DWORD);
typedef BOOL (WINAPI *PFN_StretchBlt)(HDC, int, int, int, int, HDC, int, int, int, int, DWORD);
typedef int  (WINAPI *PFN_SetDIBitsToDevice)(HDC, int, int, DWORD, DWORD, int, int, UINT, UINT, const VOID*, const BITMAPINFO*, UINT);
typedef int  (WINAPI *PFN_StretchDIBits)(HDC, int, int, int, int, int, int, int, int, const VOID*, const BITMAPINFO*, UINT, DWORD);
typedef BOOL (WINAPI *PFN_UpdateLayeredWindow)(HWND, HDC, POINT*, SIZE*, HDC, POINT*, COLORREF, BLENDFUNCTION*, DWORD);

static PFN_BitBlt g_origBitBlt = NULL;
static PFN_StretchBlt g_origStretchBlt = NULL;
static PFN_SetDIBitsToDevice g_origSetDIBitsToDevice = NULL;
static PFN_StretchDIBits g_origStretchDIBits = NULL;
static PFN_UpdateLayeredWindow g_origULW = NULL;

static ZKSurfaceSlot *find_or_create_slot(HWND hwndDst, int cx, int cy) {
    if (!g_shm || cx <= 0 || cy <= 0 || cx > ZK_MAX_W || cy > ZK_MAX_H) return NULL;

    // If hwndDst is NULL (memory DC), find the first active slot or active Chrome widget
    if (!hwndDst) {
        for (int i = 0; i < ZK_MAX_SURFACES; i++) {
            if (g_shm->slots[i].active && (cx > 100 && cy > 100)) {
                return &g_shm->slots[i];
            }
        }
        // If no slot active yet, look for any Chrome_WidgetWin_1 or Chrome_WidgetWin_0
        HWND hEdge = FindWindowA("Chrome_WidgetWin_1", NULL);
        if (!hEdge) hEdge = FindWindowA("Chrome_WidgetWin_0", NULL);
        if (hEdge) hwndDst = hEdge;
        else return NULL;
    }

    HWND host_hwnd = GetAncestor(hwndDst, GA_ROOT);
    HWND p = GetParent(hwndDst);
    while (p) {
        WCHAR pcls[128] = {0};
        GetClassNameW(p, pcls, 128);
        if (wcscmp(pcls, L"Chrome_WidgetWin_0") == 0 || wcsstr(pcls, L"Afx") != NULL) {
            host_hwnd = p;
            break;
        }
        p = GetParent(p);
    }
    if (!host_hwnd) host_hwnd = hwndDst;

    ZKSurfaceSlot *slot = NULL;
    for (int i = 0; i < ZK_MAX_SURFACES; i++) {
        if (g_shm->slots[i].active && (HWND)(uintptr_t)g_shm->slots[i].host_hwnd == host_hwnd) {
            slot = &g_shm->slots[i];
            break;
        }
    }
    if (!slot) {
        for (int i = 0; i < ZK_MAX_SURFACES; i++) {
            if (!g_shm->slots[i].active) {
                slot = &g_shm->slots[i];
                slot->active = 1;
                slot->host_hwnd = (uint32_t)(uintptr_t)host_hwnd;
                slot->child_hwnd = (uint32_t)(uintptr_t)hwndDst;
                log_msg("[Bridge Producer] Registered surface slot %d: host=%p child=%p (%dx%d)\n",
                        i, (void*)host_hwnd, (void*)hwndDst, cx, cy);
                break;
            }
        }
    }
    return slot;
}

static void copy_pixels_from_raw_bits(ZKSurfaceSlot *slot, const VOID *lpBits, const BITMAPINFO *lpbmi,
                                      int srcX, int srcY, int srcW, int srcH, int dstW, int dstH) {
    if (dstW < 100 || dstH < 100) return;
    if (!slot || !lpBits || !lpbmi || dstW <= 0 || dstH <= 0) return;

    slot->width = dstW;
    slot->height = dstH;

    const BITMAPINFOHEADER *bih = &lpbmi->bmiHeader;
    int bmWidth = bih->biWidth;
    int bmHeight = bih->biHeight;
    int bitCount = bih->biBitCount;
    if (bitCount != 32 && bitCount != 24) return;

    int srcStride = ((bmWidth * bitCount + 31) / 32) * 4;
    int dstStride = dstW * 4;
    const BYTE *src = (const BYTE *)lpBits;
    BYTE *dst = (BYTE *)slot->pixels;

    BOOL isTopDown = (bmHeight < 0);
    int absHeight = (bmHeight < 0) ? -bmHeight : bmHeight;

    for (int r = 0; r < dstH && (srcY + r) < absHeight; r++) {
        int srcRow = isTopDown ? (srcY + r) : (absHeight - 1 - (srcY + r));
        const BYTE *srcLine = src + srcRow * srcStride + srcX * (bitCount / 8);
        BYTE *dstLine = dst + r * dstStride;

        if (bitCount == 32) {
            memcpy(dstLine, srcLine, dstW * 4);
        } else if (bitCount == 24) {
            for (int c = 0; c < dstW; c++) {
                dstLine[c * 4 + 0] = srcLine[c * 3 + 0];
                dstLine[c * 4 + 1] = srcLine[c * 3 + 1];
                dstLine[c * 4 + 2] = srcLine[c * 3 + 2];
                dstLine[c * 4 + 3] = 0xFF;
            }
        }
    }

    LONG seq = InterlockedIncrement(&slot->frame_seq);
    if (seq % 60 == 1) {
        log_msg("[Bridge Producer] Captured RAW frame seq=%ld (%dx%d)\n", seq, dstW, dstH);
    }
}

static void capture_frame_hdc(HDC hdcDst, int cx, int cy, HDC hdcSrc, int x1, int y1) {
    if (!g_shm || cx <= 0 || cy <= 0 || cx > ZK_MAX_W || cy > ZK_MAX_H) return;
    HWND hwndDst = WindowFromDC(hdcDst);
    if (!hwndDst) return;

    ZKSurfaceSlot *slot = find_or_create_slot(hwndDst, cx, cy);
    if (!slot) return;

    slot->width = cx;
    slot->height = cy;

    HBITMAP hbm = (HBITMAP)GetCurrentObject(hdcSrc, OBJ_BITMAP);
    if (!hbm) return;

    DIBSECTION ds;
    if (GetObjectW(hbm, sizeof(ds), &ds) == sizeof(ds) && ds.dsBm.bmBits) {
        int srcStride = ds.dsBm.bmWidthBytes;
        int dstStride = cx * 4;
        BYTE *src = (BYTE *)ds.dsBm.bmBits;
        BYTE *dst = (BYTE *)slot->pixels;

        if (ds.dsBmih.biHeight < 0) { // top-down
            for (int r = 0; r < cy; r++) {
                memcpy(dst + r * dstStride, src + (y1 + r) * srcStride + x1 * 4, dstStride);
            }
        } else { // bottom-up
            for (int r = 0; r < cy; r++) {
                int srcRow = ds.dsBm.bmHeight - 1 - (y1 + r);
                memcpy(dst + r * dstStride, src + srcRow * srcStride + x1 * 4, dstStride);
            }
        }
    } else {
        BITMAPINFO bmi = {0};
        bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bmi.bmiHeader.biWidth = cx;
        bmi.bmiHeader.biHeight = -cy;
        bmi.bmiHeader.biPlanes = 1;
        bmi.bmiHeader.biBitCount = 32;
        bmi.bmiHeader.biCompression = BI_RGB;
        GetDIBits(hdcSrc, hbm, y1, cy, slot->pixels, &bmi, DIB_RGB_COLORS);
    }

    LONG seq = InterlockedIncrement(&slot->frame_seq);
    if (seq % 60 == 1) {
        log_msg("[Bridge Producer] Captured GDI frame seq=%ld (%dx%d)\n", seq, cx, cy);
    }
}

static BOOL WINAPI Hooked_BitBlt(HDC d, int x, int y, int cx, int cy, HDC s, int x1, int y1, DWORD r) {
    static int bb_count = 0;
    if (++bb_count <= 10 || bb_count % 60 == 0) {
        HWND hw = WindowFromDC(d);
        log_msg("[Bridge Producer] Hooked_BitBlt #%d: d=%p (hwnd=%p) %dx%d\n", bb_count, d, hw, cx, cy);
    }
    capture_frame_hdc(d, cx, cy, s, x1, y1);
    if (g_origBitBlt) return g_origBitBlt(d, x, y, cx, cy, s, x1, y1, r);
    return BitBlt(d, x, y, cx, cy, s, x1, y1, r);
}

static BOOL WINAPI Hooked_StretchBlt(HDC d, int x, int y, int w, int h, HDC s, int x1, int y1, int w1, int h1, DWORD r) {
    capture_frame_hdc(d, w, h, s, x1, y1);
    if (g_origStretchBlt) return g_origStretchBlt(d, x, y, w, h, s, x1, y1, w1, h1, r);
    return StretchBlt(d, x, y, w, h, s, x1, y1, w1, h1, r);
}

static int WINAPI Hooked_SetDIBitsToDevice(HDC hdc, int xDest, int yDest, DWORD w, DWORD h,
    int xSrc, int ySrc, UINT startScan, UINT cScanLines, const VOID *lpvBits, const BITMAPINFO *lpbmi, UINT colorUse) {
    HWND hwndDst = WindowFromDC(hdc);
    if (hwndDst && lpvBits && lpbmi) {
        ZKSurfaceSlot *slot = find_or_create_slot(hwndDst, (int)w, (int)h);
        if (slot) copy_pixels_from_raw_bits(slot, lpvBits, lpbmi, xSrc, ySrc, (int)w, (int)h, (int)w, (int)h);
    }
    if (g_origSetDIBitsToDevice) return g_origSetDIBitsToDevice(hdc, xDest, yDest, w, h, xSrc, ySrc, startScan, cScanLines, lpvBits, lpbmi, colorUse);
    return SetDIBitsToDevice(hdc, xDest, yDest, w, h, xSrc, ySrc, startScan, cScanLines, lpvBits, lpbmi, colorUse);
}

static int WINAPI Hooked_StretchDIBits(HDC hdc, int xDest, int yDest, int DestWidth, int DestHeight,
    int xSrc, int ySrc, int SrcWidth, int SrcHeight, const VOID *lpBits, const BITMAPINFO *lpbmi, UINT iUsage, DWORD rop) {
    static int sd_count = 0;
    HWND hwndDst = WindowFromDC(hdc);
    if (++sd_count <= 20 || sd_count % 60 == 0) {
        log_msg("[Bridge Producer] Hooked_StretchDIBits #%d: hdc=%p (hwnd=%p) %dx%d\n", sd_count, hdc, hwndDst, DestWidth, DestHeight);
    }
    if (lpBits && lpbmi) {
        ZKSurfaceSlot *slot = find_or_create_slot(hwndDst, DestWidth, DestHeight);
        if (slot) copy_pixels_from_raw_bits(slot, lpBits, lpbmi, xSrc, ySrc, SrcWidth, SrcHeight, DestWidth, DestHeight);
    }
    if (g_origStretchDIBits) return g_origStretchDIBits(hdc, xDest, yDest, DestWidth, DestHeight, xSrc, ySrc, SrcWidth, SrcHeight, lpBits, lpbmi, iUsage, rop);
    return StretchDIBits(hdc, xDest, yDest, DestWidth, DestHeight, xSrc, ySrc, SrcWidth, SrcHeight, lpBits, lpbmi, iUsage, rop);
}

static BOOL WINAPI Hooked_UpdateLayeredWindow(HWND hwnd, HDC hdcDst, POINT *pptDst, SIZE *psize,
    HDC hdcSrc, POINT *pptSrc, COLORREF crKey, BLENDFUNCTION *pblend, DWORD dwFlags) {
    int cx = psize ? psize->cx : 0;
    int cy = psize ? psize->cy : 0;
    int x1 = pptSrc ? pptSrc->x : 0;
    int y1 = pptSrc ? pptSrc->y : 0;
    HDC d = hdcDst ? hdcDst : GetDC(hwnd);
    if (d && hdcSrc && cx > 0 && cy > 0) {
        capture_frame_hdc(d, cx, cy, hdcSrc, x1, y1);
    }
    if (!hdcDst && d) ReleaseDC(hwnd, d);
    if (g_origULW) return g_origULW(hwnd, hdcDst, pptDst, psize, hdcSrc, pptSrc, crKey, pblend, dwFlags);
    return UpdateLayeredWindow(hwnd, hdcDst, pptDst, psize, hdcSrc, pptSrc, crKey, pblend, dwFlags);
}

static HMODULE g_hSelfModule = NULL;
static BOOL g_isProducer = FALSE;

typedef LRESULT (WINAPI *PFN_SendMessageW)(HWND, UINT, WPARAM, LPARAM);
typedef LRESULT (WINAPI *PFN_SendMessageA)(HWND, UINT, WPARAM, LPARAM);
static PFN_SendMessageW g_origSendMessageW = NULL;
static PFN_SendMessageA g_origSendMessageA = NULL;

static LRESULT WINAPI Hooked_SendMessageW(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (hwnd == HWND_BROADCAST || hwnd == (HWND)0xFFFF ||
        (hwnd && GetWindowThreadProcessId(hwnd, NULL) != GetCurrentThreadId())) {
        ULONG_PTR result = 0;
        if (SendMessageTimeoutW(hwnd, msg, wp, lp, SMTO_ABORTIFHUNG | SMTO_NORMAL, 2000, &result)) {
            return (LRESULT)result;
        }
        DWORD targetPid = 0;
        DWORD targetTid = (hwnd && hwnd != HWND_BROADCAST && hwnd != (HWND)0xFFFF)
                          ? GetWindowThreadProcessId(hwnd, &targetPid) : 0;
        log_msg("[DeadlockGuard] SendMessageW TIMED OUT: hwnd=%p msg=0x%x wp=0x%llx lp=0x%llx target=(pid:%lu tid:%lu) callerTid=%lu err=%lu\n",
                hwnd, msg, (unsigned long long)wp, (unsigned long long)lp, targetPid, targetTid, GetCurrentThreadId(), GetLastError());
        return 0;
    }
    if (g_origSendMessageW) return g_origSendMessageW(hwnd, msg, wp, lp);
    return DefWindowProcW(hwnd, msg, wp, lp);
}

static LRESULT WINAPI Hooked_SendMessageA(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (hwnd == HWND_BROADCAST || hwnd == (HWND)0xFFFF ||
        (hwnd && GetWindowThreadProcessId(hwnd, NULL) != GetCurrentThreadId())) {
        ULONG_PTR result = 0;
        if (SendMessageTimeoutA(hwnd, msg, wp, lp, SMTO_ABORTIFHUNG | SMTO_NORMAL, 2000, &result)) {
            return (LRESULT)result;
        }
        DWORD targetPid = 0;
        DWORD targetTid = (hwnd && hwnd != HWND_BROADCAST && hwnd != (HWND)0xFFFF)
                          ? GetWindowThreadProcessId(hwnd, &targetPid) : 0;
        log_msg("[DeadlockGuard] SendMessageA TIMED OUT: hwnd=%p msg=0x%x wp=0x%llx lp=0x%llx target=(pid:%lu tid:%lu) callerTid=%lu err=%lu\n",
                hwnd, msg, (unsigned long long)wp, (unsigned long long)lp, targetPid, targetTid, GetCurrentThreadId(), GetLastError());
        return 0;
    }
    if (g_origSendMessageA) return g_origSendMessageA(hwnd, msg, wp, lp);
    return DefWindowProcA(hwnd, msg, wp, lp);
}

// ----------------------------------------------------------------------------
// PendingFileRenameOperations suppression for installers
// ----------------------------------------------------------------------------
typedef LSTATUS (WINAPI *PFN_RegQueryValueExW)(HKEY, LPCWSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD);
typedef LSTATUS (WINAPI *PFN_RegQueryValueExA)(HKEY, LPCSTR, LPDWORD, LPDWORD, LPBYTE, LPDWORD);
static PFN_RegQueryValueExW g_origRegQueryValueExW = NULL;
static PFN_RegQueryValueExA g_origRegQueryValueExA = NULL;

static LSTATUS WINAPI Hooked_RegQueryValueExW(HKEY hKey, LPCWSTR lpValueName, LPDWORD lpReserved, LPDWORD lpType, LPBYTE lpData, LPDWORD lpcbData) {
    if (lpValueName && _wcsicmp(lpValueName, L"PendingFileRenameOperations") == 0) {
        log_msg("[Registry] Blocked query for PendingFileRenameOperations (W) in PID %lu\n", GetCurrentProcessId());
        return ERROR_FILE_NOT_FOUND;
    }
    if (g_origRegQueryValueExW) {
        return g_origRegQueryValueExW(hKey, lpValueName, lpReserved, lpType, lpData, lpcbData);
    }
    HMODULE adv = GetModuleHandleW(L"advapi32.dll");
    PFN_RegQueryValueExW fn = adv ? (PFN_RegQueryValueExW)GetProcAddress(adv, "RegQueryValueExW") : NULL;
    return fn ? fn(hKey, lpValueName, lpReserved, lpType, lpData, lpcbData) : ERROR_FILE_NOT_FOUND;
}

static LSTATUS WINAPI Hooked_RegQueryValueExA(HKEY hKey, LPCSTR lpValueName, LPDWORD lpReserved, LPDWORD lpType, LPBYTE lpData, LPDWORD lpcbData) {
    if (lpValueName && _stricmp(lpValueName, "PendingFileRenameOperations") == 0) {
        log_msg("[Registry] Blocked query for PendingFileRenameOperations (A) in PID %lu\n", GetCurrentProcessId());
        return ERROR_FILE_NOT_FOUND;
    }
    if (g_origRegQueryValueExA) {
        return g_origRegQueryValueExA(hKey, lpValueName, lpReserved, lpType, lpData, lpcbData);
    }
    HMODULE adv = GetModuleHandleW(L"advapi32.dll");
    PFN_RegQueryValueExA fn = adv ? (PFN_RegQueryValueExA)GetProcAddress(adv, "RegQueryValueExA") : NULL;
    return fn ? fn(hKey, lpValueName, lpReserved, lpType, lpData, lpcbData) : ERROR_FILE_NOT_FOUND;
}

// ----------------------------------------------------------------------------
// Optional WebView2 installer redirection via ZK_WEBVIEW2_STUB env var
// ----------------------------------------------------------------------------
typedef BOOL (WINAPI *PFN_CreateProcessW)(LPCWSTR, LPWSTR, LPSECURITY_ATTRIBUTES, LPSECURITY_ATTRIBUTES, BOOL, DWORD, LPVOID, LPCWSTR, LPSTARTUPINFOW, LPPROCESS_INFORMATION);
static PFN_CreateProcessW g_origCreateProcessW = NULL;

static BOOL WINAPI Hooked_CreateProcessW(LPCWSTR lpApplicationName, LPWSTR lpCommandLine,
                                        LPSECURITY_ATTRIBUTES lpProcessAttributes, LPSECURITY_ATTRIBUTES lpThreadAttributes,
                                        BOOL bInheritHandles, DWORD dwCreationFlags, LPVOID lpEnvironment,
                                        LPCWSTR lpCurrentDirectory, LPSTARTUPINFOW lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation) {
    if ((lpApplicationName && wcsstr(lpApplicationName, L"MicrosoftEdgeWebView2RuntimeInstaller")) ||
        (lpCommandLine && wcsstr(lpCommandLine, L"MicrosoftEdgeWebView2RuntimeInstaller"))) {
        static WCHAR stubCmd[MAX_PATH] = {0};
        DWORD stubLen = GetEnvironmentVariableW(L"ZK_WEBVIEW2_STUB", stubCmd, MAX_PATH);
        if (stubLen > 0 && stubLen < MAX_PATH && g_origCreateProcessW) {
            log_msg("[Process] Intercepted WebView2 installer call in PID %lu, redirecting to ZK_WEBVIEW2_STUB\n", GetCurrentProcessId());
            return g_origCreateProcessW(stubCmd, stubCmd, lpProcessAttributes, lpThreadAttributes, bInheritHandles, dwCreationFlags, lpEnvironment, lpCurrentDirectory, lpStartupInfo, lpProcessInformation);
        }
    }
    if (g_origCreateProcessW) {
        return g_origCreateProcessW(lpApplicationName, lpCommandLine, lpProcessAttributes, lpThreadAttributes, bInheritHandles, dwCreationFlags, lpEnvironment, lpCurrentDirectory, lpStartupInfo, lpProcessInformation);
    }
    HMODULE k32 = GetModuleHandleW(L"kernel32.dll");
    PFN_CreateProcessW fn = k32 ? (PFN_CreateProcessW)GetProcAddress(k32, "CreateProcessW") : NULL;
    return fn ? fn(lpApplicationName, lpCommandLine, lpProcessAttributes, lpThreadAttributes, bInheritHandles, dwCreationFlags, lpEnvironment, lpCurrentDirectory, lpStartupInfo, lpProcessInformation) : FALSE;
}

// ----------------------------------------------------------------------------
// Optional WinINet / Winsock host suppression via ZK_BLOCK_HOSTS env var
// Comma-separated host substrings (e.g. ZK_BLOCK_HOSTS=example.com,cdn.example.com)
// ----------------------------------------------------------------------------
typedef LPVOID HINTERNET;
typedef HINTERNET (WINAPI *PFN_InternetOpenUrlW)(HINTERNET, LPCWSTR, LPCWSTR, DWORD, DWORD, DWORD_PTR);
typedef HINTERNET (WINAPI *PFN_InternetOpenUrlA)(HINTERNET, LPCSTR, LPCSTR, DWORD, DWORD, DWORD_PTR);
typedef HINTERNET (WINAPI *PFN_InternetConnectW)(HINTERNET, LPCWSTR, WORD, LPCWSTR, LPCWSTR, DWORD, DWORD, DWORD_PTR);
typedef HINTERNET (WINAPI *PFN_InternetConnectA)(HINTERNET, LPCSTR, WORD, LPCSTR, LPCSTR, DWORD, DWORD, DWORD_PTR);
typedef int (WSAAPI *PFN_getaddrinfo)(const char *, const char *, const void *, void **);

static PFN_InternetOpenUrlW g_origInternetOpenUrlW = NULL;
static PFN_InternetOpenUrlA g_origInternetOpenUrlA = NULL;
static PFN_InternetConnectW g_origInternetConnectW = NULL;
static PFN_InternetConnectA g_origInternetConnectA = NULL;
static PFN_getaddrinfo g_origGetaddrinfo = NULL;

static BOOL should_block_host_a(const char *target) {
    if (!target || !*target) return FALSE;
    char hostsBuf[512];
    DWORD len = GetEnvironmentVariableA("ZK_BLOCK_HOSTS", hostsBuf, sizeof(hostsBuf));
    if (len == 0 || len >= sizeof(hostsBuf)) return FALSE;
    char *tok = hostsBuf;
    while (tok && *tok) {
        char *comma = strchr(tok, ',');
        if (comma) *comma = '\0';
        while (*tok == ' ' || *tok == '\t') tok++;
        if (*tok && strstr(target, tok) != NULL) return TRUE;
        tok = comma ? (comma + 1) : NULL;
    }
    return FALSE;
}

static BOOL should_block_host_w(const WCHAR *target) {
    if (!target || !*target) return FALSE;
    char utf8[512];
    int n = WideCharToMultiByte(CP_UTF8, 0, target, -1, utf8, sizeof(utf8), NULL, NULL);
    if (n <= 0) return FALSE;
    return should_block_host_a(utf8);
}

static HINTERNET WINAPI Hooked_InternetOpenUrlW(HINTERNET hInternet, LPCWSTR lpszUrl, LPCWSTR lpszHeaders, DWORD dwHeadersLength, DWORD dwFlags, DWORD_PTR dwContext) {
    if (should_block_host_w(lpszUrl)) {
        log_msg("[Bridge Net] Blocked InternetOpenUrlW for '%ls' (ZK_BLOCK_HOSTS)\n", lpszUrl);
        SetLastError(12029); // ERROR_INTERNET_CANNOT_CONNECT
        return NULL;
    }
    if (g_origInternetOpenUrlW) return g_origInternetOpenUrlW(hInternet, lpszUrl, lpszHeaders, dwHeadersLength, dwFlags, dwContext);
    HMODULE hMod = GetModuleHandleW(L"wininet.dll");
    PFN_InternetOpenUrlW fn = hMod ? (PFN_InternetOpenUrlW)GetProcAddress(hMod, "InternetOpenUrlW") : NULL;
    return fn ? fn(hInternet, lpszUrl, lpszHeaders, dwHeadersLength, dwFlags, dwContext) : NULL;
}

static HINTERNET WINAPI Hooked_InternetOpenUrlA(HINTERNET hInternet, LPCSTR lpszUrl, LPCSTR lpszHeaders, DWORD dwHeadersLength, DWORD dwFlags, DWORD_PTR dwContext) {
    if (should_block_host_a(lpszUrl)) {
        log_msg("[Bridge Net] Blocked InternetOpenUrlA for '%s' (ZK_BLOCK_HOSTS)\n", lpszUrl);
        SetLastError(12029); // ERROR_INTERNET_CANNOT_CONNECT
        return NULL;
    }
    if (g_origInternetOpenUrlA) return g_origInternetOpenUrlA(hInternet, lpszUrl, lpszHeaders, dwHeadersLength, dwFlags, dwContext);
    HMODULE hMod = GetModuleHandleW(L"wininet.dll");
    PFN_InternetOpenUrlA fn = hMod ? (PFN_InternetOpenUrlA)GetProcAddress(hMod, "InternetOpenUrlA") : NULL;
    return fn ? fn(hInternet, lpszUrl, lpszHeaders, dwHeadersLength, dwFlags, dwContext) : NULL;
}

static HINTERNET WINAPI Hooked_InternetConnectW(HINTERNET hInternet, LPCWSTR lpszServerName, WORD nServerPort, LPCWSTR lpszUserName, LPCWSTR lpszPassword, DWORD dwService, DWORD dwFlags, DWORD_PTR dwContext) {
    if (should_block_host_w(lpszServerName)) {
        log_msg("[Bridge Net] Blocked InternetConnectW for '%ls' (ZK_BLOCK_HOSTS)\n", lpszServerName);
        SetLastError(12029);
        return NULL;
    }
    if (g_origInternetConnectW) return g_origInternetConnectW(hInternet, lpszServerName, nServerPort, lpszUserName, lpszPassword, dwService, dwFlags, dwContext);
    HMODULE hMod = GetModuleHandleW(L"wininet.dll");
    PFN_InternetConnectW fn = hMod ? (PFN_InternetConnectW)GetProcAddress(hMod, "InternetConnectW") : NULL;
    return fn ? fn(hInternet, lpszServerName, nServerPort, lpszUserName, lpszPassword, dwService, dwFlags, dwContext) : NULL;
}

static HINTERNET WINAPI Hooked_InternetConnectA(HINTERNET hInternet, LPCSTR lpszServerName, WORD nServerPort, LPCSTR lpszUserName, LPCSTR lpszPassword, DWORD dwService, DWORD dwFlags, DWORD_PTR dwContext) {
    if (should_block_host_a(lpszServerName)) {
        log_msg("[Bridge Net] Blocked InternetConnectA for '%s' (ZK_BLOCK_HOSTS)\n", lpszServerName);
        SetLastError(12029);
        return NULL;
    }
    if (g_origInternetConnectA) return g_origInternetConnectA(hInternet, lpszServerName, nServerPort, lpszUserName, lpszPassword, dwService, dwFlags, dwContext);
    HMODULE hMod = GetModuleHandleW(L"wininet.dll");
    PFN_InternetConnectA fn = hMod ? (PFN_InternetConnectA)GetProcAddress(hMod, "InternetConnectA") : NULL;
    return fn ? fn(hInternet, lpszServerName, nServerPort, lpszUserName, lpszPassword, dwService, dwFlags, dwContext) : NULL;
}

static int WSAAPI Hooked_getaddrinfo(const char *nodename, const char *servname, const void *hints, void **res) {
    if (should_block_host_a(nodename)) {
        log_msg("[Bridge Net] Blocked getaddrinfo for '%s' (ZK_BLOCK_HOSTS)\n", nodename);
        return 11001; // WSAHOST_NOT_FOUND
    }
    if (g_origGetaddrinfo) return g_origGetaddrinfo(nodename, servname, hints, res);
    HMODULE hMod = GetModuleHandleW(L"ws2_32.dll");
    PFN_getaddrinfo fn = hMod ? (PFN_getaddrinfo)GetProcAddress(hMod, "getaddrinfo") : NULL;
    return fn ? fn(nodename, servname, hints, res) : 11001;
}

// ----------------------------------------------------------------------------
// Wine MSI ADDLOCAL Feature Resolution & In-Memory Feature State Fix
// ----------------------------------------------------------------------------
typedef UINT (WINAPI *PFN_MsiInstallProductW)(LPCWSTR, LPCWSTR);
typedef UINT (WINAPI *PFN_MsiOpenDatabaseW)(LPCWSTR, LPCWSTR, MSIHANDLE *);
typedef UINT (WINAPI *PFN_MsiDatabaseOpenViewW)(MSIHANDLE, LPCWSTR, MSIHANDLE *);
typedef UINT (WINAPI *PFN_MsiViewExecute)(MSIHANDLE, MSIHANDLE);
typedef UINT (WINAPI *PFN_MsiViewFetch)(MSIHANDLE, MSIHANDLE *);
typedef UINT (WINAPI *PFN_MsiViewClose)(MSIHANDLE);
typedef UINT (WINAPI *PFN_MsiRecordGetStringW)(MSIHANDLE, UINT, LPWSTR, DWORD *);
typedef int  (WINAPI *PFN_MsiRecordGetInteger)(MSIHANDLE, UINT);
typedef UINT (WINAPI *PFN_MsiCloseHandle)(MSIHANDLE);

static PFN_MsiInstallProductW g_origMsiInstallProductW = NULL;
static BOOL g_msiPatchAttempted = FALSE;

#ifndef _WIN64
static BOOL patch_bytes_if_expected(BYTE *addr, const BYTE *expected, const BYTE *alreadyPatched,
                                    const BYTE *patch, size_t len, const char *label) {
    if (alreadyPatched && memcmp(addr, alreadyPatched, len) == 0) {
        return TRUE;
    }
    if (memcmp(addr, expected, len) != 0) {
        log_msg("[MSI] Byte mismatch in msi.dll (%s at %p)\n", label, addr);
        return FALSE;
    }
    DWORD op = 0;
    if (!VirtualProtect(addr, len, PAGE_EXECUTE_READWRITE, &op)) {
        log_msg("[MSI] VirtualProtect failed for %s: %lu\n", label, GetLastError());
        return FALSE;
    }
    memcpy(addr, patch, len);
    VirtualProtect(addr, len, op, &op);
    FlushInstructionCache(GetCurrentProcess(), addr, len);
    return TRUE;
}

static void patch_msi_in_memory(HMODULE hMsi) {
    if (!hMsi || g_msiPatchAttempted) return;
    g_msiPatchAttempted = TRUE;

    BYTE *base = (BYTE *)hMsi;
    // _disable_children (+0x50a1): check parent->ActionRequest > 0 instead of parent->Level <= installlevel
    static const BYTE origDisable[17] = {
        0x8b, 0x47, 0x1c, 0x85, 0xc0, 0x0f, 0x9f, 0xc1,
        0x39, 0xf0, 0x0f, 0x9e, 0xc2, 0x84, 0xd1, 0x75, 0xd8
    };
    static const BYTE newDisable[17] = {
        0x83, 0x7f, 0x2c, 0x00, 0x7f, 0xe3, 0x8b, 0x47, 0x1c,
        0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90
    };
    // _follow_parent (+0x5140): replace prologue with retl; nop so resolved states aren't clobbered
    static const BYTE origFollow[11] = {
        0x66, 0x90, 0x55, 0x89, 0xe5, 0x53, 0x57, 0x56, 0x83, 0xec, 0x30
    };
    static const BYTE newFollow[2] = { 0xc3, 0x90 };

    BOOL ok1 = patch_bytes_if_expected(base + 0x50a1, origDisable, newDisable, newDisable,
                                       sizeof(origDisable), "_disable_children");
    BOOL ok2 = FALSE;
    BYTE *pFollow = base + 0x5140;
    if (memcmp(pFollow, newFollow, sizeof(newFollow)) == 0) {
        ok2 = TRUE;
    } else if (memcmp(pFollow, origFollow, sizeof(origFollow)) == 0) {
        ok2 = patch_bytes_if_expected(pFollow, origFollow, NULL, newFollow,
                                      sizeof(newFollow), "_follow_parent");
    } else {
        log_msg("[MSI] Byte mismatch in msi.dll (_follow_parent at %p)\n", pFollow);
    }

    if (ok1 && ok2) {
        log_msg("[MSI] Patched msi.dll at %p (_disable_children + _follow_parent)\n", base);
    }
}
#endif

static BOOL find_cmd_param(const WCHAR *cmd, const WCHAR *key,
                           const WCHAR **outTokStart, const WCHAR **outValStart,
                           size_t *outValLen, const WCHAR **outTokEnd) {
    if (!cmd || !key) return FALSE;
    size_t keyLen = wcslen(key);
    const WCHAR *p = cmd;

    while (*p) {
        while (*p == L' ' || *p == L'\t') p++;
        if (!*p) break;

        const WCHAR *tokStart = p;
        if (_wcsnicmp(p, key, keyLen) == 0) {
            const WCHAR *valStart = p + keyLen;
            const WCHAR *valEnd = NULL;
            const WCHAR *tokEnd = NULL;
            if (*valStart == L'"') {
                valStart++;
                valEnd = wcschr(valStart, L'"');
                if (!valEnd) valEnd = valStart + wcslen(valStart);
                tokEnd = (*valEnd == L'"') ? (valEnd + 1) : valEnd;
            } else {
                valEnd = valStart;
                while (*valEnd && *valEnd != L' ' && *valEnd != L'\t') valEnd++;
                tokEnd = valEnd;
            }
            if (outTokStart) *outTokStart = tokStart;
            if (outValStart) *outValStart = valStart;
            if (outValLen) *outValLen = (size_t)(valEnd - valStart);
            if (outTokEnd) *outTokEnd = tokEnd;
            return TRUE;
        }

        while (*p && *p != L' ' && *p != L'\t') {
            if (*p == L'"') {
                p++;
                while (*p && *p != L'"') p++;
            }
            if (*p) p++;
        }
    }
    return FALSE;
}

typedef struct {
    WCHAR *name;
    WCHAR *parent;
    int level;
    int attrs;
    BOOL enabled;
} ZKFeatureItem;

static void free_feature_items(ZKFeatureItem *items, size_t count) {
    if (!items) return;
    for (size_t i = 0; i < count; i++) {
        free(items[i].name);
        free(items[i].parent);
    }
    free(items);
}

static int find_feature_index(const ZKFeatureItem *items, size_t count, const WCHAR *name) {
    if (!name || !name[0]) return -1;
    for (size_t i = 0; i < count; i++) {
        if (wcscmp(items[i].name, name) == 0) return (int)i;
    }
    for (size_t i = 0; i < count; i++) {
        if (_wcsicmp(items[i].name, name) == 0) return (int)i;
    }
    return -1;
}

static LPWSTR expand_addlocal_features(LPCWSTR szPackagePath, LPCWSTR szCommandLine) {
    const WCHAR *tokStart = NULL, *valStart = NULL, *tokEnd = NULL;
    size_t valLen = 0;
    if (!find_cmd_param(szCommandLine, L"ADDLOCAL=", &tokStart, &valStart, &valLen, &tokEnd)) {
        return NULL;
    }
    if (valLen == 0 || (valLen == 3 && _wcsnicmp(valStart, L"ALL", 3) == 0)) {
        return NULL;
    }

    HMODULE hMsi = GetModuleHandleW(L"msi.dll");
    if (!hMsi) return NULL;
    PFN_MsiOpenDatabaseW pOpenDb = (PFN_MsiOpenDatabaseW)GetProcAddress(hMsi, "MsiOpenDatabaseW");
    PFN_MsiDatabaseOpenViewW pOpenView = (PFN_MsiDatabaseOpenViewW)GetProcAddress(hMsi, "MsiDatabaseOpenViewW");
    PFN_MsiViewExecute pViewExec = (PFN_MsiViewExecute)GetProcAddress(hMsi, "MsiViewExecute");
    PFN_MsiViewFetch pViewFetch = (PFN_MsiViewFetch)GetProcAddress(hMsi, "MsiViewFetch");
    PFN_MsiViewClose pViewClose = (PFN_MsiViewClose)GetProcAddress(hMsi, "MsiViewClose");
    PFN_MsiRecordGetStringW pRecGetStr = (PFN_MsiRecordGetStringW)GetProcAddress(hMsi, "MsiRecordGetStringW");
    PFN_MsiRecordGetInteger pRecGetInt = (PFN_MsiRecordGetInteger)GetProcAddress(hMsi, "MsiRecordGetInteger");
    PFN_MsiCloseHandle pCloseHandle = (PFN_MsiCloseHandle)GetProcAddress(hMsi, "MsiCloseHandle");
    if (!pOpenDb || !pOpenView || !pViewExec || !pViewFetch || !pViewClose || !pRecGetStr || !pRecGetInt || !pCloseHandle) {
        return NULL;
    }

    MSIHANDLE hDb = 0;
    UINT err = pOpenDb(szPackagePath, (LPCWSTR)MSIDBOPEN_READONLY, &hDb);
    if (err != ERROR_SUCCESS || !hDb) {
        log_msg("[MSI] MsiOpenDatabaseW('%ls') failed: %u\n", szPackagePath, err);
        return NULL;
    }

    int installLevel = 100;
    MSIHANDLE hPropView = 0;
    if (pOpenView(hDb, L"SELECT `Value` FROM `Property` WHERE `Property`='INSTALLLEVEL'", &hPropView) == ERROR_SUCCESS && hPropView) {
        if (pViewExec(hPropView, 0) == ERROR_SUCCESS) {
            MSIHANDLE hPropRec = 0;
            if (pViewFetch(hPropView, &hPropRec) == ERROR_SUCCESS && hPropRec) {
                WCHAR lvlBuf[32] = {0};
                DWORD cch = 32;
                if (pRecGetStr(hPropRec, 1, lvlBuf, &cch) == ERROR_SUCCESS) {
                    int dbLvl = _wtoi(lvlBuf);
                    if (dbLvl > 0) installLevel = dbLvl;
                }
                pCloseHandle(hPropRec);
            }
        }
        pViewClose(hPropView);
        pCloseHandle(hPropView);
    }

    const WCHAR *cmdLvlStart = NULL;
    size_t cmdLvlLen = 0;
    if (find_cmd_param(szCommandLine, L"INSTALLLEVEL=", NULL, &cmdLvlStart, &cmdLvlLen, NULL) && cmdLvlLen > 0) {
        WCHAR buf[32] = {0};
        size_t n = cmdLvlLen < 31 ? cmdLvlLen : 31;
        wcsncpy(buf, cmdLvlStart, n);
        int cmdLvl = _wtoi(buf);
        if (cmdLvl > 0) installLevel = cmdLvl;
    }

    MSIHANDLE hView = 0;
    err = pOpenView(hDb, L"SELECT `Feature`, `Feature_Parent`, `Level`, `Attributes` FROM `Feature`", &hView);
    if (err != ERROR_SUCCESS || !hView) {
        log_msg("[MSI] MsiDatabaseOpenViewW(Feature) failed: %u\n", err);
        pCloseHandle(hDb);
        return NULL;
    }

    ZKFeatureItem *items = NULL;
    size_t count = 0, cap = 0;
    if (pViewExec(hView, 0) == ERROR_SUCCESS) {
        MSIHANDLE hRec = 0;
        while (pViewFetch(hView, &hRec) == ERROR_SUCCESS && hRec) {
            WCHAR nameBuf[256] = {0};
            WCHAR parentBuf[256] = {0};
            DWORD cchName = 256, cchParent = 256;
            if (pRecGetStr(hRec, 1, nameBuf, &cchName) == ERROR_SUCCESS && nameBuf[0]) {
                pRecGetStr(hRec, 2, parentBuf, &cchParent);
                int lvl = pRecGetInt(hRec, 3);
                int attrs = pRecGetInt(hRec, 4);
                if (lvl == (int)MSI_NULL_INTEGER) lvl = 0;
                if (attrs == (int)MSI_NULL_INTEGER) attrs = 0;

                if (count == cap) {
                    size_t newCap = cap ? cap * 2 : 256;
                    ZKFeatureItem *grown = (ZKFeatureItem *)realloc(items, newCap * sizeof(ZKFeatureItem));
                    if (!grown) {
                        pCloseHandle(hRec);
                        free_feature_items(items, count);
                        items = NULL;
                        count = 0;
                        break;
                    }
                    items = grown;
                    cap = newCap;
                }
                items[count].name = _wcsdup(nameBuf);
                items[count].parent = _wcsdup(parentBuf);
                items[count].level = lvl;
                items[count].attrs = attrs;
                items[count].enabled = FALSE;
                count++;
            }
            pCloseHandle(hRec);
        }
    }
    pViewClose(hView);
    pCloseHandle(hView);
    pCloseHandle(hDb);

    if (!items || count == 0) {
        free_feature_items(items, count);
        return NULL;
    }

    size_t origCount = 0;
    const WCHAR *cur = valStart;
    const WCHAR *end = valStart + valLen;
    while (cur < end) {
        const WCHAR *comma = cur;
        while (comma < end && *comma != L',') comma++;
        const WCHAR *s = cur, *e = comma;
        while (s < e && (*s == L' ' || *s == L'\t')) s++;
        while (e > s && (e[-1] == L' ' || e[-1] == L'\t')) e--;
        if (e > s) {
            size_t tlen = (size_t)(e - s);
            WCHAR tok[256];
            if (tlen < 256) {
                memcpy(tok, s, tlen * sizeof(WCHAR));
                tok[tlen] = 0;
                int idx = find_feature_index(items, count, tok);
                if (idx >= 0 && !items[idx].enabled) {
                    items[idx].enabled = TRUE;
                    origCount++;
                }
            }
        }
        cur = (comma < end) ? (comma + 1) : end;
    }

    if (origCount == 0) {
        free_feature_items(items, count);
        return NULL;
    }

    // Step A: enable all ancestor features of requested ADDLOCAL features
    BOOL changed = TRUE;
    while (changed) {
        changed = FALSE;
        for (size_t i = 0; i < count; i++) {
            if (items[i].enabled && items[i].parent[0]) {
                int pIdx = find_feature_index(items, count, items[i].parent);
                if (pIdx >= 0 && !items[pIdx].enabled) {
                    items[pIdx].enabled = TRUE;
                    changed = TRUE;
                }
            }
        }
    }

    // Step B: enable default-level (0 < Level <= installLevel) features under enabled parents
    changed = TRUE;
    while (changed) {
        changed = FALSE;
        for (size_t i = 0; i < count; i++) {
            if (!items[i].enabled && items[i].parent[0] &&
                items[i].level > 0 && items[i].level <= installLevel) {
                int pIdx = find_feature_index(items, count, items[i].parent);
                if (pIdx >= 0 && items[pIdx].enabled) {
                    items[i].enabled = TRUE;
                    changed = TRUE;
                }
            }
        }
    }

    size_t enabledCount = 0;
    size_t addLocalChars = wcslen(L"ADDLOCAL=");
    for (size_t i = 0; i < count; i++) {
        if (items[i].enabled) {
            enabledCount++;
            addLocalChars += wcslen(items[i].name) + 1;
        }
    }

    if (enabledCount <= origCount) {
        free_feature_items(items, count);
        return NULL;
    }

    size_t prefixLen = (size_t)(tokStart - szCommandLine);
    size_t suffixLen = wcslen(tokEnd);
    size_t totalChars = prefixLen + addLocalChars + suffixLen + 4;
    LPWSTR outCmd = (LPWSTR)malloc(totalChars * sizeof(WCHAR));
    if (!outCmd) {
        free_feature_items(items, count);
        return NULL;
    }

    WCHAR *w = outCmd;
    if (prefixLen > 0) {
        memcpy(w, szCommandLine, prefixLen * sizeof(WCHAR));
        w += prefixLen;
    }
    memcpy(w, L"ADDLOCAL=", 9 * sizeof(WCHAR));
    w += 9;

    BOOL first = TRUE;
    for (size_t i = 0; i < count; i++) {
        if (!items[i].enabled) continue;
        if (!first) *w++ = L',';
        first = FALSE;
        size_t flen = wcslen(items[i].name);
        memcpy(w, items[i].name, flen * sizeof(WCHAR));
        w += flen;
    }
    memcpy(w, tokEnd, (suffixLen + 1) * sizeof(WCHAR));

    log_msg("[MSI] Expanded ADDLOCAL for '%ls' (INSTALLLEVEL=%d): %zu -> %zu features\n",
            szPackagePath, installLevel, origCount, enabledCount);

    free_feature_items(items, count);
    return outCmd;
}

static UINT WINAPI Hooked_MsiInstallProductW(LPCWSTR szPackagePath, LPCWSTR szCommandLine) {
    log_msg("[MSI] MsiInstallProductW pkg='%ls' cmd='%ls'\n",
            szPackagePath ? szPackagePath : L"(null)",
            szCommandLine ? szCommandLine : L"(null)");

#ifndef _WIN64
    HMODULE hMsi = GetModuleHandleW(L"msi.dll");
    if (hMsi) patch_msi_in_memory(hMsi);
#endif

    LPWSTR expandedCmd = NULL;
    if (szPackagePath && szCommandLine) {
        expandedCmd = expand_addlocal_features(szPackagePath, szCommandLine);
    }

    LPCWSTR finalCmd = expandedCmd ? expandedCmd : szCommandLine;
    UINT res;
    if (g_origMsiInstallProductW) {
        res = g_origMsiInstallProductW(szPackagePath, finalCmd);
    } else {
        HMODULE m = GetModuleHandleW(L"msi.dll");
        PFN_MsiInstallProductW fn = m ? (PFN_MsiInstallProductW)GetProcAddress(m, "MsiInstallProductW") : NULL;
        res = fn ? fn(szPackagePath, finalCmd) : ERROR_CALL_NOT_IMPLEMENTED;
    }

    log_msg("[MSI] MsiInstallProductW returned %u\n", res);
    if (expandedCmd) free(expandedCmd);
    return res;
}

static void *resolve_hook_for_import(const char *name) {
    if (strcmp(name, "CreateProcessW") == 0) return (void *)Hooked_CreateProcessW;
    if (strcmp(name, "RegQueryValueExW") == 0) return (void *)Hooked_RegQueryValueExW;
    if (strcmp(name, "RegQueryValueExA") == 0) return (void *)Hooked_RegQueryValueExA;
    if (strcmp(name, "SendMessageW") == 0) return (void *)Hooked_SendMessageW;
    if (strcmp(name, "SendMessageA") == 0) return (void *)Hooked_SendMessageA;
    if (strcmp(name, "InternetOpenUrlW") == 0) return (void *)Hooked_InternetOpenUrlW;
    if (strcmp(name, "InternetOpenUrlA") == 0) return (void *)Hooked_InternetOpenUrlA;
    if (strcmp(name, "InternetConnectW") == 0) return (void *)Hooked_InternetConnectW;
    if (strcmp(name, "InternetConnectA") == 0) return (void *)Hooked_InternetConnectA;
    if (strcmp(name, "getaddrinfo") == 0) return (void *)Hooked_getaddrinfo;
    if (!g_isProducer) {
        if (strcmp(name, "MsiInstallProductW") == 0) return (void *)Hooked_MsiInstallProductW;
    }
    if (g_isProducer) {
        if (strcmp(name, "BitBlt") == 0) return (void *)Hooked_BitBlt;
        if (strcmp(name, "StretchBlt") == 0) return (void *)Hooked_StretchBlt;
        if (strcmp(name, "SetDIBitsToDevice") == 0) return (void *)Hooked_SetDIBitsToDevice;
        if (strcmp(name, "StretchDIBits") == 0) return (void *)Hooked_StretchDIBits;
        if (strcmp(name, "UpdateLayeredWindow") == 0) return (void *)Hooked_UpdateLayeredWindow;
    }
    return NULL;
}

static void patch_thunk_array(HMODULE mod, BYTE *base, const char *dll,
                              IMAGE_THUNK_DATA *oft, IMAGE_THUNK_DATA *ft) {
    if (!oft || !ft) return;
    BOOL isMsi = (_stricmp(dll, "msi.dll") == 0);
    BOOL isAdvapi = (_stricmp(dll, "advapi32.dll") == 0);
    BOOL isK32 = (_stricmp(dll, "kernel32.dll") == 0);
    BOOL isWininet = (_stricmp(dll, "wininet.dll") == 0);
    BOOL isWs2 = (_stricmp(dll, "ws2_32.dll") == 0 || _stricmp(dll, "wsock32.dll") == 0);
    if (!isMsi && !isAdvapi && !isK32 && !isWininet && !isWs2 && _stricmp(dll, "gdi32.dll") != 0 && _stricmp(dll, "user32.dll") != 0) return;

    for (; oft->u1.AddressOfData; oft++, ft++) {
        void *hook = NULL;
        if (IMAGE_SNAP_BY_ORDINAL(oft->u1.Ordinal)) {
            if (isMsi && !g_isProducer) {
                ULONG_PTR ord = IMAGE_ORDINAL(oft->u1.Ordinal);
                if (ord == 88 || (g_origMsiInstallProductW && (void *)(uintptr_t)ft->u1.Function == (void *)g_origMsiInstallProductW)) {
                    hook = (void *)Hooked_MsiInstallProductW;
                }
            }
        } else {
            const char *name = (const char *)((IMAGE_IMPORT_BY_NAME *)(base + oft->u1.AddressOfData))->Name;
            hook = resolve_hook_for_import(name);
        }

        if (hook && (void *)(uintptr_t)ft->u1.Function != hook) {
            DWORD op;
            if (VirtualProtect(&ft->u1.Function, sizeof(ULONG_PTR), PAGE_READWRITE, &op)) {
                ft->u1.Function = (ULONG_PTR)(uintptr_t)hook;
                VirtualProtect(&ft->u1.Function, sizeof(ULONG_PTR), op, &op);
                if (hook == (void *)Hooked_MsiInstallProductW) {
                    log_msg("[MSI] Hooked MsiInstallProductW in module %p\n", mod);
                }
            }
        }
    }
}

static void patch_module_iat(HMODULE mod) {
    if (!mod || mod == g_hSelfModule) return;
    BYTE *base = (BYTE *)mod;
    IMAGE_DOS_HEADER *dos = (IMAGE_DOS_HEADER *)base;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return;
    IMAGE_NT_HEADERS *nt = (IMAGE_NT_HEADERS *)(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) return;
    DWORD rva = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress;
    if (!rva) return;
    IMAGE_IMPORT_DESCRIPTOR *imp = (IMAGE_IMPORT_DESCRIPTOR *)(base + rva);
    for (; imp->Name; imp++) {
        if (!imp->FirstThunk) continue;
        const char *dll = (const char *)(base + imp->Name);
        IMAGE_THUNK_DATA *oft = (IMAGE_THUNK_DATA *)(base + (imp->OriginalFirstThunk ? imp->OriginalFirstThunk : imp->FirstThunk));
        IMAGE_THUNK_DATA *ft = (IMAGE_THUNK_DATA *)(base + imp->FirstThunk);
        patch_thunk_array(mod, base, dll, oft, ft);
    }
}

static void patch_all_loaded_modules(void) {
    HMODULE mods[512];
    DWORD needed = 0;
    if (EnumProcessModules(GetCurrentProcess(), mods, sizeof(mods), &needed)) {
        DWORD count = needed / sizeof(HMODULE);
        if (count > 512) count = 512;
        for (DWORD i = 0; i < count; i++) {
            patch_module_iat(mods[i]);
        }
    }
}

static DWORD WINAPI IatHookWatchThread(LPVOID param) {
    HMODULE usr = GetModuleHandleW(L"user32.dll");
    if (!usr) usr = LoadLibraryW(L"user32.dll");
    if (usr) {
        g_origSendMessageW = (PFN_SendMessageW)GetProcAddress(usr, "SendMessageW");
        g_origSendMessageA = (PFN_SendMessageA)GetProcAddress(usr, "SendMessageA");
        g_origULW = (PFN_UpdateLayeredWindow)GetProcAddress(usr, "UpdateLayeredWindow");
    }
    HMODULE adv = GetModuleHandleW(L"advapi32.dll");
    if (!adv) adv = LoadLibraryW(L"advapi32.dll");
    if (adv) {
        g_origRegQueryValueExW = (PFN_RegQueryValueExW)GetProcAddress(adv, "RegQueryValueExW");
        g_origRegQueryValueExA = (PFN_RegQueryValueExA)GetProcAddress(adv, "RegQueryValueExA");
    }
    HMODULE k32 = GetModuleHandleW(L"kernel32.dll");
    if (k32) {
        g_origCreateProcessW = (PFN_CreateProcessW)GetProcAddress(k32, "CreateProcessW");
    }
    HMODULE hInet = GetModuleHandleW(L"wininet.dll");
    if (hInet) {
        g_origInternetOpenUrlW = (PFN_InternetOpenUrlW)GetProcAddress(hInet, "InternetOpenUrlW");
        g_origInternetOpenUrlA = (PFN_InternetOpenUrlA)GetProcAddress(hInet, "InternetOpenUrlA");
        g_origInternetConnectW = (PFN_InternetConnectW)GetProcAddress(hInet, "InternetConnectW");
        g_origInternetConnectA = (PFN_InternetConnectA)GetProcAddress(hInet, "InternetConnectA");
    }
    HMODULE hWs2 = GetModuleHandleW(L"ws2_32.dll");
    if (hWs2) {
        g_origGetaddrinfo = (PFN_getaddrinfo)GetProcAddress(hWs2, "getaddrinfo");
    }
    if (!g_isProducer) {
        HMODULE hMsi = GetModuleHandleW(L"msi.dll");
        if (!hMsi) hMsi = LoadLibraryW(L"msi.dll");
        if (hMsi) {
            g_origMsiInstallProductW = (PFN_MsiInstallProductW)GetProcAddress(hMsi, "MsiInstallProductW");
#ifndef _WIN64
            patch_msi_in_memory(hMsi);
#endif
        }
    }
    if (g_isProducer) {
        HMODULE gdi = GetModuleHandleW(L"gdi32.dll");
        if (gdi) {
            g_origBitBlt = (PFN_BitBlt)GetProcAddress(gdi, "BitBlt");
            g_origStretchBlt = (PFN_StretchBlt)GetProcAddress(gdi, "StretchBlt");
            g_origSetDIBitsToDevice = (PFN_SetDIBitsToDevice)GetProcAddress(gdi, "SetDIBitsToDevice");
            g_origStretchDIBits = (PFN_StretchDIBits)GetProcAddress(gdi, "StretchDIBits");
        }
        log_msg("[Bridge Producer] IatHookWatchThread started...\n");
    } else {
        log_msg("[DeadlockGuard] IatHookWatchThread started in PID %lu\n", GetCurrentProcessId());
    }

    for (int iter = 0; iter < 10; iter++) {
        patch_all_loaded_modules();
        Sleep(200);
    }
    while (1) {
        Sleep(30000);
        patch_all_loaded_modules();
    }
    return 0;
}

// ----------------------------------------------------------------------------
// Consumer Role (Legacy GDI Producer-Consumer SHM fallback; idle when CDP overlay active)
// ----------------------------------------------------------------------------
static DWORD WINAPI ConsumerBlitThread(LPVOID param) {
    DWORD myPid = GetCurrentProcessId();
    LONG lastSeqs[ZK_MAX_SURFACES] = {0};
    log_msg("[Bridge Consumer] ConsumerBlitThread running in PID %lu\n", myPid);

    BOOL anyActive = FALSE;
    while (1) {
        Sleep(anyActive ? 16 : 250);
        if (!g_shm) continue;

        anyActive = FALSE;
        for (int i = 0; i < ZK_MAX_SURFACES; i++) {
            ZKSurfaceSlot *slot = &g_shm->slots[i];
            if (!slot->active || slot->width <= 0 || slot->height <= 0) continue;
            anyActive = TRUE;

            HWND host_hwnd = (HWND)(uintptr_t)slot->host_hwnd;
            if (!IsWindow(host_hwnd)) continue;

            DWORD pid = 0;
            GetWindowThreadProcessId(host_hwnd, &pid);
            if (pid != myPid) continue;

            HWND blitTarget = host_hwnd;
            RECT rcHost;
            GetWindowRect(host_hwnd, &rcHost);
            int hostW = rcHost.right - rcHost.left;
            int hostH = rcHost.bottom - rcHost.top;

            if (hostW <= 0 || hostH <= 0) {
                HWND child = FindWindowExW(host_hwnd, NULL, L"Chrome_WidgetWin_0", NULL);
                if (child) {
                    blitTarget = child;
                    GetWindowRect(child, &rcHost);
                    hostW = rcHost.right - rcHost.left;
                    hostH = rcHost.bottom - rcHost.top;
                }
            }

            LONG curSeq = slot->frame_seq;
            if (curSeq != lastSeqs[i] || curSeq % 120 == 1) {
                lastSeqs[i] = curSeq;

                BITMAPINFO bmi = {0};
                bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
                bmi.bmiHeader.biWidth = slot->width;
                bmi.bmiHeader.biHeight = -slot->height;
                bmi.bmiHeader.biPlanes = 1;
                bmi.bmiHeader.biBitCount = 32;
                bmi.bmiHeader.biCompression = BI_RGB;

                HDC hdc = GetDC(blitTarget);
                if (hdc) {
                    if (hostW > 0 && hostH > 0 && (hostW != slot->width || hostH != slot->height)) {
                        StretchDIBits(hdc, 0, 0, hostW, hostH,
                                      0, 0, slot->width, slot->height,
                                      slot->pixels, &bmi, DIB_RGB_COLORS, SRCCOPY);
                    } else {
                        SetDIBitsToDevice(hdc, 0, 0, slot->width, slot->height,
                                          0, 0, 0, slot->height,
                                          slot->pixels, &bmi, DIB_RGB_COLORS);
                    }
                    ReleaseDC(blitTarget, hdc);
                }
            }
        }
    }
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    if (fdwReason == DLL_PROCESS_ATTACH) {
        g_hSelfModule = hinstDLL;
        DisableThreadLibraryCalls(hinstDLL);
        load_real_version();
        init_shm();

        WCHAR exePath[MAX_PATH] = {0};
        GetModuleFileNameW(NULL, exePath, MAX_PATH);

        if (wcsstr(exePath, L"msedgewebview2") != NULL || wcsstr(exePath, L"msedge") != NULL) {
            g_isProducer = TRUE;
            log_msg("[Bridge] Process '%ls' detected as PRODUCER\n", exePath);
            CreateThread(NULL, 0, IatHookWatchThread, NULL, 0, NULL);
        } else {
            g_isProducer = FALSE;
            log_msg("[Bridge] Process '%ls' detected as CONSUMER\n", exePath);
            CreateThread(NULL, 0, IatHookWatchThread, NULL, 0, NULL);
            CreateThread(NULL, 0, ConsumerBlitThread, NULL, 0, NULL);
        }
    }
    return TRUE;
}
