#!/bin/bash
# Runs the game from the project with the Godot binary (no export needed).
# Usage: tools/run.sh            (a fresh run)
#        tools/run.sh --seed=N   (replay a run; the seed is on the summary and in the RUN_OVER/RUN_WON line)
# Controls: WASD move, mouse aim, hold left click to shoot, Space or right click to dash, Tab for the
# build, 1/2/3 or a click on the upgrade cards, R restarts. The game is fullscreen; Cmd+Q quits.
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1
exec "$GODOT_BIN" --path . -- "$@"
