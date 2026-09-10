#!/usr/bin/env python3
"""Write data/icons.json: card and HUD icons by name.

Usage: tools/gen_icons.py
Each entry is {"sheet": name, "x": px, "y": px, "w": 16, "h": 16}. Sheets are the textures
IconAtlas knows: "raven" is assets/raven_icons/raven_16.png, 16 columns of 16 px cells, addressed
here by (row, col); "guns" is assets/guns/handgun.png, a single 16x16 cell.
Cell choices were made by eye on the Raven sheet; tools/icon_sheet.gd renders them for a check.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "data/icons.json"
CELL = 16

# name: (sheet, row, col)
ICONS = {
    "damage": ("raven", 45, 7),          # sword with a sparkle
    "fire_rate": ("raven", 39, 10),      # running figure (haste); the sheet has no hourglass
    "multishot": ("raven", 52, 5),       # three orange shots fanning out
    "pierce": ("raven", 134, 9),         # blue arrow
    "bounce": ("raven", 67, 2),          # figure with a looping arrow overhead
    "homing": ("raven", 44, 14),         # eye
    "flaming": ("raven", 62, 5),         # fire burst
    "shock": ("raven", 64, 0),           # lightning bolt
    "chill": ("raven", 63, 4),           # ice crystals
    "heal": ("raven", 67, 0),            # figure with a green cross
    "heart_container": ("raven", 65, 1), # gold heart with arrows
    "dash_charge": ("raven", 41, 10),    # boot with motion lines
    "crossbow": ("raven", 106, 2),       # crossbow with a green bolt
    "handgun": ("guns", 0, 0),
}

SHEETS = {"raven": (16, 137), "guns": (1, 1)}  # sheet: (columns, rows) of 16 px cells
for name, (sheet, row, col) in ICONS.items():
    assert sheet in SHEETS, f"{name}: unknown sheet {sheet!r}"
    cols, rows = SHEETS[sheet]
    assert 0 <= col < cols and 0 <= row < rows, f"{name}: ({row}, {col}) is off the {sheet} sheet"

entries = {
    name: {"sheet": sheet, "x": col * CELL, "y": row * CELL, "w": CELL, "h": CELL}
    for name, (sheet, row, col) in ICONS.items()
}
OUT.write_text(json.dumps(entries, indent=1, sort_keys=True) + "\n")
print(f"wrote {len(entries)} icons to {OUT}")
