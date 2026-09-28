#!/usr/bin/env python3
"""Palettes for the art: how well images hold up to one, and a candidate drawn from images.

    tools/art/palette.py fit <palette.gpl> <image>... [--sheet reports/x.png] [--label name]
    tools/art/palette.py extract <n> <image>... --out art/style/<name>.gpl [--name "Name"]
    tools/art/palette.py extend <base.gpl> <k> <image>... --out art/style/<name>.gpl

Colours are compared in OKLab (distances x100: under 2 is hard to see side by side, over 5 is a
visible shift, over 10 a different colour). `fit` maps every opaque pixel to its nearest palette
colour and reports, per image: the distinct colours before and after, the mean, 95th-percentile,
and worst distance, and the share of pixels moved by more than 5; `--sheet` lays each image beside
its snapped version at 3x. An outline black snapped to a palette's near-black counts as a match
(`is_black`). `extract` clusters the images' distinct colours (k-means in OKLab, each
colour weighted by the square root of its pixel count so small accents like a crest survive) into
n colours, sorted dark to light by hue family, and writes a GIMP palette Aseprite can load.
`extend` adds to a base palette the k colours of the images that most reduce its error.
"""

import argparse
import math
import random
import sys
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

MOVED = 5.0


def srgb_to_linear(c: float) -> float:
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def oklab(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    r, g, b = (srgb_to_linear(c) for c in rgb)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(v) ** (1 / 3), v) for v in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def linear_to_srgb(c: float) -> int:
    c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return max(0, min(255, round(c * 255)))


