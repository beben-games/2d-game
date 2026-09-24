# Milestone 4 design: the slice

Approved 2026-09-15 in the brainstorm session that closed Milestone 3 (tag `m3`). Expands the
Milestone 4 line of the design table in `docs/plans/2026-09-02-action-roguelike-design.md`
("Sound, particles, balance pass. Done when: a vertical slice worth showing a friend") with a
front door and one new mechanic, both chosen in the brainstorm.
`docs/plans/2026-09-15-m4-prework-notes.md` holds the code hooks this design builds on.

## Goal

A build a friend can launch cold: a title screen, sound and music, a pause screen with volume,
eight rooms that rise in difficulty, and a boss at the end to talk about. Sound is the top of the
game-feel thesis and the piece the game still lacks entirely; the boss gives the run a climax; the
balance pass acts on the inputs the Milestone 3 review and playtest recorded. The milestone closes
on the user's playtest against `docs/plans/<date>-m4-feel-checklist.md` and a tester build
(`0.4.0-rc1`).

## Decisions taken in the brainstorm

- Scope: the three pillars of the brief (sound, particles polish, balance) plus a front door
  (title screen, pause) and one mechanic: a boss at room 8.
- Sound and music files come from the user, sourced from the list in this document; the build
  wires them and is silent (never broken) while any file is missing.
- The boss is a separate scene and script with its own pure brain, reusing `Health`,
  `StatusEffects`, the flash shader, and the enemy bolt; `Enemy`, the chaser, and the shooter are
  untouched. Its body is the tileset's `big_demon` at 2x, because the chasers are imps.
- Audio is an autoload listening to the bus like `Fx`, not players in gameplay scenes.
- The title is a CanvasLayer inside Main, not a second main scene, so every test and tool keeps
  building `main.tscn`.
- The pause screen is the existing build screen: Tab or Esc opens the same screen, with the
  options in a left column of 30 percent and the build in the remaining 70 percent (the user's
  direction).
