#!/bin/bash
# Usage: tools/smoke.sh [idle|move|combat]
# Opens a window briefly, saves reports/smoke_<scenario>.png, exits 1 on any Godot script error,
# a nonzero Godot exit, or a screenshot that is black or not 1280x720.
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1
scenario="${1:-idle}"
mkdir -p reports
touch reports/.gdignore  # keep Godot from importing saved screenshots as textures

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

fail() {
  echo "smoke: $1 (exit $code); full log: reports/smoke_${scenario}.log"
  if grep -q "DisplayServer" "$log"; then
    echo "smoke: needs a display; run locally"
  fi
  exit 1
}

if grep -qE "SCRIPT ERROR|ERROR:|WARNING:" "$log"; then
  fail "Godot reported problems"
fi
if ! grep -q "SMOKE_DONE" "$log"; then
  fail "scenario did not finish"
fi
# SMOKE_IMAGE size=1280x720 mean=0.123
image_line="$(grep -m1 "SMOKE_IMAGE" "$log")"
size="$(sed -E 's/.*size=([0-9]+x[0-9]+).*/\1/' <<<"$image_line")"
mean="$(sed -E 's/.*mean=([0-9.]+).*/\1/' <<<"$image_line")"
if [ "$size" != "1280x720" ] || ! awk -v m="${mean:-0}" 'BEGIN { exit !(m >= 0.02) }'; then
  fail "screenshot is black or wrong size (size=${size:-?} mean=${mean:-?})"
fi
[ "$code" -eq 0 ] || fail "Godot exited nonzero"
echo "smoke: ok"
