#!/usr/bin/env python3
"""Animated previews of a concept's animations, for the user to watch them move.

    tools/art/preview.py C2 [--scale 3] [--ms 100] [--only c2_run_]

Writes reports/art_<concept>_anim.gif (every animation of the concept in a grid, labelled, each
looping on its own frames at the same frame rate) and reports/anim/<id>.gif (one each). Frames come
from the same place the contact sheet reads them (tools/art/sheet.py groups_of); every frame sits
on flat sand at the given scale, anchored at the feet (bottom centre), since the methods draw on
different canvases.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sheet import ROOT, groups_of  # noqa: E402

SAND = (236, 184, 104, 255)  # a flat sand, the S5 swatch's middle tone
LABEL_HEIGHT = 20
GRID_FRAMES = 48
CELL = 80


def backdrop(size: int, scale: int) -> Image.Image:
    return Image.new("RGBA", (size * scale, size * scale), SAND)


def placed(frame: Image.Image, scale: int) -> Image.Image:
    """A frame on a CELL-sized sand square, feet at the bottom centre."""
    cell = backdrop(CELL, scale)
    box = frame.getbbox() or (0, 0, frame.width, frame.height)
    figure = frame.crop((0, 0, frame.width, box[3]))
    figure = figure.resize((figure.width * scale, figure.height * scale), Image.Resampling.NEAREST)
    x = (cell.width - figure.width) // 2
    y = cell.height - figure.height - 4 * scale
    cell.alpha_composite(figure, (x, max(0, y)))
    return cell


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("concept")
    parser.add_argument("--scale", type=int, default=3)
    parser.add_argument("--ms", type=int, default=100)
    parser.add_argument("--only", default="")
    args = parser.parse_args(argv)
    raw = ROOT / "art" / "raw" / args.concept
    prefixes = [p for p in args.only.split(",") if p]
    animations = []
    for call in sorted(d for d in raw.iterdir() if d.is_dir()):
        if prefixes and not any(call.name.startswith(p) for p in prefixes):
            continue
        for label, paths in groups_of(call):
            if len(paths) > 1 and "candidates" not in label:
                animations.append((label, [placed(Image.open(p).convert("RGBA"), args.scale) for p in paths]))
    if not animations:
        print(f"no animations under {raw}", file=sys.stderr)
        return 1
    (ROOT / "reports" / "anim").mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default(size=14)
    for label, frames in animations:
        out = ROOT / "reports" / "anim" / f"{label}.gif"
        frames[0].save(out, save_all=True, append_images=frames[1:], duration=args.ms, loop=0, disposal=2)
    side = CELL * args.scale
    columns = min(4, len(animations))
    rows = (len(animations) + columns - 1) // columns
    grid = []
    for t in range(GRID_FRAMES):
        canvas = Image.new("RGBA", (columns * side, rows * (side + LABEL_HEIGHT)), (40, 36, 44, 255))
        draw = ImageDraw.Draw(canvas)
        for i, (label, frames) in enumerate(animations):
            x, y = (i % columns) * side, (i // columns) * (side + LABEL_HEIGHT)
            draw.text((x + 4, y + 3), f"{label} ({len(frames)})", fill=(235, 225, 205), font=font)
            canvas.alpha_composite(frames[t % len(frames)], (x, y + LABEL_HEIGHT))
        grid.append(canvas.convert("RGB"))
    out = ROOT / "reports" / f"art_{args.concept}_anim.gif"
    grid[0].save(out, save_all=True, append_images=grid[1:], duration=args.ms, loop=0)
    print(out, f"and {len(animations)} in reports/anim/")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
