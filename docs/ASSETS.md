# Assets that are not in the repository

Some packs the game uses allow shipping their files inside a game but forbid reposting them, so
they are in the release builds and not in the public repo (`.gitignore` keeps them out; `CREDITS.md`
has every license). A fresh clone runs without them: icons from a missing sheet draw as a framed
placeholder square (`ICON_MISSING` on the console), missing sounds play as silence (`AUDIO_MISSING`),
and `tools/check_boot.sh` counts both. Two tests need the files and fail without them by design:
`test_every_listed_sound_file_exists` and `test_icon_rect_is_sized_for_a_container` in
`tests/test_assets.gd`.

To get the full game from source, download the packs from their pages (free) and place the files:

| Files | Pack | Where to get it | How they were made |
|---|---|---|---|
| `assets/raven_icons/raven_16.png` | Raven Fantasy Icons, free set (Clockwork Raven Studios) | https://clockworkraven.itch.io/raven-fantasy-icons | The pack's 16 px full sheet, 16 columns by 137 rows, unchanged. `tools/gen_icons.py` addresses its cells. |
| `assets/guns/pistols_10x.png`, `pistols.png`, `handgun.png` | Pixel Art Pistol Gun Pack (Hatitler) | https://muhammet-hamza-okumus.itch.io/pistol | `pistols_10x.png` is the pack's 800 x 640 sheet; `tools/gen_guns.gd` writes the other two from it. |
| `assets/sfx/player_hurt.wav`, `player_die.wav`, `door_open.wav`, `door_seal.wav`, `assets/music/music_run.ogg`, `music_boss.ogg` | Minifantasy Dungeon SFX and Music (Leohpaz) | https://leohpaz.itch.io/minifantasy-dungeon-sfx-pack | One variant per name, `afconvert` to 16-bit 44.1 kHz mono with the silent tail trimmed; the loops `oggenc -q 6` from the pack's WAVs. |
| `assets/sfx/die_imp.wav`, `die_shaman.wav`, `boss_spawn.wav`, `boss_phase.wav`, `boss_die.wav` | Classic Monster Sounds (Coucassi) | itch.io | Same conversion as the effects above. |

The volumes, pitch jitter, and gaps for each name are in `data/audio.json`. The original picks came
from the project owner's copies; a clone that picks a different variant plays a different sound
under the same name.

For the project owner: these files live only in your working copy and inside the release builds, so
back them up somewhere private (a private repo or a zip) along with the original packs.