- The title's name is a placeholder, "Arena", until the user chooses one.
- Early rooms are not tuned (the user's standing direction: difficulty comes from later rooms
  and mechanics). The `DashCharges` tidy-up is left out; the two tidy-ups the work touches
  anyway (a `UiTheme` panel helper, the HUD rank digit's font) come in, and the unused
  `tools/gen_ui_font.gd` and `assets/dungeon_ui/ui_font.*` are deleted.

## The boss (room 8)

### Files

- `scripts/defs/boss_def.gd` (`BossDef`, a Resource) and `data/enemies/boss.tres`.
- `scripts/boss_brain.gd` (`BossBrain`, a RefCounted, pure: ticks with delta, distance, and the
  def, returns what to do; testable without a scene).
- `scripts/boss.gd` (`Boss`, a CharacterBody2D) and `scenes/enemies/boss.tscn`.
- `data/waves/room_8.tres` becomes one wave with one group: `boss.tscn`, count 1. Room 8's old
  finale numbers move to room 7's last wave (see the balance pass).
- The HUD gains a boss bar; `Events` gains `boss_spawned(boss)` and `boss_phase_changed(phase)`.

### Body

Layer 2 (enemies), mask 19 (walls, enemies, player), in the `enemies` group so homing finds it,
with `Health`, `StatusEffects`, a hurtbox that damages the player on contact like `Enemy`'s, and
the flash shader (`Juice.flash` on every hit, the shooter's pulse on a telegraph). Sprite:
`big_demon_idle_anim` and `big_demon_run_anim` from `SpriteAtlas` at scale 2 (64 by 72 px),
flipped toward the player, collision circle radius 20, `sprite_offset` to seat the feet on the
circle. It emits `enemy_hit` and `enemy_died` like any enemy, so kills, score, `Fx`, and the
wave runner keep working; `RunState` counts it as a kill. A spawn fade-in of 1.2 s at the top
center of the floor (`ArenaGrid.bounds` centre x, one tile below the top wall), with a roar and
0.4 trauma; `boss_spawned(self)` is emitted when it becomes active.

`BossDef` (all numbers tunable, defaults in brackets): `max_hp` [60], `speed` [50],
`contact_damage` [1], `score` [200], `spawn_delay` [1.2], `approach_time` [1.0],
`telegraph_time` [0.6], `recover_time` [0.8], `ring_count` [12], `volley_count` [5],
`volley_spread_degrees` [40], `charge_speed` [320], `charge_time` [0.5], `bolt` (the shaman
bolt `WeaponDef`), `phase2_fraction` [0.5], `phase2_telegraph_time` [0.45],
`phase2_recover_time` [0.5], `phase2_ring_count` [16], `summon_count` [2],
`summon_scene` (chaser.tscn), `status_scale` [0.5], `idle_anim`, `run_anim`, `sprite_offset`.
`validate()` like the other defs; `Boss._ready` asserts it.

### The brain

Phases: SPAWNING, APPROACH, TELEGRAPH, ATTACK, RECOVER, DEAD. The cycle is APPROACH (walk
toward the player at `speed` for `approach_time`), TELEGRAPH (`telegraph_time`, stand still),
ATTACK (pattern-specific), RECOVER (`recover_time`, stand still), then the next pattern.
Patterns in phase 1, in fixed order, repeating: RING, VOLLEY, CHARGE. In phase 2: RING,
VOLLEY, CHARGE, SUMMON. The brain returns an action at the phase edges (`fire_ring`,
`fire_volley`, `start_charge`, `summon`) and a wish direction for movement; `Boss` performs them:

- RING: `ring_count` shaman bolts evenly around the boss, from the bolt scene into the room's
  projectile container. ATTACK lasts one tick.
- VOLLEY: `volley_count` bolts across `volley_spread_degrees` centred on the player. One tick.
- CHARGE: the direction is locked at the end of the telegraph; the body moves at `charge_speed`
  for `charge_time` (ATTACK lasts that long) with contact damage live; `move_and_slide` stops it
  at a wall, and a wall collision during the charge ends it early with 0.3 trauma and a dust
  burst. The player's dash passes through it (layer 7 is not in the mask; the same rule as every
  enemy).
- SUMMON (phase 2 only): `summon_count` chasers placed at the left and right wall midpoints
  through the room's `Spawner.spawn(scene, at)`; they are added to the `summoned` group.

Phase 2 begins the first time HP falls to `phase2_fraction` of max, at the next phase edge (a
charge is never cut): `boss_phase_changed(2)`, a brighter tint (`modulate` toward
`Color(1.3, 0.9, 0.9)`), a roar, 0.5 trauma, and the phase-2 timings and ring count from then
on. The brain exposes `phase`, `pattern`, and `phase_time` so tests read them.

Status: burn in full; `StatusEffects.apply_stun` and `apply_chill` take a duration scale from
the owner (`status_scale`, 1.0 for `Enemy`), so the boss's stun and chill last half as long; a
stun during CHARGE is ignored (a charge cannot be stunned), and a stun during TELEGRAPH
interrupts it like the shooter's. Chill halves `speed` and `charge_speed` alike.

Death: `DEATH_HITSTOP` 0.12, trauma 0.8, `Fx` plays a staged burst (three bursts over 0.6 s and
a white flash), the corpse stays with `modulate` dimmed, every node in the `summoned` group
dies at once (through their `Health`, so they burst and count as kills), then the existing clear
flow runs: the runner counts the boss's death as the wave's only death, `room_cleared` fires,
`Main` clears the projectiles and, since room 8 is the last, the win summary follows after
`WIN_SUMMARY_DELAY`. `WaveRunner._on_enemy_died` ignores enemies in the `summoned` group, so
summons never advance the wave; `WaveProgress` is untouched.

### HUD

A boss bar at the top centre: a `UiTheme` panel (paper and frame) 480 by 40 px in the HUD's
1280-wide layout with the name "Imp Lord" in Alagard `FONT_SMALL` and a red fill that tracks
`Health.hp / max_hp` (tweened over 0.15 s). Shown on `boss_spawned`, hidden on the boss's
`enemy_died`, and reset by `Main.restart()`. While the HUD gains the bar, its rank digit
(`RANK_FONT_SIZE`) moves to Pixel Operator at 16 px.

## Audio

### Structure

`scripts/autoload/audio.gd` (`Audio`, an autoload after `Juice`) mirrors `Fx`: `_ready`
connects one handler per bus signal, `_exit_tree` disconnects them. `default_bus_layout.tres`
defines Master, Sfx, and Music buses. Players:

- A game pool of eight `AudioStreamPlayer`s on Sfx, `process_mode` PAUSABLE so the picker and
  the pause screen silence them; round robin, the oldest is stolen.
- A UI pool of four `AudioStreamPlayer`s on Sfx, `process_mode` ALWAYS, for menu sounds under a
  paused tree.
- Two music players on Music, ALWAYS, crossfading over 0.8 s (`MUSIC_FADE`).

Non-positional throughout: a room is one screen. Each sound has a minimum gap (`min_gap`, 0.03 s
default) so a multishot volley or a ring of bolts plays once, and a pitch jitter drawn from the
global RNG (cosmetic). Under hitstop, `Engine.time_scale` drops to 0.05; whether that pitches
playback in 4.7.2 is probed in the plan with a throwaway `-s` script, and only if it does are
the players compensated by `pitch_scale` (or `AudioServer.playback_speed_scale` pinned to 1).

`data/audio.json` maps a sound name to `{"file": "sfx/<name>.wav" | "music/<name>.ogg",
"volume_db": -6, "pitch_jitter": 0.08, "min_gap": 0.03}`; music entries carry only the file.
`Audio.load_table()` reads it at `_ready`; a listed file that is missing yields silence for that
name and one `AUDIO_MISSING <name>` line at boot (a `print`, not a `push_warning`, so
`tools/check_boot.sh` stays green; `check_boot.sh` reports the count of such lines without
failing). A name that is not in the table at all is a `push_error` (a typo in code). `Audio.play(name)`
and `Audio.play_ui(name)` are the two entry points; `Audio.music(name)` switches the loop
(`""` stops it); `Audio.plays` counts plays for tests and the smoke tool (`SMOKE_AUDIO n`).

Volumes: `scripts/settings.gd` (`Settings`, a RefCounted with static `load(path)` and
`save(path)`, default path `user://settings.cfg`, keys `master`, `sfx`, `music` in 0..1,
defaults 0.8, 1.0, 0.7). `Audio.apply(settings)` sets the three bus volumes with
`linear_to_db` (0 is mute, `-80 dB`). The pause screen's sliders call it live and save on close.

### Signals added to the bus

`enemy_telegraphed(enemy)` (the shooter and the boss), `enemy_fired(enemy, position)` (a bolt
leaves), `shot_bounced(position)`, `shot_hit_wall(position)` (a player shot or a bolt ends on a
wall), `status_applied(enemy, kind)` (kind is `"burn"`, `"stun"`, or `"chill"`),
`boss_spawned(boss)`, `boss_phase_changed(phase)`, `menu_opened(name)` and `menu_closed(name)`
(`"upgrade"`, `"build"`, `"title"`, `"summary"`), `card_hovered()`, `run_started()` (from
`RunState.start_run`). `shot_fired` gains a third argument, `weapon_id`, so the handgun and the
crossbow sound different; `Fx` ignores it. Every emit site is the node that already knows the
moment (the projectile for bounces and walls, `StatusEffects` for statuses, the menus for
open and close).

### Event to sound map

| Signal or moment | Sound |
|---|---|
| `shot_fired` by weapon | `shot_handgun`, `shot_crossbow` |
| `shot_bounced`, `shot_hit_wall` | `shot_bounce`, `shot_wall` |
| `enemy_hit` | `hit_enemy` (jittered) |
| `enemy_died` by enemy id | `die_imp`, `die_shaman`; `boss_die` for the boss |
| `status_applied` by kind | `status_burn`, `status_shock`, `status_chill` |
| `enemy_telegraphed`, `enemy_fired` | `telegraph`, `bolt_fire` (the boss's own: `boss_telegraph`, `boss_ring`, `boss_volley`, `boss_charge`, `boss_summon`) |
| `player_hit`, `player_healed`, `player_died`, `player_dashed` | `player_hurt`, `player_heal`, `player_die`, `dash` |
| `door_sealed`, exit opened (`Main._open_exit`), `room_entered`, `wave_started`, `room_cleared` | `door_seal`, `door_open`, `room_enter`, `wave_start`, `room_clear` |
| `menu_opened("upgrade")`, `menu_closed`, `card_hovered`, `upgrade_chosen`, Play pressed | `ui_open`, `ui_close`, `ui_hover`, `ui_pick`, `ui_play` |
| `boss_spawned`, `boss_phase_changed` | `boss_spawn`, `boss_phase` |
| `run_won`, `player_died` (with the summary) | `win`, `lose` |
| Music: title shown, `run_started`, `boss_spawned`, the summary, Quit to title | `music_title`, `music_run`, `music_boss`, stop (the sting plays), `music_title` |

### The list for the user to source

Files go in `assets/sfx/<name>.wav` (or `.ogg`) and `assets/music/<name>.ogg`; mono is fine
for effects; loops should be seamless. 33 effects and 3 loops (built as 36 effects and 2 loops: the user chose one regular track, shared by the title and the run, and one boss track; see the build deviations):

| Name | Character | Length |
|---|---|---|
| shot_handgun | short dry crack | 0.1 to 0.2 s |
| shot_crossbow | heavier thunk with a string twang | 0.2 to 0.3 s |
| shot_bounce | metallic ricochet ping | 0.1 s |
| shot_wall | dull tap on stone | 0.1 s |
| hit_enemy | fleshy thud | 0.1 to 0.15 s |
| die_imp | small squeal | 0.3 s |
| die_shaman | a croak | 0.4 s |
| status_burn | ignite whoosh | 0.3 s |
| status_shock | electric crackle | 0.2 s |
| status_chill | icy shimmer | 0.3 s |
| telegraph | rising wind-up tone | 0.4 s |
| bolt_fire | a hiss | 0.15 s |
| player_hurt | a grunt | 0.2 s |
| player_heal | warm chime | 0.5 s |
| player_die | low fall | 0.8 s |
| dash | air whoosh | 0.2 s |
| door_seal | bricks slamming into place | 0.4 s |
| door_open | stone grinding | 0.6 s |
| room_enter | short stinger | 0.5 s |
| wave_start | a low drum | 0.4 s |
| room_clear | bright sting | 1.0 s |
| ui_open | paper unfolding | 0.2 s |
| ui_close | paper folding | 0.2 s |
| ui_hover | a tick | 0.05 s |
| ui_pick | a stamp | 0.2 s |
| ui_play | deep confirm | 0.5 s |
| boss_spawn | a roar | 1.0 s |
| boss_telegraph | deep wind-up | 0.5 s |
| boss_ring | wide burst | 0.4 s |
| boss_volley | triple hiss | 0.3 s |
| boss_charge | stomping rush | 0.5 s |
| boss_summon | dark chant | 0.6 s |
| boss_phase | roar with a crack | 1.0 s |
| boss_die | long collapse | 1.5 s |
| win | fanfare sting | 2 s |
| lose | sombre sting | 2 s |
| music_title | calm loop | 60 to 120 s |
| music_run | driving loop | 60 to 120 s |
| music_boss | heavier loop | 60 to 120 s |

The build is fully playable before any file arrives; each file starts playing the moment it is
dropped in with the listed name and `data/audio.json` is left as generated. `CREDITS.md` gains a
section for their sources when they land.

## The front door

### Title

`scenes/ui/title.tscn` and `scripts/ui/title.gd` (`Title`, a CanvasLayer at 15, `process_mode`
ALWAYS: over the HUD at 1 and the menus at 10, under the fade at 20 and the summary at 30). A
60 percent black dim over the first room, the name "Arena" in Alagard at 96 px, a Play button
(`UiTheme` red button; Enter or a click), a seed `LineEdit` (digits only, blank means random,
placeholder "seed"), the hint line "WASD move, mouse aim, click shoot, Space dash, Tab build,
Esc pause" in Pixel Operator `FONT_SMALL`, and the version from
`ProjectSettings.get_setting("application/config/version")` in the bottom-right corner.

Main's flow: `_ready` builds the first room as today but, when `start_at_title` is true (an
`@export`, default true), pauses the tree and shows the title instead of starting the run; the
wave runner stays idle under it. `Title.play_pressed(seed)` calls `Main.play(seed)`: hide the
title, `RunState.start_run(seed)` (a blank field is `-1`, random), unpause, enter room 0 the way
`restart()` does today. `quiet_main()` and `quiet_main_with_floor()` set `start_at_title` false
before adding Main, and `tools/smoke.gd` does the same, so the 41 suites, the boot gate, and
the seven smoke scenarios keep their flow; the new `title` smoke scenario leaves it true.
`--seed=N` fills the field and plays at once, so a replay is still one command. `Main.restart()`
(R) goes straight into a new run, as today; `Main.quit_to_title()` restarts and shows the title
again. The summary line gains "Esc: title" beside "R: restart"; Esc on the summary calls
`quit_to_title`.

### Pause and build merged

`BuildScreen` becomes the pause screen. A new `pause` action (Esc) joins `build_screen` (Tab);
either opens it, either closes it, and R inside still restarts. The tree pauses as today. The
panel (`PANEL_SIZE` 1000 by 560, grown to 1120 by 600 if the columns need it) holds an
`HBoxContainer`: a left `VBoxContainer` with `size_flags_stretch_ratio` 3 and a right one with 7.

- Left, "Options" in Alagard: Resume (closes), Restart (`restart_pressed`), three rows of a
  label, an `HSlider` (0 to 100, step 5), and the value ("Master 80"), and Quit to title
  (`quit_pressed`, which `Main` connects to `quit_to_title`). Sliders call
  `Audio.apply(settings)` on every change and `Settings.save()` on close. Buttons and sliders
  are `UiTheme`-styled and keyboard-reachable (focus neighbours set), since the screen runs
  under a paused tree in `process_mode` ALWAYS as it does now.
- Right, "Build" in Alagard over the rows the screen shows today, unchanged.

`UiTheme` gains `panel(size) -> Control` (paper plus frame, the block both menus build by hand
today) and `clear_children(node)`; `UpgradeMenu` and `BuildScreen` use them. The build
screen's weapon row keeps its current detection; the review's named-parameter tidy-up is out of
scope.

## Particles polish

Every recipe is a one-shot in `Fx` (or, for the persistent ones, in `StatusEffects`), on a bus
signal, using `_burst`, `fade_scale`, and `fade_ramp`:

1. Enemy death: the burst takes the enemy's colour (imp red, shaman green, boss dark red from a
   `death_color` on `EnemyDef` and `BossDef`) and adds a grey smoke puff that rises and fades
   over 0.5 s.