def oklab_to_rgb(lab: tuple[float, float, float]) -> tuple[int, int, int]:
    L, a, b = lab
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (linear_to_srgb(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            linear_to_srgb(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            linear_to_srgb(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))


def distance(p: tuple, q: tuple) -> float:
    return 100 * math.dist(p, q)


def is_black(colour: tuple) -> bool:
    """Outline black: OKLab stretches the dark end, so pure black against a palette's near-black
    (AAP-64's 060608) measures 12 while the eye sees no difference; those count as a match."""
    return max(colour) <= 8


def read_gpl(path: Path) -> list[tuple[int, int, int]]:
    colours = []
    for line in path.read_text().splitlines():
        parts = line.split()
        if len(parts) >= 3 and all(p.isdigit() for p in parts[:3]):
            colours.append(tuple(int(p) for p in parts[:3]))
    return colours


def write_gpl(path: Path, name: str, colours: list[tuple[int, int, int]]) -> None:
    lines = ["GIMP Palette", f"#Palette Name: {name}", f"#Colors: {len(colours)}"]
    lines += [f"{r:>3} {g:>3} {b:>3}\t{r:02x}{g:02x}{b:02x}" for r, g, b in colours]
    path.write_text("\n".join(lines) + "\n")


def opaque_pixels(image: Image.Image) -> Counter:
    return Counter(p[:3] for p in image.convert("RGBA").get_flattened_data() if p[3] == 255)


def nearest(colour_lab: tuple, palette_lab: list[tuple]) -> int:
    return min(range(len(palette_lab)), key=lambda i: math.dist(colour_lab, palette_lab[i]))


def snap(image: Image.Image, palette: list, palette_lab: list, cache: dict) -> Image.Image:
    out = image.convert("RGBA").copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 255:
                continue
            if (r, g, b) not in cache:
                cache[(r, g, b)] = nearest(oklab((r, g, b)), palette_lab)
            px[x, y] = (*palette[cache[(r, g, b)]], 255)
    return out


def fit(args) -> int:
    palette = read_gpl(Path(args.palette))
    palette_lab = [oklab(c) for c in palette]
    cache: dict = {}
    rows = []
    print(f"{'image':<44} {'colours':>9} {'mean':>6} {'p95':>6} {'worst':>6} {'moved>5':>8}")
    totals = Counter()
    for name in args.images:
        image = Image.open(name).convert("RGBA")
        counts = opaque_pixels(image)
        dists = []
        after = set()
        for colour, n in counts.items():
            if colour not in cache:
                cache[colour] = nearest(oklab(colour), palette_lab)
            index = cache[colour]
            after.add(index)
            d = 0.0 if is_black(colour) and is_black(palette[index]) else distance(oklab(colour), palette_lab[index])
            dists += [d] * n
        dists.sort()
        moved = sum(1 for d in dists if d > MOVED) / len(dists)
        mean = sum(dists) / len(dists)
        totals["pixels"] += len(dists)
        totals["sum"] += sum(dists)
        totals["moved"] += sum(1 for d in dists if d > MOVED)
        print(f"{Path(name).as_posix()[-44:]:<44} {len(counts):>4}>{len(after):<4} {mean:>6.1f} "
              f"{dists[int(0.95 * (len(dists) - 1))]:>6.1f} {dists[-1]:>6.1f} {100 * moved:>7.0f}%")
        rows.append((image, snap(image, palette, palette_lab, cache)))
    print(f"all: mean {totals['sum'] / totals['pixels']:.1f}, moved>5 {100 * totals['moved'] / totals['pixels']:.0f}% "
          f"of {totals['pixels']} pixels; palette colours used {len(set(cache.values()))} of {len(palette)}")
    if args.sheet:
        scale, pad = 3, 6
        cells = [(a.resize((a.width * scale, a.height * scale), Image.Resampling.NEAREST),
                  b.resize((b.width * scale, b.height * scale), Image.Resampling.NEAREST)) for a, b in rows]
        per_row = 4
        groups = [cells[i:i + per_row] for i in range(0, len(cells), per_row)]
        width = max(sum(a.width * 2 + pad * 3 for a, _ in g) for g in groups) + pad
        height = 24 + sum(max(a.height for a, _ in g) + pad for g in groups) + pad
        sheet = Image.new("RGBA", (width, height), (40, 36, 44, 255))
        draw = ImageDraw.Draw(sheet)
        draw.text((pad, 4), f"each pair: original, then snapped to {args.label or Path(args.palette).stem}",
                  fill=(235, 225, 205), font=ImageFont.load_default(size=14))
        y = 24
        for g in groups:
            x = pad
            for a, b in g:
                sheet.alpha_composite(a, (x, y))
                sheet.alpha_composite(b, (x + a.width + pad, y))
                x += a.width * 2 + pad * 3
            y += max(a.height for a, _ in g) + pad
        Path(args.sheet).parent.mkdir(parents=True, exist_ok=True)
        sheet.save(args.sheet)
        print(args.sheet)
    return 0


def extract(args) -> int:
    counts = Counter()
    for name in args.images:
        counts.update(opaque_pixels(Image.open(name)))
    colours = list(counts)
    points = [oklab(c) for c in colours]
    weights = [math.sqrt(counts[c]) for c in colours]
    rng = random.Random(1)
    # k-means++ seeding, then weighted Lloyd iterations.
    centres = [points[rng.choices(range(len(points)), weights=weights)[0]]]
    while len(centres) < args.n:
        d2 = [w * min(math.dist(p, c) ** 2 for c in centres) for p, w in zip(points, weights)]
        centres.append(points[rng.choices(range(len(points)), weights=d2)[0]])
    for _ in range(40):
        groups = [[] for _ in centres]
        for p, w in zip(points, weights):
            groups[nearest(p, centres)].append((p, w))
        centres = [tuple(sum(p[i] * w for p, w in g) / sum(w for _, w in g) for i in range(3)) if g else c
                   for g, c in zip(groups, centres)]
    rgb = sorted({oklab_to_rgb(c) for c in centres},
                 key=lambda c: (round(math.degrees(math.atan2(oklab(c)[2], oklab(c)[1])) / 45) if
                                math.hypot(*oklab(c)[1:]) > 0.03 else -1, oklab(c)[0]))
    write_gpl(Path(args.out), args.name, rgb)
    print(f"{args.out}: {len(rgb)} colours from {len(colours)} distinct in {sum(counts.values())} pixels")
    return 0


def extend(args) -> int:
    """A base palette plus the k colours from the images that most reduce the fit's error (greedy)."""
    base = read_gpl(Path(args.base))
    counts = Counter()
    for name in args.images:
        counts.update(opaque_pixels(Image.open(name)))
    colours = [c for c in counts if not is_black(c)]
    labs = {c: oklab(c) for c in colours}
    current = {c: min(distance(labs[c], oklab(b)) for b in base) for c in colours}
    added = []
    for _ in range(args.k):
        def gain(candidate):
            return sum(counts[c] * max(0.0, current[c] - distance(labs[c], labs[candidate])) for c in colours)
        best = max(colours, key=gain)
        added.append(best)
        for c in colours:
            current[c] = min(current[c], distance(labs[c], labs[best]))
    write_gpl(Path(args.out), args.name, base + added)
    print(f"{args.out}: {len(base)} + {len(added)} colours: " + " ".join(f"{r:02x}{g:02x}{b:02x}" for r, g, b in added))
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    f = sub.add_parser("fit")
    f.add_argument("palette")
    f.add_argument("images", nargs="+")
    f.add_argument("--sheet")
    f.add_argument("--label")
    e = sub.add_parser("extract")
    e.add_argument("n", type=int)
    e.add_argument("images", nargs="+")
    e.add_argument("--out", required=True)
    e.add_argument("--name", default="Candidate")
    x = sub.add_parser("extend")
    x.add_argument("base")
    x.add_argument("k", type=int)
    x.add_argument("images", nargs="+")
    x.add_argument("--out", required=True)
    x.add_argument("--name", default="Extended")
    args = parser.parse_args(argv)
    return {"fit": fit, "extract": extract, "extend": extend}[args.command](args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
