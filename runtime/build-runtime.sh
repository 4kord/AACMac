#!/usr/bin/env bash
set -euo pipefail
rev="${1:?usage: build-runtime.sh <revision, e.g. r1>}"
here="$(cd "$(dirname "$0")" && pwd)"
source "$here/sources.env"
work="$here/build"; dist="$here/dist"; out="$work/runtime"
mkdir -p "$work/cache" "$dist"

fetch() { # url sha256 dest
  if [[ ! -f "$3" ]] || ! echo "$2  $3" | shasum -a 256 -c --status; then
    curl -fL --retry 3 -o "$3.part" "$1" && mv "$3.part" "$3"
  fi
  echo "$2  $3" | shasum -a 256 -c --status || { echo "hash mismatch: $3" >&2; exit 1; }
}

echo "==> Base runtime r17"
fetch "$BASE_RUNTIME_URL" "$BASE_RUNTIME_SHA256" "$work/cache/base.tar.xz"
rm -rf "$out" "$work/base"; mkdir -p "$work/base"
tar -xJf "$work/cache/base.tar.xz" -C "$work/base"
mv "$work/base/.wine-runtime" "$out"

echo "==> Wine source at $WINE_COMMIT + patches"
src="$work/wine-src"
if [[ ! -d "$src/.git" ]]; then
  git clone --filter=blob:none -b "$WINE_BRANCH" "$WINE_REPO" "$src"
fi
git -C "$src" fetch -q origin "$WINE_COMMIT" || true
git -C "$src" checkout -q -f "$WINE_COMMIT"
git -C "$src" clean -qfdx
for p in "$here"/patches/*.patch; do git -C "$src" apply "$p"; done

echo "==> Configure (x86_64 host, i386+x86_64 PE)"
libs="$work/libs"; mkdir -p "$libs"      # -L paths can't contain spaces
cp "$out/lib/external/libfreetype.6.dylib" "$out/lib/external/libvulkan.1.dylib" "$libs/"
ln -sf libfreetype.6.dylib "$libs/libfreetype.dylib"; ln -sf libvulkan.1.dylib "$libs/libvulkan.dylib"
bld="$work/wine-build"; mkdir -p "$bld"
if [[ ! -f "$bld/Makefile" ]]; then
  (cd "$bld" && arch -x86_64 /bin/zsh -c "PATH=$(brew --prefix bison)/bin:\$PATH \
    CC='clang -arch x86_64' OBJC='clang -arch x86_64' LDFLAGS='-L$libs' \
    FREETYPE_CFLAGS='-I$(brew --prefix freetype)/include/freetype2' FREETYPE_LIBS='-L$libs -lfreetype' \
    '$src/configure' --enable-archs=i386,x86_64 --without-x --without-gnutls --without-gstreamer \
    --without-sdl --without-cups --without-sane --without-pcap --without-usb --without-krb5 \
    --without-capi --without-gphoto --without-netapi --without-opencl --without-dbus") > "$work/configure.log" 2>&1
fi
grep -q 'SONAME_LIBFREETYPE "libfreetype.6.dylib"' "$bld/include/config.h"
grep -q 'SONAME_LIBVULKAN "libvulkan.1.dylib"' "$bld/include/config.h"

echo "==> Build patched modules"
targets="dlls/win32u/win32u.so server/wineserver dlls/ole32/x86_64-windows/ole32.dll dlls/ole32/i386-windows/ole32.dll dlls/d3d9/i386-windows/d3d9.dll"
(cd "$bld" && arch -x86_64 /bin/zsh -c "PATH=$(brew --prefix bison)/bin:\$PATH make -j$(sysctl -n hw.ncpu) $targets") > "$work/make.log" 2>&1
cp "$bld/dlls/win32u/win32u.so" "$out/lib/wine/x86_64-unix/win32u.so"
cp "$bld/server/wineserver" "$out/bin/wineserver"
cp "$bld/dlls/ole32/x86_64-windows/ole32.dll" "$out/lib/wine/x86_64-windows/ole32.dll"
cp "$bld/dlls/ole32/i386-windows/ole32.dll" "$out/lib/wine/i386-windows/ole32.dll"
cp "$bld/dlls/d3d9/i386-windows/d3d9.dll" "$out/lib/wine/i386-windows/d3d9.dll"   # stock wined3d d3d9 (fallback renderer)

echo "==> MTLd3D v0.11.0"
fetch "$MTLD3D_URL" "$MTLD3D_SHA256" "$work/cache/mtld3d.tar.xz"
m="$work/mtld3d"; rm -rf "$m"; mkdir -p "$m"; tar -xJf "$work/cache/mtld3d.tar.xz" -C "$m"
cp "$m/wine/i386-windows/mtld3d.dll" "$out/lib/wine/i386-windows/mtld3d.dll"
cp "$m/wine/x86_64-windows/mtld3d.dll" "$out/lib/wine/x86_64-windows/mtld3d.dll"
cp "$m/wine/x86_64-unix/mtld3d.so" "$out/lib/wine/x86_64-unix/mtld3d.so"
rm -f "$out/lib/wine/i386-windows/mtld3d9.dll" "$out/lib/mtld3d.conf"
mkdir -p "$out/mtld3d/native/i386-windows" "$out/mtld3d/prefix-markers"
cp "$m/native/i386-windows/d3d9.dll" "$out/mtld3d/native/i386-windows/"
cp -R "$m/prefix-markers/syswow64" "$m/prefix-markers/system32" "$out/mtld3d/prefix-markers/"

echo "==> rosettax87"
fetch "$ROSETTAX87_DMG_URL" "$ROSETTAX87_DMG_SHA256" "$work/cache/rosettax87.dmg"
mnt="$work/dmg"; mkdir -p "$mnt"
hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$work/cache/rosettax87.dmg" >/dev/null
trap 'hdiutil detach "$mnt" >/dev/null 2>&1 || true' EXIT
rx="$mnt/WoWSilicon.app/Contents/Resources/WoWSilicon-swift_WoWSiliconSwift.bundle/Patching/rosettax87"
mkdir -p "$out/x87"; cp "$rx/rosettax87" "$rx/libRuntimeRosettax87" "$out/x87/"
hdiutil detach "$mnt" >/dev/null; trap - EXIT

echo "==> Licenses, sources, revision"
mkdir -p "$out/LICENSES"
cp "$src/COPYING.LIB" "$out/LICENSES/Wine-LGPL-2.1.txt"
cp "$m/LICENSE" "$out/LICENSES/MTLd3D-zlib.txt"
cp "$here/SOURCES.md" "$out/SOURCES.md"
cp "$here"/patches/*.patch "$out/LICENSES/"
echo "$rev" > "$out/REVISION"
xattr -cr "$out"

echo "==> Pack"
name="ArcheAge-Runtime-$rev.tar.xz"
tar -C "$work" -cJf "$dist/$name" runtime
(cd "$dist" && shasum -a 256 "$name" > "$name.sha256")
cat "$dist/$name.sha256"
