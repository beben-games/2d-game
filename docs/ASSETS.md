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
| `assets/sfx/player_hurt.wav`, `player_die.wav`, `door_open.wav`, `door_seal.wav`, `assets/music/music_run.ogg`, `music_boss.ogg` | Minifantasy Dungeon SFX and Music (Leohpaz) | https://leohpaz.itch.io/minifantasy-dungeon-sfx-pack | One variant per name, `afconvert` to 16-bit 44.1 kHz mono with the silent tail trimmed; the loops `oggenc -q 6` from the pack's WAVs. `door_seal.wav` has had no row in `data/audio.json` since M5 Task 1 (the doors went); `door_open.wav` had none either but stood in as `lift_open` from M7 Task 11 until 2026-10-10, when the Pixel Combat file took the row. |
| `assets/sfx/die_imp.wav`, `die_shaman.wav`, `boss_spawn.wav`, `boss_phase.wav`, `boss_die.wav`; since 2026-10-10 `beast_roar.wav` (`Dragon_Attack`), `handler_call.wav` (`Ghost_Attack`), `charge_windup.wav` (`Orc_Attack`), `die_beast.wav` (`Dragon_Death`), `die_handler.wav` (`Ghost_Death`), `die_charger.wav` (`Bat_Death`) | Classic Monster Sounds (Coucassi) | itch.io | Same conversion as the effects above (the 2026-10-10 six with `ffmpeg`, the silence trimmed at both ends). The first five's source files were not written down when they were made (by their lengths, `die_shaman` is probably `Orc_Death` and `boss_die` `Behemoth_Death`); the sound banks section below is kept so that never happens again. |
| `assets/music/music_run.ogg`, `music_boss.ogg`, `music_grounds.ogg` (since 2026-09-25) | Land of the Ancients (Andrew LiVecchi) | itch.io | "War - Legions", "War - Sons of Mars", "Ambient - Agricola": the whole track with its last 3 to 4 s cross-faded into its first, `loudnorm` to -29, -26, and -31 LUFS, `oggenc -q 6`. |
| `assets/sfx/crowd_boo.wav`, `crowd_quiet.wav`, `crowd_roar.wav`, `crowd_hush.wav`, `verdict_up.wav`, `verdict_down.wav`, `verdict_roll.wav`, `gate.wav`, `assets/music/crowd_ambience.ogg`, `crowd_angry.ogg` | Pixabay files by Dragon Studio, Universfield, vishiv, benkirb, floraphonic, freesound_community (see `CREDITS.md`) | https://pixabay.com | Silence trimmed, mono 44.1 kHz 16-bit, peak at -3 dBFS. `crowd_roar` is the stadium file's loudest 4 s; `gate` is the wooden gate under the chains; `verdict_down` the drum hit under the mega horn; the two loops cross-faded over 2 s. |
| `assets/sfx/coin_get.wav`, `coin_toss.wav`, `buy.wav` | CHAWPNEM Dice, Coin and Mechanical Tabletop Mini SFX | itch.io | The coin bounce, scatter, and jingle files, converted as above. |
| `assets/sfx/coin_pickup.wav` | Coins sounds [OGG] | user-supplied, source to be recorded | `2_Coins.ogg`, converted as above. |
| `assets/sfx/charge.wav`, `charge_skid.wav`, `banner.wav`, `lift_open.wav` (since 2026-10-10) | Pixel Combat (Helton Yan), the same pack as the 27 effects already in the repo | https://heltonyan.itch.io/pixelcombat | `WHSH_MOVEMENT-Windy Passby`, `WHSH_MOVEMENT-Sand Swipe`, `DSGNSynth_BUFF-Invigoration`, `DSGNMisc_USABLE-Mecha Weapon Equip`, variant 001 of each, `ffmpeg` to 16-bit 44.1 kHz mono with the silence trimmed at both ends. |
| `assets/sfx/crowd_cheer.wav`, `buy_denied.wav` | moneywithjj free samplers | https://moneywithjjcom.itch.io | `crowd-cheer.wav`, `purchase-denied.wav`, converted as above. |

The volumes, pitch jitter, and gaps for each name are in `data/audio.json`. The original picks came
from the project owner's copies; a clone that picks a different variant plays a different sound
under the same name.

For the project owner: these files live only in your working copy and inside the release builds, so
back them up somewhere private (a private repo or a zip) along with the original packs.

## Sound banks on hand

Before a new sound is wanted, or a stand-in chosen, look here: the user holds these packs as zips (their Downloads folder; ask them for a pack by name), and each has more in it than the game has used. A new pick goes in the table above with its source file's name, so the mapping is never lost again.

| Pack | What is in it | Licence, in the repo | Used so far |
|---|---|---|---|
| Classic Monster Sounds (Coucassi) | Creature voices: eight monsters (Bat, Behemoth, Dragon, Ghost, Hornet, Orc, Slime, Spider), each with Attack, Damage, Death, Emerge, and Step (0.2 to 4 s), plus two bonus attacks (a bat's sonic, a spider's net); WAV and OGG. The only pack with voices: roars, growls, wails, grunts. | Free for commercial use, edits allowed, no reposting the sounds: builds only (`.gitignore`) | `die_imp`, `die_shaman`, `boss_spawn`, `boss_phase`, `boss_die` (M3 and M4), the beast's roar and death, the handler's call and death, the charger's wind-up and death (M7) |
| Pixel Combat (Helton Yan) | About 370 synth and retro families of six variants each (2101 files): explosions, hits, melee, movement whooshes and swishes, steps, projectiles, spell casts, buffs, skills, usable items, UI clicks, glitches, interface tones. No voices. | CC BY 4.0: in the repo | 27 effects since M4 (the shots, the hits, the statuses, the UI, the room and wave sounds), plus the charge, the skid, the banner, and the lift's rise (M7) |
| Minifantasy Dungeon SFX and Music (Leohpaz) | A small dungeon set: the player's hurt and death, doors, and two music loops (kept in `assets/reserve/minifantasy_loops`). | Free with credit, no redistribution: builds only | `player_hurt`, `player_die`, `door_open`, `door_seal` |
| CHAWPNEM Dice, Coin and Mechanical Tabletop Mini SFX | Coins (bounce, scatter, jingle), dice, small mechanisms. | Free to use in the game, not to repost: builds only | `coin_get`, `coin_toss`, `buy` |
| Coins sounds [OGG] | A handful of coin pickups. | User-supplied, source to be recorded: builds only | `coin_pickup` |
| moneywithjj free samplers | Crowd cheers and UI denials, among others. | Free to use in the game, not to repost: builds only | `crowd_cheer`, `buy_denied` |
| Pixabay files (Dragon Studio, Universfield, vishiv, benkirb, floraphonic, freesound_community) | Single downloads: a stadium crowd, boos, a hush, a drum roll and hits, a mega horn, a wooden gate, an angry crowd loop. | Pixabay's licence, not to repost as files: builds only | the crowd's and the verdict's sounds, the two crowd loops |
| Land of the Ancients (Andrew LiVecchi) | Orchestral tracks: war, ambient, and more than the three in use. | Free to use in the game, not to repost: builds only | `music_run`, `music_boss`, `music_grounds` |
