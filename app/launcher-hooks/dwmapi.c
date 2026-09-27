/* The launcher injects the anti-cheat into the 32-bit game with its own 64-bit
 * LoadLibraryA address, which crashes the game. This proxy, loaded only by the
 * launcher, hands it the game's 32-bit LoadLibraryA instead. */
#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

typedef LONG NTSTATUS;
typedef NTSTATUS (NTAPI *NtAllocateVirtualMemory_t)(HANDLE, PVOID *, ULONG_PTR, PSIZE_T, ULONG, ULONG);

static HMODULE real_dwmapi, self;
static FILE *logf;

static void logmsg(const char *fmt, ...)
{
    va_list ap;
    if (!logf) return;
    SYSTEMTIME t;
    GetLocalTime(&t);
    fprintf(logf, "%02d:%02d:%02d.%03d ", t.wHour, t.wMinute, t.wSecond, t.wMilliseconds);
    va_start(ap, fmt);
    vfprintf(logf, fmt, ap);
    va_end(ap);
    fputc('\n', logf);
    fflush(logf);
}

static FARPROC real(const char *name)
{
    if (!real_dwmapi) {
        char path[MAX_PATH];
        GetSystemDirectoryA(path, MAX_PATH);
        strcat(path, "\\dwmapi.dll");
        real_dwmapi = LoadLibraryA(path);
        if (real_dwmapi == self) real_dwmapi = NULL;
        logmsg("real dwmapi: %p", real_dwmapi);
    }
    return real_dwmapi ? GetProcAddress(real_dwmapi, name) : NULL;
}

HRESULT WINAPI DwmGetWindowAttribute(HWND h, DWORD a, PVOID p, DWORD n)
{
    HRESULT (WINAPI *f)(HWND, DWORD, PVOID, DWORD) = (void *)real("DwmGetWindowAttribute");
    return f ? f(h, a, p, n) : E_NOTIMPL;
}

HRESULT WINAPI DwmSetWindowAttribute(HWND h, DWORD a, LPCVOID p, DWORD n)
{
    HRESULT (WINAPI *f)(HWND, DWORD, LPCVOID, DWORD) = (void *)real("DwmSetWindowAttribute");
    return f ? f(h, a, p, n) : E_NOTIMPL;
}

HRESULT WINAPI DwmEnableBlurBehindWindow(HWND h, const void *b)
{
    HRESULT (WINAPI *f)(HWND, const void *) = (void *)real("DwmEnableBlurBehindWindow");
    return f ? f(h, b) : E_NOTIMPL;
}

static BOOL rd(HANDLE p, ULONG_PTR addr, void *buf, SIZE_T n)
{
    SIZE_T got = 0;
    return ReadProcessMemory(p, (void *)addr, buf, n, &got) && got == n;
}

static DWORD find_game_pid(void)
{
    PROCESSENTRY32W pe = { sizeof(pe) };
    DWORD pid = 0;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return 0;
    if (Process32FirstW(snap, &pe)) do {
        if (!_wcsicmp(pe.szExeFile, L"archeage.exe")) pid = pe.th32ProcessID;
    } while (Process32NextW(snap, &pe));
    CloseHandle(snap);
    return pid;
}

static DWORD remote_module32(HANDLE proc, const WCHAR *want)
{
    HMODULE mods[1024];
    DWORD n = 0, i;
    WCHAR name[MAX_PATH];

    if (!EnumProcessModulesEx(proc, mods, sizeof(mods), &n, LIST_MODULES_32BIT)) return 0;
    for (i = 0; i < n / sizeof(HMODULE) && i < ARRAYSIZE(mods); i++)
    {
        if ((ULONG_PTR)mods[i] >= 0x100000000ULL) continue;
        if (GetModuleBaseNameW(proc, mods[i], name, MAX_PATH) && !_wcsicmp(name, want))
            return (DWORD)(ULONG_PTR)mods[i];
    }
    return 0;
}

