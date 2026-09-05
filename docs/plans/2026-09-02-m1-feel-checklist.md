# Milestone 1 feel checklist

Play for five minutes, then rate each line: good / meh / bad, with a note.
The milestone closes when shooting is "good".

- Movement: does the hero feel responsive but weighty? (MAX_SPEED, ACCEL, FRICTION in scripts/player.gd)
- Run animation: does it match the movement speed? (fps argument of SpriteAtlas.frames, MOVING_THRESHOLD in scripts/movement.gd)
- Shooting cadence: too slow, too fast? 5 shots per second since playtest 2, down from 7. (fire_rate in data/weapons/pistol.tres)
- Shot impact: can you feel each hit? White flash, sparks, knockback. (HIT_TRAUMA in scripts/enemy.gd, FLASH_DURATION in scripts/autoload/juice.gd, knockback in pistol.tres)
- Kill impact: is a kill satisfying? The imp holds a white pose for a 0.06 s freeze, then bursts. (DEATH_TRAUMA, DEATH_HITSTOP in scripts/enemy.gd, death burst in scripts/fx.gd)
- Screen shake: enough, too much, nauseating? Hits are subtle, kills thump. (MAX_SHAKE in scripts/camera.gd, TRAUMA_DECAY in juice.gd)
- Recoil: the pistol nudges you back a hair per shot; want more? (recoil in pistol.tres)
- Getting hit: the 0.09 s freeze and 0.7 trauma are heavier than a kill. Does it read as "I got hit" rather than "the game hitched"? (HIT_TRAUMA, HIT_HITSTOP in scripts/player.gd)
- I-frames and blink: 0.8 s of invulnerability with a 10 Hz blink, counted in real time through freezes; readable, or flicker? Standing on one imp costs 6 hp in about 5 s. (INVULN_TIME in player.gd, BLINK_PERIOD in scripts/player_hit_rules.gd)
- Being surrounded: enemies pass through you, so you can walk out of a swarm during the blink. Does that feel fair, or should bodies be solid? (player collision_mask in scenes/player.tscn)
- Chaser: readable, dodgeable, fair? Half a second of fade-in before it can move or hurt. (speed, accel, spawn_delay in data/enemies/chaser.tres)
- Spawn pacing: boring early, overwhelming late? Starts one every 1.6 s, ramps to 0.45 s over 90 s, max 14 alive. (interval_start, interval_min, ramp_seconds, max_alive in scripts/spawner.gd)
- Camera: the view leans a little toward your aim. Helpful or disorienting? The room is exactly one screen wide, so the lean is small. (MAX_LEAN, LEAN_FACTOR in scripts/camera.gd)
- Death: 0.25 s freeze, a blue burst, one second of stillness, then a fresh run. Pressing R during that second restarts at once. Acceptable as the Milestone 1 contract? (RESTART_DELAY in scripts/main.gd)

## Verdict, playtest 2 (2026-09-04)

Ratings the user gave line by line. Milestone 1 closes after the tuning pass below and a replay.

| Line | Rating | Note |
|---|---|---|
| Movement | good | |
| Run animation | not judged | sprites are too small to see; the knight is 32 px tall at 2x zoom in a small window |
| Shooting cadence | too fast | 7/s; go to 5/s for now. Later weapons and classes (guns, bows, melee) may want a more deliberate rate |
| Shot impact | good | |
| Kill impact | good | |
| Screen shake | good | |
| Recoil | good | |
| Getting hit | good | reads as damage, not a hitch |
| I-frames and blink | readable, too long | feels longer than 0.8 s. Confirmed in code: `invuln_left` counts scaled physics delta, so the 0.09 s hit freeze and every 0.06 s kill freeze inside the window pause it |
| Being surrounded | make bodies solid | solid bodies scale difficulty better and leave room for a dash or dodge through enemies. Hit knockback becomes the escape; dash comes in Milestone 2 |
| Chaser | good | |
| Spawn pacing | decent, not a target | the final game has rooms and probably finite spawns per room; do not tune the endless ramp |
| Camera | good | |
| Death | meh | auto-restart after one second is wrong; freeze on the corpse and wait for R. The summary stays in Milestone 2 |
| Verdict | close after tuning | |

