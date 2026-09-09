# Milestone 3 pre-work notes

For the session that brainstorms and plans Milestone 3. Written 2026-09-08 at the Milestone 2 close. Read `docs/STATUS.md` first, then this, then start the brainstorm.

## The brief, from the design doc

Milestone 3: "Upgrade picker, eight upgrades, at least three that combine. Done when: the user finds a build they like." The design's fun thesis, item 3: "Upgrades that combine. Stat bumps plus behavior modifiers (multishot, pierce, bounce, size, homing) stacked as a modifier list on the weapon. Combinations produce unplanned builds." The data model: "An Upgrade is a list of modifiers. The weapon folds its modifier list at fire time to compute damage, projectile count, spread, pierce, bounce, homing. Adding content means adding a .tres file." The scene tree note: "UpgradeMenu pauses the tree and shows three cards."

## What the user has said that shapes it

- The game is easy in the first rooms and that is fine for now; difficulty comes from later mechanics and rooms, not from tuning the M2 numbers. The dash exists to matter once chasers run at player speed (they do since replay 2).
- One heart per room is too generous, to be fixed by introducing other rewards (weapons, upgrades), not by removing the heart now. So the room-clear moment becomes a choice, and the heart is one option among several or drops less often.
- Weapons and classes (guns, bows, melee) are wanted eventually. `WeaponDef` plus `FireController` covers guns and bows; melee needs a different attack path. Keep the player's attack behind one call so a `WeaponDef.kind` can pick the path later; do not build melee in M3 unless the brainstorm chooses it.
- The user supplies art, sound, and music files on request. If an upgrade card needs an icon the tileset lacks, ask for the sprite (size, count) rather than drawing a placeholder; sound and music are Milestone 4.
- For 1.0: rooms that are not rectangles, and rooms with more than one exit. Not M3 work; do not widen `RoomDef` or `Door` for it yet.

## Where the hooks are

