#!/usr/bin/env python3
"""Mock-ups of effects done in code instead of generated frames, as GIFs on sand for the user.

    tools/art/mock_fx.py dash <pose.png> [--out reports/anim/mock_dash.gif]
    tools/art/mock_fx.py hit <frame.png> [--out reports/anim/mock_hit.gif]

dash: the still pose travels DASH_PX down the cell over DASH_FRAMES, leaving AFTERIMAGES copies
behind it, each fainter and tinted toward TRAIL_TINT, then a short hold. hit: a frame flashes white
for FLASH_FRAMES while it is knocked back KNOCK_PX and settles, as the game's flash shader and
knockback would draw it. Both at the given scale; the numbers are the mock's, the game tunes its own.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from preview import SAND  # noqa: E402

CELL_W, CELL_H = 80, 120
DASH_FRAMES, DASH_PX, AFTERIMAGES = 6, 48, 3
TRAIL_TINT = (120, 200, 255)
FLASH_FRAMES, KNOCK_PX = 2, 4
MS = 50


def tinted(sprite: Image.Image, colour: tuple, amount: float, alpha: float) -> Image.Image:
    out = sprite.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (round(r + (colour[0] - r) * amount), round(g + (colour[1] - g) * amount),
                            round(b + (colour[2] - b) * amount), round(a * alpha))
    return out


def frame_on_sand(layers: list[tuple[Image.Image, int, int]], scale: int) -> Image.Image:
    cell = Image.new("RGBA", (CELL_W, CELL_H), SAND)
    for sprite, x, y in layers:
        cell.alpha_composite(sprite, (x, y))
    return cell.resize((CELL_W * scale, CELL_H * scale), Image.Resampling.NEAREST)


def dash(pose: Image.Image, scale: int) -> list[Image.Image]:
    x = (CELL_W - pose.width) // 2
    frames, trail = [], []
    for i in range(DASH_FRAMES + 1):
        y = 8 + round(DASH_PX * i / DASH_FRAMES)
        ghosts = [(tinted(pose, TRAIL_TINT, 0.5 + 0.15 * k, 0.6 - 0.18 * k), x, gy)
                  for k, gy in enumerate(reversed(trail[-AFTERIMAGES:]))]
        frames.append(frame_on_sand(list(reversed(ghosts)) + [(pose, x, y)], scale))
        trail.append(y)
    frames += [frames[-1]] * 6
    return frames


def hit(sprite: Image.Image, scale: int) -> list[Image.Image]:
    x, y = (CELL_W - sprite.width) // 2, 40
    white = tinted(sprite, (255, 255, 255), 1.0, 1.0)
    frames = [frame_on_sand([(sprite, x, y)], scale)] * 4
    for i in range(6):
        knock = round(KNOCK_PX * (1 - i / 5))
        frames.append(frame_on_sand([(white if i < FLASH_FRAMES else sprite, x, y - knock)], scale))
    frames += [frame_on_sand([(sprite, x, y)], scale)] * 6
    return frames


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("effect", choices=["dash", "hit"])
    parser.add_argument("sprite")
    parser.add_argument("--scale", type=int, default=3)
    parser.add_argument("--out")
    args = parser.parse_args(argv)
    sprite = Image.open(args.sprite).convert("RGBA")
    frames = (dash if args.effect == "dash" else hit)(sprite, args.scale)
    out = Path(args.out or f"reports/anim/mock_{args.effect}.gif")
    out.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=MS, loop=0)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
