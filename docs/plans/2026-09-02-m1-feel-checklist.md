# Milestone 1 feel checklist

Play for five minutes, then rate each line: good / meh / bad, with a note.
The milestone closes when shooting is "good".

- Movement: does the hero feel responsive but weighty? (MAX_SPEED, ACCEL, FRICTION in scripts/player.gd)
- Run animation: does it match the movement speed? (fps argument of SpriteAtlas.frames, MOVING_THRESHOLD in scripts/movement.gd)
- Shooting cadence: too slow, too fast? (fire_rate in data/weapons/pistol.tres)
- Shot impact: can you feel each hit? White flash, sparks, knockback. (HIT_TRAUMA in scripts/enemy.gd, FLASH_DURATION in scripts/autoload/juice.gd, knockback in pistol.tres)
- Kill impact: is a kill satisfying? The imp holds a white pose for a 0.06 s freeze, then bursts. (DEATH_TRAUMA, DEATH_HITSTOP in scripts/enemy.gd, death burst in scripts/fx.gd)
- Screen shake: enough, too much, nauseating? Hits are subtle, kills thump. (MAX_SHAKE in scripts/camera.gd, TRAUMA_DECAY in juice.gd)
- Recoil: the pistol nudges you back a hair per shot; want more? (recoil in pistol.tres)
- Getting hit: the 0.09 s freeze and 0.7 trauma are heavier than a kill. Does it read as "I got hit" rather than "the game hitched"? (HIT_TRAUMA, HIT_HITSTOP in scripts/player.gd)
- I-frames and blink: 0.8 s of invulnerability with a 10 Hz blink; readable, or flicker? Standing on one imp costs 6 hp in about 5 s. (INVULN_TIME in player.gd, BLINK_PERIOD in scripts/player_hit_rules.gd)
- Being surrounded: enemies pass through you, so you can walk out of a swarm during the blink. Does that feel fair, or should bodies be solid? (player collision_mask in scenes/player.tscn)
- Chaser: readable, dodgeable, fair? Half a second of fade-in before it can move or hurt. (speed, accel, spawn_delay in data/enemies/chaser.tres)
- Spawn pacing: boring early, overwhelming late? Starts one every 1.6 s, ramps to 0.45 s over 90 s, max 14 alive. (interval_start, interval_min, ramp_seconds, max_alive in scripts/spawner.gd)
- Camera: the view leans a little toward your aim. Helpful or disorienting? The room is exactly one screen wide, so the lean is small. (MAX_LEAN, LEAN_FACTOR in scripts/camera.gd)
- Death: 0.25 s freeze, a blue burst, one second of stillness, then a fresh run. Pressing R during that second restarts at once. Acceptable as the Milestone 1 contract? (RESTART_DELAY in scripts/main.gd)