- The reward moment: `Main._on_room_cleared` (`scripts/main.gd`). Today it increments `RunState.rooms_cleared`, calls `_win()` on the last room, else opens the exit, sets `room_open`, and drops the heart through `_drop_heart.call_deferred(room)`. The picker slots in here. Lifetime rule: `room_cleared` arrives from inside a physics callback (a shot's `body_entered`), so showing the menu must be deferred like the heart drop, and freeing or adding physics nodes from a card's effect must be too.
- Pausing: `Juice.hitstop` drives `Engine.time_scale`; the fade and summary timers are real time (`create_timer(t, true, false, true)`). A `get_tree().paused = true` menu needs `process_mode` set on the menu's CanvasLayer (and on Juice if its timers must keep running, or reset Juice before pausing). Decide in the brainstorm whether the picker pauses the tree (design doc says yes) or simply runs in the cleared room with the exit shut until a card is taken (no pause plumbing, enemies are dead anyway, bolts in flight can still hit). The second is cheaper and fits "clear, choose, go".
- The weapon: `Player._ready` duplicates `weapon` (`WeaponDef`) so upgrades mutate the copy. `Player._shoot` reads `fire_rate`, `projectile_count`, `spread_degrees`, `inaccuracy_degrees`, `recoil`; `Projectile.setup(def, dir)` reads `projectile_speed`, `damage`, `knockback`, `pierce`, `lifetime`. `WeaponDef.spread_offsets(count, spread)` fans multishot. `WeaponDef.validate` does not reject negative `pierce`, `knockback`, `spread_degrees`, `inaccuracy_degrees`; fix that when upgrades start writing these.
- Projectiles move by teleport (`position += direction * speed * delta`); above about 480 px/s they can tunnel through r 5 enemies. A speed upgrade needs a raycast from the previous position first.
- Modifiers that need new projectile behavior: bounce (walls despawn shots today, `Projectile._on_body_entered`), homing (no steering), size (the `_draw` circle and the r 3 shape). Pierce exists. Multishot exists through `projectile_count` and `spread_degrees`.
- Randomness for the offered cards: use `RunState.stream("upgrades")` (or key it by room like the spawner: `"upgrades:%d" % RunState.room`) so a seed replays the same offers. `RunState` has `seed_value`, `rng`, `score` (accumulated, shown nowhere), `kills`, `elapsed`, `room`, `wave`, `rooms_cleared`, `rooms_total`; `start_run` resets all but `rooms_total`. The design wants `chosen upgrades` on RunState and `upgrade_chosen` on the bus.
- HUD: `scripts/ui/hud.gd`, CanvasLayer 1; Fade 20; Summary 30. A picker layer fits at 10 (over the HUD, under the fade) if it should be covered by a transition, or 25 if it must show over a black fade. Labels use the default font at 22 to 56 px; tileset hearts are drawn at 3x with `expand_mode = EXPAND_IGNORE_SIZE` (containers reset child `scale`).
- Input: actions are `move_*`, `shoot`, `dash`, `restart`. The picker needs mouse clicks on cards or number keys; the mouse is free (no capture) and `aim_override` exists for tests and the smoke tool.
- Rooms: `Room` owns the heart it drops (a child), so anything spawned into the room dies with it. `RunState.room` is set before `add_child(room)`, so per-room seeding works in `_ready`.
- Tests: every scene test extends `SceneSuite` (`tests/support/scene_suite.gd`: `quiet_main`, `quiet_main_with_floor`, `tiny_floor`, `ticks`, `real_seconds`, `wait_for_death_freeze`, `active_chaser_on`, `active_shooter_on`, `enemies_of`, `projectiles_of`). Emit `Events.room_cleared` from a test to reach the reward moment; `test_floor_scene.gd` shows the pattern and also clears a room with a real shot to prove the deferred path. The smoke tool has `room` (clears a one-chaser room and walks through the door on `tools/smoke_floor.tres`); a picker changes that scenario: it must choose a card before walking, or the smoke floor must skip the picker.

## Carried over from the Milestone 2 notes (still open)

- Juice scene tests use real-time waits; make the Juice clock injectable or accept the margins.
- `run_state.gd` header still claims placement depends only on seed and time; `SpawnMath.pick_position` consumes a player-position-dependent number of draws (replay with identical input still works).
- `juice.gd` header says every feel number lives there; they do not (see CLAUDE.md's feel-constants bullet). Fix the comment or fold them into `data/feel.tres`.
- `Juice.flash` and `MuzzleFlash` tweens run in scaled time; a hit flash during another enemy's kill freeze lingers.
- `Enemy._ready` rebuilds `SpriteFrames` per spawn; cache per `def.id` if wave counts grow.
- `WeaponDef.validate` negatives and projectile tunneling (above), both relevant the moment upgrades exist.
- The stuck-movement-key investigation (M2 notes, "Open: stuck movement key") has not recurred since fullscreen.

## Small things noticed in the Milestone 2 reviews, none urgent

- A shooter parked in range fires every 1.3 s with no repositioning; two in range fire in lockstep once synchronised. The user did not flag it; a random jitter on `recover_time` is the cheap fix if it ever reads as unfair.
- `fire_rate` in `data/weapons/shaman_bolt.tres` is inert (`ShooterBrain` owns the cadence) but `WeaponDef.validate` requires it > 0.
- After death, live chasers cluster on the corpse under the summary dim; cosmetic.
- `RunState.elapsed` keeps ticking after the ending, so the summary's time is 0.6 s or 1.0 s later than the `RUN_OVER`/`RUN_WON` line; cosmetic.
- `Arena._ready` builds a default room and `Room._ready` rebuilds it with doors: 420 cells painted twice per room; harmless.
- `Arena.seal` erases the side from `door_sides`; a later `build` with the original sides would reopen the gap visually (nothing does this).
- The entry-seal dust puff lives 0.3 s and may be missed; `fx.gd` is the knob.

## Process that worked, to repeat

1. `superpowers:brainstorming`: one question at a time, then 2 or 3 approaches with a recommendation, then the design in sections approved one by one, saved as `docs/plans/<date>-milestone-3-design.md` and committed.
2. `superpowers:writing-plans`: bite-sized TDD tasks with complete code, saved as `docs/plans/<date>-milestone-3.md`. Verify any risky engine detail with a throwaway probe before writing it into the plan (the M2 plan did this for the typed-array `.tres` syntax; reviews later found `assert_rect` does not exist, exported enums need the qualified type, containers reset child scale, a ShaderMaterial uniform must be set before it can be tweened).
3. `superpowers:subagent-driven-development`: one implementer per task with the full task text pasted in, then a spec reviewer, then `superpowers:code-reviewer`, fixes re-reviewed, the plan re-synced with every deviation. Work goes directly on `main`, one commit per task plus a commit per review fix; tag `m3-candidate` at the end, `m3` on the playtest verdict.
4. The milestone closes only on the user's playtest against a feel checklist written in the last task; a balance pass follows, one concern per commit.
