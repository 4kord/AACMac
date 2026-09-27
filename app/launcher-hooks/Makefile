CC64 = x86_64-w64-mingw32-gcc
CC32 = i686-w64-mingw32-gcc
CFLAGS = -O2 -Wall

all: dwmapi.dll tests/probe64.exe tests/sleeper32.exe

dwmapi.dll: dwmapi.c dwmapi.def
	$(CC64) $(CFLAGS) -shared -static-libgcc -o $@ dwmapi.c dwmapi.def -lpsapi

tests/probe64.exe: tests/probe64.c
	$(CC64) $(CFLAGS) -o $@ $<

tests/sleeper32.exe: tests/sleeper32.c
	$(CC32) $(CFLAGS) -o $@ $<

test: all
	bash tests/run.sh

clean:
	rm -f dwmapi.dll tests/*.exe

.PHONY: all test clean
