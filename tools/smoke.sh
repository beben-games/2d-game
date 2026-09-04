#!/bin/bash
# Usage: tools/smoke.sh [idle|move|combat]
# Opens a window briefly, saves reports/smoke_<scenario>.png, exits 1 on any Godot script error.
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1
scenario="${1:-idle}"
mkdir -p reports

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

if ! "$GODOT_BIN" --headless --path . --import >"$log" 2>&1; then
  echo "smoke: --import failed:" >&2
  cat "$log" >&2
  exit 1
fi

"$GODOT_BIN" --path . --resolution 1280x720 --position 0,0 res://tools/smoke.tscn -- "--scenario=${scenario}" >"$log" 2>&1 </dev/null
code=$?
cp "$log" "reports/smoke_${scenario}.log"
grep -E "SMOKE_|SCRIPT ERROR|ERROR:|WARNING:" "$log"

if grep -qE "SCRIPT ERROR|ERROR:|WARNING:" "$log"; then
  echo "smoke: Godot reported problems (exit $code); full log: reports/smoke_${scenario}.log"
  exit 1
fi
if ! grep -q "SMOKE_DONE" "$log"; then
  echo "smoke: scenario did not finish (exit $code); full log: reports/smoke_${scenario}.log"
  exit 1
fi
echo "smoke: ok"
