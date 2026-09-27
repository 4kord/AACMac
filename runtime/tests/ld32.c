#include <windows.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    int bad = 0;
    for (int i = 1; i < argc; i++)
    {
        HMODULE h = LoadLibraryA(argv[i]);
        printf("%s %s\n", argv[i], h ? "ok" : "FAIL");
        if (!h) bad = 1;
    }
    return bad;
}
