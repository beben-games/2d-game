# Arena Roguelike

A top-down real-time action roguelike built in Godot 4.7 as a Claude Code experiment.
Status and next steps: `docs/STATUS.md`. Design: `docs/plans/2026-09-02-action-roguelike-design.md`. Plans: `docs/plans/2026-09-02-arena-roguelike-m0-m1.md` (Milestones 0 and 1) and `docs/plans/2026-09-04-milestone-2.md` (Milestone 2). Conventions for Claude sessions: `CLAUDE.md`.

## Play

```bash
source tools/godot.sh && "$GODOT_BIN" --path .                 # a fresh run
source tools/godot.sh && "$GODOT_BIN" --path . -- --seed=N     # replay the run with seed N (printed on the summary)
```

WASD to move, mouse to aim, left click to shoot, Space or right click to dash, R to restart.

A run is one floor of four single-screen rooms. Clear the room's waves, take the heart that drops in the middle, and walk through the door that opens at the top. Imps chase and hurt on touch; shamans wind up a visible telegraph and fire a bolt you can sidestep or dash through. Enemies are solid: the dash passes through them, and the knockback after a hit is the other way out of a pin. Dying, or clearing the last room, shows a summary (rooms, kills, time, seed) and waits for R. There is no sound yet.

## Develop

- `tools/test.sh` runs all gdUnit4 suites headless (exit 0 on pass, 100 on failures, 105 on script errors; fails if no tests are found).
- `tools/check_boot.sh` boots the main scene headless and fails on any Godot error or warning.
- `tools/smoke.sh [idle|move|combat|kill|room|death]` boots the game windowed with scripted input for a few seconds and saves `reports/smoke_<scenario>.png` plus machine-readable `SMOKE_` lines; `kill`, `room`, and `death` assert on a kill, a room transition, and the death summary, and a 30 s in-process watchdog makes smoke.sh report `watchdog: scenario hung`.
- `tools/input_probe.sh [seconds]` logs raw key, mouse, and focus events to diagnose stuck keys.
- `tools/gen_atlas.py` regenerates `data/atlas.json` from the tileset's tile list; sprites are looked up by name through `SpriteAtlas`.
- Tuning numbers live in `data/` (weapons, enemies, waves, rooms, the floor), `scripts/dash_rules.gd` (dash), `scripts/autoload/juice.gd` and the trauma/hitstop consts in `scripts/enemy.gd` and `scripts/player.gd` (feel), `scripts/main.gd` (fade and summary delays), and `scripts/camera.gd` (lean, shake). `docs/plans/2026-09-04-m2-feel-checklist.md` maps each playtest question to its number.

## Assets

0x72 Dungeon Tileset II (CC0), see `assets/dungeon_tileset_ii/README.md`.