/* some Wine builds forward kernel32.LoadLibraryA to kernelbase */
static DWORD remote_export32(HANDLE proc, DWORD base, const char *want, int depth)
{
    IMAGE_DOS_HEADER dos;
    IMAGE_NT_HEADERS32 nt;
    IMAGE_EXPORT_DIRECTORY ed;
    DWORD i;

    if (!base || depth > 4) return 0;
    if (!rd(proc, base, &dos, sizeof(dos)) || dos.e_magic != IMAGE_DOS_SIGNATURE) return 0;
    if (!rd(proc, base + dos.e_lfanew, &nt, sizeof(nt)) || nt.Signature != IMAGE_NT_SIGNATURE) return 0;
    if (nt.OptionalHeader.Magic != IMAGE_NT_OPTIONAL_HDR32_MAGIC) return 0;
    IMAGE_DATA_DIRECTORY dir = nt.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT];
    if (!dir.VirtualAddress || !rd(proc, base + dir.VirtualAddress, &ed, sizeof(ed))) return 0;

    for (i = 0; i < ed.NumberOfNames; i++)
    {
        DWORD name_rva, fn_rva;
        WORD ord;
        char name[64] = {0};
        if (!rd(proc, base + ed.AddressOfNames + i * 4, &name_rva, 4)) return 0;
        if (!rd(proc, base + name_rva, name, sizeof(name) - 1)) continue;
        if (strcmp(name, want)) continue;
        if (!rd(proc, base + ed.AddressOfNameOrdinals + i * 2, &ord, 2)) return 0;
        if (!rd(proc, base + ed.AddressOfFunctions + ord * 4, &fn_rva, 4)) return 0;
        if (fn_rva >= dir.VirtualAddress && fn_rva < dir.VirtualAddress + dir.Size)
        {
            char fwd[128] = {0}, *dot;
            WCHAR dll[80];
            if (!rd(proc, base + fn_rva, fwd, sizeof(fwd) - 1) || !(dot = strchr(fwd, '.'))) return 0;
            *dot = 0;
            swprintf(dll, ARRAYSIZE(dll), L"%hs.dll", fwd);
            logmsg("%s forwards to %s.%s", want, fwd, dot + 1);
            return remote_export32(proc, remote_module32(proc, dll), dot + 1, depth + 1);
        }
        return base + fn_rva;
    }
    return 0;
}

/* exported for tests */
DWORD WINAPI AacFindLoadLibraryA32(DWORD pid)
{
    DWORD base, addr = 0;
    HANDLE proc = OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, FALSE, pid);

    if (!proc) { logmsg("OpenProcess(%lu) failed: %lu", pid, GetLastError()); return 0; }
    base = remote_module32(proc, L"kernel32.dll");
    if (base) addr = remote_export32(proc, base, "LoadLibraryA", 0);
    CloseHandle(proc);
    logmsg("pid %lu: kernel32 at %08lx, LoadLibraryA at %08lx", pid, base, addr);
    return addr;
}

static DWORD loadlibrary32(void)
{
    DWORD pid = find_game_pid();
    if (!pid) { logmsg("archeage.exe not running"); return 0; }
    return AacFindLoadLibraryA32(pid);
}

static FARPROC WINAPI hook_GetProcAddress(HMODULE mod, LPCSTR name)
{
    if (HIWORD((ULONG_PTR)name) && !strcmp(name, "LoadLibraryA") &&
        mod == GetModuleHandleA("kernel32.dll")) {
        DWORD a = loadlibrary32();
        if (a) return (FARPROC)(ULONG_PTR)a;
        logmsg("falling back to the 64-bit LoadLibraryA");
    }
    return GetProcAddress(mod, name);
}

static BOOL is_wow64(HANDLE proc)
{
    BOOL w = FALSE;
    return IsWow64Process(proc, &w) && w;
}