2. Player hit: a red vignette on the HUD (a full-screen `ColorRect` with a radial gradient at
   alpha 0.35 fading over 0.25 s) on `player_hit`, beside the existing burst.
3. Dash: three afterimages of the player sprite (a `Sprite2D` copy per 0.05 s, fading over
   0.2 s) on `player_dashed`, in the dash direction's wake.
4. Shot on a wall: four sparks on `shot_hit_wall` in the shot's colour; on `shot_bounced` the
   same sparks plus a brief flash.
5. Statuses: `StatusEffects` owns one `CPUParticles2D` per status, emitting while it is active:
   rising embers (burn), a spark flicker (stun), frost mist drifting down (chill), in the
   status tints.
6. Door: a fall of dust from the lintel on the exit opening (`Main._open_exit`), 0.4 s.
7. Boss: a dust trail during the charge (a burst per physics tick along the path), a ring
   flash on `boss_ring` (a white circle scaling out over 0.15 s), and the staged death (three
   bursts of growing size over 0.6 s and a white flash on the whole sprite).

## Balance pass

One commit each, with the before and after recorded in `docs/plans/<date>-m4-feel-checklist.md`
under "Balance pass". Early rooms are not touched.

1. The Heal slot: `UpgradeCatalog.draw` draws the three offers from the Heal-free pool; when the
   player is hurt, Heal replaces one slot chosen from `RunState.stream("upgrades:heal:room:round")`,
   so a seed replays the other two cards regardless of hurt state and only the Heal slot varies.
