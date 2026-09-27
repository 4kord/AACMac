#include <windows.h>
#include <stdio.h>

int main(void)
{
    LARGE_INTEGER f, a, b;
    volatile float x = 0.5f, m = 1.0001f;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&a);
    for (int i = 0; i < 20000000; i++) x = __builtin_sqrtf(x * m + m);
    QueryPerformanceCounter(&b);
    printf("%.3f\n", (double)(b.QuadPart - a.QuadPart) / f.QuadPart);
    return 0;
}
