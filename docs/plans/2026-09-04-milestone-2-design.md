# Milestone 2 design: rooms, waves, Shooter, dash, HUD, run end

Date: 2026-09-04
Status: Approved (brainstorm with the user after the Milestone 1 close)

Builds on `2026-09-02-action-roguelike-design.md`. Milestone 1 closed at tag `m1` with the verdict "shooting feels good". This milestone gives a run a beginning and an end.

## Decisions

| Question | Decision | Why |
|---|---|---|
| Room shape | One screen, Isaac style, now | Every enemy visible from spawn, telegraphs always read, waves authored for the room they run in |
| Run shape | A chain of four rooms, then a win | Finite waves per room, a reward, a door to the next room; a real ending for the summary. Branching floors and a boss later |
| Reward on clear | Heart pickup | Keeps M2 about structure; the M3 upgrade picker slots into the same moment |
| Dash | 0.15 s burst through bodies, no i-frames | Solid bodies (M1 tuning) need an escape; dodging comes from moving, not invulnerability |
| Spawn placement | Random floor spots with the 0.5 s fade-in | Already tested and seed-driven |
| Shooter | Keeps range, telegraphs 0.5 s, one slow aimed bolt | Simplest readable ranged enemy; first of the family |
| Room architecture | `Room` scene swapped by Main | Enemies and projectiles die with their room, so cleanup is free |

Alternatives considered: rebuilding the arena in place (least churn, but every transition needs hand cleanup); a whole floor laid out at once with a snapping camera (right for branching floors, not for a chain); endless rooms or endless waves (no ending for the summary); dash with i-frames (makes the dash a universal answer to bolts); enemies entering through doors (bunches early waves at one edge).

## Run structure and data

A run is a `FloorDef` resource: an ordered list of `RoomDef`s, four for this milestone (`data/floors/floor_1.tres`). A `RoomDef` holds width and height in tiles, a `WaveTable`, and an exit side. The entry door is on the side opposite the previous room's exit; the first room has no entry door. Clearing a room's last wave drops the heart pickup at the room center and opens the exit door. Stepping through loads the next room. Clearing the last room wins the run; death ends it early. Both show a summary and wait for R.

Room size is 27 by 15 tiles, 432 by 240 world px including the wall ring, floor 25 by 13. The view at 3x is 426.7 by 240, so the camera limits pin it with under 3 px of lean and the outer 2.7 px of each side wall sit off screen.

Resources, each with `validate()` like the existing defs: `WaveTable` (list of `WaveDef`), `WaveDef` (list of `SpawnGroup`, breather seconds before it starts), `SpawnGroup` (enemy scene, count), `RoomDef`, `FloorDef`. Under `data/waves/`, `data/rooms/`, `data/floors/`.

## Room scene and doors

`Room` (Node2D) owns what dies with the room: the tile painter and wall colliders (today's `Arena`, taking width and height from the `RoomDef`), a `Doors` node, the `Enemies` and `Projectiles` containers, the `Spawner`, and a `WaveRunner`. Main keeps the player, the camera, the HUD, the summary overlay, and the floor logic. On transition Main frees the old room, instances the next, applies camera limits from the room bounds grown by one tile (`_apply_camera_limits` from the M1 tuning pass), and places the player one tile inside the entry door. A short fade to black covers the swap.

A door is a wall gap in the middle of a side with the tileset's `doors_frame_*` and `doors_leaf_closed` / `doors_leaf_open` sprites. Closed, the wall collider stays. Open, the collider drops and an `Area2D` past the threshold emits `Events.room_exit_requested`. Only the exit door opens; the entry door stays closed behind the player. No backtracking in this milestone.

## Waves and spawner

`WaveRunner` walks its `WaveTable`. A wave starts after its breather, places its groups one enemy every 0.25 s at seed-driven floor spots at least 96 px from the player, each with the existing fade-in as the telegraph. It counts deaths from `Events.enemy_died` filtered to its room's container, so the kill freeze does not delay the count. When the count reaches the wave's total the next wave starts; after the last wave it emits `Events.room_cleared`.

`Events` gains `wave_started(index, total)`, `room_cleared`, `room_entered(index, total)`, `room_exit_requested`. `RunState` gains `room`, `wave`, `rooms_cleared`. The timed endless ramp leaves `Spawner`; it becomes a placement service with `spawn(scene, at)` and `pick_position()`.

Content: room 1 has two waves of chasers; room 2 introduces one Shooter alone, then chasers plus a Shooter; room 3 mixes with two Shooters; room 4 has three waves ending in a crowd. About 20 enemies per room by the end. Numbers live in the resources and get one balance pass at the playtest.

## Shooter and enemy bolts

Orc shaman sprites. `EnemyDef` gains a `behavior` enum (Chaser, Shooter) and shooter numbers: preferred range 130 px, too-close range 80 px, telegraph 0.5 s, recover 0.8 s, bolt speed 120 px/s, bolt damage 1. `enemy.gd` keeps spawn, death, knockback, and flash; the active state delegates to a behavior object picked by the def. The Chaser behavior is today's chase code moved as is. The Shooter cycles approach (toward until in range, back away if too close), telegraph (stop, pulse the flash shader twice, sprite shivers), fire (one bolt aimed at the player's current position), recover (idle), approach. Telegraph and recover are pure functions of elapsed time. Body contact still hurts like a chaser.

