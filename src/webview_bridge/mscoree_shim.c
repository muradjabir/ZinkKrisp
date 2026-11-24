#define WIN32_LEAN_AND_MEAN
#include <windows.h>

static volatile HMODULE g_mscoreei = NULL;

static HMODULE GetMscoreei(void) {
    HMODULE h = g_mscoreei;
    if (!h) {
        h = LoadLibraryW(L"C:\\windows\\Microsoft.NET\\Framework64\\v4.0.30319\\mscoreei.dll");
        g_mscoreei = h;
    }
    return h;
}

__attribute__((used)) FARPROC ResolveByName(const char *name) {
    HMODULE h = GetMscoreei();
    return h ? GetProcAddress(h, name) : NULL;
}

__attribute__((used)) FARPROC ResolveByOrd(ULONG_PTR ord) {
    HMODULE h = GetMscoreei();
    return h ? GetProcAddress(h, (LPCSTR)ord) : NULL;
}

BOOL WINAPI ord_142_GetVersionExW(LPOSVERSIONINFOW lpVersionInformation) {
    return GetVersionExW(lpVersionInformation);
}

typedef HRESULT (WINAPI *PFN_CLRCreateInstance)(REFCLSID, REFIID, LPVOID*);
static const GUID kCLSID_CLRMetaHost = {0x9280188d,0x0e8e,0x4867,{0xb3,0x0c,0x7f,0xa8,0x38,0x84,0xe8,0xde}};

HRESULT WINAPI GetCLRMetaHost(REFIID riid, LPVOID *ppInterface) {
    PFN_CLRCreateInstance fn = (PFN_CLRCreateInstance)ResolveByName("CLRCreateInstance");
    if (!fn) return E_NOTIMPL;
    return fn(&kCLSID_CLRMetaHost, riid, ppInterface);
}

HRESULT WINAPI _CorValidateImage(PVOID *ImageBase, LPCWSTR FileName) {
    return S_OK;
}

VOID WINAPI _CorImageUnloading(PVOID ImageBase) {
}

BOOL WINAPI DllMain(HINSTANCE hInst, DWORD reason, LPVOID reserved) {
    return TRUE;
}