static LPVOID WINAPI hook_VirtualAllocEx(HANDLE proc, LPVOID addr, SIZE_T size, DWORD type, DWORD prot)
{
    LPVOID p = VirtualAllocEx(proc, addr, size, type, prot);
    if (p && (ULONG_PTR)p >= 0x80000000ULL && !addr && is_wow64(proc)) {
        /* a 32-bit process can't use this pointer */
        NtAllocateVirtualMemory_t nt = (void *)GetProcAddress(GetModuleHandleA("ntdll.dll"), "NtAllocateVirtualMemory");
        PVOID q = NULL;
        SIZE_T sz = size;
        VirtualFreeEx(proc, p, 0, MEM_RELEASE);
        p = (nt && nt(proc, &q, 0x7fffffff, &sz, type, prot) == 0) ? q : NULL;
        logmsg("VirtualAllocEx: high address for 32-bit target, reallocated at %p", p);
    }
    return p;
}

static HANDLE WINAPI hook_CreateRemoteThread(HANDLE proc, LPSECURITY_ATTRIBUTES sa, SIZE_T stack,
                                             LPTHREAD_START_ROUTINE start, LPVOID param, DWORD flags, LPDWORD tid)
{
    HANDLE h = CreateRemoteThread(proc, sa, stack, start, param, flags, tid);
    logmsg("CreateRemoteThread(start=%p, param=%p) -> %p (err %lu)", start, param, h, h ? 0 : GetLastError());
    return h;
}

static void patch_iat(HMODULE exe, const char *dll, const char *func, void *hook)
{
    BYTE *b = (BYTE *)exe;
    IMAGE_NT_HEADERS *nt = (IMAGE_NT_HEADERS *)(b + ((IMAGE_DOS_HEADER *)b)->e_lfanew);
    IMAGE_DATA_DIRECTORY dir = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
    IMAGE_IMPORT_DESCRIPTOR *d;

    for (d = (void *)(b + dir.VirtualAddress); d->Name; d++) {
        IMAGE_THUNK_DATA *names, *iat;
        if (_stricmp((char *)(b + d->Name), dll)) continue;
        names = (void *)(b + (d->OriginalFirstThunk ? d->OriginalFirstThunk : d->FirstThunk));
        iat = (void *)(b + d->FirstThunk);
        for (; names->u1.AddressOfData; names++, iat++) {
            DWORD old;
            if (IMAGE_SNAP_BY_ORDINAL(names->u1.Ordinal)) continue;
            if (strcmp((char *)((IMAGE_IMPORT_BY_NAME *)(b + names->u1.AddressOfData))->Name, func)) continue;
            VirtualProtect(&iat->u1.Function, sizeof(void *), PAGE_READWRITE, &old);
            iat->u1.Function = (ULONG_PTR)hook;
            VirtualProtect(&iat->u1.Function, sizeof(void *), old, &old);
            logmsg("hooked %s!%s", dll, func);
            return;
        }
    }
    logmsg("import %s!%s not found", dll, func);
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved)
{
    if (reason == DLL_PROCESS_ATTACH) {
        char path[MAX_PATH], *slash;
        HMODULE exe = GetModuleHandleA(NULL);
        self = inst;
        DisableThreadLibraryCalls(inst);
        GetModuleFileNameA(exe, path, MAX_PATH);
        if (!strstr(path, "ArcheAge Classic Launcher")) return TRUE;
        if ((slash = strrchr(path, '\\'))) strcpy(slash + 1, "launcher-hooks.log");
        logf = fopen(path, "a");
        logmsg("launcher hooks loaded");
        patch_iat(exe, "kernel32.dll", "GetProcAddress", hook_GetProcAddress);
        patch_iat(exe, "kernel32.dll", "VirtualAllocEx", hook_VirtualAllocEx);
        patch_iat(exe, "kernel32.dll", "CreateRemoteThread", hook_CreateRemoteThread);
    }
    return TRUE;
}
