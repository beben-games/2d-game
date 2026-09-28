#!/usr/bin/env python3
"""A contact sheet of a concept's raw outputs for the user's review.

    tools/art/sheet.py C1 [--scale 2] [--only S1_,S2_] [--out reports/art_C1.png]

One row per call (art/raw/<concept>/<id>/), labelled with the id: a character's eight rotations
from the south round to the south-west, then the call's loose images in order (a Pro call's
candidates), wrapped at WRAP a row. Every
image sits on a checker at the given scale (2: one art pixel as two screen pixels, the planned
1080p look). Nothing is judged here: the sheet shows every output.
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DIRECTIONS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]
WRAP = 16
PAD = 8
LABEL_WIDTH = 250
CHECK = 8
BACKGROUND = (40, 36, 44, 255)
TEXT = (235, 225, 205, 255)


def groups_of(call_dir: Path) -> list[tuple[str, list[Path]]]:
    """A character's rotations, then any loose images (a Pro call's candidates), as labelled groups."""
    groups = []
    rotations = call_dir / "character"
    if rotations.exists():
        meta = json.loads((rotations / "metadata.json").read_text())
        frames = meta["states"][0]["frames"]["rotations"]
        groups.append((call_dir.name, [rotations / frames[d] for d in DIRECTIONS if d in frames]))
    loose = sorted(call_dir.glob("[0-9][0-9].png"))
    if loose:
        groups.append((call_dir.name + (" candidates" if groups else ""), loose))
    return groups


def checker(size: tuple[int, int]) -> Image.Image:
    tile = Image.new("RGBA", size, (200, 200, 200, 255))
    draw = ImageDraw.Draw(tile)
    for y in range(0, size[1], CHECK):
        for x in range(0, size[0], CHECK):
            if (x // CHECK + y // CHECK) % 2:
                draw.rectangle([x, y, x + CHECK - 1, y + CHECK - 1], fill=(160, 160, 160, 255))
    return tile


def cell(path: Path, scale: int) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    image = image.resize((image.width * scale, image.height * scale), Image.Resampling.NEAREST)
    base = checker(image.size)
    base.alpha_composite(image)
    return base


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("concept")
    parser.add_argument("--scale", type=int, default=2)
    parser.add_argument("--only", default="", help="comma-separated id prefixes")
    parser.add_argument("--out")
    args = parser.parse_args(argv)
    raw = ROOT / "art" / "raw" / args.concept
    prefixes = [p for p in args.only.split(",") if p]
    calls = [d for d in sorted(raw.iterdir()) if d.is_dir()
             and (not prefixes or any(d.name.startswith(p) for p in prefixes))]
    rows = []
    for call in calls:
        for label, paths in groups_of(call):
            cells = [cell(p, args.scale) for p in paths]
            for start in range(0, max(len(cells), 1), WRAP):
                rows.append((label if start == 0 else "", cells[start:start + WRAP]))
    if not rows:
        print(f"nothing under {raw}", file=sys.stderr)
        return 1
    width = LABEL_WIDTH + max(sum(c.width + PAD for c in cells) for _, cells in rows) + PAD
    height = sum(max([c.height for c in cells] or [16]) + PAD for _, cells in rows) + PAD
    sheet = Image.new("RGBA", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=14)
    y = PAD
    for label, cells in rows:
        row_height = max([c.height for c in cells] or [16])
        draw.text((PAD, y + row_height // 2 - 7), label, fill=TEXT, font=font)
        x = LABEL_WIDTH
        for c in cells:
            sheet.alpha_composite(c, (x, y + row_height - c.height))
            x += c.width + PAD
        y += row_height + PAD
    out = Path(args.out) if args.out else ROOT / "reports" / f"art_{args.concept}.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
