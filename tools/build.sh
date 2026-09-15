#!/bin/bash
# Builds the tester zips: Windows x64 and Linux x64 release exports, each with docs/TESTERS.md as README.
# Usage: tools/build.sh [version]   (default: config/version from project.godot)
# Needs the Godot 4.7.2 export templates installed (Editor > Manage Export Templates). Output in builds/
# (gitignored): builds/arena-roguelike-<version>-<platform>.zip. Exits 1 on any export failure.
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1
version="${1:-$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)}"
[ -n "$version" ] || { echo "build: no version (set config/version in project.godot or pass one)"; exit 1; }

rm -rf builds/windows-x64 builds/linux-x64
mkdir -p builds/windows-x64 builds/linux-x64
if ! "$GODOT_BIN" --headless --path . --import </dev/null >/dev/null 2>&1; then
  echo "build: --import failed"; exit 1
fi

export_one() {
  local preset="$1" out="$2" log
  log="$(mktemp)"
  timeout 600 "$GODOT_BIN" --headless --path . --export-release "$preset" "$out" </dev/null >"$log" 2>&1
  if ! grep -q "DONE.*savepack" "$log" || [ ! -s "$out" ]; then
    echo "build: export '$preset' failed:"; tail -25 "$log"; rm -f "$log"; exit 1
  fi
  rm -f "$log"
  echo "build: $preset -> $out ($(du -h "$out" | cut -f1))"
}
export_one "Windows x64" builds/windows-x64/ArenaRoguelike.exe
export_one "Linux x64" builds/linux-x64/ArenaRoguelike.x86_64
cp docs/TESTERS.md builds/windows-x64/README.md
cp docs/TESTERS.md builds/linux-x64/README.md
(
  cd builds || exit 1
  rm -f "arena-roguelike-$version-windows-x64.zip" "arena-roguelike-$version-linux-x64.zip"
  zip -qr "arena-roguelike-$version-windows-x64.zip" windows-x64 && zip -qr "arena-roguelike-$version-linux-x64.zip" linux-x64
) || { echo "build: zip failed"; exit 1; }
ls -la builds/*.zip
echo "build: ok ($version)"
