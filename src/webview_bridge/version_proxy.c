#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>

static HMODULE g_hRealVersion = NULL;

typedef BOOL (WINAPI *PFN_GetFileVersionInfoA)(LPCSTR, DWORD, DWORD, LPVOID);
typedef BOOL (WINAPI *PFN_GetFileVersionInfoExA)(DWORD, LPCSTR, DWORD, DWORD, LPVOID);
typedef BOOL (WINAPI *PFN_GetFileVersionInfoExW)(DWORD, LPCWSTR, DWORD, DWORD, LPVOID);
typedef DWORD (WINAPI *PFN_GetFileVersionInfoSizeA)(LPCSTR, LPDWORD);
typedef DWORD (WINAPI *PFN_GetFileVersionInfoSizeExA)(DWORD, LPCSTR, LPDWORD);
typedef DWORD (WINAPI *PFN_GetFileVersionInfoSizeExW)(DWORD, LPCWSTR, LPDWORD);
typedef DWORD (WINAPI *PFN_GetFileVersionInfoSizeW)(LPCWSTR, LPDWORD);
typedef BOOL (WINAPI *PFN_GetFileVersionInfoW)(LPCWSTR, DWORD, DWORD, LPVOID);
typedef DWORD (WINAPI *PFN_VerFindFileA)(DWORD, LPSTR, LPSTR, LPSTR, LPSTR, PUINT, LPSTR, PUINT);
typedef DWORD (WINAPI *PFN_VerFindFileW)(DWORD, LPWSTR, LPWSTR, LPWSTR, LPWSTR, PUINT, LPWSTR, PUINT);
typedef DWORD (WINAPI *PFN_VerInstallFileA)(DWORD, LPSTR, LPSTR, LPSTR, LPSTR, LPSTR, LPSTR, PUINT);
typedef DWORD (WINAPI *PFN_VerInstallFileW)(DWORD, LPWSTR, LPWSTR, LPWSTR, LPWSTR, LPWSTR, LPWSTR, PUINT);
typedef BOOL (WINAPI *PFN_VerQueryValueA)(LPCVOID, LPCSTR, LPVOID*, PUINT);
typedef BOOL (WINAPI *PFN_VerQueryValueW)(LPCVOID, LPCWSTR, LPVOID*, PUINT);

static PFN_GetFileVersionInfoA pfnGetFileVersionInfoA = NULL;
static PFN_GetFileVersionInfoExA pfnGetFileVersionInfoExA = NULL;
static PFN_GetFileVersionInfoExW pfnGetFileVersionInfoExW = NULL;
static PFN_GetFileVersionInfoSizeA pfnGetFileVersionInfoSizeA = NULL;
static PFN_GetFileVersionInfoSizeExA pfnGetFileVersionInfoSizeExA = NULL;
static PFN_GetFileVersionInfoSizeExW pfnGetFileVersionInfoSizeExW = NULL;
static PFN_GetFileVersionInfoSizeW pfnGetFileVersionInfoSizeW = NULL;
static PFN_GetFileVersionInfoW pfnGetFileVersionInfoW = NULL;
static PFN_VerFindFileA pfnVerFindFileA = NULL;
static PFN_VerFindFileW pfnVerFindFileW = NULL;
static PFN_VerInstallFileA pfnVerInstallFileA = NULL;
static PFN_VerInstallFileW pfnVerInstallFileW = NULL;
static PFN_VerQueryValueA pfnVerQueryValueA = NULL;
static PFN_VerQueryValueW pfnVerQueryValueW = NULL;

void load_real_version(void) {
    if (g_hRealVersion) return;
    g_hRealVersion = LoadLibraryA("C:\\windows\\system32\\version_real.dll");
    if (!g_hRealVersion) {
        g_hRealVersion = LoadLibraryA("version_real.dll");
    }
    if (g_hRealVersion) {
        pfnGetFileVersionInfoA = (PFN_GetFileVersionInfoA)GetProcAddress(g_hRealVersion, "GetFileVersionInfoA");
        pfnGetFileVersionInfoExA = (PFN_GetFileVersionInfoExA)GetProcAddress(g_hRealVersion, "GetFileVersionInfoExA");
        pfnGetFileVersionInfoExW = (PFN_GetFileVersionInfoExW)GetProcAddress(g_hRealVersion, "GetFileVersionInfoExW");
        pfnGetFileVersionInfoSizeA = (PFN_GetFileVersionInfoSizeA)GetProcAddress(g_hRealVersion, "GetFileVersionInfoSizeA");
        pfnGetFileVersionInfoSizeExA = (PFN_GetFileVersionInfoSizeExA)GetProcAddress(g_hRealVersion, "GetFileVersionInfoSizeExA");
        pfnGetFileVersionInfoSizeExW = (PFN_GetFileVersionInfoSizeExW)GetProcAddress(g_hRealVersion, "GetFileVersionInfoSizeExW");
        pfnGetFileVersionInfoSizeW = (PFN_GetFileVersionInfoSizeW)GetProcAddress(g_hRealVersion, "GetFileVersionInfoSizeW");
        pfnGetFileVersionInfoW = (PFN_GetFileVersionInfoW)GetProcAddress(g_hRealVersion, "GetFileVersionInfoW");
        pfnVerFindFileA = (PFN_VerFindFileA)GetProcAddress(g_hRealVersion, "VerFindFileA");
        pfnVerFindFileW = (PFN_VerFindFileW)GetProcAddress(g_hRealVersion, "VerFindFileW");
        pfnVerInstallFileA = (PFN_VerInstallFileA)GetProcAddress(g_hRealVersion, "VerInstallFileA");
        pfnVerInstallFileW = (PFN_VerInstallFileW)GetProcAddress(g_hRealVersion, "VerInstallFileW");
        pfnVerQueryValueA = (PFN_VerQueryValueA)GetProcAddress(g_hRealVersion, "VerQueryValueA");
        pfnVerQueryValueW = (PFN_VerQueryValueW)GetProcAddress(g_hRealVersion, "VerQueryValueW");
    }
}

