# Raven Fantasy Icons, free set (Clockwork Raven Studios)

Source: the "Free - Raven Fantasy Icons" pack by Caio, Clockwork Raven Studios (itch.io), as
supplied by the user on 2026-09-08. `raven_16.png` is the pack's 16 px full sheet: 16 columns,
137 rows of 16 px cells. The pack also ships 32 and 64 px sheets and every icon as a separate file;
only the 16 px sheet is checked in.

The zip carries no license file. Terms are those on the pack's store page (the user is to confirm
them for CREDITS.md). Do not redistribute the sheet as an asset pack.

Cells are addressed by (row, col) in `tools/gen_icons.py`, which writes `data/icons.json`; the game
looks icons up by name through `IconAtlas`. `tools/icon_sheet.gd` renders the chosen cells to
`reports/icons.png` for a check by eye.
