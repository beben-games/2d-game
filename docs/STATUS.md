# Project status

Updated 2026-09-07. Read this first in a new session, then the docs it points to.

## What exists

A playable run on `main`: four single-screen rooms with an ending. Milestone 2 is a candidate (tag `m2-candidate`) awaiting the user's playtest; Milestone 1 closed at tag `m1`. Godot 4.7.2, GDScript, 169 gdUnit4 tests in 34 suites green, boot gate and six smoke scenarios green.

- Milestone 0 (tag `m0`): project scaffold, headless test runner and boot gate, screenshot smoke tool, 0x72 Dungeon Tileset II with a name-based `SpriteAtlas`, `Events` and `RunState` autoloads, tiled arena with wall colliders, animated player movement, following camera with aim lean.
- Milestone 1 (tag `m1`): pistol (`WeaponDef`, `FireController`, `Projectile`), `Health` component, imp Chaser enemy with a spawn fade and chase state, `Juice` autoload (trauma shake, extending hitstop, hit flash), particles and muzzle flash, player HP with contact damage, i-frame blink, knockback, death, and restart. Solid enemy bodies, 3x zoom, fullscreen, and death holding until R came from the playtests.
- Milestone 2 (candidate, tag `m2-candidate`): single-screen 28x15 rooms (`Room` scene: arena, doors, enemies, projectiles, spawner, wave runner) built from `RoomDef`s; a four-room floor (`data/floors/floor_1.tres`) with authored waves (`data/waves/room_1..4.tres`, `WaveTable` > `WaveDef` > `SpawnGroup`) driven by `WaveRunner` and the pure `WaveProgress`; the Shooter enemy (orc shaman, `ShooterBrain`) that keeps its range and fires a telegraphed 120 px/s bolt; a dash on Space or right click (`DashRules`, layer 7 so triggers still see a dashing player); a HUD with tileset hearts, room, wave, and kills; a heart pickup dropped at the room's center on clear; doors that open on clear with a real-time fade between rooms; a run summary on death ("You died") and on the last clear ("Floor cleared") that waits for R; `-- --seed=N` replays a run. The `Spawner` is a placement service now (`spawn(scene, at)`), scene tests share `tests/support/scene_suite.gd`, and the smoke tool gained `kill`, `room`, and `death` scenarios with a 30 s watchdog.
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

Milestone 2 is a candidate (tag `m2-candidate`, 2026-09-07) awaiting the user's playtest against `docs/plans/2026-09-04-m2-feel-checklist.md`. Everything in the plan landed; the deviations found in review are recorded in `docs/plans/2026-09-04-milestone-2.md`. 169 tests green twice, boot gate and all six smoke scenarios green. Not yet played by a person: the Shooter's telegraph, the dash, the wave pacing, the room size, the transition, and the summary beat are all first-guess numbers.

Milestone 1 closed on playtest 3 (tag `m1`, 2026-09-04); its verdicts are in `docs/plans/2026-09-02-m1-feel-checklist.md`.

Open issue: during M1 playtest 1 the knight got stuck moving right. Investigation notes and a fix sketch are in `docs/plans/2026-09-04-m2-prework-notes.md` under "Open: stuck movement key". Best-supported cause: macOS discards key-ups during a title-bar window drag. It has not recurred, and the game runs fullscreen, which removes the title bar.

## Next steps, in order

1. The Milestone 2 playtest, then a balance pass from the checklist verdicts: one concern per commit, re-verified by the tests and smoke scenarios. Tag `m2` when the user says a run has a beginning and an end that feel right.
2. Milestone 3: an upgrade picker at the room-clear moment (replacing or joining the heart) with at least three combining upgrades. `WeaponDef` is already duplicated per player for in-place mutation; `Main._on_room_cleared` is the hook. The remaining pre-work notes (Juice clock, projectile tunneling above ~480 px/s, `WeaponDef.validate` gaps) matter here.
3. Milestone 4: sound, particles polish, balance pass. Then more floors, a boss (a bigger room with the scrolling camera the arena still supports), pickups, weapon variety or classes, and the shift to generated art.

## How the work was done

Subagent-driven development from the plans in `docs/plans/2026-09-02-arena-roguelike-m0-m1.md` and `docs/plans/2026-09-04-milestone-2.md`: one implementer per task, then a spec-compliance review, then a code-quality review, with fixes re-reviewed before the next task, and the plan re-synced with every deviation. Milestone 2 used the same loop; its plan records every deviation found in review (deferred heart drop and exit request, the `player_dashing` layer, the bolt container injected by the Spawner, the summary layer order, and the rest). The plans are the record of what was built and why; they are long because they hold the final code of every file. `CLAUDE.md` holds the conventions a session needs to keep working the same way.