__declspec(dllexport) BOOL WINAPI GetFileVersionInfoA(LPCSTR filename, DWORD handle, DWORD len, LPVOID data) {
    load_real_version();
    if (pfnGetFileVersionInfoA) return pfnGetFileVersionInfoA(filename, handle, len, data);
    return FALSE;
}

__declspec(dllexport) BOOL WINAPI GetFileVersionInfoExA(DWORD flags, LPCSTR filename, DWORD handle, DWORD len, LPVOID data) {
    load_real_version();
    if (pfnGetFileVersionInfoExA) return pfnGetFileVersionInfoExA(flags, filename, handle, len, data);
    return FALSE;
}

__declspec(dllexport) BOOL WINAPI GetFileVersionInfoExW(DWORD flags, LPCWSTR filename, DWORD handle, DWORD len, LPVOID data) {
    load_real_version();
    if (pfnGetFileVersionInfoExW) return pfnGetFileVersionInfoExW(flags, filename, handle, len, data);
    return FALSE;
}

__declspec(dllexport) DWORD WINAPI GetFileVersionInfoSizeA(LPCSTR filename, LPDWORD handle) {
    load_real_version();
    if (pfnGetFileVersionInfoSizeA) return pfnGetFileVersionInfoSizeA(filename, handle);
    return 0;
}

__declspec(dllexport) DWORD WINAPI GetFileVersionInfoSizeExA(DWORD flags, LPCSTR filename, LPDWORD handle) {
    load_real_version();
    if (pfnGetFileVersionInfoSizeExA) return pfnGetFileVersionInfoSizeExA(flags, filename, handle);
    return 0;
}

__declspec(dllexport) DWORD WINAPI GetFileVersionInfoSizeExW(DWORD flags, LPCWSTR filename, LPDWORD handle) {
    load_real_version();
    if (pfnGetFileVersionInfoSizeExW) return pfnGetFileVersionInfoSizeExW(flags, filename, handle);
    return 0;
}

__declspec(dllexport) DWORD WINAPI GetFileVersionInfoSizeW(LPCWSTR filename, LPDWORD handle) {
    load_real_version();
    if (pfnGetFileVersionInfoSizeW) return pfnGetFileVersionInfoSizeW(filename, handle);
    return 0;
}

__declspec(dllexport) BOOL WINAPI GetFileVersionInfoW(LPCWSTR filename, DWORD handle, DWORD len, LPVOID data) {
    load_real_version();
    if (pfnGetFileVersionInfoW) return pfnGetFileVersionInfoW(filename, handle, len, data);
    return FALSE;
}

__declspec(dllexport) DWORD WINAPI VerFindFileA(DWORD flags, LPSTR filename, LPSTR windir, LPSTR appdir, LPSTR curdir, PUINT curlen, LPSTR destdir, PUINT destlen) {
    load_real_version();
    if (pfnVerFindFileA) return pfnVerFindFileA(flags, filename, windir, appdir, curdir, curlen, destdir, destlen);
    return 0;
}

__declspec(dllexport) DWORD WINAPI VerFindFileW(DWORD flags, LPWSTR filename, LPWSTR windir, LPWSTR appdir, LPWSTR curdir, PUINT curlen, LPWSTR destdir, PUINT destlen) {
    load_real_version();
    if (pfnVerFindFileW) return pfnVerFindFileW(flags, filename, windir, appdir, curdir, curlen, destdir, destlen);
    return 0;
}

__declspec(dllexport) DWORD WINAPI VerInstallFileA(DWORD flags, LPSTR srcname, LPSTR destname, LPSTR srcdir, LPSTR destdir, LPSTR curdir, LPSTR tmpfile, PUINT tmplen) {
    load_real_version();
    if (pfnVerInstallFileA) return pfnVerInstallFileA(flags, srcname, destname, srcdir, destdir, curdir, tmpfile, tmplen);
    return 0;
}

__declspec(dllexport) DWORD WINAPI VerInstallFileW(DWORD flags, LPWSTR srcname, LPWSTR destname, LPWSTR srcdir, LPWSTR destdir, LPWSTR curdir, LPWSTR tmpfile, PUINT tmplen) {
    load_real_version();
    if (pfnVerInstallFileW) return pfnVerInstallFileW(flags, srcname, destname, srcdir, destdir, curdir, tmpfile, tmplen);
    return 0;
}

__declspec(dllexport) BOOL WINAPI VerQueryValueA(LPCVOID block, LPCSTR subblock, LPVOID *buffer, PUINT len) {
    load_real_version();
    if (pfnVerQueryValueA) return pfnVerQueryValueA(block, subblock, buffer, len);
    return FALSE;
}

__declspec(dllexport) BOOL WINAPI VerQueryValueW(LPCVOID block, LPCWSTR subblock, LPVOID *buffer, PUINT len) {
    load_real_version();
    if (pfnVerQueryValueW) return pfnVerQueryValueW(block, subblock, buffer, len);
    return FALSE;
}
void init_version_proxy_loader(void) __attribute__((constructor));
void init_version_proxy_loader(void) {
    load_real_version();
}