2. Room 5's finale: 6 chasers and 2 shooters (8) become 8 chasers and 3 shooters (11), above
   room 4's 10.
3. Room 6's first wave: a second shooter; the room's share moves from 5 of 24 to 6 of 25.
4. Room 7's finale absorbs room 8's old finale numbers (room 8 is the boss now), so the climb
   from room 5 to room 7 reads as one line.
5. Shooter lockstep: `recover_time` jittered by up to 0.15 s from `RunState.stream("shooters")`
   at each recover, so two shooters fall out of step within a few cycles; the shooter tests'
   pinned tick counts are checked against the jitter's ceiling.
6. Boss numbers: HP 60 against the handgun's base 6 shots per second of 1 damage reads as a
   10 s fight for a player who never misses and never dodges, 20 to 30 s in practice; tuned on
   the playtest with the per-phase timings.

## Assets

- Sound and music: from the user, per the list above; `CREDITS.md` records their sources.
- The boss uses the existing tileset (`big_demon_idle_anim`, `big_demon_run_anim` in
  `data/atlas.json`) and the shaman bolt; no new art.
- The title and the pause screen use `UiTheme`'s sheet, fonts, and button; the version string
  reads `config/version`.
- Deleted: `tools/gen_ui_font.gd`, `assets/dungeon_ui/ui_font.*` and their imports (unused
  since the TrueType fonts landed); `CREDITS.md` keeps the 0x72 UI sheet entry, since the
  frame and panel are still drawn from it.

