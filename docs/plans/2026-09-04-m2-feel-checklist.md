# Milestone 2 feel checklist

Play a full run (win or die), then rate each line good / meh / bad with a note. The milestone
closes when a run has a beginning and an end that feel right.

- Shooter: can you always tell a bolt is coming? Is the bolt dodgeable at 120 px/s? Do two shooters firing in lockstep feel unfair? (telegraph_time, recover_time (fire cadence, and what two shooters lock to), preferred_range in data/enemies/shooter.tres; projectile_speed in data/weapons/shaman_bolt.tres)
- Dash: does it get you out of a pin and past bolts? Cooldown too long or too short? (DashRules in scripts/dash_rules.gd)
- Wave pacing per room: breathers, group sizes, the room 4 crowd. (data/waves/*.tres; SPAWN_INTERVAL in scripts/wave_progress.gd)
- Room size at one screen: enough space to kite, or cramped? (RoomDef width/height in data/rooms/*.tres)
- Door and transition: does the fade read as moving on? Is the entry position right? (FADE_TIME in scripts/main.gd for the fade; Room.entry_position() in scripts/room.gd for the entry)
- Heart reward: worth walking to? Two hp right? Walking onto it heals; a full player standing on it when hit has to step off and back on. Fair? (HEAL in scripts/heart_pickup.gd)
- HUD: legible at a glance, in the way of anything? (scenes/ui/hud.tscn)
- Summary: the right numbers, the right beat before it shows? (DEATH_SUMMARY_DELAY, WIN_SUMMARY_DELAY in scripts/main.gd)
- A full run: how long did it take, and did it end the way you expected?

## Verdict, playtest 1 (2026-09-07)

The user played a full run. Verdict: "gameplay is satisfying, and has potential for introducing more mechanics and more difficulty." Milestone 2 closed on it (tag `m2`).

| Line | Rating | Note |
|---|---|---|
| Difficulty overall | easy, accepted | never needed the dash. Fine for the first few rooms; difficulty comes with later mechanics and rooms, not from tuning these numbers now |
| Shooter, dash, wave pacing, room size, HUD, summary | not flagged | nothing to tune before moving on |
| Heart reward | too generous | one heart per room; to be fixed by other rewards (weapons, upgrades) rather than by removing it now |
| Doors | bad | three things: the bottom entry door reuses the front-facing facade and reads wrong; the 32 px leaf hangs over the first floor row instead of sitting in the wall; the side pillars and door width look off next to the 16 px wall |
| 1.0 notes | | rooms should not all be rectangles, and rooms should be able to have more than one exit |

### Next pass, in order

1. Doors: done on 2026-09-07. The top wall is now a two-row band (`wall_top_*` ledge over `wall_mid` face with `wall_left`/`wall_right` ends), the exit door's 32 px frame and leaf sit flush in that band over unpainted gap cells, and the bottom entry is a facade-free unpainted opening with the face wall ending in shaded `wall_right`/`wall_left` pieces; the floor is 26 by 12 (bounds `(16, 32, 416, 192)`), the camera limits come from `Room.full_rect()`, and the openings show the clear colour, which project.godot now sets to black, so they read as dark passages.
2. Rewards: the Milestone 3 upgrade picker takes the room-clear moment; the heart becomes one of several rewards or drops less often.
3. Room shapes and multiple exits: design work for the rooms-and-floors milestone after the slice; `RoomDef` (size only) and `Door` (top or bottom) are the seams to widen.

### Replay 2 (2026-09-07), after the door pass

Two changes from the user's replay. The entry opening confused: a room entered from the bottom showed a dark opening that could not be used (its collider is closed), so now it shows for a beat after arriving (`ENTRY_SEAL_DELAY` 0.4 s in scripts/main.gd), then bricks up with `wall_mid` and a dust puff (`Arena.seal`, `Room.seal_entry`, `Events.door_sealed`), reading as closed behind you. Chasers were too slow for the dash to matter, so `speed` in data/enemies/chaser.tres went from 72 to 110 px/s, the player's `MAX_SPEED`; accel unchanged.

Replay 2's changes were not rated separately; the user moved to the Milestone 3 handoff on 2026-09-08, so they are judged in the Milestone 3 playtest.