__attribute__((used)) const char name_stub_17[] = "InitErrors";
__attribute__((used)) FARPROC ptr_stub_17 = NULL;
void stub_17(void);
__asm__(
    ".globl stub_17\n"
    "stub_17:\n"
    "  movq ptr_stub_17(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_17(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_17(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_18[] = "PostError";
__attribute__((used)) FARPROC ptr_stub_18 = NULL;
void stub_18(void);
__asm__(
    ".globl stub_18\n"
    "stub_18:\n"
    "  movq ptr_stub_18(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_18(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_18(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_19[] = "InitSSAutoEnterThread";
__attribute__((used)) FARPROC ptr_stub_19 = NULL;
void stub_19(void);
__asm__(
    ".globl stub_19\n"
    "stub_19:\n"
    "  movq ptr_stub_19(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_19(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_19(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_20[] = "UpdateError";
__attribute__((used)) FARPROC ptr_stub_20 = NULL;
void stub_20(void);
__asm__(
    ".globl stub_20\n"
    "stub_20:\n"
    "  movq ptr_stub_20(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_20(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_20(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_21[] = "CloseCtrs";
__attribute__((used)) FARPROC ptr_stub_21 = NULL;
void stub_21(void);
__asm__(
    ".globl stub_21\n"
    "stub_21:\n"
    "  movq ptr_stub_21(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_21(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_21(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_22[] = "LoadStringRC";
__attribute__((used)) FARPROC ptr_stub_22 = NULL;
void stub_22(void);
__asm__(
    ".globl stub_22\n"
    "stub_22:\n"
    "  movq ptr_stub_22(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_22(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_22(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_23[] = "ReOpenMetaDataWithMemory";
__attribute__((used)) FARPROC ptr_stub_23 = NULL;
void stub_23(void);
__asm__(
    ".globl stub_23\n"
    "stub_23:\n"
    "  movq ptr_stub_23(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_23(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_23(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) FARPROC ptr_stub_24 = NULL;
void stub_24(void);
__asm__(
    ".globl stub_24\n"
    "stub_24:\n"
    "  movq ptr_stub_24(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  movq $24, %rcx\n"
    "  call ResolveByOrd\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_24(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_25[] = "CollectCtrs";
__attribute__((used)) FARPROC ptr_stub_25 = NULL;
void stub_25(void);
__asm__(
    ".globl stub_25\n"
    "stub_25:\n"
    "  movq ptr_stub_25(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_25(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_25(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_26[] = "CorDllMainWorker";
__attribute__((used)) FARPROC ptr_stub_26 = NULL;
void stub_26(void);
__asm__(
    ".globl stub_26\n"
    "stub_26:\n"
    "  movq ptr_stub_26(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_26(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_26(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_27[] = "EEDllGetClassObjectFromClass";
__attribute__((used)) FARPROC ptr_stub_27 = NULL;
void stub_27(void);
__asm__(
    ".globl stub_27\n"
    "stub_27:\n"
    "  movq ptr_stub_27(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_27(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_27(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_28[] = "GetPrivateContextsPerfCounters";
__attribute__((used)) FARPROC ptr_stub_28 = NULL;
void stub_28(void);
__asm__(
    ".globl stub_28\n"
    "stub_28:\n"
    "  movq ptr_stub_28(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_28(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_28(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_29[] = "GetProcessExecutableHeap";
__attribute__((used)) FARPROC ptr_stub_29 = NULL;
void stub_29(void);
__asm__(
    ".globl stub_29\n"
    "stub_29:\n"
    "  movq ptr_stub_29(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_29(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_29(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_30[] = "GetStartupFlags";
__attribute__((used)) FARPROC ptr_stub_30 = NULL;
void stub_30(void);
__asm__(
    ".globl stub_30\n"
    "stub_30:\n"
    "  movq ptr_stub_30(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_30(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_30(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_31[] = "GetTargetForVTableEntry";
__attribute__((used)) FARPROC ptr_stub_31 = NULL;
void stub_31(void);
__asm__(
    ".globl stub_31\n"
    "stub_31:\n"
    "  movq ptr_stub_31(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_31(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_31(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_32[] = "GetTokenForVTableEntry";
__attribute__((used)) FARPROC ptr_stub_32 = NULL;
void stub_32(void);
__asm__(
    ".globl stub_32\n"
    "stub_32:\n"
    "  movq ptr_stub_32(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_32(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_32(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_33[] = "LogHelp_LogAssert";
__attribute__((used)) FARPROC ptr_stub_33 = NULL;
void stub_33(void);
__asm__(
    ".globl stub_33\n"
    "stub_33:\n"
    "  movq ptr_stub_33(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_33(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_33(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_34[] = "LogHelp_NoGuiOnAssert";
__attribute__((used)) FARPROC ptr_stub_34 = NULL;
void stub_34(void);
__asm__(
    ".globl stub_34\n"
    "stub_34:\n"
    "  movq ptr_stub_34(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_34(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_34(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_35[] = "LogHelp_TerminateOnAssert";
__attribute__((used)) FARPROC ptr_stub_35 = NULL;
void stub_35(void);
__asm__(
    ".globl stub_35\n"
    "stub_35:\n"
    "  movq ptr_stub_35(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_35(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_35(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_36[] = "OpenCtrs";
__attribute__((used)) FARPROC ptr_stub_36 = NULL;
void stub_36(void);
__asm__(
    ".globl stub_36\n"
    "stub_36:\n"
    "  movq ptr_stub_36(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_36(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_36(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_37[] = "SetTargetForVTableEntry";
__attribute__((used)) FARPROC ptr_stub_37 = NULL;
void stub_37(void);
__asm__(
    ".globl stub_37\n"
    "stub_37:\n"
    "  movq ptr_stub_37(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_37(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_37(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_38[] = "CLRCreateInstance";
__attribute__((used)) FARPROC ptr_stub_38 = NULL;
void stub_38(void);
__asm__(
    ".globl stub_38\n"
    "stub_38:\n"
    "  movq ptr_stub_38(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_38(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_38(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_39[] = "CallFunctionShim";
__attribute__((used)) FARPROC ptr_stub_39 = NULL;
void stub_39(void);
__asm__(
    ".globl stub_39\n"
    "stub_39:\n"
    "  movq ptr_stub_39(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_39(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_39(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_40[] = "ClrCreateManagedInstance";
__attribute__((used)) FARPROC ptr_stub_40 = NULL;
void stub_40(void);
__asm__(
    ".globl stub_40\n"
    "stub_40:\n"
    "  movq ptr_stub_40(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_40(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_40(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_41[] = "CoEEShutDownCOM";
__attribute__((used)) FARPROC ptr_stub_41 = NULL;
void stub_41(void);
__asm__(
    ".globl stub_41\n"
    "stub_41:\n"
    "  movq ptr_stub_41(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_41(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_41(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_42[] = "CoInitializeCor";
__attribute__((used)) FARPROC ptr_stub_42 = NULL;
void stub_42(void);
__asm__(
    ".globl stub_42\n"
    "stub_42:\n"
    "  movq ptr_stub_42(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_42(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_42(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_43[] = "CoInitializeEE";
__attribute__((used)) FARPROC ptr_stub_43 = NULL;
void stub_43(void);
__asm__(
    ".globl stub_43\n"
    "stub_43:\n"
    "  movq ptr_stub_43(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_43(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_43(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_44[] = "CoUninitializeCor";
__attribute__((used)) FARPROC ptr_stub_44 = NULL;
void stub_44(void);
__asm__(
    ".globl stub_44\n"
    "stub_44:\n"
    "  movq ptr_stub_44(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_44(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_44(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_45[] = "CoUninitializeEE";
__attribute__((used)) FARPROC ptr_stub_45 = NULL;
void stub_45(void);
__asm__(
    ".globl stub_45\n"
    "stub_45:\n"
    "  movq ptr_stub_45(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_45(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_45(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_46[] = "CorBindToCurrentRuntime";
__attribute__((used)) FARPROC ptr_stub_46 = NULL;
void stub_46(void);
__asm__(
    ".globl stub_46\n"
    "stub_46:\n"
    "  movq ptr_stub_46(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_46(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_46(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_47[] = "CorBindToRuntime";
__attribute__((used)) FARPROC ptr_stub_47 = NULL;
void stub_47(void);
__asm__(
    ".globl stub_47\n"
    "stub_47:\n"
    "  movq ptr_stub_47(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_47(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_47(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_48[] = "CorBindToRuntimeByCfg";
__attribute__((used)) FARPROC ptr_stub_48 = NULL;
void stub_48(void);
__asm__(
    ".globl stub_48\n"
    "stub_48:\n"
    "  movq ptr_stub_48(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_48(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_48(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_49[] = "CorBindToRuntimeByPath";
__attribute__((used)) FARPROC ptr_stub_49 = NULL;
void stub_49(void);
__asm__(
    ".globl stub_49\n"
    "stub_49:\n"
    "  movq ptr_stub_49(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_49(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_49(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_50[] = "CorBindToRuntimeByPathEx";
__attribute__((used)) FARPROC ptr_stub_50 = NULL;
void stub_50(void);
__asm__(
    ".globl stub_50\n"
    "stub_50:\n"
    "  movq ptr_stub_50(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_50(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_50(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_51[] = "CorBindToRuntimeEx";
__attribute__((used)) FARPROC ptr_stub_51 = NULL;
void stub_51(void);
__asm__(
    ".globl stub_51\n"
    "stub_51:\n"
    "  movq ptr_stub_51(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_51(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_51(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_52[] = "CorBindToRuntimeHost";
__attribute__((used)) FARPROC ptr_stub_52 = NULL;
void stub_52(void);
__asm__(
    ".globl stub_52\n"
    "stub_52:\n"
    "  movq ptr_stub_52(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_52(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_52(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_53[] = "CorExitProcess";
__attribute__((used)) FARPROC ptr_stub_53 = NULL;
void stub_53(void);
__asm__(
    ".globl stub_53\n"
    "stub_53:\n"
    "  movq ptr_stub_53(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_53(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_53(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_54[] = "CorGetSvc";
__attribute__((used)) FARPROC ptr_stub_54 = NULL;
void stub_54(void);
__asm__(
    ".globl stub_54\n"
    "stub_54:\n"
    "  movq ptr_stub_54(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_54(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_54(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_55[] = "CorIsLatestSvc";
__attribute__((used)) FARPROC ptr_stub_55 = NULL;
void stub_55(void);
__asm__(
    ".globl stub_55\n"
    "stub_55:\n"
    "  movq ptr_stub_55(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_55(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_55(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_56[] = "CorMarkThreadInThreadPool";
__attribute__((used)) FARPROC ptr_stub_56 = NULL;
void stub_56(void);
__asm__(
    ".globl stub_56\n"
    "stub_56:\n"
    "  movq ptr_stub_56(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_56(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_56(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_57[] = "CorTickleSvc";
__attribute__((used)) FARPROC ptr_stub_57 = NULL;
void stub_57(void);
__asm__(
    ".globl stub_57\n"
    "stub_57:\n"
    "  movq ptr_stub_57(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_57(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_57(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_58[] = "CreateConfigStream";
__attribute__((used)) FARPROC ptr_stub_58 = NULL;
void stub_58(void);
__asm__(
    ".globl stub_58\n"
    "stub_58:\n"
    "  movq ptr_stub_58(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_58(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_58(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_59[] = "CreateDebuggingInterfaceFromVersion";
__attribute__((used)) FARPROC ptr_stub_59 = NULL;
void stub_59(void);
__asm__(
    ".globl stub_59\n"
    "stub_59:\n"
    "  movq ptr_stub_59(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_59(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_59(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_60[] = "CreateInterface";
__attribute__((used)) FARPROC ptr_stub_60 = NULL;
void stub_60(void);
__asm__(
    ".globl stub_60\n"
    "stub_60:\n"
    "  movq ptr_stub_60(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_60(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_60(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_61[] = "DllCanUnloadNow";
__attribute__((used)) FARPROC ptr_stub_61 = NULL;
void stub_61(void);
__asm__(
    ".globl stub_61\n"
    "stub_61:\n"
    "  movq ptr_stub_61(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_61(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_61(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_62[] = "DllGetClassObject";
__attribute__((used)) FARPROC ptr_stub_62 = NULL;
void stub_62(void);
__asm__(
    ".globl stub_62\n"
    "stub_62:\n"
    "  movq ptr_stub_62(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_62(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_62(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_63[] = "DllRegisterServer";
__attribute__((used)) FARPROC ptr_stub_63 = NULL;
void stub_63(void);
__asm__(
    ".globl stub_63\n"
    "stub_63:\n"
    "  movq ptr_stub_63(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_63(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_63(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_64[] = "DllUnregisterServer";
__attribute__((used)) FARPROC ptr_stub_64 = NULL;
void stub_64(void);
__asm__(
    ".globl stub_64\n"
    "stub_64:\n"
    "  movq ptr_stub_64(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_64(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_64(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_65[] = "EEDllRegisterServer";
__attribute__((used)) FARPROC ptr_stub_65 = NULL;
void stub_65(void);
__asm__(
    ".globl stub_65\n"
    "stub_65:\n"
    "  movq ptr_stub_65(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_65(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_65(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_66[] = "EEDllUnregisterServer";
__attribute__((used)) FARPROC ptr_stub_66 = NULL;
void stub_66(void);
__asm__(
    ".globl stub_66\n"
    "stub_66:\n"
    "  movq ptr_stub_66(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_66(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_66(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_67[] = "GetAssemblyMDImport";
__attribute__((used)) FARPROC ptr_stub_67 = NULL;
void stub_67(void);
__asm__(
    ".globl stub_67\n"
    "stub_67:\n"
    "  movq ptr_stub_67(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_67(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_67(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_69[] = "GetCORRequiredVersion";
__attribute__((used)) FARPROC ptr_stub_69 = NULL;
void stub_69(void);
__asm__(
    ".globl stub_69\n"
    "stub_69:\n"
    "  movq ptr_stub_69(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_69(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_69(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_70[] = "GetCORRootDirectory";
__attribute__((used)) FARPROC ptr_stub_70 = NULL;
void stub_70(void);
__asm__(
    ".globl stub_70\n"
    "stub_70:\n"
    "  movq ptr_stub_70(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_70(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_70(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_71[] = "GetCORSystemDirectory";
__attribute__((used)) FARPROC ptr_stub_71 = NULL;
void stub_71(void);
__asm__(
    ".globl stub_71\n"
    "stub_71:\n"
    "  movq ptr_stub_71(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_71(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_71(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_72[] = "GetCORVersion";
__attribute__((used)) FARPROC ptr_stub_72 = NULL;
void stub_72(void);
__asm__(
    ".globl stub_72\n"
    "stub_72:\n"
    "  movq ptr_stub_72(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_72(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_72(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_73[] = "GetCompileInfo";
__attribute__((used)) FARPROC ptr_stub_73 = NULL;
void stub_73(void);
__asm__(
    ".globl stub_73\n"
    "stub_73:\n"
    "  movq ptr_stub_73(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_73(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_73(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_74[] = "GetFileVersion";
__attribute__((used)) FARPROC ptr_stub_74 = NULL;
void stub_74(void);
__asm__(
    ".globl stub_74\n"
    "stub_74:\n"
    "  movq ptr_stub_74(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_74(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_74(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_75[] = "GetHashFromAssemblyFile";
__attribute__((used)) FARPROC ptr_stub_75 = NULL;
void stub_75(void);
__asm__(
    ".globl stub_75\n"
    "stub_75:\n"
    "  movq ptr_stub_75(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_75(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_75(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_76[] = "GetHashFromAssemblyFileW";
__attribute__((used)) FARPROC ptr_stub_76 = NULL;
void stub_76(void);
__asm__(
    ".globl stub_76\n"
    "stub_76:\n"
    "  movq ptr_stub_76(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_76(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_76(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_77[] = "GetHashFromBlob";
__attribute__((used)) FARPROC ptr_stub_77 = NULL;
void stub_77(void);
__asm__(
    ".globl stub_77\n"
    "stub_77:\n"
    "  movq ptr_stub_77(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_77(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_77(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_78[] = "GetHashFromFile";
__attribute__((used)) FARPROC ptr_stub_78 = NULL;
void stub_78(void);
__asm__(
    ".globl stub_78\n"
    "stub_78:\n"
    "  movq ptr_stub_78(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_78(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_78(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_79[] = "GetHashFromFileW";
__attribute__((used)) FARPROC ptr_stub_79 = NULL;
void stub_79(void);
__asm__(
    ".globl stub_79\n"
    "stub_79:\n"
    "  movq ptr_stub_79(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_79(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_79(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_80[] = "GetHashFromHandle";
__attribute__((used)) FARPROC ptr_stub_80 = NULL;
void stub_80(void);
__asm__(
    ".globl stub_80\n"
    "stub_80:\n"
    "  movq ptr_stub_80(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_80(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_80(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_81[] = "GetHostConfigurationFile";
__attribute__((used)) FARPROC ptr_stub_81 = NULL;
void stub_81(void);
__asm__(
    ".globl stub_81\n"
    "stub_81:\n"
    "  movq ptr_stub_81(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_81(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_81(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_82[] = "GetMetaDataInternalInterface";
__attribute__((used)) FARPROC ptr_stub_82 = NULL;
void stub_82(void);
__asm__(
    ".globl stub_82\n"
    "stub_82:\n"
    "  movq ptr_stub_82(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_82(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_82(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_83[] = "GetMetaDataInternalInterfaceFromPublic";
__attribute__((used)) FARPROC ptr_stub_83 = NULL;
void stub_83(void);
__asm__(
    ".globl stub_83\n"
    "stub_83:\n"
    "  movq ptr_stub_83(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_83(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_83(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_84[] = "GetMetaDataPublicInterfaceFromInternal";
__attribute__((used)) FARPROC ptr_stub_84 = NULL;
void stub_84(void);
__asm__(
    ".globl stub_84\n"
    "stub_84:\n"
    "  movq ptr_stub_84(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_84(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_84(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_85[] = "GetPermissionRequests";
__attribute__((used)) FARPROC ptr_stub_85 = NULL;
void stub_85(void);
__asm__(
    ".globl stub_85\n"
    "stub_85:\n"
    "  movq ptr_stub_85(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_85(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_85(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_86[] = "GetRealProcAddress";
__attribute__((used)) FARPROC ptr_stub_86 = NULL;
void stub_86(void);
__asm__(
    ".globl stub_86\n"
    "stub_86:\n"
    "  movq ptr_stub_86(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_86(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_86(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_87[] = "GetRequestedRuntimeInfo";
__attribute__((used)) FARPROC ptr_stub_87 = NULL;
void stub_87(void);
__asm__(
    ".globl stub_87\n"
    "stub_87:\n"
    "  movq ptr_stub_87(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_87(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_87(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_88[] = "GetRequestedRuntimeVersion";
__attribute__((used)) FARPROC ptr_stub_88 = NULL;
void stub_88(void);
__asm__(
    ".globl stub_88\n"
    "stub_88:\n"
    "  movq ptr_stub_88(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_88(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_88(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_89[] = "GetRequestedRuntimeVersionForCLSID";
__attribute__((used)) FARPROC ptr_stub_89 = NULL;
void stub_89(void);
__asm__(
    ".globl stub_89\n"
    "stub_89:\n"
    "  movq ptr_stub_89(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_89(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_89(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_90[] = "GetVersionFromProcess";
__attribute__((used)) FARPROC ptr_stub_90 = NULL;
void stub_90(void);
__asm__(
    ".globl stub_90\n"
    "stub_90:\n"
    "  movq ptr_stub_90(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_90(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_90(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_91[] = "GetXMLElement";
__attribute__((used)) FARPROC ptr_stub_91 = NULL;
void stub_91(void);
__asm__(
    ".globl stub_91\n"
    "stub_91:\n"
    "  movq ptr_stub_91(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_91(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_91(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_92[] = "GetXMLElementAttribute";
__attribute__((used)) FARPROC ptr_stub_92 = NULL;
void stub_92(void);
__asm__(
    ".globl stub_92\n"
    "stub_92:\n"
    "  movq ptr_stub_92(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_92(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_92(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_93[] = "GetXMLObject";
__attribute__((used)) FARPROC ptr_stub_93 = NULL;
void stub_93(void);
__asm__(
    ".globl stub_93\n"
    "stub_93:\n"
    "  movq ptr_stub_93(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_93(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_93(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_94[] = "IEE";
__attribute__((used)) FARPROC ptr_stub_94 = NULL;
void stub_94(void);
__asm__(
    ".globl stub_94\n"
    "stub_94:\n"
    "  movq ptr_stub_94(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_94(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_94(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_95[] = "LoadLibraryShim";
__attribute__((used)) FARPROC ptr_stub_95 = NULL;
void stub_95(void);
__asm__(
    ".globl stub_95\n"
    "stub_95:\n"
    "  movq ptr_stub_95(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_95(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_95(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_96[] = "LoadLibraryWithPolicyShim";
__attribute__((used)) FARPROC ptr_stub_96 = NULL;
void stub_96(void);
__asm__(
    ".globl stub_96\n"
    "stub_96:\n"
    "  movq ptr_stub_96(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_96(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_96(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_97[] = "LoadStringRCEx";
__attribute__((used)) FARPROC ptr_stub_97 = NULL;
void stub_97(void);
__asm__(
    ".globl stub_97\n"
    "stub_97:\n"
    "  movq ptr_stub_97(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_97(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_97(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_98[] = "LockClrVersion";
__attribute__((used)) FARPROC ptr_stub_98 = NULL;
void stub_98(void);
__asm__(
    ".globl stub_98\n"
    "stub_98:\n"
    "  movq ptr_stub_98(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_98(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_98(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_99[] = "MetaDataGetDispenser";
__attribute__((used)) FARPROC ptr_stub_99 = NULL;
void stub_99(void);
__asm__(
    ".globl stub_99\n"
    "stub_99:\n"
    "  movq ptr_stub_99(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_99(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_99(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_100[] = "ND_CopyObjDst";
__attribute__((used)) FARPROC ptr_stub_100 = NULL;
void stub_100(void);
__asm__(
    ".globl stub_100\n"
    "stub_100:\n"
    "  movq ptr_stub_100(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_100(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_100(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_101[] = "ND_CopyObjSrc";
__attribute__((used)) FARPROC ptr_stub_101 = NULL;
void stub_101(void);
__asm__(
    ".globl stub_101\n"
    "stub_101:\n"
    "  movq ptr_stub_101(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_101(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_101(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_102[] = "ND_RI2";
__attribute__((used)) FARPROC ptr_stub_102 = NULL;
void stub_102(void);
__asm__(
    ".globl stub_102\n"
    "stub_102:\n"
    "  movq ptr_stub_102(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_102(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_102(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_103[] = "ND_RI4";
__attribute__((used)) FARPROC ptr_stub_103 = NULL;
void stub_103(void);
__asm__(
    ".globl stub_103\n"
    "stub_103:\n"
    "  movq ptr_stub_103(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_103(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_103(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_104[] = "ND_RI8";
__attribute__((used)) FARPROC ptr_stub_104 = NULL;
void stub_104(void);
__asm__(
    ".globl stub_104\n"
    "stub_104:\n"
    "  movq ptr_stub_104(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_104(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_104(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_105[] = "ND_RU1";
__attribute__((used)) FARPROC ptr_stub_105 = NULL;
void stub_105(void);
__asm__(
    ".globl stub_105\n"
    "stub_105:\n"
    "  movq ptr_stub_105(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_105(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_105(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_106[] = "ND_WI2";
__attribute__((used)) FARPROC ptr_stub_106 = NULL;
void stub_106(void);
__asm__(
    ".globl stub_106\n"
    "stub_106:\n"
    "  movq ptr_stub_106(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_106(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_106(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_107[] = "ND_WI4";
__attribute__((used)) FARPROC ptr_stub_107 = NULL;
void stub_107(void);
__asm__(
    ".globl stub_107\n"
    "stub_107:\n"
    "  movq ptr_stub_107(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_107(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_107(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_108[] = "ND_WI8";
__attribute__((used)) FARPROC ptr_stub_108 = NULL;
void stub_108(void);
__asm__(
    ".globl stub_108\n"
    "stub_108:\n"
    "  movq ptr_stub_108(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_108(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_108(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_109[] = "ND_WU1";
__attribute__((used)) FARPROC ptr_stub_109 = NULL;
void stub_109(void);
__asm__(
    ".globl stub_109\n"
    "stub_109:\n"
    "  movq ptr_stub_109(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_109(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_109(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_110[] = "ReOpenMetaDataWithMemoryEx";
__attribute__((used)) FARPROC ptr_stub_110 = NULL;
void stub_110(void);
__asm__(
    ".globl stub_110\n"
    "stub_110:\n"
    "  movq ptr_stub_110(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_110(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_110(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_111[] = "RunDll32ShimW";
__attribute__((used)) FARPROC ptr_stub_111 = NULL;
void stub_111(void);
__asm__(
    ".globl stub_111\n"
    "stub_111:\n"
    "  movq ptr_stub_111(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_111(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_111(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_112[] = "RuntimeOSHandle";
__attribute__((used)) FARPROC ptr_stub_112 = NULL;
void stub_112(void);
__asm__(
    ".globl stub_112\n"
    "stub_112:\n"
    "  movq ptr_stub_112(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_112(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_112(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_113[] = "RuntimeOpenImage";
__attribute__((used)) FARPROC ptr_stub_113 = NULL;
void stub_113(void);
__asm__(
    ".globl stub_113\n"
    "stub_113:\n"
    "  movq ptr_stub_113(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_113(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_113(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_114[] = "RuntimeReleaseHandle";
__attribute__((used)) FARPROC ptr_stub_114 = NULL;
void stub_114(void);
__asm__(
    ".globl stub_114\n"
    "stub_114:\n"
    "  movq ptr_stub_114(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_114(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_114(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_115[] = "StrongNameCompareAssemblies";
__attribute__((used)) FARPROC ptr_stub_115 = NULL;
void stub_115(void);
__asm__(
    ".globl stub_115\n"
    "stub_115:\n"
    "  movq ptr_stub_115(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_115(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_115(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_116[] = "StrongNameErrorInfo";
__attribute__((used)) FARPROC ptr_stub_116 = NULL;
void stub_116(void);
__asm__(
    ".globl stub_116\n"
    "stub_116:\n"
    "  movq ptr_stub_116(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_116(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_116(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_117[] = "StrongNameFreeBuffer";
__attribute__((used)) FARPROC ptr_stub_117 = NULL;
void stub_117(void);
__asm__(
    ".globl stub_117\n"
    "stub_117:\n"
    "  movq ptr_stub_117(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_117(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_117(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_118[] = "StrongNameGetBlob";
__attribute__((used)) FARPROC ptr_stub_118 = NULL;
void stub_118(void);
__asm__(
    ".globl stub_118\n"
    "stub_118:\n"
    "  movq ptr_stub_118(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_118(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_118(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_119[] = "StrongNameGetBlobFromImage";
__attribute__((used)) FARPROC ptr_stub_119 = NULL;
void stub_119(void);
__asm__(
    ".globl stub_119\n"
    "stub_119:\n"
    "  movq ptr_stub_119(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_119(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_119(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_120[] = "StrongNameGetPublicKey";
__attribute__((used)) FARPROC ptr_stub_120 = NULL;
void stub_120(void);
__asm__(
    ".globl stub_120\n"
    "stub_120:\n"
    "  movq ptr_stub_120(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_120(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_120(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_121[] = "StrongNameHashSize";
__attribute__((used)) FARPROC ptr_stub_121 = NULL;
void stub_121(void);
__asm__(
    ".globl stub_121\n"
    "stub_121:\n"
    "  movq ptr_stub_121(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_121(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_121(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_122[] = "StrongNameKeyDelete";
__attribute__((used)) FARPROC ptr_stub_122 = NULL;
void stub_122(void);
__asm__(
    ".globl stub_122\n"
    "stub_122:\n"
    "  movq ptr_stub_122(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_122(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_122(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_123[] = "StrongNameKeyGen";
__attribute__((used)) FARPROC ptr_stub_123 = NULL;
void stub_123(void);
__asm__(
    ".globl stub_123\n"
    "stub_123:\n"
    "  movq ptr_stub_123(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_123(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_123(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_124[] = "StrongNameKeyGenEx";
__attribute__((used)) FARPROC ptr_stub_124 = NULL;
void stub_124(void);
__asm__(
    ".globl stub_124\n"
    "stub_124:\n"
    "  movq ptr_stub_124(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_124(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_124(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_125[] = "StrongNameKeyInstall";
__attribute__((used)) FARPROC ptr_stub_125 = NULL;
void stub_125(void);
__asm__(
    ".globl stub_125\n"
    "stub_125:\n"
    "  movq ptr_stub_125(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_125(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_125(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_126[] = "StrongNameSignatureGeneration";
__attribute__((used)) FARPROC ptr_stub_126 = NULL;
void stub_126(void);
__asm__(
    ".globl stub_126\n"
    "stub_126:\n"
    "  movq ptr_stub_126(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_126(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_126(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_127[] = "StrongNameSignatureGenerationEx";
__attribute__((used)) FARPROC ptr_stub_127 = NULL;
void stub_127(void);
__asm__(
    ".globl stub_127\n"
    "stub_127:\n"
    "  movq ptr_stub_127(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_127(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_127(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_128[] = "StrongNameSignatureSize";
__attribute__((used)) FARPROC ptr_stub_128 = NULL;
void stub_128(void);
__asm__(
    ".globl stub_128\n"
    "stub_128:\n"
    "  movq ptr_stub_128(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_128(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_128(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_129[] = "StrongNameSignatureVerification";
__attribute__((used)) FARPROC ptr_stub_129 = NULL;
void stub_129(void);
__asm__(
    ".globl stub_129\n"
    "stub_129:\n"
    "  movq ptr_stub_129(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_129(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_129(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_130[] = "StrongNameSignatureVerificationEx";
__attribute__((used)) FARPROC ptr_stub_130 = NULL;
void stub_130(void);
__asm__(
    ".globl stub_130\n"
    "stub_130:\n"
    "  movq ptr_stub_130(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_130(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_130(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_131[] = "StrongNameSignatureVerificationFromImage";
__attribute__((used)) FARPROC ptr_stub_131 = NULL;
void stub_131(void);
__asm__(
    ".globl stub_131\n"
    "stub_131:\n"
    "  movq ptr_stub_131(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_131(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_131(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_132[] = "StrongNameTokenFromAssembly";
__attribute__((used)) FARPROC ptr_stub_132 = NULL;
void stub_132(void);
__asm__(
    ".globl stub_132\n"
    "stub_132:\n"
    "  movq ptr_stub_132(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_132(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_132(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_133[] = "StrongNameTokenFromAssemblyEx";
__attribute__((used)) FARPROC ptr_stub_133 = NULL;
void stub_133(void);
__asm__(
    ".globl stub_133\n"
    "stub_133:\n"
    "  movq ptr_stub_133(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_133(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_133(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_134[] = "StrongNameTokenFromPublicKey";
__attribute__((used)) FARPROC ptr_stub_134 = NULL;
void stub_134(void);
__asm__(
    ".globl stub_134\n"
    "stub_134:\n"
    "  movq ptr_stub_134(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_134(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_134(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_135[] = "TranslateSecurityAttributes";
__attribute__((used)) FARPROC ptr_stub_135 = NULL;
void stub_135(void);
__asm__(
    ".globl stub_135\n"
    "stub_135:\n"
    "  movq ptr_stub_135(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_135(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_135(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_136[] = "_CorDllMain";
__attribute__((used)) FARPROC ptr_stub_136 = NULL;
void stub_136(void);
__asm__(
    ".globl stub_136\n"
    "stub_136:\n"
    "  movq ptr_stub_136(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_136(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_136(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_137[] = "_CorExeMain";
__attribute__((used)) FARPROC ptr_stub_137 = NULL;
void stub_137(void);
__asm__(
    ".globl stub_137\n"
    "stub_137:\n"
    "  movq ptr_stub_137(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_137(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_137(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);

__attribute__((used)) const char name_stub_138[] = "_CorExeMain2";
__attribute__((used)) FARPROC ptr_stub_138 = NULL;
void stub_138(void);
__asm__(
    ".globl stub_138\n"
    "stub_138:\n"
    "  movq ptr_stub_138(%rip), %rax\n"
    "  testq %rax, %rax\n"
    "  jnz 1f\n"
    "  pushq %rcx\n  pushq %rdx\n  pushq %r8\n  pushq %r9\n"
    "  subq $40, %rsp\n"
    "  leaq name_stub_138(%rip), %rcx\n"
    "  call ResolveByName\n"
    "  addq $40, %rsp\n"
    "  popq %r9\n  popq %r8\n  popq %rdx\n  popq %rcx\n"
    "  movq %rax, ptr_stub_138(%rip)\n"
    "  testq %rax, %rax\n  jz 2f\n"
    "1:\n  jmp *%rax\n"
    "2:\n  movl $0x80004001, %eax\n  ret\n"
);
