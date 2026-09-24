# 0x72 Dungeon UI v1

`dungeonui.png` (506 x 396) is 0x72's dungeon UI sheet as supplied by the user on 2026-09-08. It
has frames, bars, panels, hearts, buttons, 1-bit icons, and a proportional pixel font drawn in
white (invisible on a white background). No index ships with it; regions used by the game were
measured by a component scan and live in `scripts/ui/ui_theme.gd`:

| Part | Region (x, y, w, h) | Nine-patch margin |
|---|---|---|
| Frame with corner nubs | 16, 40, 40, 24 | 7 |
| Plain frame | 64, 41, 40, 22 | 6 |
| Small square frame | 24, 72, 24, 24 | 7 |
| Beige panel | 80, 104, 24, 24 | 4 |
| Small beige panel | 61, 109, 14, 14 | 4 |
| Hearts full / half / empty | 20, 135, 13, 12 / 36, 135 / 52, 135 | |
| Buttons red / green / blue / orange | 16, 160, 32, 22 and every 40 px | 6 |
| Font rows | digits y 302, lowercase baseline 328, uppercase baseline 352 | |

The sheet supplies the game's frame, panel, and red button (`UiTheme.nine_patch` regions above).
Its font rows are not used: the fonts live in `assets/fonts` (TrueType pixel fonts, since playtest 1,
note 7, 2026-09-14); the BMFont generator that once read the rows and its outputs were deleted in
Milestone 4.

License: CC0, as stated on https://0x72.itch.io/dungeonui.
