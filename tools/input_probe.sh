#!/bin/bash
# Diagnostic for stuck keys: opens a small window for 25 s and logs every key/mouse event,
# window notification, and the move_right action state to the terminal and reports/input_probe.log.
# Usage: tools/input_probe.sh [seconds]
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1
mkdir -p reports && touch reports/.gdignore
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1
echo "Window opens now. Click into it, then: hold D for 2 s and release; hold D again and do the"
echo "mouse/trackpad thing you did during the playtest; release D while that is happening; come back;"
echo "tap D once more. The window closes by itself after 25 s."
"$GODOT_BIN" --path . --resolution 640x360 --position 0,0 -s res://tools/input_probe.gd -- "--seconds=${1:-25}" 2>&1 </dev/null | grep --line-buffered "PROBE" | tee reports/input_probe.log
