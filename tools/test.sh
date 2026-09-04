#!/bin/bash
# Runs every gdUnit4 suite under tests/ headless.
# Usage: tools/test.sh            (all suites)
#        tools/test.sh -a res://tests/test_movement.gd   (one suite; -a overrides the default)
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1

mkdir -p reports
touch reports/.gdignore  # keep Godot from importing generated reports as resources

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# Refresh the import cache so new class_name scripts and assets are visible.
if ! "$GODOT_BIN" --headless --path . --import >"$log" 2>&1; then
  echo "test.sh: --import failed:" >&2
  cat "$log" >&2
  exit 1
fi

if [ $# -eq 0 ]; then
  set -- -a res://tests
fi

# No -d: without the local debugger Godot can never stop at an interactive
# 'debug>' prompt on script errors; stdin from /dev/null is belt-and-braces.
"$GODOT_BIN" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -c -rc 5 -rd res://reports "$@" </dev/null 2>&1 | tee "$log"
code=${PIPESTATUS[0]}

# gdUnit4 exits 0 when it discovers nothing, so a mistyped -a path would be a silent green.
if grep -q "No test cases found" "$log"; then
  echo "test.sh: no test cases discovered" >&2
  exit 1
fi
echo "gdUnit4 exit code: $code (0=pass, 100=failures, 101=warnings, 105=script errors)"
exit "$code"
