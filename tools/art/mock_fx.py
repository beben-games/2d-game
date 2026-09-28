#!/usr/bin/env python3
"""Mock-ups of effects done in code instead of generated frames, as GIFs on sand for the user.

    tools/art/mock_fx.py dash <pose.png> [<idle.png>] [--out reports/anim/mock_dash.gif]
    tools/art/mock_fx.py hit <frame.png> [--out reports/anim/mock_hit.gif]
    tools/art/mock_fx.py fall <idle.png> <fallen.png> [--out reports/anim/mock_fall.gif]

dash: a crouch on the idle, then the pose stretched and eased DASH_PX down the cell over
DASH_FRAMES with speed streaks, a dust puff, and AFTERIMAGES copies (fainter, tinted toward
TRAIL_TINT), a landing squash, the idle, and the afterimages fading after the stop. fall: the idle
tips back (squashed upward) onto the fallen still with a small bounce. hit: a frame flashes white
for FLASH_FRAMES while it is knocked back KNOCK_PX and settles, as the game's flash shader and
knockback would draw it. Both at the given scale; the numbers are the mock's, the game tunes its own.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

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


def scaled(sprite: Image.Image, sx: float, sy: float) -> Image.Image:
    return sprite.resize((max(1, round(sprite.width * sx)), max(1, round(sprite.height * sy))), Image.Resampling.NEAREST)


def streaks(width: int, top: int, bottom: int, x: int, alpha: int) -> Image.Image:
    """Thin light lines trailing behind a figure moving down: the speed effect."""
    layer = Image.new("RGBA", (CELL_W, CELL_H))
    draw = ImageDraw.Draw(layer)
    for dx, length in ((3, 1.0), (width // 2, 0.7), (width - 4, 0.9)):
        y0 = round(bottom - (bottom - top) * length)
        draw.line([(x + dx, y0), (x + dx, bottom)], fill=(255, 250, 230, alpha))
    return layer


def dash(pose: Image.Image, scale: int, idle: Image.Image | None = None) -> list[Image.Image]:
    """Anticipation (a crouch), the launch (stretched, streaks, afterimages), a landing squash, and
    the afterimages fading after the stop, with a dust puff where the dash began."""
    idle = idle or pose
    x0, y0 = (CELL_W - pose.width) // 2, 10
    frames = []
    crouch = scaled(idle, 1.06, 0.9)
    for _ in range(2):
        frames.append(frame_on_sand([(crouch, (CELL_W - crouch.width) // 2, y0 + idle.height - crouch.height)], scale))
    trail = []
    for i in range(1, DASH_FRAMES + 1):
        ease = 1 - (1 - i / DASH_FRAMES) ** 2
        y = y0 + round(DASH_PX * ease)
        body = scaled(pose, 0.94, 1.12)
        bx = (CELL_W - body.width) // 2
        ghosts = [(tinted(pose, TRAIL_TINT, 0.5 + 0.15 * k, 0.55 - 0.15 * k), x0, gy)
                  for k, gy in enumerate(reversed(trail[-AFTERIMAGES:]))]
        puff = dust(x0 + pose.width // 2, y0 + pose.height, i)
        layers = [(puff, 0, 0)] + list(reversed(ghosts)) + [(streaks(pose.width, y0, y + 6, x0, 170), 0, 0), (body, bx, y)]
        frames.append(frame_on_sand(layers, scale))
        trail.append(y)
    land_y = y0 + DASH_PX
    squash = scaled(pose, 1.08, 0.9)
    for k in range(6):
        fade = 0.45 * (1 - k / 6)
        ghosts = [(tinted(pose, TRAIL_TINT, 0.6, fade * (1 - 0.25 * j)), x0, gy) for j, gy in enumerate(reversed(trail[-AFTERIMAGES:]))]
        body, by = (squash, land_y + pose.height - squash.height) if k < 2 else (idle, land_y + pose.height - idle.height)
        frames.append(frame_on_sand(list(reversed(ghosts)) + [(body, (CELL_W - body.width) // 2, by)], scale))
    frames += [frames[-1]] * 6
    return frames


def dust(x: int, y: int, step: int) -> Image.Image:
    layer = Image.new("RGBA", (CELL_W, CELL_H))
    draw = ImageDraw.Draw(layer)
    alpha = max(0, 200 - step * 35)
    for dx, dy in ((-4, 0), (4, 0), (-7, -1), (7, -1), (0, 1)):
        spread = 1 + step // 2
        draw.point((x + dx * spread // 2, y + dy), fill=(250, 225, 170, alpha))
    return layer


def fall(idle: Image.Image, fallen: Image.Image, scale: int) -> list[Image.Image]:
    """A code fall: the standing sprite tips back (squashed upward, as a body falling away from a
    south-facing camera), then the fallen still lands with a one-pixel bounce."""
    x, base = (CELL_W - idle.width) // 2, 60 + idle.height
    frames = [frame_on_sand([(idle, x, base - idle.height)], scale)] * 3
    for sy, lift in ((0.92, 1), (0.8, 3), (0.62, 5)):
        body = scaled(idle, 1.04, sy)
        frames.append(frame_on_sand([(body, (CELL_W - body.width) // 2, base - body.height - lift)], scale))
    fx = (CELL_W - fallen.width) // 2
    for bounce in (2, 0, 1, 0):
        frames.append(frame_on_sand([(fallen, fx, base - fallen.height - 6 - bounce)], scale))
    frames += [frames[-1]] * 10
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
    parser.add_argument("effect", choices=["dash", "hit", "fall"])
    parser.add_argument("sprite")
    parser.add_argument("second", nargs="?", help="dash: the idle for the crouch and the recovery; fall: the fallen still")
    parser.add_argument("--scale", type=int, default=3)
    parser.add_argument("--out")
    args = parser.parse_args(argv)
    sprite = Image.open(args.sprite).convert("RGBA")
    second = Image.open(args.second).convert("RGBA") if args.second else None
    if args.effect == "dash":
        frames = dash(sprite, args.scale, second)
    elif args.effect == "fall":
        frames = fall(sprite, second, args.scale)
    else:
        frames = hit(sprite, args.scale)
    out = Path(args.out or f"reports/anim/mock_{args.effect}.gif")
    out.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(out, save_all=True, append_images=frames[1:], duration=MS, loop=0)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
