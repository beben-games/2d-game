#!/bin/bash
# Runs the game from the project with the Godot binary (no export needed).
# Usage: tools/run.sh            (a fresh run)
#        tools/run.sh --seed=N   (replay a run; the seed is on the gate screen and in the RUN_END line)
# Controls: WASD move, mouse aim, hold left click to shoot, Space or right click to dash, Tab or Esc
# for the pause screen (the build, the volumes, Restart, Quit to title, Quit game), 1/2/3 or a click
# on the upgrade cards, R restarts, Esc on the end screen returns to the title. The game is
# fullscreen; the title's Quit button or the pause screen's Quit game exits (Cmd+Q too).
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1
exec "$GODOT_BIN" --path . -- "$@"
