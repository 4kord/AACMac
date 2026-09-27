#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    SECURITY_ATTRIBUTES sa = { sizeof(sa), NULL, TRUE };
    HANDLE rd, wr;
    STARTUPINFOA si = { sizeof(si) };
    PROCESS_INFORMATION pi;
    char line[32] = {0};
    DWORD got = 0, expected, found;
    DWORD (WINAPI *find)(DWORD);
    HMODULE dll;

    if (argc < 3) { fprintf(stderr, "usage: probe64 <dwmapi.dll> <archeage.exe>\n"); return 2; }
    CreatePipe(&rd, &wr, &sa, 0);
    SetHandleInformation(rd, HANDLE_FLAG_INHERIT, 0);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdOutput = wr;
    if (!CreateProcessA(argv[2], NULL, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) { printf("FAIL spawn %lu\n", GetLastError()); return 1; }
    CloseHandle(wr);
    ReadFile(rd, line, sizeof(line) - 1, &got, NULL);
    expected = strtoul(line, NULL, 16);
    Sleep(500);

    if (!(dll = LoadLibraryA(argv[1]))) { printf("FAIL load %lu\n", GetLastError()); return 1; }
    find = (void *)GetProcAddress(dll, "AacFindLoadLibraryA32");
    if (!find) { printf("FAIL no export\n"); return 1; }
    found = find(pi.dwProcessId);
    TerminateProcess(pi.hProcess, 0);
    printf("expected %08lx found %08lx\n", expected, found);
    if (found != expected || !found) { printf("FAIL\n"); return 1; }
    printf("PASS\n");
    return 0;
}
