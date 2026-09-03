#!/bin/bash
# Runs every gdUnit4 suite under tests/ headless.
# Usage: tools/test.sh            (all suites)
#        tools/test.sh -a res://tests/test_movement.gd   (one suite; -a overrides the default)
set -u
cd "$(dirname "$0")/.."
source tools/godot.sh || exit 1

# Refresh the import cache so new class_name scripts and assets are visible.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1

if [ $# -eq 0 ]; then
  set -- -a res://tests
fi

# No -d: without the local debugger Godot can never stop at an interactive
# 'debug>' prompt on script errors; stdin from /dev/null is belt-and-braces.
"$GODOT_BIN" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -c -rd res://reports "$@" </dev/null
code=$?
echo "gdUnit4 exit code: $code (0=pass, 100=failures, 101=warnings, other=abnormal)"
exit $code
