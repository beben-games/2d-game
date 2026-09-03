# Action Roguelike — Design

Date: 2026-09-02
Status: Approved

## Goal

An experiment in how far a game can be built collaboratively with Claude Code. The process matters as much as the result, so the design favors short iteration loops, text-based tooling, and milestones that are playable at every step.

## Decisions

| Question | Decision | Why |
|---|---|---|
| 2D or 3D | 2D top-down | Fast to iterate, forgiving of art, matches genre |
| Genre | Real-time action roguelike (Isaac / Gungeon lineage) | Systems stack, every session adds visible depth |
| Pacing | Real-time | User preference over turn-based; requires a game-feel-first plan |
| Platform | Desktop native, web export later | User preference; Godot exports both |
| Engine | Godot 4 (GDScript) | Full 2D toolkit, all-text project, headless testing, most game per session |
| Art | 0x72 Dungeon Tileset II (CC0, 16x16) for the slice; generated sprites for 1.0 | Looks like a game on day one, distinct identity later |
| First target | Single-room wave arena | Nail combat feel before dungeon structure |

Alternatives considered: Bevy/Rust (ECS fits roguelikes, but slow compiles and heavy plumbing), LOVE/Pygame-CE (instant reload, but rebuilds what an engine provides).

## The game

Top-down arena. WASD to move, mouse to aim, click to shoot. Enemies arrive in escalating waves. Clear a wave, choose one of three upgrades, continue until death. Death shows a run summary; restart is one keypress. Rooms, doors, floors, and bosses come after the arena feels good.

## Fun thesis, in priority order

1. Game feel first. Hit-flash, knockback, hitstop on kills, scaled screen shake, muzzle flash, death particles, punchy sound. Movement uses acceleration and friction. Milestone 1 does not close until the user says shooting feels good.
2. Readable enemies with distinct verbs. Slice ships two: Chaser (rushes) and Shooter (keeps distance, fires slow dodgeable projectiles). Every attack is telegraphed. Difficulty comes from mixing types and counts.
3. Upgrades that combine. Stat bumps plus behavior modifiers (multishot, pierce, bounce, size, homing) stacked as a modifier list on the weapon. Combinations produce unplanned builds.
4. Short runs, fast restart. Runs last minutes. Seeded RNG makes runs replayable.
5. Tuning loop. All numbers live in data files. Balancing is editing, playing, editing.

## Architecture

### Layout

```
project.godot
scenes/        main, arena, player, enemies/, projectiles/, ui/
scripts/       one .gd per scene plus shared base classes
data/          enemy stats, weapon defs, upgrades, wave tables (.tres)
assets/        0x72 tileset, fonts, sfx
tests/         gdUnit4 unit and scene tests
tools/         headless screenshot and smoke-test scripts
docs/plans/    design and implementation docs
```

### Scene tree

Main -> Game -> Arena. Arena holds the TileMap, Player, Spawner, and containers for enemies and projectiles. HUD is a CanvasLayer (HP, wave, score). UpgradeMenu pauses the tree and shows three cards.

Player and enemies are CharacterBody2D. Projectiles are Area2D. Physics layers: player, enemies, player_shots, enemy_shots, walls. Collisions are declared by layer/mask, not filtered in code.

### Autoloads

- Events: signal bus (enemy_died, player_hit, wave_cleared, upgrade_chosen). Systems do not hold references to each other.
- RunState: seed, RNG, score, wave number, chosen upgrades.
- Juice: screen shake, hitstop, hit-flash. One tunable place for all impact feedback.

### Data model

Custom Resource classes: EnemyDef, WeaponDef, Upgrade, WaveTable. An Upgrade is a list of modifiers. The weapon folds its modifier list at fire time to compute damage, projectile count, spread, pierce, bounce, homing. Adding content means adding a .tres file.

### Enemy AI

Small state machine per enemy: idle, telegraph, act, recover. Driven by EnemyDef. Chaser and Shooter differ only in their act behavior. Future enemies reuse the skeleton.

### Error handling

Missing resources fail at load. Resource data is validated on load (no zero HP, no negative fire rate). Godot errors from headless runs are test failures.

## Testing and verification

- gdUnit4 runs headless from the CLI.
- Unit tests: modifier folding, damage calc, wave table progression, seeded RNG determinism, enemy state transitions.
- Smoke test: boot the arena headless, simulate a few hundred frames of scripted input, assert no errors, write a PNG for visual inspection after every milestone.
- Feel is verified by the user playing a build at the end of each milestone.

## Milestones

| # | Deliverable | Done when |
|---|---|---|
| 0 | Godot installed, project scaffolded, arena renders, player moves | Screenshot shows hero on tiles; tests run headless |
| 1 | Shooting, Chaser enemy, full juice pass | User plays it and says shooting feels good |
| 2 | Shooter enemy, waves, HP, death, restart, HUD | A run has a beginning and an end |
| 3 | Upgrade picker, eight upgrades, at least three that combine | User finds a build they like |
| 4 | Sound, particles, run summary, balance pass | A vertical slice worth showing a friend |

After the slice, in rough order: rooms and doors, multiple floors, a boss, pickups, then the shift to generated art.
