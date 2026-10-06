#!/bin/bash
# Usage: tools/smoke.sh [idle|move|combat|kill|round|fall|wake|pick|roar|boo|title|pause|boss|grounds|rooms|talk|tier2|pair]
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
  round) grep -q "SMOKE_ROUND 1$" "$log" || fail "expected round 2 to start after the gap" ;;
  fall)  { grep -q "SMOKE_VERDICT up$" "$log" && grep -q "SMOKE_NARRATOR verdict_up$" "$log" && grep -q "SMOKE_GATE Porta Triumphalis" "$log"; } || fail "expected a thumb up with the narrator's line under it, and the gate screen" ;;
  wake)  { grep -q "SMOKE_GATE Porta Libitinaria" "$log" && grep -q "SMOKE_WAKE spoliarium prone=true$" "$log" && grep -q "SMOKE_ROSE true$" "$log"; } || fail "expected a thumbs down's gate screen, the gladiator lying in the Spoliarium, and a press to rise" ;;
  pick)  { grep -q "SMOKE_MENU_OPEN true$" "$log" && grep -qE "SMOKE_CROWD_LINE crowd\.[a-z0-9_]+$" "$log" && grep -qE "SMOKE_UPGRADE [a-z_]+$" "$log"; } || fail "expected the menu to open with the crowd's line over the heading and a card to be taken" ;;
  roar)  { grep -q "SMOKE_ROAR 4$" "$log" && grep -q "SMOKE_CROWD_ROARS 2$" "$log"; } || fail "expected four cards with the crowd's dropped in, and the crowd's roar twice (the round's end and the drop)" ;;
  boo)   { grep -q "SMOKE_MENU_OPEN true$" "$log" && grep -qE "SMOKE_CROWD_LINE crowd\.[a-z0-9_]+$" "$log" && grep -qE "SMOKE_BOO_LOCKED [0-9]+$" "$log" && grep -qE "SMOKE_UPGRADE [a-z_]+$" "$log"; } || fail "expected a Boo's picker with one card locked under the crowd's line, and an open card to be taken" ;;
  title) grep -q "SMOKE_TITLE played=true paused=false$" "$log" || fail "expected Play to start the run" ;;
  pause) grep -q "SMOKE_PAUSE open=true paused=true$" "$log" || fail "expected Esc to open the pause screen" ;;
  # Pool ids are the code's; event names are the writer's: the checks match the pool and the shape.
  # An arrival's `enter` event may sit in any pool (the writer's choice); at the post only the keeper speaks.
  grounds) { grep -qE "SMOKE_ARRIVAL [a-z]+\.[a-z0-9_]+ open=true$" "$log" && grep -qE "SMOKE_GROUNDS_WORD lanista\.[a-z0-9_]+$" "$log" && grep -q "SMOKE_GROUNDS post$" "$log"; } || fail "expected the first arrival's word, then E at the post to play the lanista's word and open the training panel" ;;
  talk)  grep -qE "SMOKE_TALK veteran\.[a-z0-9_]+ open=false$" "$log" || fail "expected E on the veteran to play a word in the box, and the box to shut" ;;
  rooms) grep -q "SMOKE_ROOMS ludus armamentarium sanitarium hypogeum spoliarium$" "$log" || fail "expected E at the doors to walk through all five rooms" ;;
  tier2) { grep -q "SMOKE_TIER 2 56x30$" "$log" && grep -q "SMOKE_ARROW true$" "$log" && grep -q "SMOKE_CHARGE_LINE true$" "$log" && grep -qE "SMOKE_BANNER [1-9][0-9]* hastened$" "$log"; } || fail "expected tier 2's two-screen arena, an arrow for an enemy off screen, a charger's line through its wind-up, and a banner hastening its pack" ;;
  pair)  { grep -q "SMOKE_BOSS_BARS 2$" "$log" && grep -q "SMOKE_BOSS_FAVOUR 100$" "$log"; } || fail "expected the beast and its handler with a bar each, the meter at the top on their arrival" ;;
  boss)
    hp_line="$(grep -m1 "SMOKE_BOSS_HP" "$log")"
    hp="$(sed -E 's/.*SMOKE_BOSS_HP ([0-9]+) of ([0-9]+).*/\1/' <<<"$hp_line")"
    max="$(sed -E 's/.*SMOKE_BOSS_HP ([0-9]+) of ([0-9]+).*/\2/' <<<"$hp_line")"
    { [ -n "$hp" ] && [ "$hp" -lt "${max:-0}" ] && grep -q "SMOKE_BOSS_BAR true$" "$log"; } || fail "expected the boss to be hit under its bar"
    grep -q "SMOKE_BOSS_FAVOUR 100$" "$log" || fail "expected the meter at the top on the boss's arrival" ;;
esac
# Every scenario plays at least the boot room's sounds and the music.
grep -qE "SMOKE_AUDIO [1-9][0-9]*$" "$log" || fail "scenario ran silent"
# SMOKE_IMAGE size=1280x720 mean=0.123
image_line="$(grep -m1 "SMOKE_IMAGE" "$log")"
size="$(sed -E 's/.*size=([0-9]+x[0-9]+).*/\1/' <<<"$image_line")"
mean="$(sed -E 's/.*mean=([0-9.]+).*/\1/' <<<"$image_line")"
if [ "$size" != "1280x720" ] || ! awk -v m="${mean:-0}" 'BEGIN { exit !(m >= 0.02) }'; then
  fail "screenshot is black or wrong size (size=${size:-?} mean=${mean:-?})"
fi
[ "$code" -eq 0 ] || fail "Godot exited nonzero"
echo "smoke: ok"