Enemy bolts reuse the `Projectile` script through an `enemy_bolt.tscn` variant on layer 8 with mask 16 (walls), purple tint, 3 s lifetime, no knockback. The player's hurtbox mask adds layer 8; the contact poll also checks overlapping areas, and a bolt calls `Player.hurt(1, bolt.position)` then frees itself. Player shots and bolts never interact, by mask.

## Dash

New `dash` action on Space and right mouse. On press, if off cooldown: 0.15 s at 330 px/s in the move direction, or the aim direction when standing still. During the dash the body mask drops the enemy layer; the hurtbox stays live, so touching still hurts. Cooldown 0.6 s from the start of the dash. Shooting is allowed mid-dash; hit knockback still adds on top. `DashRules` is a pure class like `PlayerHitRules`. A dust puff from the existing particle system marks the start.

## HUD, reward, run end

HUD: a `CanvasLayer` in Main. Top left, tileset hearts, one per 2 hp with half-heart granularity. Top right, "Room 2/4", "Wave 1/3", kills. The heart layout is a pure function of hp and max hp. The HUD reads the player's hp at ready and then follows `player_hit`, `wave_started`, `room_entered`. Drawn at integer scale so the pixel art stays crisp.

Reward: on `room_cleared` a heart pickup appears at the room center with a small pop. Touching heals 2 hp, capped at max, and despawns it; at full hp it stays until you leave. `Area2D` on layer 6 (bit 32) with mask 1 (player body), the first pickup of the family.

Run end: a summary overlay in Main. Death: after the freeze and burst, 0.6 s real time, then "You died" with rooms cleared, kills, time survived, seed. Win: on the last room's `room_cleared` no door opens; after 1 s, "Floor cleared" with the same numbers. Both wait for R, which starts a fresh run with a new seed. A `--seed=N` launch argument replays a seed.

## Testing and tooling

Unit tests without a scene: validation for the five resources; wave progression from synthetic death events; Shooter timing; `DashRules`; heart layout; floor progression (next room, entry side). Scene tests in the real main scene: a bolt hurts through the hurtbox and frees itself; a dash carries the player through a chaser; the pickup heals and caps; the exit door opens on `room_cleared` and not before; stepping through swaps the room and places the player inside the entry door; the win overlay on the last room; the death summary and R restart. Every scene test disables the wave runner right after instancing.

Pre-work items folded in: shared helpers in `tests/support/` (`quiet_main`, `ticks`, `active_chaser_on`, `wait_for_death_freeze`, a base `after_test` resetting Juice and RunState) as the first task; the spawner taking a scene; the `--seed=` argument. The injectable Juice clock stays deferred.

Smoke tool: scenarios `kill` (chaser at 80 px, aim, 90 ticks, one kill required), `room` (one-enemy test floor, kill, walk through the door, screenshot the second room), `death` (hp 1, chaser on top, screenshot the summary), a 30 s watchdog exiting with code 3, and a `tools/smoke_floor.tres` so scenarios never depend on the balance numbers.

## Done when

The user plays a full run to the win or to death and rates a short checklist: Shooter readability, dash usefulness, wave pacing per room, door and transition feel, HUD legibility, summary. One balance pass follows. The milestone closes on that verdict, like Milestone 1.
