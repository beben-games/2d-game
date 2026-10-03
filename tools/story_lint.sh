#!/bin/bash
# Lints the story (data/story by default, or the res:// directory given): prints the catalog's
# errors, the lint's warnings, the flag map, and the placeholder count (tools/story_lint.gd).
# Exits 1 on any error in the story (or when the lint did not run), 0 otherwise: warnings alone pass.
# Usage: tools/story_lint.sh [res://dir]
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# Refresh the import cache so the story's class_name scripts are visible on a fresh clone.
if ! "$GODOT_BIN" --headless --path . --import >"$log" 2>&1; then
  echo "story_lint: --import failed:"
  cat "$log"
  exit 1
fi

perl -e 'alarm 120; exec @ARGV' "$GODOT_BIN" --headless --path . -s res://tools/story_lint.gd -- "$@" >"$log" 2>&1 </dev/null
code=$?
grep -v "^Godot Engine v" "$log"
if ! grep -q "^STORY_LINT " "$log" || grep -qE "SCRIPT ERROR|^ERROR:" "$log"; then
  echo "story_lint: the lint did not run cleanly (exit $code)"
  exit 1
fi
exit "$code"