### Tuning pass to close Milestone 1

One concern per commit. After each: `tools/test.sh`, `tools/check_boot.sh`, `tools/smoke.sh combat`, and read the PNG.

1. **Zoom 3x and fullscreen.** `zoom = Vector2(3, 3)` on the camera in `scenes/player.tscn`; `display/window/size/mode=2` (fullscreen) in `project.godot`. At 3x the view is about 427x240 world px against a 640x368 room, so the camera now scrolls and the limits matter: move them out of `player.tscn` into `Main._ready` from `arena.bounds()` grown by one tile (the Milestone 2 should-fix, pulled forward). `tools/smoke.sh` passes `--resolution 1280x720`, but the `--windowed` flag does not override the project setting, so `tools/smoke.gd` switches to a 1280x720 window in `_ready` before instancing Main. Done in 3x-zoom commit; the camera lean test needed a smoothing reset because the lean is no longer clamped from the room center. If pixels shimmer at the fullscreen scale, try `display/window/stretch/scale_mode="integer"` and accept the letterbox.
2. **Fire rate 7 to 5** in `data/weapons/pistol.tres`. `test_fire_controller.gd` uses its own rate, so nothing should break; check `tools/smoke.sh combat` still reports kills.
3. **I-frames count real time across freezes.** Done. The first sketch (Juice capturing `Engine.time_scale` at the top of each tick, player dividing delta by it) failed: a freeze that starts between ticks leaves the next tick's delta computed with the old scale, and a probe showed one tick per hitstop with an unscaled delta under the new scale. Physics keeps ticking at its fixed rate through a freeze, so the player now subtracts `Juice.unscaled_physics_delta()` (one over the physics tick rate) per tick. Test: `test_invulnerability_counts_real_time_through_freezes` lands a hit, starts a 0.3 s freeze inside the window, and requires the window to still close at 48 ticks. `INVULN_TIME` stays 0.8 for the replay; shorten to 0.6 only if it still feels long.
4. **Solid enemy bodies.** Player body mask 16 to 18 (walls and enemies), chaser body mask 18 to 19 (add the player) so both sides see each other. The hurtbox is a 5 px circle inside a 6 px body, and the chaser body is 5 px, so pressed bodies sit 11 px apart and the hurtbox would never overlap: grow the hurtbox to about 8 px (or give enemies a contact area) and add a test that a chaser pressed against the player still lands a hit. Replace `test_enemies_pass_through_the_player` with a test that the chaser is held at body distance. Check `HIT_KNOCKBACK` (200) still clears a ring of imps; raise it if you stay pinned. Update the physics-layer line in `CLAUDE.md` (it says the player body mask is walls only) and the design-decision line in `docs/STATUS.md`.
5. **Death waits for R.** Remove the `RESTART_DELAY` timer from `Main._on_player_died`; keep the freeze, burst, and disabled spawner, then idle until `restart`. Update the comment in `test_lethal_damage_emits_player_died_and_stops_spawner`. The Milestone 2 "show summary, wait for R" hook becomes "show summary" only.

### Replay questions

- Run animation at 3x: does it match the ground speed?
- Fullscreen: any shimmer or uneven pixels? Is the letterbox acceptable?
- Camera scroll and lean now that the room is wider than the view: still good?
- 5 shots/s: right, or go further?
- I-frames: right length after the fix?
- Solid bodies: can you get pinned, and does the hit knockback get you out? Is being blocked by imps fun or annoying?
- Death: does freezing until R feel right?
- Overall: does shooting feel good? If yes, tag `m1`.