## Tests

Pure suites: `BossBrain` (the pattern order in each phase, the phase edge timings, the charge
direction lock, phase 2 entering only at a phase edge and never during a charge, the summon
cadence), `Settings` (load with defaults on a missing file, round trip through a temp path,
clamping), the audio table (`data/audio.json` parses, every name the code plays is in the
table, every entry's file path is under `assets/sfx` or `assets/music`; the file-exists check
is a separate test that lands with the files), `UpgradeCatalog` (the Heal slot draw: same seed
and picks, hurt or not, gives the same two non-Heal cards; the Heal slot index is seeded),
`WaveRunner` ignoring a death in the `summoned` group.

Scene suites (all extend `SceneSuite`, physics-frame waits): the boss room clears into the win
summary when the boss dies; `fire_ring` places `ring_count` bolts in the room's projectile
container and `fire_volley` `volley_count`; a charge stops at the wall inside the floor bounds;
the HUD bar tracks the boss's HP and hides on death; summons die with the boss and never
advance the wave; stun during a charge is ignored and halved otherwise; the title shows on boot
with the tree paused, Play starts a run with the seed from the field, and `quiet_main()` skips
it; Esc opens the build screen with the options column and Tab still does; a slider moves its
bus volume through `Audio`; Quit to title shows the title with a fresh `RunState`; `Audio`
runs with no files present, plays every mapped event without a `push_error`, and counts them;
the pitch under hitstop (whichever way the probe decides); `shot_fired` carries the weapon id.

