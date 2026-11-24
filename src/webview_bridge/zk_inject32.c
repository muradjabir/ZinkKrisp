#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdlib.h>
#include <wchar.h>

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmdLine, int nShow) {
    if (!lpCmdLine || !*lpCmdLine) return 1;
    DWORD pid = (DWORD)strtoul(lpCmdLine, NULL, 10);
    if (!pid) return 1;
    HANDLE hProc = OpenProcess(PROCESS_CREATE_THREAD | PROCESS_QUERY_INFORMATION | PROCESS_VM_OPERATION | PROCESS_VM_WRITE | PROCESS_VM_READ, FALSE, pid);
    if (!hProc) return 1;
    const WCHAR* dllPath = L"C:\\windows\\syswow64\\zk_bridge.dll";
    SIZE_T sz = (wcslen(dllPath) + 1) * sizeof(WCHAR);
    LPVOID remoteMem = VirtualAllocEx(hProc, NULL, sz, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (remoteMem) {
        if (WriteProcessMemory(hProc, remoteMem, dllPath, sz, NULL)) {
            HMODULE hK32 = GetModuleHandleW(L"kernel32.dll");
            LPTHREAD_START_ROUTINE pLoadLib = (LPTHREAD_START_ROUTINE)GetProcAddress(hK32, "LoadLibraryW");
            if (pLoadLib) {
                HANDLE hThread = CreateRemoteThread(hProc, NULL, 0, pLoadLib, remoteMem, 0, NULL);
                if (hThread) CloseHandle(hThread);
            }
        }
    }
    CloseHandle(hProc);
    return 0;
}
