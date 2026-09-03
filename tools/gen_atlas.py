#!/usr/bin/env python3
"""Convert the 0x72 tile_list into data/atlas.json.

Usage: tools/gen_atlas.py [path/to/tile_list.txt]
Each input line is: name x y w h. Animation frames are separate lines named <anim>_f<N>;
they are folded into one entry {x, y, w, h, frames} where frame N sits at x + N*w.
Blank lines and anything that does not parse are skipped, as are animations whose frames are not
contiguous (a warning is printed for those). Duplicate names and 16x16 sprites that are not on the
16 px grid are also reported on stderr.
"""
import json
import pathlib
import re
import sys

FRAME_RE = re.compile(r"^(.+)_f(\d+)$")
TILE = 16
ROOT = pathlib.Path(__file__).resolve().parents[1]

src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/dungeon_tileset_ii/tile_list.txt"
out = ROOT / "data/atlas.json"

entries = {}
frames = {}  # anim name -> {frame index: (x, y, w, h)}
for line in src.read_text().splitlines():
    parts = line.split()
    if len(parts) < 5:
        continue
    try:
        x, y, w, h = (int(p) for p in parts[1:5])
    except ValueError:
        continue
    match = FRAME_RE.match(parts[0])
    if match:
        by_index = frames.setdefault(match.group(1), {})
        if int(match.group(2)) in by_index:
            print(f"warning: duplicate frame {parts[0]}; keeping the last one", file=sys.stderr)
        by_index[int(match.group(2))] = (x, y, w, h)
    else:
        if parts[0] in entries:
            print(f"warning: duplicate sprite {parts[0]}; keeping the last one", file=sys.stderr)
        entries[parts[0]] = {"x": x, "y": y, "w": w, "h": h, "frames": 1}

for name, by_index in frames.items():
    # SpriteAtlas addresses frame N at x + N*w, so it cannot represent sprites that break that layout.
    if 0 not in by_index:
        print(f"warning: skipping {name}: has no _f0 frame (frames: {sorted(by_index)})", file=sys.stderr)
        continue
    x0, y0, w, h = by_index[0]
    count = max(by_index) + 1
    if any(by_index.get(i) != (x0 + i * w, y0, w, h) for i in range(count)):
        print(f"warning: skipping {name}: frames are not laid out contiguously {w} px apart", file=sys.stderr)
        continue
    entries[name] = {"x": x0, "y": y0, "w": w, "h": h, "frames": count}

# SpriteAtlas.tile_coords() only works for 16x16 sprites on the 16 px grid; the rest need texture().
off_grid = sorted(
    n for n, e in entries.items()
    if e["w"] == TILE and e["h"] == TILE and (e["x"] % TILE or e["y"] % TILE)
)
if off_grid:
    print(f"warning: {len(off_grid)} 16x16 sprites are off the {TILE} px grid (texture() only, "
          f"not tile_coords()): {', '.join(off_grid)}", file=sys.stderr)

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(entries, indent=1, sort_keys=True) + "\n")
print(f"wrote {len(entries)} sprites to {out}")
