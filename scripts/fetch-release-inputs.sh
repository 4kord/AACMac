#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
source "$root/scripts/lib.sh"
source "$root/scripts/release.env"
out="$root/dist/inputs"; mkdir -p "$out"
lock="$root/runtime/runtime-lock.json"

tag="$(plutil -extract releaseTag raw -o - "$lock")"
asset="$(plutil -extract asset raw -o - "$lock")"
sha="$(plutil -extract sha256 raw -o - "$lock")"
if [[ -f "$root/runtime/dist/$asset" && ! -f "$out/runtime.tar.xz" ]]; then
  cp -c "$root/runtime/dist/$asset" "$out/runtime.tar.xz"
fi
if ! { [[ -f "$out/runtime.tar.xz" ]] && echo "$sha  $out/runtime.tar.xz" | shasum -a 256 -c --status; }; then
  fetch_verified "https://github.com/$(repo_slug)/releases/download/$tag/$asset" "$sha" "$out/runtime.tar.xz"
fi
cp "$lock" "$out/runtime-lock.json"

fetch_verified "$SEVENZIP_URL" "$SEVENZIP_SHA256" "$out/7z-mac.tar.xz"
tar -xJf "$out/7z-mac.tar.xz" -C "$out" 7zz License.txt
mv "$out/License.txt" "$out/7zip-License.txt"
chmod +x "$out/7zz"
echo "inputs ready in $out"
