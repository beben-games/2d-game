# Milestone 4 feel checklist

Play a full run (win or die; seven rooms of waves, a card after each, the boss in room 8), then
rate each line good / meh / bad with a note. The milestone closes when the slice is one you would
hand a friend. Tab or Esc opens the pause screen (volumes, restart, quit to title); R restarts;
the seed is on the summary and in the `RUN_OVER`/`RUN_WON` line; `-- --seed=N` replays it. The
sound files are yours: a missing one is silent and named in `AUDIO_MISSING` lines at boot.

- The title: does it read as a front door? Is the seed field discoverable? (`scripts/ui/title.gd`, `GAME_NAME` is the placeholder)
- R mid-run restarts without the title; Quit to title shows it; the Play button takes a mouse click (the GUI click cannot be driven headless).
- Sound: which effects land, which are too loud, too soft, too frequent? Does the hit sound read under a volley? Do the UI sounds help or nag? (`data/audio.json`: `volume_db`, `pitch_jitter`, `min_gap` per name; `scripts/autoload/audio.gd` maps signals to names)
- Music: title, run, boss: do the loops fit, and is the crossfade (`Audio.MUSIC_FADE`) too slow or too fast? Levels against the effects? (`Settings` defaults in `scripts/settings.gd`)
- The pause screen: are the options findable, do the sliders feel right, is the build still readable at three quarters of the panel, and do the options need keyboard focus (they are mouse-only)? (`scripts/ui/build_screen.gd`)
- The boss: does the telegraph read for each pattern? Is the ring dodgeable, the volley fair, the charge scary? Does stage two read (the tint, the roar, the summons)? How long did the fight take, and did you win? (`data/enemies/boss.tres`: hp, timings, counts; `scripts/boss.gd` feel consts; `scripts/boss_brain.gd` cycle) The ring's upward bolts spawn on the wall line and die at once (the seat is 24 px below the edge, `BOLT_MUZZLE` 24): is the ring too thin at the top?
- The boss bar: readable, in the way of anything? (`scripts/ui/hud.gd`, `BOSS_BAR_*`) The bar vanishes on the killing blow instead of draining; should it hide after the corpse hold? A summon can spawn on top of the player or a live summon at a midpoint (a few ticks of depenetration, no damage).
- Particles: the coloured deaths and puffs, the vignette on a hit, the dash ghosts, the wall sparks, the status embers/sparks/frost, the door dust, the boss's trail and flash: which read, which are noise? (`scripts/fx.gd`, `scripts/status_effects.gd`, `scripts/ui/hud.gd` `VIGNETTE_*`)
- The right card: when hurt, is the heal card always on the right, and does the eye find it there? Is the first one (a heart container) the right welcome, and does a later Heal (half your hearts) ever beat a container? Does a replay with a different hurt state keep the other two cards? (`UpgradeCatalog.offers`, `RunState.heal_slot_uses`, `HeartRules.heal_amount`)
- Rooms 4 to 7: does difficulty climb into the boss now that the waves are bigger? Where did you take damage, and did a wave ever feel like a wall? (`data/waves/room_4..7.tres`)
- Shooter pairs: do they still fire in lockstep? (`Enemy.RECOVER_JITTER`)
- The Piercing bullets icon: does it read as a bullet passing through, apart from the crossbow cards? (`tools/gen_icons.py`, `pierce`)
- A full run: how long, did it end the way you expected, would you hand this to a friend?

## Balance pass

One commit per item; before and after as built. Items 1 to 3 and 5 to 8 come from the user's
playtest notes of 2026-09-21 (in the Task 9 text of `2026-09-15-milestone-4.md`), which reshaped
the plan's original rows: Heal on a fixed slot instead of a seeded one, the first heal a container,
later heals half the max, and waves from room 4 on grown past the plan's numbers.

| # | Concern | Before | After | Commit |
|---|---|---|---|---|
| 1 | Heal crowds the draw and changes the other two cards | Heal joins the pool; a 3-card draw from the whole pool, so hurt or not changes all three | Draw from the Heal-free pool; when hurt, the heal card takes the last slot (the right card), so a seed replays the other two regardless of hurt state | 9c44490 |
| 2 | The first heal is "heal or grow" | The right slot is always Heal | The first time the right slot fills in a run it offers Heart container (while a rank is left), every later time Heal (`RunState.heal_slot_uses`, reset by `start_run`) | a72a3c5 |
| 3 | Heal never competes with a container | Heal restores one heart (2 hp) | Heal restores half the max, rounded up to whole hearts (max 6 hp: 2 hearts; 8: 2; 10: 3; 12: 3) | e393447 |
| 4 | Room 4's finale is where the run should start to bite | finale 8 chasers + 2 shooters (10) | finale 9 + 3 (12) |c409172 |
| 5 | Room 5 reads as a step back after room 4 | 5+2 / 5+2 / 6+2 (7, 7, 8) | 8+3 / 9+3 / 11+4 (11, 12, 15) |c409172 |
| 6 | Room 6 opens with a single shooter | 6+1 / 5+2 / 8+2 (7, 7, 10) | 10+3 / 11+4 / 13+4 (13, 15, 17) |c409172 |
| 7 | Room 7 must carry the climb, since room 8 is the boss | 6+2 / 6+2 / 8+2 (8, 8, 10) | 12+4 / 13+4 / 15+5 (16, 17, 20) |c409172 |
| 8 | Two shooters fire in lockstep | recover 0.6 s fixed | recover 0.6 s plus up to 0.15 s per cycle (`Enemy.RECOVER_JITTER`, from the gameplay RNG) | 3851463 |
| 9 | The Piercing bullets icon reads as a bow's arrow next to the crossbow cards | Raven cell (134, 9), a blue arrow | Raven cell (62, 9), an orange bullet in flight with a trail: no head or fletching, and the same shot family as multishot's orange shots (the sheet has no bullet drawn through a target) | 1a331b8 |
| 10 | Boss numbers | HP 60, ring 12/16, volley 5, charge 320 px/s for 0.5 s | tuned on the playtest | |

## Verdict, playtest 1

(recorded after the user's run)
