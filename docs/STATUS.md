# Project status

Updated 2026-09-08. Read this first in a new session, then the docs it points to.

## What exists

A playable run on `main`: four single-screen rooms with an ending. Milestone 2 closed at tag `m2` on 2026-09-07; Milestone 1 closed at tag `m1`. Godot 4.7.2, GDScript, 177 gdUnit4 tests in 34 suites green, boot gate and six smoke scenarios green.

- Milestone 0 (tag `m0`): project scaffold, headless test runner and boot gate, screenshot smoke tool, 0x72 Dungeon Tileset II with a name-based `SpriteAtlas`, `Events` and `RunState` autoloads, tiled arena with wall colliders, animated player movement, following camera with aim lean.
- Milestone 1 (tag `m1`): pistol (`WeaponDef`, `FireController`, `Projectile`), `Health` component, imp Chaser enemy with a spawn fade and chase state, `Juice` autoload (trauma shake, extending hitstop, hit flash), particles and muzzle flash, player HP with contact damage, i-frame blink, knockback, death, and restart. Solid enemy bodies, 3x zoom, fullscreen, and death holding until R came from the playtests.
- Milestone 2 (tag `m2`; the door pass and replay 2 fixes landed after the tag): single-screen 28x15 rooms (`Room` scene: arena, doors, enemies, projectiles, spawner, wave runner) built from `RoomDef`s, ringed by a two-row top wall (the tileset's ledge over its brick face, with the exit door set into the band) and one-row side and bottom walls (the entry is a dark opening with shaded wall ends that bricks up 0.4 s after you arrive), leaving a 26x12 floor; a four-room floor (`data/floors/floor_1.tres`) with authored waves (`data/waves/room_1..4.tres`, `WaveTable` > `WaveDef` > `SpawnGroup`) driven by `WaveRunner` and the pure `WaveProgress`; chasers run at the player's 110 px/s so the dash is the escape; the Shooter enemy (orc shaman, `ShooterBrain`) that keeps its range and fires a telegraphed 120 px/s bolt; a dash on Space or right click (`DashRules`, layer 7 so triggers still see a dashing player); a HUD with tileset hearts, room, wave, and kills; a heart pickup dropped at the room's center on clear; doors that open on clear with a real-time fade between rooms; a run summary on death ("You died") and on the last clear ("Floor cleared") that waits for R; `-- --seed=N` replays a run. The `Spawner` is a placement service now (`spawn(scene, at)`), scene tests share `tests/support/scene_suite.gd`, and the smoke tool gained `kill`, `room`, and `death` scenarios with a 30 s watchdog.
- Design decisions taken during review, all recorded in the plans: `room_cleared` and `enemy_died` arrive from physics callbacks, so the exit request and the heart drop are deferred; the first ending (win or death) claims the run and later events change nothing; a death during the fade holds on the corpse under the black; the summary draws over the fade (CanvasLayer 30 over 20 over the HUD at 1); `quiet_main_with_floor` is quiet for the first room only.

## How to run and verify

```bash
source tools/godot.sh && "$GODOT_BIN" --path .              # play: WASD, mouse aim, click to shoot, Space/right click dash, R restarts
source tools/godot.sh && "$GODOT_BIN" --path . -- --seed=N  # replay a run (the seed is on the summary and in the RUN_OVER/RUN_WON line)
tools/test.sh                                               # all suites headless; exit 0 pass
tools/check_boot.sh                                         # boots main scene headless, fails on any error
tools/smoke.sh <idle|move|combat|kill|room|death>           # scripted run in a 1280x720 window, screenshot in reports/; a 30 s in-process watchdog, reported as `watchdog: scenario hung`
tools/input_probe.sh 25                                     # logs raw key/mouse/focus events (stuck-key diagnosis)
```

Smoke scenarios: `idle` (the first room, nothing spawning), `move` (run right and dash), `combat` (the real floor, the first wave under fire), `kill` (a placed chaser dies, `SMOKE_KILLS 1`), `room` (clear a one-chaser room and walk through the door, `SMOKE_ROOM 1`), `death` (hp 1 against a chaser, `SMOKE_SUMMARY You died`). `room` and `death` run on `tools/smoke_floor.tres`.

Tuning numbers: `data/enemies/*.tres` (shooter range and telegraph), `data/weapons/*.tres` (pistol, shaman bolt), `data/waves/*.tres` (breathers, groups), `data/rooms/*.tres` (size, exit), `scripts/dash_rules.gd`, `scripts/heart_pickup.gd` (`HEAL`), `scripts/main.gd` (`FADE_TIME`, summary delays), `scripts/autoload/juice.gd`, the trauma and hitstop consts at the top of `scripts/enemy.gd` and `scripts/player.gd`, `scripts/camera.gd`. `docs/plans/2026-09-04-m2-feel-checklist.md` maps each playtest question to its number.

## Milestone state

Milestone 2 is closed (tag `m2`, 2026-09-07). The user played a full run and called the gameplay satisfying with room for more mechanics and difficulty; ratings in `docs/plans/2026-09-04-m2-feel-checklist.md` under "Verdict, playtest 1". Two follow-up passes landed on their replays and are recorded there: the door look (two-row top wall with the door set into it, dark bottom opening, black clear colour) and, from replay 2, the entry bricking up behind the player and chasers at player speed. Replay 2's changes have not been rated separately; they get judged in the Milestone 3 playtest. Accepted as-is for now: the first rooms are easy, one heart per room is generous. Recorded for 1.0: non-rectangular rooms and rooms with more than one exit.

## Milestone 3 in progress (2026-09-08)

Designed, planned, and four of fifteen tasks built on `main`: `docs/plans/2026-09-08-milestone-3-design.md` (approved design) and `docs/plans/2026-09-08-milestone-3.md` (the plan; its "## Progress" and "## Deviations" sections at the end say exactly where the build stands). Data model, the pure `Build` fold, the `UpgradeCatalog` with every card file, and the player firing the resolved weapon are in; the menu, projectiles, status effects, dash charges, HUD, build screen, rooms 5 to 8, and smoke scenarios are next, starting at Task 5 (assets). Resume with `superpowers:subagent-driven-development` on that plan. Open items for the user: the pistol sheet's origin and license, and confirming the Raven and 0x72 UI terms for `CREDITS.md`.

## Next steps, in order

1. Milestone 3: the upgrade picker at the room-clear moment, eight upgrades, at least three that combine; the heart becomes one reward among several. Start with `docs/plans/2026-09-08-m3-prework-notes.md` (the brief, the user's directions, every code hook, the open items), then brainstorm, plan, and build with the process in "How the work was done".
2. Milestone 4: sound, particles polish, balance pass (difficulty rises here and with rooms). The user supplies sound and music files on request.
3. After the slice: rooms and floors (non-rectangular rooms, multiple exits, finite spawns per room), a boss, pickups, weapons or classes, the shift to generated art.

## Handoff for a fresh session

Read, in order: this file, `CLAUDE.md`, `docs/plans/2026-09-08-m3-prework-notes.md`, then the milestone table in `docs/plans/2026-09-02-action-roguelike-design.md`. Confirm the build is green before designing anything: `tools/test.sh` (177 tests), `tools/check_boot.sh`, `tools/smoke.sh room`. Then invoke `superpowers:brainstorming` for Milestone 3 and ask the user questions one at a time; the user is the playtester and the source of assets, and prefers to be asked rather than have a substitute quietly chosen. The plan files in `docs/plans/` hold the final code of every file built so far and every deviation found in review; grep them before assuming how something works.

## How the work was done

Subagent-driven development from the plans in `docs/plans/2026-09-02-arena-roguelike-m0-m1.md` and `docs/plans/2026-09-04-milestone-2.md`: one implementer per task, then a spec-compliance review, then a code-quality review, with fixes re-reviewed before the next task, and the plan re-synced with every deviation. Milestone 2 used the same loop; its plan records every deviation found in review (deferred heart drop and exit request, the `player_dashing` layer, the bolt container injected by the Spawner, the summary layer order, and the rest). The plans are the record of what was built and why; they are long because they hold the final code of every file. `CLAUDE.md` holds the conventions a session needs to keep working the same way.
