#!/bin/bash
# Runs every gdUnit4 suite under tests/ headless.
# Usage: tools/test.sh            (all suites)
#        tools/test.sh -a res://tests/test_movement.gd   (one suite; -a overrides the default)
#        tools/test.sh -v ...     (stream gdUnit4's full output instead of the digest)
#        tools/test.sh --realtime ...   (pace the engine on the wall clock instead of fixed steps)
# By default the engine runs --fixed-fps 60: every loop iteration is one 1/60 s step with no
# waiting on the wall clock, so the scene tests' ticks and real-time timers (the engine's unscaled
# step, the Clock autoload) pass in a fraction of their seconds. --realtime runs them at the wall
# clock's pace, for a change that touches the clock itself. -v and --realtime come first, in
# either order.
# By default it prints a digest: each failed test with its report, script errors, and the summary.
# The full output is written to reports/test_<pid>.log while it runs (two runners never share a
# log) and moved to reports/test.log at the end.
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1

mkdir -p reports
touch reports/.gdignore  # keep Godot from importing generated reports as resources

log="$(mktemp)"
full="reports/test_$$.log"
trap 'rm -f "$log"; [ -f "$full" ] && mv -f "$full" reports/test.log' EXIT

# Refresh the import cache so new class_name scripts and assets are visible.
if ! "$GODOT_BIN" --headless --path . --import >"$log" 2>&1; then
  echo "test.sh: --import failed:" >&2
  cat "$log" >&2
  exit 1
fi

verbose=0
pace=(--fixed-fps 60)
while [ $# -gt 0 ]; do
  case "$1" in
    -v) verbose=1; shift ;;
    --realtime) pace=(); shift ;;
    *) break ;;
  esac
done
if [ $# -eq 0 ]; then
  set -- -a res://tests
fi

# No -d: without the local debugger Godot can never stop at an interactive
# 'debug>' prompt on script errors; stdin from /dev/null is belt-and-braces.
if [ "$verbose" -eq 1 ]; then
  "$GODOT_BIN" --headless ${pace[@]+"${pace[@]}"} --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -c -rc 5 -rd res://reports "$@" </dev/null 2>&1 | tee "$full"
  code=${PIPESTATUS[0]}
else
  "$GODOT_BIN" --headless ${pace[@]+"${pace[@]}"} --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -c -rc 5 -rd res://reports "$@" </dev/null >"$full" 2>&1
  code=$?
fi
sed $'s/\x1b\\[[0-9;]*m//g' "$full" >"$log"

if [ "$verbose" -eq 0 ]; then
  # A failed test's block runs from its FAILED line to the next test or suite line.
  awk '
    / FAILED( |$)/ { show = 1 }
    / STARTED( |$)| PASSED( |$)|^Run Test Suite|Statistics:/ && !/ FAILED/ { show = 0 }
    show { print }
    /SCRIPT ERROR|Parse Error|Parse error|Failed to load script|Script errors were detected/ { print }
    /^Overall Summary:/ { print }
  ' "$log"
fi

# gdUnit4 exits 0 when it discovers nothing, so a mistyped -a path would be a silent green.
if grep -q "No test cases found" "$log"; then
  echo "test.sh: no test cases discovered" >&2
  exit 1
fi
echo "gdUnit4 exit code: $code (0=pass, 100=failures, 101=warnings, 105=script errors)"
exit "$code"
