#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static int spawn(const wchar_t *self, const wchar_t *args)
{
    wchar_t cmd[1024];
    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi;

    swprintf(cmd, 1024, L"\"%ls\" --child %ls", self, args);
    if (!CreateProcessW(NULL, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi)) return 1;
    WaitForSingleObject(pi.hProcess, INFINITE);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return 0;
}

int main(void)
{
    const wchar_t *line = GetCommandLineW();
    wchar_t self[MAX_PATH];

    if (wcsstr(line, L"--child")) {
        printf("%ls\n", wcsstr(line, L"--child"));
        return 0;
    }
    GetModuleFileNameW(NULL, self, MAX_PATH);
    if (spawn(self, L"--disable-features=Ignored --embedded-browser-webview=1 --disable-features=msSmartScreenProtection --lang=en-US")) return 1;
    return spawn(self, L"--type=renderer --embedded-browser-webview=1");
}
