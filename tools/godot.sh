#!/bin/bash
# Source this file to get GODOT_BIN. Override by exporting GODOT_BIN before sourcing.
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
[ -x "$GODOT_BIN" ] || GODOT_BIN="$(command -v godot 2>/dev/null || true)"
[ -x "$GODOT_BIN" ] || { echo "godot.sh: Godot binary not found; export GODOT_BIN" >&2; return 1 2>/dev/null || exit 1; }
