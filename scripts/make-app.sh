#!/usr/bin/env bash
set -euo pipefail
version="${1:?usage: make-app.sh <version, e.g. 0.1.0>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
in="$root/dist/inputs"
app="$root/dist/ArcheAge Classic.app"; c="$app/Contents"
for f in runtime.tar.xz runtime-lock.json 7zz 7zip-License.txt; do
  [[ -f "$in/$f" ]] || { echo "missing $in/$f (run scripts/fetch-release-inputs.sh)" >&2; exit 1; }
done
[[ -f "$root/app/launcher-hooks/dwmapi.dll" ]] || make -C "$root/app/launcher-hooks" dwmapi.dll

echo "==> swift build"
swift build -c release --arch arm64 --package-path "$root/app"
bin="$(swift build -c release --arch arm64 --package-path "$root/app" --show-bin-path)"

echo "==> bundle"
rm -rf "$app"
mkdir -p "$c/MacOS" "$c/Resources/LICENSES"
cp "$bin/ArcheAgeClassic" "$c/MacOS/"
cp "$root/app/Info.plist" "$c/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$c/Info.plist"
plutil -replace CFBundleVersion -string "$version" "$c/Info.plist"
cp -c "$in/runtime.tar.xz" "$in/runtime-lock.json" "$in/7zz" "$c/Resources/"
cp "$root/app/launcher-hooks/dwmapi.dll" "$c/Resources/"
cp "$in/7zip-License.txt" "$c/Resources/LICENSES/"

echo "==> ad-hoc signature (not notarized)"
codesign --force --sign - "$c/Resources/7zz"
codesign --force --deep --sign - "$app"

echo "==> dmg"
dmg="$root/dist/ArcheAge-Classic-$version.dmg"
stage="$root/dist/dmg-stage"; rm -rf "$stage"; mkdir -p "$stage"
ditto "$app" "$stage/ArcheAge Classic.app"
ln -s /Applications "$stage/Applications"
# hdiutil's own size estimate is too small for the runtime tarball
size_mb=$(( $(du -sm "$stage" | cut -f1) * 3 / 2 + 20 ))
hdiutil create -volname "ArcheAge Classic" -srcfolder "$stage" -size "${size_mb}m" -format UDZO -ov "$dmg" >/dev/null
rm -rf "$stage"
echo "$dmg"
