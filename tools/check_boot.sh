#!/bin/bash
# Imports the project, boots the main scene headless for one frame, and fails on any Godot error.
# Usage: tools/check_boot.sh
set -u
cd "$(dirname "$0")/.."
source tools/godot.sh || exit 1

"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1

log="$(mktemp)"
"$GODOT_BIN" --headless --path . --quit >"$log" 2>&1
code=$?
if grep -E "SCRIPT ERROR|ERROR:|WARNING:" "$log"; then
  echo "check_boot: Godot reported problems above (exit $code)"
  rm -f "$log"
  exit 1
fi
rm -f "$log"
if [ "$code" -ne 0 ]; then
  echo "check_boot: Godot exited $code"
  exit 1
fi
echo "check_boot: ok"
