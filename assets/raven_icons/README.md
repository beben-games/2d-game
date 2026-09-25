# Raven Fantasy Icons, free set (Clockwork Raven Studios)

Source: the "Free - Raven Fantasy Icons" pack by Caio, Clockwork Raven Studios (itch.io), as
supplied by the user on 2026-09-08. `raven_16.png` is the pack's 16 px full sheet: 16 columns,
137 rows of 16 px cells. The pack also ships 32 and 64 px sheets and every icon as a separate file;
only the 16 px sheet is used, and it is not in the public repo (its terms forbid reposting; see
`docs/ASSETS.md`).

The zip carries no license file. The store page's terms for the free version: personal use only
(projects released for free with no microtransactions or paid ads); no redistribution as a separate
product; attribution welcome, not required. A commercial release needs the paid pack. See CREDITS.md.

Cells are addressed by (row, col) in `tools/gen_icons.py`, which writes `data/icons.json`; the game
looks icons up by name through `IconAtlas`. `tools/icon_sheet.gd` renders the chosen cells to
`reports/icons.png` for a check by eye.
