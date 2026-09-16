# Milestone 4 pre-work notes

For the session that brainstorms and plans Milestone 4. Written 2026-09-15 while Milestone 3 waits on
tester feedback and the user's replay. Read `docs/STATUS.md` first, then this, then start the
brainstorm once Milestone 3 is closed (`git tag m3`).

## The brief, from the design doc

Milestone 4 row: "Sound, particles, balance pass (the run summary shipped in 2). Done when: a vertical
slice worth showing a friend." The design's fun thesis, item 1: "punchy sound" is part of game feel,
the top priority. The user supplies sound and music files on request; ask for them with the list of
events that need a sound and the count, rather than substituting free packs.

## What the user has said that shapes it

- Difficulty comes from later mechanics and rooms, not from tuning the early rooms; the balance pass
  starts from the inputs recorded in `docs/plans/2026-09-14-m3-feel-checklist.md`.
- Tiers must read plainly: rank bonuses stack additively (25 / 50 / 75), summaries show the owned
  total, cards do not repeat themselves. Keep that standard for any new text.
- The user wants feedback from testers before moving on; tester builds exist (`tools/build.sh`,
  Windows x64 and Linux x64 zips, version `config/version` in `project.godot`, `docs/TESTERS.md`).
  A macOS build was not asked for; a web build would need itch.io or another host that sets the
  cross-origin isolation headers.
- For 1.0: multiple characters with different starting weapons (a character is a starting `Build`),
  melee and caster weapons (`WeaponDef.kind` to pick the attack path; the reserve icon packs in
  `assets/reserve` hold tiered weapons), weapon tiers, non-rectangular rooms, multiple exits.
- Assets: DungeonUI CC0; the Raven free icon set is personal use only (a paid release needs the paid
  pack); the pistol pack states no licence; the fonts (Pixel Operator CC0, Alagard free with credit,
  m5x7 CC0) are in `assets/fonts`. See `CREDITS.md`.

## Where the hooks are

- Sound: every gameplay moment already emits on the bus (`scripts/autoload/events.gd`): `shot_fired`,
  `enemy_hit`, `enemy_died`, `player_hit`, `player_healed`, `player_died`, `player_dashed`,
  `door_sealed`, `room_entered`, `wave_started`, `room_cleared`, `run_won`, `upgrade_chosen`,
  `build_changed`, `dash_charges_changed`. `scripts/fx.gd` (`Fx`, a Node2D under Main) is the model
  for a listener that spawns one-shots per event and disconnects in `_exit_tree`; an `Audio` sibling
  or autoload can mirror it with `AudioStreamPlayer` pools. No audio bus layout exists yet; the
  project has no `default_bus_layout.tres`. Hitstop scales `Engine.time_scale`, which also pitches
  `AudioStreamPlayer`s unless `pitch_scale` is compensated or the players are set to ignore it;
  decide in the brainstorm. Music: state changes are `room_entered`, `room_cleared` (the picker beat,
  `Main.PICKER_DELAY`), `player_died` and `run_won` (the summary delays in `main.gd`).
- Particles: `Fx._burst` is the CPUParticles2D recipe; `Fx.fade_scale()` / `fade_ramp()` are shared
  with the projectile trails (`Projectile._dress_status`). Enemy spawn fade-in is visible since the
  flash shader fix (`assets/shaders/flash.gdshader` mixes from `COLOR`, so modulate works).
- Balance knobs: `data/enemies/*.tres`, `data/weapons/*.tres`, `data/upgrades/*.tres` (per-rank
  modifiers and `max_rank`), `data/waves/room_1..8.tres`, `scripts/wave_progress.gd`
  (`SPAWN_INTERVAL`), `scripts/status_effects.gd`, `scripts/dash_rules.gd`, `scripts/build.gd`
  (`BASE_MAX_HP`, `BASE_DASH_CHARGES`). The checklist's "Inputs for the balance pass" lists the
  first concerns: room 5's finale wave, the shooter share at room 6, whether Heal crowds out weapon
  cards when hurt, and the recommendation to draw offers from the Heal-free pool and swap Heal into
  one slot from a separate stream so a seed replays the other two cards regardless of hurt state.
- Feel constants live next to what they affect (CLAUDE.md lists them); `Main.PICKER_DELAY` (0.8 s)
  is the beat before the picker; shooter bolts are 150 px/s with a 0.6 s recover.

## Tidy-up candidates recorded by the Milestone 3 reviews, none urgent

- A `DashCharges` RefCounted holding charges, max, and the refill clock, so `Player` stops carrying
  three loose vars and `DashRules.refill`'s Array return.
- `UiTheme` helpers for clearing a container's children and building the framed panel (paper plus
  frame) that `UpgradeMenu` and `BuildScreen` both do by hand.
- The build screen's weapon row is detected by empty rank and description strings in `_row`.
- The HUD's rank digit (`hud.gd`, `RANK_FONT_SIZE`) still uses Godot's default font; a 16 px Pixel
  Operator would match the rest of the UI.
- The 0x72 frame piece has a dark hanging tab under its top gem; on the build screen it sits as a
  72 by 58 block under the door. The plain frame region (64, 41, 40, 22) from the same sheet is a
  one-constant swap if it bothers anyone.
- `tools/gen_ui_font.gd` and its outputs (`assets/dungeon_ui/ui_font.*`) are unused since the fonts
  moved to TrueType; keep as a record or delete.

## Open from the Milestone 3 playtest

- Tester feedback (builds handed to the user 2026-09-14) and the user's own replay decide the close.
  Record either as "Verdict, playtest 2" in the M3 checklist, fix one concern per commit, rebuild
  with `tools/build.sh` (bump `config/version` when the build changes), then `git tag m3`.
- The 13 notes of playtest 1 are all landed (the table's `Done` column has the commits).

## Process that worked, to repeat

1. `superpowers:brainstorming`: one question at a time, then 2 or 3 approaches with a recommendation,
   then the design in sections approved one by one, saved as `docs/plans/<date>-milestone-4-design.md`.
2. `superpowers:writing-plans`: bite-sized TDD tasks with complete code; probe risky engine details
   with throwaway headless `-s` scripts first (autoloads only via `root.get_node` from
   `_initialize`; a failed `assert` hangs, so use `timeout`, now installed, and `quit()` on every
   path; Pillow is installed for image work).
3. `superpowers:subagent-driven-development`: one implementer per task reading its "### Task N"
   section by heading, a spec reviewer, then `superpowers:code-reviewer`; fixes in a separate
   commit that re-syncs the plan's code blocks and adds a "Task N review:" Deviations bullet;
   `SendMessage` is unavailable, so fix agents are fresh dispatches with full context; UI is checked
   by screenshot since gdUnit cannot see pixels.
4. The milestone closes only on the user's playtest against a feel checklist; small playtest passes
   are done directly, one commit per note, recorded in the checklist's verdict table.
