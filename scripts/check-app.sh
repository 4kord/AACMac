#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/dist/ArcheAge Classic.app"; c="$app/Contents"
fail() { echo "FAIL: $*" >&2; exit 1; }

for f in MacOS/ArcheAgeClassic Info.plist Resources/runtime.tar.xz Resources/runtime-lock.json \
         Resources/dwmapi.dll Resources/7zz Resources/LICENSES/7zip-License.txt; do
  [[ -e "$c/$f" ]] || fail "missing Contents/$f"
done
plutil -lint "$c/Info.plist" >/dev/null || fail "Info.plist is invalid"
[[ "$(plutil -extract LSUIElement raw -o - "$c/Info.plist")" == "true" ]] || fail "LSUIElement is not set"
sha="$(plutil -extract sha256 raw -o - "$c/Resources/runtime-lock.json")"
[[ "$(shasum -a 256 "$c/Resources/runtime.tar.xz" | cut -d' ' -f1)" == "$sha" ]] || fail "runtime does not match its lock"
file "$c/Resources/dwmapi.dll" | grep -q "PE32+ executable (DLL)" || fail "dwmapi.dll is not a 64-bit Windows DLL"
"$c/Resources/7zz" i >/dev/null || fail "7zz does not run"
codesign --verify --deep --strict "$app" || fail "code signature is invalid"
echo "bundle ok"
