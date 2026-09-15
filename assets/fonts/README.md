# UI fonts

TrueType pixel fonts supplied by the user on 2026-09-14 for playtest 1 notes 7 and 8 (the 0x72
sheet's bitmap font in `assets/dungeon_ui` is no longer used by the UI). Each is drawn on a 16 px
grid, so `UiTheme` uses sizes that are multiples of 16 (32, 48, 64) and the `.import` files turn
off antialiasing, hinting, and subpixel positioning so the glyphs land on whole pixels.

| File | Font | Author | Source | Licence | Role |
|---|---|---|---|---|---|
| `PixelOperator.ttf` | Pixel Operator | Jayvee Enaguas (HarvettFox96) | https://notabug.org/HarvettFox96/ttf-pixeloperator (also https://www.dafont.com/pixel-operator.font) | CC0 1.0 (`pixel_operator_LICENSE.txt`) | Body font: `UiTheme.FONT`, card descriptions, rank lines, build screen rows |
| `PixelOperator-Bold.ttf` | Pixel Operator Bold | Jayvee Enaguas (HarvettFox96) | same | CC0 1.0 | Kept for later; not used yet |
| `alagard.ttf` | Alagard | Pix3M (Hewett Tsoi) | https://www.dafont.com/alagard.font | Free for commercial use, credit the author | Title font: `UiTheme.TITLE_FONT`, card names and the build screen's weapon row |
| `m5x7.ttf` | m5x7 | Daniel Linssen | https://managore.itch.io/m5x7 | CC0 | Alternative body font, kept for later; not used yet |
