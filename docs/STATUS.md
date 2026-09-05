# Project status

Updated 2026-09-04. Read this first in a new session, then the docs it points to.

## What exists

A playable single-arena vertical slice on `main` (tag `m1-candidate` at ac8f4dc, later commits add tooling and notes). Godot 4.7.2, GDScript, 104 gdUnit4 tests green, boot gate and smoke tool green.

- Milestone 0 (tag `m0`): project scaffold, headless test runner and boot gate, screenshot smoke tool, 0x72 Dungeon Tileset II with a name-based `SpriteAtlas`, `Events` and `RunState` autoloads, tiled 40x23 arena with wall colliders, animated player movement, following camera with aim lean.
- Milestone 1 (tag `m1-candidate`): pistol (`WeaponDef`, `FireController`, `Projectile`), `Health` component, imp Chaser enemy with a spawn fade and chase state, timed spawner with a seed-derived RNG stream, `Juice` autoload (trauma shake, extending hitstop, hit flash), particles and muzzle flash, player HP with contact damage, i-frame blink, knockback, death, and restart.
- Design decisions taken during review, all recorded in the plan: enemies pass through the player and only the hurtbox hurts (being reversed in the tuning pass below); the kill freeze holds the enemy's white pose; the camera leans through `position` and shakes through `offset`; spawning draws from `RunState.stream("spawn")`; `Player.hurt()` is the single damage entry point; `Main.restart()` only reloads when Main is the current scene.

## How to run and verify

```bash
source tools/godot.sh && "$GODOT_BIN" --path .   # play: WASD, mouse aim, click to shoot, R restarts
tools/test.sh                                    # all suites headless; exit 0 pass
tools/check_boot.sh                              # boots main scene headless, fails on any error
tools/smoke.sh combat                            # windowed scripted run, screenshot in reports/
tools/input_probe.sh 25                          # logs raw key/mouse/focus events (stuck-key diagnosis)
```

Tuning numbers: `data/weapons/pistol.tres`, `data/enemies/chaser.tres`, `scripts/spawner.gd` exports, `scripts/autoload/juice.gd`, the trauma and hitstop consts at the top of `scripts/enemy.gd` and `scripts/player.gd`, `scripts/camera.gd`. The feel checklist maps each question to its constant.

## Milestone state

Milestone 1 is a candidate, not closed. The user played twice and rated every line of `docs/plans/2026-09-02-m1-feel-checklist.md` on 2026-09-04 (see "Verdict, playtest 2" at the bottom of that file). Movement, impact, shake, recoil, getting hit, the chaser, and the camera are all good. Five things need changing before the milestone closes: sprites are too small (zoom 3x, fullscreen), the pistol is too fast (5/s), i-frames run long because hitstop pauses the timer, enemy bodies should be solid, and death should wait for R instead of auto-restarting. The verdict is "close after tuning".

Open issue: during playtest 1 the knight got stuck moving right. Investigation notes and a fix sketch are in `docs/plans/2026-09-04-m2-prework-notes.md` under "Open: stuck movement key". Best-supported cause: macOS discards key-ups during a title-bar window drag. It did not recur in playtest 2. Fullscreen (part of the tuning pass) removes the title bar, which removes the suspected trigger.

## Next steps, in order

1. Run the five-item tuning pass in the feel checklist, one commit per item, re-running `tools/test.sh`, `tools/check_boot.sh`, and `tools/smoke.sh combat` after each. Item 1 pulls the "camera limits from the arena" should-fix forward from the Milestone 2 notes. Then the user replays against the "Replay questions" list. Tag `m1` when they say shooting feels good.
2. Brainstorm and plan Milestone 2 with the same brainstorming and writing-plans skills, starting from the design doc's milestone table and `docs/plans/2026-09-04-m2-prework-notes.md` (remaining should-fix items first: injectable Juice clock, spawner taking a scene, shared test helpers, a smoke `kill` scenario). Milestone 2 scope from the design: Shooter enemy (telegraphed, dodgeable projectiles), waves and wave tables, HP display, death and restart with a run summary. Feedback added a dash or dodge through enemies to that scope; see "Design hooks from the playtest 2 feedback" in the notes.
3. Milestone 3: upgrade picker between waves with at least three combining upgrades (`WeaponDef` is already duplicated per player for in-place mutation). Milestone 4: sound, particles polish, balance pass. Then rooms and doors (with finite spawns per room instead of the endless ramp), floors, a boss, pickups, weapon variety or classes, and the shift to generated art.

## How the work was done

Subagent-driven development from the plan in `docs/plans/2026-09-02-arena-roguelike-m0-m1.md`: one implementer per task, then a spec-compliance review, then a code-quality review, with fixes re-reviewed before the next task, and the plan re-synced with every deviation. That plan is the record of what was built and why; it is long because it holds the final code of every file. `CLAUDE.md` holds the conventions a session needs to keep working the same way.
