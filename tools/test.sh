#!/bin/bash
# Runs every gdUnit4 suite under tests/ headless.
# Usage: tools/test.sh            (all suites)
#        tools/test.sh -a res://tests/test_movement.gd   (one suite; -a overrides the default)
#        tools/test.sh -v ...     (stream gdUnit4's full output instead of the digest)
# By default it prints a digest: each failed test with its report, script errors, and the summary.
# The full output is always in reports/test.log.
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

verbose=0
if [ "${1:-}" = "-v" ]; then
  verbose=1
  shift
fi
if [ $# -eq 0 ]; then
  set -- -a res://tests
fi

# No -d: without the local debugger Godot can never stop at an interactive
# 'debug>' prompt on script errors; stdin from /dev/null is belt-and-braces.
full=reports/test.log
if [ "$verbose" -eq 1 ]; then
  "$GODOT_BIN" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -c -rc 5 -rd res://reports "$@" </dev/null 2>&1 | tee "$full"
  code=${PIPESTATUS[0]}
else
  "$GODOT_BIN" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
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
