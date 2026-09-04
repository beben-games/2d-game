# Milestone 2 pre-work notes

Findings from the final review of the Milestone 1 candidate (tag `m1-candidate`). None block the playtest. Do these before or as part of the Milestone 2 plan.

## Should fix

- Juice scene tests use real-time waits (`tests/test_juice_scene.gd`); make the Juice clock injectable (a `_now_usec()` override or a `clock: Callable`) so those tests advance time deterministically, or widen the margins.
- Camera limits in `scenes/player.tscn` duplicate the arena size; set `camera.limit_*` in `Main._ready` from `arena.bounds()` grown by one tile. Rooms need this anyway.
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
- Run summary: `Main._on_player_died` is the hook; the auto-restart timer becomes "show summary, wait for R"; `restart_requested` lets harnesses observe it.
