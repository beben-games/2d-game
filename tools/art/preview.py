#!/usr/bin/env python3
"""Animated previews of a concept's animations, for the user to watch them move.

    tools/art/preview.py C2 [--scale 3] [--ms 100] [--only c2_run_] [--timing c2_idle_template=200]

Writes reports/art_<concept>_anim.gif (every animation of the concept in a grid, labelled, each
looping on its own frames at the same frame rate) and reports/anim/<id>.gif (one each). Frames come
from the same place the contact sheet reads them (tools/art/sheet.py groups_of); every frame sits
on flat sand at the given scale, one offset per animation (its lowest foot at the bottom), as the
game plays it. Stills (characters, states) are left to the contact sheet.
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
TICK = 50
CELL = 80


def backdrop(size: int, scale: int) -> Image.Image:
    return Image.new("RGBA", (size * scale, size * scale), SAND)


def placed(frames: list[Image.Image], scale: int) -> list[Image.Image]:
    """An animation's frames on CELL-sized sand squares, all with one offset (the lowest foot of any
    frame at the cell's bottom, the canvas centred), as the game plays them on a fixed canvas: a
    per-frame anchor would turn the figure's bounce into jitter."""
    bottom = max((f.getbbox() or (0, 0, 0, f.height))[3] for f in frames)
    cells = []
    for frame in frames:
        cell = backdrop(CELL, scale)
        figure = frame.crop((0, 0, frame.width, bottom))
        figure = figure.resize((figure.width * scale, figure.height * scale), Image.Resampling.NEAREST)
        cell.alpha_composite(figure, ((cell.width - figure.width) // 2, max(0, cell.height - figure.height - 4 * scale)))
        cells.append(cell)
    return cells


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("concept")
    parser.add_argument("--scale", type=int, default=3)
    parser.add_argument("--ms", type=int, default=100)
    parser.add_argument("--only", default="")
    parser.add_argument("--timing", default="", help="id=ms,... a frame time per animation (the default --ms)")
    args = parser.parse_args(argv)
    timings = {k: int(v) for k, v in (t.split("=") for t in args.timing.split(",") if t)}
    raw = ROOT / "art" / "raw" / args.concept
    prefixes = [p for p in args.only.split(",") if p]
    animations = []
    for call in sorted(d for d in raw.iterdir() if d.is_dir()):
        if prefixes and not any(call.name.startswith(p) for p in prefixes):
            continue
        request = (call / "request.json").read_text() if (call / "request.json").exists() else ""
        if "/animate-character" not in request:
            continue  # characters and states are stills in eight directions: the contact sheet shows them
        for label, paths in groups_of(call):
            if len(paths) > 1:
                ms = timings.get(label, args.ms)
                animations.append((label, ms, placed([Image.open(p).convert("RGBA") for p in paths], args.scale)))
    if not animations:
        print(f"no animations under {raw}", file=sys.stderr)
        return 1
    (ROOT / "reports" / "anim").mkdir(parents=True, exist_ok=True)
    font = ImageFont.load_default(size=14)
    for label, ms, frames in animations:
        out = ROOT / "reports" / "anim" / f"{label}.gif"
        frames[0].save(out, save_all=True, append_images=frames[1:], duration=ms, loop=0, disposal=2)
    side = CELL * args.scale
    columns = min(4, len(animations))
    rows = (len(animations) + columns - 1) // columns
    grid = []
    # The grid ticks every TICK ms; each cell shows its frame for its own time.
    longest = max(ms * len(frames) for _, ms, frames in animations)
    for t in range(0, max(longest, GRID_FRAMES * TICK), TICK):
        canvas = Image.new("RGBA", (columns * side, rows * (side + LABEL_HEIGHT)), (40, 36, 44, 255))
        draw = ImageDraw.Draw(canvas)
        for i, (label, ms, frames) in enumerate(animations):
            x, y = (i % columns) * side, (i // columns) * (side + LABEL_HEIGHT)
            draw.text((x + 4, y + 3), f"{label} ({len(frames)} @ {ms} ms)", fill=(235, 225, 205), font=font)
            canvas.alpha_composite(frames[(t // ms) % len(frames)], (x, y + LABEL_HEIGHT))
        grid.append(canvas.convert("RGB"))
    out = ROOT / "reports" / f"art_{args.concept}_anim.gif"
    grid[0].save(out, save_all=True, append_images=grid[1:], duration=TICK, loop=0)
    print(out, f"and {len(animations)} in reports/anim/")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
