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


def unique(paths: list[Path]) -> list[Path]:
    """Drops repeats by pixels: a template's result carries its frames twice (images and
    quantized_images, the same pixels in different files)."""
    seen, kept = set(), []
    for path in paths:
        image = Image.open(path).convert("RGBA")
        data = (image.size, image.tobytes())
        if data not in seen:
            seen.add(data)
            kept.append(path)
    return kept


def groups_of(call_dir: Path) -> list[tuple[str, list[Path]]]:
    """What a call made, as labelled groups: an animation's frames (inline, or from the character
    download under the call's name), a state's rotations, or a character's rotations then any loose
    images (a Pro call's candidates)."""
    request = json.loads((call_dir / "request.json").read_text()) if (call_dir / "request.json").exists() else {}
    endpoint = request.get("endpoint", "")
    loose = unique(sorted(call_dir.glob("[0-9][0-9].png")))
    rotations = call_dir / "character"
    meta = json.loads((rotations / "metadata.json").read_text()) if (rotations / "metadata.json").exists() else None
    if endpoint == "/animate-character":
        if loose:
            return [(call_dir.name, loose)]
        for state in (meta or {}).get("states", []):
            frames = state["frames"]["animations"].get(call_dir.name, {})
            if frames:
                return [(call_dir.name, [rotations / f for d in DIRECTIONS for f in frames.get(d, [])])]
        return []
    groups = []
    live = [call_dir / f"{d}.png" for d in DIRECTIONS if (call_dir / f"{d}.png").exists()]
    if endpoint == "/create-character-state" and live:
        # The state's own rotations, fetched by its id; the character download's copy can be stale.
        return [(call_dir.name, live)]
    if meta:
        states = meta["states"]
        if endpoint == "/create-character-state":
            # The download holds the character's every state; take the one this call named.
            wanted = request.get("body", {}).get("state_name", "")
            states = [st for st in states if st.get("folder", "").lower() == wanted.lower()] or \
                [st for st in states if st.get("folder") != "Idle"] or states
        frames = states[0]["frames"]["rotations"]
        groups.append((call_dir.name, [rotations / frames[d] for d in DIRECTIONS if d in frames]))
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
