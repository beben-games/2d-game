# Project status

Updated 2026-09-04. Read this first in a new session, then the docs it points to.

## What exists

A playable single-arena vertical slice on `main` (tag `m1` closes Milestone 1; `m1-candidate` at ac8f4dc was the pre-tuning build). Godot 4.7.2, GDScript, 108 gdUnit4 tests green, boot gate and smoke tool green.

- Milestone 0 (tag `m0`): project scaffold, headless test runner and boot gate, screenshot smoke tool, 0x72 Dungeon Tileset II with a name-based `SpriteAtlas`, `Events` and `RunState` autoloads, tiled 40x23 arena with wall colliders, animated player movement, following camera with aim lean.
- Milestone 1 (tag `m1`): pistol (`WeaponDef`, `FireController`, `Projectile`), `Health` component, imp Chaser enemy with a spawn fade and chase state, timed spawner with a seed-derived RNG stream, `Juice` autoload (trauma shake, extending hitstop, hit flash), particles and muzzle flash, player HP with contact damage, i-frame blink, knockback, death, and restart.
- Design decisions taken during review, all recorded in the plan: enemy bodies are solid since playtest 2 (they were pass-through in the candidate) and only the hurtbox hurts; the kill freeze holds the enemy's white pose; the camera leans through `position` and shakes through `offset`; spawning draws from `RunState.stream("spawn")`; `Player.hurt()` is the single damage entry point; `Main.restart()` only reloads when Main is the current scene.

## How to run and verify

```bash
source tools/godot.sh && "$GODOT_BIN" --path .   # play: WASD, mouse aim, click to shoot, R restarts
tools/test.sh                                    # all suites headless; exit 0 pass
tools/check_boot.sh                              # boots main scene headless, fails on any error
tools/smoke.sh combat                            # scripted run in a 1280x720 window, screenshot in reports/
tools/input_probe.sh 25                          # logs raw key/mouse/focus events (stuck-key diagnosis)
```

Tuning numbers: `data/weapons/pistol.tres`, `data/enemies/chaser.tres`, `scripts/spawner.gd` exports, `scripts/autoload/juice.gd`, the trauma and hitstop consts at the top of `scripts/enemy.gd` and `scripts/player.gd`, `scripts/camera.gd`. The feel checklist maps each question to its constant.

## Milestone state

Milestone 1 is closed (tag `m1`, 2026-09-04). The user played three times: the second playtest produced the line-by-line verdict in `docs/plans/2026-09-02-m1-feel-checklist.md`, the five-item tuning pass from it landed (b932eeb through 11e1e8e: 3x zoom and fullscreen with camera limits from the arena, pistol at 5 shots/s, i-frames counting real time through hitstop, solid enemy bodies with a wider hurtbox, death holding until R), and the third playtest verdict was "much better, tag m1" with nothing left to tune. 108 tests green twice, boot gate and smoke green.

Open issue: during playtest 1 the knight got stuck moving right. Investigation notes and a fix sketch are in `docs/plans/2026-09-04-m2-prework-notes.md` under "Open: stuck movement key". Best-supported cause: macOS discards key-ups during a title-bar window drag. It has not recurred, and the game now runs fullscreen, which removes the title bar.

## Next steps, in order

1. Milestone 2 is designed (`docs/plans/2026-09-04-milestone-2-design.md`, approved 2026-09-04); write the implementation plan with the writing-plans skill, then build it. Background: the design doc's milestone table and `docs/plans/2026-09-04-m2-prework-notes.md` (remaining should-fix items first: injectable Juice clock, spawner taking a scene, shared test helpers, a smoke `kill` scenario). Milestone 2 scope from the design: Shooter enemy (telegraphed, dodgeable projectiles), waves and wave tables, HP display, death and restart with a run summary. Feedback added a dash or dodge through enemies; see "Design hooks from the playtest 2 feedback" in the notes. Settle the room-shape question there too ("Rooms as single screens" in the notes) because wave tables and the arena size depend on it.
2. Milestone 3: upgrade picker between waves with at least three combining upgrades (`WeaponDef` is already duplicated per player for in-place mutation). Milestone 4: sound, particles polish, balance pass. Then rooms and doors (with finite spawns per room instead of the endless ramp), floors, a boss, pickups, weapon variety or classes, and the shift to generated art.

## How the work was done

Subagent-driven development from the plan in `docs/plans/2026-09-02-arena-roguelike-m0-m1.md`: one implementer per task, then a spec-compliance review, then a code-quality review, with fixes re-reviewed before the next task, and the plan re-synced with every deviation. That plan is the record of what was built and why; it is long because it holds the final code of every file. `CLAUDE.md` holds the conventions a session needs to keep working the same way.