Smoke: `title` (boot with the title up, screenshot `smoke_title.png`, press Play, assert
`SMOKE_TITLE played`), `pause` (open the screen on Esc, screenshot `smoke_pause.png`, assert
`SMOKE_PAUSE open`), `boss` (a boss-only floor `tools/smoke_boss_floor.tres`, screenshot
mid-fight after the first ring, assert `SMOKE_BOSS_HP <n>` below max). Every scenario prints
`SMOKE_AUDIO <plays>`. Sound and music themselves are judged in the user's playtest.

## Build order

1. Audio scaffold: buses, `Settings`, `Audio` silent with the table, the new signals and their
   emit sites, `check_boot.sh` counting `AUDIO_MISSING`. The sound list goes to the user with
   this task so files arrive during the build.
2. Title: the layer, `Main.play` and `start_at_title`, the seed field, `quiet_main` and the
   smoke tool skipping it, the `title` scenario.
3. The merged pause and build screen: the `pause` action, the columns, sliders through `Audio`
   and `Settings`, Quit to title, `UiTheme.panel` and `clear_children`, the `pause` scenario.
4. The boss: `BossDef` and `BossBrain` (pure, TDD), then `Boss` with each pattern, the HUD bar,
   the `summoned` group and `WaveRunner`, `status_scale`, room 8's table, the `boss` scenario.
