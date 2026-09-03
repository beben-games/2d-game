#!/bin/bash
# Imports the project, boots the main scene headless for one frame, and fails on any Godot error.
# Usage: tools/check_boot.sh
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

if ! "$GODOT_BIN" --headless --path . --import >"$log" 2>&1; then
  echo "check_boot: --import failed:"
  cat "$log"
  exit 1
fi

"$GODOT_BIN" --headless --path . --quit >"$log" 2>&1 </dev/null
code=$?
if grep -qE "SCRIPT ERROR|ERROR:|WARNING:" "$log"; then
  cat "$log"
  echo "check_boot: Godot reported problems above (exit $code)"
  exit 1
fi
if [ "$code" -ne 0 ]; then
  cat "$log"
  echo "check_boot: Godot exited $code"
  exit 1
fi
echo "check_boot: ok"
