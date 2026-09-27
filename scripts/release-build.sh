#!/usr/bin/env bash
set -euo pipefail
version="${1:?usage: release-build.sh <version, e.g. 0.1.0>}"
root="$(cd "$(dirname "$0")/.." && pwd)"

make -C "$root/app/launcher-hooks" clean dwmapi.dll
"$root/scripts/fetch-release-inputs.sh"
swift test --package-path "$root/app"
"$root/scripts/make-app.sh" "$version"
"$root/scripts/check-app.sh"
echo "release build ok: $root/dist/ArcheAge-Classic-$version.dmg"
