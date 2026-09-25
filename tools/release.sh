#!/bin/bash
# Publishes the tester zips as a GitHub release of beben-games/2d-game, tagged v<version>.
# Usage: tools/release.sh [version]   (default: config/version from project.godot)
# Run tools/build.sh first, and push the commit being released. Needs the GitHub CLI signed in
# (gh auth login). A version with a pre-release suffix (-rc1, -beta) is marked a pre-release.
# The notes are docs/TESTERS.md; edit the release on GitHub to add a changelog.
set -u
cd "$(dirname "$0")/.." || exit 1
command -v gh >/dev/null || { echo "release: the GitHub CLI is not installed (brew install gh)"; exit 1; }
version="${1:-$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)}"
[ -n "$version" ] || { echo "release: no version"; exit 1; }
zips=("builds/arena-roguelike-$version-windows-x64.zip" "builds/arena-roguelike-$version-linux-x64.zip")
for z in "${zips[@]}"; do
  [ -s "$z" ] || { echo "release: $z missing (run tools/build.sh $version)"; exit 1; }
done
flags=()
case "$version" in *-*) flags+=(--prerelease) ;; esac
gh release create "v$version" "${zips[@]}" --repo beben-games/2d-game --target "$(git rev-parse HEAD)" \
  --title "Arena Roguelike $version" --notes-file docs/TESTERS.md "${flags[@]}" || exit 1
echo "release: ok (v$version)"
