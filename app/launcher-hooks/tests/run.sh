#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
WINE="${WINE:?set WINE to the runtime bin/wine}"
runtime="$(cd "$(dirname "$WINE")/.." && pwd)"
tmp="$(mktemp -d)"
export WINEPREFIX="${WINEPREFIX:-$tmp/prefix}" DYLD_LIBRARY_PATH="$runtime/lib/external" WINEDEBUG=-all WINEMSYNC=1
trap '"$runtime/bin/wineserver" -k 2>/dev/null || true; rm -rf "$tmp"' EXIT
cp "$here/../dwmapi.dll" "$here/probe64.exe" "$tmp/"
cp "$here/sleeper32.exe" "$tmp/archeage.exe"
cd "$tmp"
"$WINE" probe64.exe "Z:${tmp//\//\\}\\dwmapi.dll" "Z:${tmp//\//\\}\\archeage.exe" 2>/dev/null | tr -d '\r' | tee "$tmp/out.txt"
grep -q '^PASS$' "$tmp/out.txt"
