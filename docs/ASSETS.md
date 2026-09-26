# Assets that are not in the repository

Some packs the game uses allow shipping their files inside a game but forbid reposting them, so
they are in the release builds and not in the public repo (`.gitignore` keeps them out; `CREDITS.md`
has every license). A fresh clone runs without them: icons from a missing sheet draw as a framed
placeholder square (`ICON_MISSING` on the console), missing sounds play as silence (`AUDIO_MISSING`),
and `tools/check_boot.sh` counts both. The tests pass either way:
`test_every_listed_sound_file_exists` accepts the restricted sounds all present or all missing, so
a partial set, or a new sound name without a file, still fails.

To get the full game from source, download the packs from their pages (free) and place the files:

| Files | Pack | Where to get it | How they were made |
|---|---|---|---|
| `assets/raven_icons/raven_16.png` | Raven Fantasy Icons, free set (Clockwork Raven Studios) | https://clockworkraven.itch.io/raven-fantasy-icons | The pack's 16 px full sheet, 16 columns by 137 rows, unchanged. `tools/gen_icons.py` addresses its cells. |
| `assets/guns/pistols_10x.png`, `pistols.png`, `handgun.png` | Pixel Art Pistol Gun Pack (Hatitler) | https://muhammet-hamza-okumus.itch.io/pistol | `pistols_10x.png` is the pack's 800 x 640 sheet; `tools/gen_guns.gd` writes the other two from it. |
| `assets/sfx/player_hurt.wav`, `player_die.wav`, `door_open.wav`, `door_seal.wav`, `assets/music/music_run.ogg`, `music_boss.ogg` | Minifantasy Dungeon SFX and Music (Leohpaz) | https://leohpaz.itch.io/minifantasy-dungeon-sfx-pack | One variant per name, `afconvert` to 16-bit 44.1 kHz mono with the silent tail trimmed; the loops `oggenc -q 6` from the pack's WAVs. `door_open.wav` and `door_seal.wav` have had no row in `data/audio.json` since M5 Task 1 (the doors went); kept for the grounds' gate or later. |
| `assets/sfx/die_imp.wav`, `die_shaman.wav`, `boss_spawn.wav`, `boss_phase.wav`, `boss_die.wav` | Classic Monster Sounds (Coucassi) | itch.io | Same conversion as the effects above. |
| `assets/music/music_run.ogg`, `music_boss.ogg`, `music_grounds.ogg` (since 2026-09-25) | Land of the Ancients (Andrew LiVecchi) | itch.io | "War - Legions", "War - Sons of Mars", "Ambient - Agricola": the whole track with its last 3 to 4 s cross-faded into its first, `loudnorm` to -29, -26, and -31 LUFS, `oggenc -q 6`. |
| `assets/sfx/crowd_boo.wav`, `crowd_quiet.wav`, `crowd_roar.wav`, `crowd_hush.wav`, `verdict_up.wav`, `verdict_down.wav`, `verdict_roll.wav`, `gate.wav`, `assets/music/crowd_ambience.ogg`, `crowd_angry.ogg` | Pixabay files by Dragon Studio, Universfield, vishiv, benkirb, floraphonic, freesound_community (see `CREDITS.md`) | https://pixabay.com | Silence trimmed, mono 44.1 kHz 16-bit, peak at -3 dBFS. `crowd_roar` is the stadium file's loudest 4 s; `gate` is the wooden gate under the chains; `verdict_down` the drum hit under the mega horn; the two loops cross-faded over 2 s. |
| `assets/sfx/coin_get.wav`, `coin_toss.wav`, `buy.wav` | CHAWPNEM Dice, Coin and Mechanical Tabletop Mini SFX | itch.io | The coin bounce, scatter, and jingle files, converted as above. |
| `assets/sfx/coin_pickup.wav` | Coins sounds [OGG] | user-supplied, source to be recorded | `2_Coins.ogg`, converted as above. |
| `assets/sfx/crowd_cheer.wav`, `buy_denied.wav` | moneywithjj free samplers | https://moneywithjjcom.itch.io | `crowd-cheer.wav`, `purchase-denied.wav`, converted as above. |

The volumes, pitch jitter, and gaps for each name are in `data/audio.json`. The original picks came
from the project owner's copies; a clone that picks a different variant plays a different sound
under the same name.

For the project owner: these files live only in your working copy and inside the release builds, so
back them up somewhere private (a private repo or a zip) along with the original packs.
