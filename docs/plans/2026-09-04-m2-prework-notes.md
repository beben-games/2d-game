# Milestone 2 pre-work notes

Findings from the final review of the Milestone 1 candidate (tag `m1-candidate`). None block the playtest. Do these before or as part of the Milestone 2 plan.

## Should fix

- Juice scene tests use real-time waits (`tests/test_juice_scene.gd`); make the Juice clock injectable (a `_now_usec()` override or a `clock: Callable`) so those tests advance time deterministically, or widen the margins.
- Done in the M1 tuning pass: camera limits come from `arena.bounds()` grown by one tile in `Main._apply_camera_limits`; rooms call it per room.
- `Spawner` preloads the Chaser scene; change `spawn_one()` to `spawn(scene: PackedScene, at: Vector2)` before wave tables arrive. Fix the `run_state.gd` header: `SpawnMath.pick_position` consumes a player-position-dependent number of draws, so placement depends on the player's path, not only on seed and time (replay with identical input still works).
- Test helpers are duplicated (`_ticks`, `_wait_for_death_freeze`, "instantiate main, disable spawner") across six suites, and `RunState` reset hygiene is inconsistent; add a `tests/support/` helper or base suite with `ticks`, `real_seconds`, `quiet_main`, `wait_for_death_freeze`, and a shared `after_test` that resets `Juice` and `RunState`.
- Smoke tool: add a deterministic `kill` scenario (chaser at player + (80, 0), aim there, 90 ticks, require `SMOKE_KILLS 1`) and a 30 s watchdog that quits with code 3. Note the real `reload_current_scene` path is exercised only by pressing R or dying in a real run.

## Minor

- `scripts/autoload/juice.gd` header says every feel number lives there; hit/death trauma and hitstop live in `enemy.gd` and `player.gd`, `MAX_SHAKE` in `camera.gd`, blink in `player_hit_rules.gd`. Fix the comment or fold them into a `data/feel.tres`.
- No way to supply a seed; parse a `--seed=` user arg in `Main._ready` so `RUN_OVER` seeds are replayable in bug reports.
- `Juice.flash` and `MuzzleFlash` tweens run in scaled time, so a hit flash during another enemy's kill freeze lingers; decide deliberately (`Tween.set_ignore_time_scale(true)`).
- Projectiles move by teleport; a speed upgrade above about 480 px/s can tunnel through r 5 enemies. Raycast from the previous position when M3 adds speed upgrades.
- `WeaponDef.validate` does not reject negative `pierce`, `knockback`, `spread_degrees`, `inaccuracy_degrees`.
- `Enemy._ready` rebuilds `SpriteFrames` per spawn; cache per `def.id` when waves push counts up.

## Design hooks already in place

- HUD: `player_hit(damage, hp, max_hp)` fires only on hits; the HUD needs an initial read or an `Events.run_started` signal.
- Waves: `alive_count()` lags by the 0.06 s death freeze, so count `enemy_died` against spawned rather than waiting for `_alive == 0`; add `wave_cleared` to `Events` and `wave` to `RunState`.
- Shooter: extract the ACTIVE body of `enemy.gd` into a behavior selected by `EnemyDef` so telegraph/act/recover states slot in; `is_harmful()` is the hook for harmless telegraph states.
- Enemy projectiles: layer 8 with mask 16; add 8 to the hurtbox mask and extend `_check_contact` with `get_overlapping_areas()` calling `Player.hurt()`.
- Run summary: `Main._on_player_died` is the hook; since the M1 tuning pass it only disables the spawner and prints `RUN_OVER`, and the game idles until R, so the summary is drawn over that idle state; `restart_requested` lets harnesses observe the restart.

## Open: stuck movement key during the playtest (2026-09-04)

Symptom: the knight kept moving right and A could not move it left (a stuck `move_right` action; A only cancels it). Investigated with `tools/input_probe.sh`. Ruled out: our code (nothing presses actions; the player stops without input), scene reload and `Juice.reset()` (a held key survives them), app or window focus loss (Godot 4.7 releases all keys on focus loss), Cmd-modified key-ups, the macOS accent popup (Godot only routes keys through text input when a text field is active).

Best-supported cause: macOS title-bar window drags run a modal loop that discards keyboard events. In two probe runs, key repeats stopped the moment a drag began and never arrived afterwards, and a D released mid-drag left the action pressed. Mission Control also opens with no focus notification to the game, so overlays are a second candidate. Not fully closed: the final confirmation run (drop the window, then observe the state) was not done.

If it recurs, the fix sketch is: an autoload that releases movement actions on `NOTIFICATION_WM_WINDOW_FOCUS_OUT` and window position/size changes, plus a watchdog that releases an action whose key has produced no press or repeat event for about a second (arm it only after at least one repeat has been observed, so machines with key repeat off are unaffected; this Mac repeats every 83 ms after a 0.5 s delay). Confining the mouse to the window during play would also prevent accidental drags and hot corners.

## Design hooks from the playtest 2 feedback (2026-09-04)

The full ratings are in `docs/plans/2026-09-02-m1-feel-checklist.md`. These are the parts that shape Milestone 2 and later rather than the M1 tuning pass.

- **Dash or dodge through enemies.** The user chose solid enemy bodies partly to make room for this. Milestone 2 scope: a short dash on a key or right click with a cooldown, during which the player body ignores the enemy layer (mask back to walls only) and, probably, takes no contact damage. Design it against being pinned: the hit knockback is the M1 escape, the dash is the intended one.
- **Weapons and classes later.** The pistol goes to 5 shots/s for now; the user wants the option of more deliberate weapons and other archetypes (bows, melee). `WeaponDef` plus `FireController` covers guns and bows; melee needs a different attack path (an arc hitbox, not a projectile). Keep the player's attack behind one call so a `WeaponDef.kind` can pick the path when this arrives, likely with the upgrade work in Milestone 3 or after rooms.
- **Finite spawns per room.** The endless ramp in `Spawner` is a placeholder the user does not want tuned. Wave tables in Milestone 2 should already be finite lists (count per wave, clear condition) so rooms can reuse them.
- **Death.** M1 tuning makes death wait for R with no auto-restart. The Milestone 2 run summary is drawn over that idle state; `Main._on_player_died` no longer owns a timer.
- **Camera limits from the arena** moved into the M1 tuning pass (needed as soon as the view is smaller than the room at 3x zoom). Strike it from the should-fix list above when it lands.

## Rooms as single screens (raised at the M1 close, 2026-09-04)

The design doc already schedules rooms and doors after the slice. The user asked whether each room should be exactly one screen, Binding of Isaac style. Recommendation: yes. It fits the design's "readable enemies" principle (every enemy is on screen from the moment it spawns, so telegraphs always land), it pairs with finite spawns per room, and it removes camera scrolling as a source of surprise. Trade-off: less room to kite chasers, so the dash matters more, and large set pieces (a boss) need a bigger room with the scrolling camera the arena already has.

What it means in code, none of it urgent: `Arena.WIDTH`/`HEIGHT` become per-room parameters; `Main._apply_camera_limits` already pins the camera when the room equals the view (the lean clamps to zero on its own, as it did at 2x); the view at 3x is 426.7 x 240 world px, so a one-screen room is 26 x 15 tiles of 16 px with about 10 px of slack in width (either accept it, or pick a zoom or viewport that makes the width a whole number of tiles). Decide during Milestone 2 planning: wave tables should be authored for the room size they will run in, and shrinking the arena to one screen before Milestone 2 is a small change.
