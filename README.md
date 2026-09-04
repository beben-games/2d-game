# Arena Roguelike

A top-down real-time action roguelike built in Godot 4.7 as a Claude Code experiment.
Design: `docs/plans/2026-09-02-action-roguelike-design.md`. Plan for Milestones 0 and 1: `docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.

## Play

```bash
source tools/godot.sh && "$GODOT_BIN" --path .
```

WASD to move, mouse to aim, left click to shoot, R to restart. Enemies pass through you; only touching hurts, and you blink invulnerable for a moment after each hit. Dying restarts the run after a second. There is no HUD, sound, or run summary yet (those are Milestone 2 and later).

## Develop

- `tools/test.sh` runs all gdUnit4 suites headless (exit 0 on pass, 100 on failures, 105 on script errors; fails if no tests are found).
- `tools/check_boot.sh` boots the main scene headless and fails on any Godot error or warning.
- `tools/smoke.sh [idle|move|combat]` boots the game windowed with scripted input for a second or two and saves `reports/smoke_<scenario>.png` plus machine-readable `SMOKE_` lines.
- `tools/gen_atlas.py` regenerates `data/atlas.json` from the tileset's tile list; sprites are looked up by name through `SpriteAtlas`.
- Tuning numbers live in `data/` (weapons, enemies), `scripts/autoload/juice.gd` and the trauma/hitstop consts in `scripts/enemy.gd` and `scripts/player.gd` (feel), `scripts/spawner.gd` exports (pacing), and `scripts/camera.gd` (lean, shake).

## Assets

0x72 Dungeon Tileset II (CC0), see `assets/dungeon_tileset_ii/README.md`.
