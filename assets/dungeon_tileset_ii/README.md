# 0x72 Dungeon Tileset II (CC0)

Source: https://0x72.itch.io/dungeontileset-ii by 0x72. Public domain (CC0).

- `atlas.png`: the full sprite sheet.
- `tile_list.txt`: the sheet's own index, one line per sprite: `name x y w h`.
  Animation frames are separate lines named `<anim>_f0`, `<anim>_f1`, ... laid out side by side,
  each `w` pixels apart. `tools/gen_atlas.py` folds them into one entry per animation.
- `data/atlas.json` is generated from `tile_list.txt` by `tools/gen_atlas.py`. Regenerate it
  after updating the tileset; never edit it by hand.
- Not every 16x16 sprite sits on the 16 px grid (upstream lists `wall_edge_top_left` at x=31, probably
  a typo for 32; `wall_outer_*`, `goblin_*`, `skelet_*`, ... are offset too). `gen_atlas.py` warns about
  them; draw those with `SpriteAtlas.texture()`, not `tile_coords()`.

Sprites the game uses (looked up by name through `SpriteAtlas`):

| Purpose | Name(s) |
|---|---|
| Floor variants | `floor_1` .. `floor_8` |
| Wall | `wall_mid` |
| Player | `knight_m_idle_anim`, `knight_m_run_anim` |
| Chaser | `imp_idle_anim`, `imp_run_anim` |
