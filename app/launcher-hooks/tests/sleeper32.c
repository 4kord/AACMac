#include <windows.h>
#include <stdio.h>

int main(void)
{
    FARPROC p = GetProcAddress(GetModuleHandleA("kernel32.dll"), "LoadLibraryA");
    printf("%08lx\n", (unsigned long)(ULONG_PTR)p);
    fflush(stdout);
    Sleep(20000);
    return 0;
}
