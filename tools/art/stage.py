#!/usr/bin/env python3
"""Lays a corner (Wang) tileset out as the tier 1 arena, to judge a tileset as a whole stage.

    tools/art/stage.py art/raw/C5/<call>/ [--out reports/art_stage_<call>.png]

The arena is ArenaGrid's: 28 x 15 cells, a two-row wall on top and one row on the other sides, the
floor inside (scripts/arena_grid.gd; the numbers are repeated here, the one place outside the game).
A vertex is floor ("lower") when it lies on or inside the floor's outline, wall ("upper")
otherwise; each cell takes the tile whose four corners match, so the wall ring carries the
transition (the wall's face) and the floor is plain. A standard tileset names its corners
(detail.json's tiles[].corners); a Pro tileset gives a 4-bit mask per tile: SE 1, SW 2, NE 4,
NW 8, a set bit for the floor (the first of its terrains), read off its tiles on 2026-09-28.
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

WIDTH, HEIGHT, TOP_ROWS = 28, 15, 2
CORNERS = ("NW", "NE", "SW", "SE")


def vertex_is_wall(vx: int, vy: int) -> bool:
    return not (1 <= vx <= WIDTH - 1 and TOP_ROWS <= vy <= HEIGHT - 1)


def tiles_of(call: Path) -> tuple[dict, int]:
    detail = json.loads((call / "detail.json").read_text())
    images = sorted(call.glob("[0-9][0-9].png"))
    if "tileset" in detail:
        table = {}
        for tile, path in zip(detail["tileset"]["tiles"], images):
            key = tuple(tile["corners"][c] == "upper" for c in CORNERS)
            table[key] = Image.open(path).convert("RGBA")
        return table, detail["tileset"]["tile_size"]["width"]
    table = {}
    for name, rule in detail["tile_rules"]["tiles"].items():
        mask = rule["mask"]
        key = tuple(not (mask & bit) for bit in (8, 4, 2, 1))
        table[key] = Image.open(images[int(name.split("_")[1])]).convert("RGBA")
    return table, detail["tile_rules"]["frame_px"]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("call")
    parser.add_argument("--out")
    args = parser.parse_args(argv)
    call = Path(args.call)
    table, size = tiles_of(call)
    stage = Image.new("RGBA", (WIDTH * size, HEIGHT * size), (0, 0, 0, 255))
    missing = set()
    for y in range(HEIGHT):
        for x in range(WIDTH):
            key = (vertex_is_wall(x, y), vertex_is_wall(x + 1, y), vertex_is_wall(x, y + 1), vertex_is_wall(x + 1, y + 1))
            tile = table.get(key)
            if tile is None:
                missing.add(key)
                continue
            stage.alpha_composite(tile.resize((size, size)) if tile.size != (size, size) else tile, (x * size, y * size))
    out = Path(args.out) if args.out else Path("reports") / f"art_stage_{call.name}.png"
    stage.save(out)
    print(out, stage.size, f"missing corner sets: {sorted(missing)}" if missing else "")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
