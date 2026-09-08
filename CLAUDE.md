# Arena Roguelike: notes for Claude sessions

Start with `docs/STATUS.md` (current state, next steps), then `docs/plans/2026-09-02-action-roguelike-design.md` (the approved design). The M0+M1 plan in `docs/plans/` is the build record.

## Commands

- `tools/test.sh` runs every gdUnit4 suite headless; exit 0 pass, 100 failures, 105 script errors, 1 if no tests found. `tools/test.sh -a res://tests/<file>.gd` runs one suite.
- `tools/check_boot.sh` boots the main scene headless and fails on any `ERROR:`/`WARNING:` line. Godot exits 0 even when the main scene fails to load, so never use its exit code alone.
- `tools/smoke.sh [idle|move|combat]` opens a window for a second or two, drives input in physics ticks, and writes `reports/smoke_<scenario>.png` plus `SMOKE_` lines. Read the PNG to verify visuals.
- `tools/gen_atlas.py` regenerates `data/atlas.json` from the tileset's tile list. Sprites are always looked up by name through `SpriteAtlas`; never hardcode atlas pixel coordinates.
- Godot binary: `source tools/godot.sh` exports `GODOT_BIN` (/Applications/Godot.app/Contents/MacOS/Godot, 4.7.2).

## Conventions

- Commits: no global git identity on this machine. Use `git -c user.name="Benjamin Zigh" -c user.email="78459259+beben-games@users.noreply.github.com" commit` and end messages with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Commit Godot's generated `.uid` and `.import` files. `reports/` and `.godot/` are ignored. Never edit `addons/gdUnit4` (vendored upstream v6.2.1).
- The login shell is zsh; tool scripts are bash and are executed, never sourced.
- Physics layers: 1 player, 2 enemies, 3 player_shots, 4 enemy_shots, 5 walls (bit values 1, 2, 4, 8, 16), 7 player_dashing (bit 64): the player's body layer during a dash; enemies never mask it, the door trigger and pickups mask 65. Player body mask is 18 (walls, enemies), or 16 (walls only) while dashing; enemy bodies 19 (walls, enemies, player), projectiles 18. Enemy bodies are solid; damage reaches the player only through the hurtbox.
- Randomness: shot spread uses `RunState.rng`; systems whose placement must depend only on seed and time use `RunState.stream(name)`; cosmetic effects use the global RNG; the arena floor derives its own RNG from the seed.
- `Events` is the signal bus; nodes that connect to it disconnect in `_exit_tree`. `Player.hurt()` is the only way to damage the player.
- Feel constants live next to what they affect (`juice.gd`, top of `enemy.gd` and `player.gd`, `camera.gd`); data lives in `data/*.tres`.

## Tests

- gdUnit4 with `report/godot/push_error=true`: a `push_error` during a test fails it. Autoloads are live in the runner.
- Scene tests wait on `get_tree().physics_frame`, not wall-clock, so timings are machine-independent. Real-time waits are only for hitstop, which ignores time scale.
- Every test that instances `res://scenes/main.tscn` sets `main.get_node("Spawner").enabled = false` right after `scene_runner`, and every suite that deals damage has `after_test()` calling `Juice.reset()` and `RunState.start_run()`. Never add a second `RunState` to the tree.
- Follow TDD: write the failing test, run it, implement, run again. Run `tools/test.sh` twice before claiming a suite is stable.

## Process

- Milestones close only on the user's playtest verdict. Keep the plan document in sync with every deviation from it.
- Do not downgrade silently when a step needs the user (downloads, logins): put it in the plan as a user action and work around it.
