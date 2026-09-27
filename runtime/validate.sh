#!/usr/bin/env bash
set -euo pipefail
tarball="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
here="$(cd "$(dirname "$0")" && pwd)"; repo="$(cd "$here/.." && pwd)"
tmp="$(mktemp -d)"; trap 'WINEPREFIX="$tmp/prefix" "$rt/bin/wineserver" -k 2>/dev/null || true; rm -rf "$tmp"' EXIT
tar -xJf "$tarball" -C "$tmp"; rt="$tmp/runtime"
export WINEPREFIX="$tmp/prefix" DYLD_LIBRARY_PATH="$rt/lib/external" WINEDEBUG=-all WINEMSYNC=1
fail() { echo "FAIL: $*" >&2; exit 1; }

echo "==> wineboot"
WINEDLLOVERRIDES="mscoree=;mshtml=" "$rt/bin/wine" wineboot -i >/dev/null 2>&1
"$rt/bin/wineserver" -w
[[ -f "$tmp/prefix/system.reg" ]] || fail "prefix not created"

echo "==> patched win32u present"
strings "$rt/lib/wine/x86_64-unix/win32u.so" | grep -c "Flushing %p window surface" >/dev/null || fail "launcher window patch missing"

echo "==> MTLd3D loads (native route)"
W="$tmp/prefix/drive_c/windows"
cp "$rt/mtld3d/native/i386-windows/d3d9.dll" "$W/syswow64/d3d9.dll"
cp "$rt/mtld3d/prefix-markers/syswow64/mtld3d.dll" "$W/syswow64/mtld3d.dll"
cp "$rt/mtld3d/prefix-markers/system32/mtld3d.dll" "$W/system32/mtld3d.dll"
i686-w64-mingw32-gcc -O2 -o "$tmp/ld32.exe" "$here/tests/ld32.c"
(cd "$tmp" && WINEDLLOVERRIDES="d3d9=n" "$rt/bin/wine" ld32.exe mtld3d.dll d3d9.dll 2>/dev/null) | tr -d '\r' | tee "$tmp/ld.txt"
grep -q "mtld3d.dll ok" "$tmp/ld.txt" && grep -q "d3d9.dll ok" "$tmp/ld.txt" || fail "MTLd3D does not load"

echo "==> anti-cheat fix lookup"
make -s -C "$repo/app/launcher-hooks" all
WINE="$rt/bin/wine" bash "$repo/app/launcher-hooks/tests/run.sh" || fail "anti-cheat fix lookup"

echo "==> x87 acceleration"
i686-w64-mingw32-gcc -O2 -mfpmath=387 -march=i686 -o "$tmp/archeage.exe" "$here/tests/x87bench.c"
t="$(cd "$tmp" && ROSETTA_X87_PATH="$rt/x87/rosettax87" "$rt/bin/wine" archeage.exe 2>/dev/null | tr -d '\r' | grep -E '^[0-9]+\.[0-9]+$' | tail -1)"
echo "x87 bench: ${t}s"
awk -v t="$t" 'BEGIN { exit !(t > 0 && t < 1.0) }' || fail "x87 bench too slow (${t}s)"

echo "PASS"
