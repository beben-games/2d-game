#!/bin/bash
# Imports the project, boots the main scene headless for one frame, and fails on any Godot error.
# Usage: tools/check_boot.sh
set -u
cd "$(dirname "$0")/.." || exit 1
source tools/godot.sh || exit 1

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

if ! "$GODOT_BIN" --headless --path . --import >"$log" 2>&1; then
  echo "check_boot: --import failed:"
  cat "$log"
  exit 1
fi

"$GODOT_BIN" --headless --path . --quit >"$log" 2>&1 </dev/null
code=$?
if grep -qE "SCRIPT ERROR|ERROR:|WARNING:" "$log"; then
  cat "$log"
  echo "check_boot: Godot reported problems above (exit $code)"
  exit 1
fi
# The reload paths (Restart, Quit to title) run only with Main as the current scene.
probe="$(mktemp)"
perl -e 'alarm 60; exec @ARGV' "$GODOT_BIN" --headless --path . -s res://tools/reload_probe.gd >"$probe" 2>&1 </dev/null
if grep -qE "SCRIPT ERROR|ERROR:|WARNING:" "$probe" || ! grep -q "^RELOAD_PROBE ok" "$probe"; then
  cat "$probe"; rm -f "$probe"
  echo "check_boot: the reload probe (tools/reload_probe.gd) failed"
  exit 1
fi
rm -f "$probe"
missing="$(grep -c "^AUDIO_MISSING" "$log" || true)"
if [ "${missing:-0}" -gt 0 ]; then
  echo "check_boot: $missing sounds missing (silent until the files land; see data/audio.json and docs/ASSETS.md)"
fi
icons="$(grep -c "^ICON_MISSING" "$log" || true)"
if [ "${icons:-0}" -gt 0 ]; then
  echo "check_boot: $icons icon sheets missing (placeholders drawn; see docs/ASSETS.md)"
fi
if [ "$code" -ne 0 ]; then
  cat "$log"
  echo "check_boot: Godot exited $code"
  exit 1
fi
echo "check_boot: ok"