5. Particles polish, one recipe per commit.
6. The balance pass, one commit per item with the checklist note.
7. Wiring the files as they land (`CREDITS.md`), the M4 feel checklist, the tidy-ups, and the
   `0.4.0-rc1` tester build.

## Open items

- The game's name (placeholder "Arena").
- The user's playtest decides the boss numbers, the music levels, and whether the Heal slot
  draw feels right; each change goes into the checklist's verdict table as before.
- Whether `Engine.time_scale` pitches audio is decided by the probe in the plan.

## Deviations during the build

One line per bullet of the plan's "## Deviations" (`docs/plans/2026-09-15-milestone-4.md`), which holds the full record with tests and reasons.

- (Planning) The Sfx and Music buses are made at runtime by `Audio._ensure_bus`, not by a `default_bus_layout.tres`.
- (Planning) `Engine.time_scale` does not pitch audio in Godot 4; no hitstop compensation exists.
- (Planning) Two extra bus signals: `boss_attacked(pattern, position)` and `door_opened(position)`; the summary reports `summary_won`/`summary_lost` through `menu_opened`, and `run_won`/`player_died` only stop the music.
- (Planning) The boss places its own summons (`Boss._summon`); `Spawner.spawn` seats a runner-spawned boss at the top centre.
- (Planning) The build screen's rank column reads "2/3" and `PANEL_SIZE` is 1240 x 600 (was 1000 x 560).
- (Planning) `Spawner.spawn` returns `Node2D`; `Player._check_contact` duck-types harmful bodies through `is_harmful()` and `def.contact_damage`.
- (Planning) The status emitters are built at `StatusEffects._ready` and toggled, since a status lands inside a shot's `body_entered`.
- (Planning) The pause screen: columns split 1:3, no "Build" heading (the weapon row is it), no keyboard focus on the options, and `UiTheme.framed_panel(host, size, scale)` instead of `panel(size)`.
- (Planning) `BossBrain`: actions named `ring`/`volley`/`charge`/`charge_end`/`summon`, a timed approach (`tick(delta, def)` takes no distance), SPAWNING/DEAD on the body, and the design's "phase 2" is the brain's `stage`.
- Task 1: three test-side changes in `tests/test_audio.gd` (the stolen player is found as `_next_player` does, the crossfade stand-in loops, the gap and steal tests wait on the wall clock).
- Task 1 review: `music()` stops the incoming player before reuse, `reset()` clears `_music_live`, the `music` flag guards both entry points, a paused game sound is dropped, `has_sound()` is gone, `_ready` applies the loaded settings directly.
- Task 2: `Audio` reads gameplay nodes duck-typed (a static `Health`/`Enemy`/`Player` reference leaks scripts at quit on 4.7.2), `_on_enemy_died` types `def` as Variant, the menu test waits out `ui_close`'s gap, `test_audio` unpauses in `after_test`, and a cold boot has no run music until Play.
- Task 3: the seed-field test types real keys (`insert_text_at_caret` emits no `text_changed`), the boot test waits a frame after Play, and the title capture is `smoke_title_screen.png`.
- Task 3 review-prep: `Main._skip_title_once` so R restarts straight into a run and only Quit to title shows the title after a reload.
- Task 3 review: `Audio.stop_game_sounds()` under the title, a `title_play` action (Enter, not `ui_accept`), `blocked` reads `title.is_open()`, tests for the button and the field's submit, `CLAUDE.md` names the title's layer.
- Task 2 review: the Heal card's sound plays on the UI pool, `test_run_state` resets Audio, `wall_msec` lives in `SceneSuite`, `_handlers()` is typed, small doc fixes.
- Sound files (2026-09-17): three packs wired under the design names (Pixel Combat, Minifantasy Dungeon, Classic Monster Sounds); two loops instead of three (`music_title` is gone; the title plays `music_run`), the loops are Ogg after a WAV commit, `Audio._loop` handles both, and the release at quit waits for the mixer; `test_every_listed_sound_file_exists` landed early.
- Task 4: the pause capture is `smoke_pause_menu.png`; every harness Main saves its volumes to `SceneSuite.SETTINGS_SCRATCH`; the frame's top ornament lands on the weapon name's tail (for the playtest).
- Task 4 review: the widest-rows test pins the columns' size, `close()` warns on a failed save, `SceneSuite.quiet(main)`, explicit button names, the pause scenario's own settings file, and the rest of the twelve items.
- Task 5 review: the recover edge enters APPROACH before advancing the pattern, so an enrage requested during a recover starts stage two's cycle at that edge.
- Audio release at quit (2026-09-20): `Audio._release_streams` waits for a mixer step (`get_time_since_last_mix`, capped by `RELEASE_TIMEOUT_MSEC`) instead of a 50 ms delay; the boot gate is clean fourteen runs in a row.
- Task 5 quality review: the stage flips only on an edge inside `tick()`, `BossDef.validate` reports an empty id, a negative spread, and a weak bolt, the phase lengths in ticks are pinned (0.45 s and 0.5 s land a tick late at 60 Hz).
- Task 6: `ticks(n)` resumes before that tick's callbacks (the waits carry a tick of slack), the boss keeps its fade tween and kills it on death (the corpse's alpha), and `test_shipped_floor_is_valid` pins room 8 at one enemy.
- (Planning) The boss's seat is a tile and a half below the top wall, not one tile.
- Task 6 review: the charge test proves the lock from `Vector2.UP` and the wall stop within a pixel, only a `StaticBody2D` ends a charge (`Boss._hit_wall`), lane and on-time charge-end and body-level enrage tests, the sprite faces the charge, `Spawner.spawn` asserts an enemy scene.
- Task 7: as planned; the charge tests' second wait is 16 ticks and the attack edge is the 38th tick.
- (Planning) The boss bar is 480 by 48 (not 40) and sits on the ledge row.
- Task 7 review: tests own their boss defs (`SceneSuite.own_def`) and wait in ticks, the stage-two attack lands on tick 30, the HUD tracks one `Health`, `summon_count` is capped at 2, every smoke scenario fails when silent.
- Task 8: `_children_of_type` matches script classes by global name, the vignette alpha compares approximately, the boss death check counts four particles, the juice suite counts five bursts, a kill mid-charge stops the charge dust, the `_boss_death` hook landed with recipe 7.
- Task 8 review: `RingFlash` grows its radius at a 2 px stroke, the status emitters attach on the body's `ready`, the afterimage gaps are physics-driven, `Fx.DUST`/`BOUNCE_SPARK`/`DEFAULT_DEATH_COLOR`, `_ring_flash` returns void, the sparks test checks brightness.
- (Playtest) The user's 2026-09-21 notes supersede the Heal-slot stream: Heal is always the right card when hurt, the first heal slot offers a heart container, Heal restores half the max in whole hearts, the waves from room 4 on grow past the plan's numbers, and the stats screen goes to the post-slice list.
- Task 9: `UpgradeCatalog.offers(build, hurt, rng, first_heal)` and `heal_card` keep the catalog pure, a container already drawn moves right, `HeartRules.heal_amount`, `UpgradeMenu.chosen(card, index)` with `Main._heal_slot`, room 4's finale 9 + 3, the four wave files in one commit, the pierce icon at Raven (62, 9), two test rewrites.
- Task 9 review: a full-health pick never counts a heal-slot use, `offers` takes one hurt flag and drops `count`, the jitter's RNG is recorded, checklist and doc nits.
- Task 10: `BOLT_SCALE` 0.7; trails named `Trail_<status>` stacked burn/stun/chill 2 px apart with the mean tint; the seed field's digit filter is gone (`permawhat?` carries a `?`), `Cheats.parse` is the gate, `max_length` 16, `RunState.start_run(seed, cheats)`, `cheats=<flag names>` on the summary and the run line, the immortality check in `Player.hurt` alone; the Quit tests read the button's `Text` label and disconnect the real quit before pressing; the loop levels are pinned by a test; the tidy-up run's one-off exit 101; the boss flash/telegraph copies stay recorded, not taken.
