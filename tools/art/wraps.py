#!/usr/bin/env python3
"""Recolours the C1 S5 gladiator's forearm wraps (white, low contrast on sand) in code.

    tools/art/wraps.py    writes art/work/c1_gladiator_wraps/<ramp>/<direction>.png

The white patches below the head are found per direction; the lowest one is the loincloth and
stays, the others are the wraps and take a ramp from the sprite's own colours (the crest's reds,
the belt's browns), light to dark by the whites' own order. No generation spent.
"""
import json, colorsys, sys
from pathlib import Path
from PIL import Image

base = Path("art/raw/C1/r2_S5_gladiator_pro/character")
meta = json.loads((base/"metadata.json").read_text()); rot = meta["states"][0]["frames"]["rotations"]
DIRS = ["south","south-east","east","north-east","north","north-west","west","south-west"]
RAMPS = {  # light to dark, all taken from the sprite's own crest and belt
    "red": [(170,47,52),(130,23,33),(104,15,24)],
    "brown": [(168,123,71),(128,91,57),(93,61,44)],
}
def whiteish(p):
    if p[3] < 255: return False
    h,s,v = colorsys.rgb_to_hsv(*(c/255 for c in p[:3]))
    return s < 0.2 and v > 0.5
def components(im):
    w,h = im.size; px = im.load(); seen=set(); comps=[]
    for y in range(h):
        for x in range(w):
            if (x,y) in seen or not whiteish(px[x,y]): continue
            stack=[(x,y)]; seen.add((x,y)); comp=[]
            while stack:
                cx,cy=stack.pop(); comp.append((cx,cy))
                for nx,ny in ((cx+1,cy),(cx-1,cy),(cx,cy+1),(cx,cy-1)):
                    if 0<=nx<w and 0<=ny<h and (nx,ny) not in seen and whiteish(px[nx,ny]):
                        seen.add((nx,ny)); stack.append((nx,ny))
            comps.append(comp)
    return comps
def recolour(im, ramp):
    im = im.copy(); px = im.load()
    bbox = im.getbbox(); top, bottom = bbox[1], bbox[3]; height = bottom-top
    head_line = top + height*0.38
    comps = components(im)
    body = [c for c in comps if min(y for _,y in c) > head_line]
    if not body: return im, 0
    cloth = max(body, key=lambda c: (max(y for _, y in c), len(c)))   # the loincloth: the lowest white patch (where the legs start)
    changed = 0
    shades = sorted({px[x,y][:3] for c in body if c is not cloth for x,y in c}, key=lambda c: -sum(c))
    for c in body:
        if c is cloth: continue
        for x,y in c:
            r,g,b,a = px[x,y]
            i = min(len(ramp)-1, shades.index((r,g,b)) * len(ramp) // max(1,len(shades)))
            px[x,y] = (*ramp[i],255); changed += 1
    return im, changed
out = Path("art/work/c1_gladiator_wraps"); out.mkdir(parents=True, exist_ok=True)
for name, ramp in RAMPS.items():
    for d in DIRS:
        im = Image.open(base/rot[d]).convert("RGBA")
        new, n = recolour(im, ramp)
        (out/name).mkdir(exist_ok=True); new.save(out/name/f"{d}.png")
        print(name, d, n)
