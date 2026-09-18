#!/bin/bash
# Usage: tools/smoke.sh [idle|move|combat|kill|room|death|pick|title|pause]
# Opens a window briefly, saves reports/smoke_<scenario>.png, exits 1 on any Godot script error,
# a nonzero Godot exit, a missing per-scenario line, or a screenshot that is black or not 1280x720.
# smoke.gd has a 30 s watchdog that quits with code 3 when a scenario hangs.
# The watchdog is in-process; a hang before the scene's _ready (import, window creation) is not covered.
# The project runs fullscreen; smoke.gd switches to a 1280x720 window first (the --windowed flag
# alone does not override it).
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

if [ "$code" -eq 3 ]; then
  fail "watchdog: scenario hung"
fi
if grep -qE "SCRIPT ERROR|ERROR:|WARNING:" "$log"; then
  fail "Godot reported problems"
fi
if ! grep -q "SMOKE_DONE" "$log"; then
  fail "scenario did not finish"
fi
case "$scenario" in
  kill)  grep -q "SMOKE_KILLS 1$" "$log" || fail "expected one kill" ;;
  room)  grep -q "SMOKE_ROOM 1$" "$log" || fail "expected to reach room 2" ;;
  death) grep -q "SMOKE_SUMMARY You died" "$log" || fail "expected the death summary" ;;
  pick)  { grep -q "SMOKE_MENU_OPEN true$" "$log" && grep -qE "SMOKE_UPGRADE [a-z_]+$" "$log"; } || fail "expected the menu to open and a card to be taken" ;;
  title) grep -q "SMOKE_TITLE played=true paused=false$" "$log" || fail "expected Play to start the run" ;;
  pause) grep -q "SMOKE_PAUSE open=true paused=true$" "$log" || fail "expected Esc to open the pause screen" ;;
esac
# SMOKE_IMAGE size=1280x720 mean=0.123
image_line="$(grep -m1 "SMOKE_IMAGE" "$log")"
size="$(sed -E 's/.*size=([0-9]+x[0-9]+).*/\1/' <<<"$image_line")"
mean="$(sed -E 's/.*mean=([0-9.]+).*/\1/' <<<"$image_line")"
if [ "$size" != "1280x720" ] || ! awk -v m="${mean:-0}" 'BEGIN { exit !(m >= 0.02) }'; then
  fail "screenshot is black or wrong size (size=${size:-?} mean=${mean:-?})"
fi
[ "$code" -eq 0 ] || fail "Godot exited nonzero"
echo "smoke: ok"
