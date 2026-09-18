# Arena Roguelike: notes for Claude sessions

Start with `docs/STATUS.md` (current state, next steps, the handoff), then `docs/plans/2026-09-02-action-roguelike-design.md` (the approved design). The M0+M1, Milestone 2, and Milestone 3 plans in `docs/plans/` are the build records (they hold the final code of every file and every deviation found in review); `docs/plans/2026-09-08-milestone-3-design.md` is the Milestone 3 design and `docs/plans/2026-09-14-m3-feel-checklist.md` the playtest that closes it.

## Commands

- `tools/test.sh` runs every gdUnit4 suite headless; exit 0 pass, 100 failures, 105 script errors, 1 if no tests found. `tools/test.sh -a res://tests/<file>.gd` runs one suite.
- `tools/check_boot.sh` boots the main scene headless and fails on any `ERROR:`/`WARNING:` line. Godot exits 0 even when the main scene fails to load, so never use its exit code alone.
- `tools/smoke.sh [idle|move|combat|kill|room|death|pick]` opens a window for a few seconds, drives input in physics ticks, and writes `reports/smoke_<scenario>.png` plus `SMOKE_` lines. `kill`, `room`, `death`, and `pick` assert on their key line; `room`, `death`, and `pick` run on `tools/smoke_floor.tres` (two rooms of one chaser). `room` takes card 1 before walking through the door; `pick` also saves `reports/smoke_pick_menu.png` with the cards up. A 30 s in-process watchdog; smoke.sh reports `watchdog: scenario hung`. Read the PNG to verify visuals.
- `tools/run.sh [--seed=N]` plays the game from the project with the Godot binary; the user's way to run locally.
- `tools/build.sh [version]` exports the tester zips (Windows x64 and Linux x64, release, `export_presets.cfg`, `docs/TESTERS.md` as the README) into `builds/` (gitignored). Needs the 4.7.2 export templates installed in the editor. The version comes from `config/version` in `project.godot`.
- `tools/gen_atlas.py` regenerates `data/atlas.json` from the tileset's tile list. Sprites are always looked up by name through `SpriteAtlas`; never hardcode atlas pixel coordinates.
- `tools/gen_icons.py` regenerates `data/icons.json` (card and HUD icons by name, from a (row, col) table on the Raven sheet). Headless Godot generators, run as `source tools/godot.sh && perl -e 'alarm 120; exec @ARGV' "$GODOT_BIN" --headless --path . -s tools/<script>.gd </dev/null`: `gen_ui_font.gd` (the BMFont from the 0x72 UI sheet), `gen_guns.gd` (the handgun sprite from the user's pistol sheet), `icon_sheet.gd` (renders every icon to `reports/icons.png` for a check by eye).
- Godot binary: `source tools/godot.sh` exports `GODOT_BIN` (/Applications/Godot.app/Contents/MacOS/Godot, 4.7.2).

## Conventions

- Commits: no global git identity on this machine. Use `git -c user.name="Benjamin Zigh" -c user.email="78459259+beben-games@users.noreply.github.com" commit` and end messages with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Commit Godot's generated `.uid` and `.import` files. `reports/` and `.godot/` are ignored. Never edit `addons/gdUnit4` (vendored upstream v6.2.1).
- The login shell is zsh; tool scripts are bash and are executed, never sourced.
- Physics layers: 1 player, 2 enemies, 3 player_shots, 4 enemy_shots, 5 walls (bit values 1, 2, 4, 8, 16), 6 (bit 32) reserved, unused since the heart pickup was removed, 7 player_dashing (bit 64): the player's body layer during a dash; enemies never mask it, the door trigger masks 65. Player body mask is 18 (walls, enemies), or 16 (walls only) while dashing; enemy bodies 19 (walls, enemies, player). Player shots mask 2 (enemies only) and enemy bolts mask 0; walls are handled by the projectile's raycast against layer 5 (`Projectile.WALL_MASK`). Enemy bodies are solid; damage reaches the player only through the hurtbox.
- Randomness: shot spread uses `RunState.rng`; systems whose placement must depend only on seed and time use `RunState.stream(name)`; cosmetic effects use the global RNG; the arena floor derives its own RNG from the seed.
- `Events` is the signal bus; nodes that connect to it disconnect in `_exit_tree`. `Player.hurt()` is the only way to damage the player.
- Signals live in `scripts/autoload/events.gd`. Lifetime rule: `room_cleared` and `enemy_died` arrive from inside physics callbacks (a shot's `body_entered`), so a handler that adds or removes physics nodes, or pauses the tree, must defer (`call_deferred`, or emit deferred as `Door` does), or Godot fails with "can't change this state while flushing queries". `upgrade_chosen(card, rank)` carries rank 0 for Heal and Switch cards.
- Pausing: the upgrade menu and the build screen set `get_tree().paused`; they are CanvasLayers with `process_mode` ALWAYS on layer 10. Anything that must run under them (input, timers) lives in those nodes. `Main.restart` and `SceneSuite.after_test` unpause. Call `Juice.reset()` before pausing so a kill freeze's time scale does not survive under the menu.
- Weapons are never mutated: the player fires `RunState.build.resolve(...)`, re-resolved on `build_changed`. New weapon stats are Modifier stat names too (`Modifier.WEAPON_STATS`); adding content means adding a `data/upgrades/*.tres` or `data/weapons/*.tres` file, which `UpgradeCatalog` validates at load.
- Icons and UI: card and HUD icons are looked up by name through `IconAtlas` (`data/icons.json`, generated by `tools/gen_icons.py` from a (row, col) table on the Raven sheet); frames and panels come from `UiTheme` (`assets/dungeon_ui`) and the fonts from `assets/fonts` (TrueType pixel fonts on a 16 px grid, imported without antialiasing or hinting; font sizes are multiples of 16 so the glyphs land on whole pixels). Never hardcode a sheet coordinate outside those tools.
- Audio: `audio.gd` never names a gameplay Node class (`Health`, `Enemy`, `Player`, ...) statically; it duck-types through `get()` and `get_node_or_null`; `check_boot` catches a regression as leaked ObjectDB instances at exit.
- Headless generator scripts (`tools/gen_*.gd`, `tools/icon_sheet.gd`) run with `-s` and must `quit()` on every path; a failed `assert` hangs the process, so they report with `push_error` and `quit(1)`. Run them under `perl -e 'alarm 120; exec @ARGV'`.
- Room geometry: rooms are 28x15 tiles of 16 px (448x240, one screen at 3x zoom). The top wall is two rows (ledge over face) with the exit door set into it at x 208..240; side and bottom walls are one row; the floor is 26x12 (`ArenaGrid.bounds`). The entry opening on the bottom wall bricks up 0.4 s after arrival. All of it derives from `ArenaGrid`; never hardcode a room coordinate. CanvasLayer order: HUD 1, UpgradeMenu and BuildScreen 10 (never shown together), Fade 20, Summary 30.
- Feel constants live next to what they affect (`juice.gd`, top of `enemy.gd` and `player.gd`, `dash_rules.gd`, `status_effects.gd`, `projectile.gd` for homing and the wall nudge, `camera.gd`, the fade and summary delays in `main.gd`, the card and panel sizes at the top of `ui/upgrade_menu.gd` and `ui/build_screen.gd`); data lives in `data/*.tres` (enemies, weapons, upgrades, waves, rooms, floors).

## Tests

- gdUnit4 with `report/godot/push_error=true`: a `push_error` during a test fails it. Autoloads are live in the runner.
- Scene tests wait on `get_tree().physics_frame`, not wall-clock, so timings are machine-independent. Real-time waits are only for what is real time by design: hitstop, the room fade, the summary delays, and the picker delay (`Main.PICKER_DELAY`).
- Every scene test extends `SceneSuite` (`tests/support/scene_suite.gd`) and builds Main with `quiet_main()` or `quiet_main_with_floor()`, which disable `Room/WaveRunner` so nothing spawns on its own (only for the first room: a room entered later gets a fresh runner). The base `after_test` resets `Juice` and `RunState`; a suite that overrides it must call `super()`. Never add a second `RunState` to the tree.
- Follow TDD: write the failing test, run it, implement, run again. Run `tools/test.sh` twice before claiming a suite is stable.

## Process

- Milestones close only on the user's playtest verdict. Keep the plan document in sync with every deviation from it.
- Do not downgrade silently when a step needs the user (downloads, logins): put it in the plan as a user action and work around it.
