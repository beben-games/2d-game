# Arena Roguelike M0+M1 Implementation Plan

> **Slimmed 2026-09-24.** Code blocks over 15 lines were replaced by pointers: the committed files are the reference for the code (they always were once a task landed; this plan's own blocks marked "superseded" said as much). The full original is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A playable single-arena build where the player moves, shoots, and fights Chaser enemies with full hit feedback, backed by headless tests and a screenshot smoke tool.

**Architecture:** Godot 4.7 project, all text files. Pure-logic classes (`Movement`, `FireController`, `ArenaGrid`, `SpawnMath`, `JuiceMath`, `Health`, `PlayerHitRules`, `SpriteAtlas`) hold every rule and are unit-tested with gdUnit4. Scenes are thin wrappers that call those classes. Three autoloads (`Events` signal bus, `RunState` seeded RNG and score, `Juice` shake/hitstop/flash) decouple systems.

**Tech Stack:** Godot 4.7.2 (Homebrew cask), GDScript, gdUnit4 v6.2.1, 0x72 Dungeon Tileset II (CC0, animated 16px sprites), macOS arm64.

**Design doc:** `docs/plans/2026-09-02-action-roguelike-design.md`

---

## One manual step for the user (Task 3)

The 0x72 Dungeon Tileset II is only downloadable through itch.io in a browser. Everything else in this plan is automated. **Task 3 needs the user to download the zip** and drop it in `~/Downloads/`. Tasks 1, 2, and 4 do not need the assets, so if the zip is not there yet, do those first and then ask for it.

---

## Conventions used throughout

- `GODOT_BIN` is `/Applications/Godot.app/Contents/MacOS/Godot`. Every script sources `tools/godot.sh` which sets it.
- Run all commands from the project root `/Users/benjaminzigh/Claude/2d-game`.
- gdUnit4 exit codes: `0` pass, `100` failures, `101` warnings, other (e.g. 105) abnormal such as a script parse error. `tools/test.sh` prints the code.
- `tools/check_boot.sh` imports, boots the main scene headless, and fails on any `ERROR:`/`WARNING:` line. Godot exits 0 even when the main scene fails to load, so never use its exit code alone as a gate.
- The login shell is zsh. Tool scripts are `#!/bin/bash` and are executed, never sourced. Do not use `${PIPESTATUS[0]}` in commands typed into the zsh prompt.
- Godot rebuilds its class-name cache only when the editor imports the project. `tools/test.sh` and `tools/smoke.sh` both run `--import` first, so new `class_name` scripts are always picked up. If a test fails with "Identifier not found" for a class you just wrote, that import step did not run.
- Randomness: gameplay draws that may interleave with player input (shot jitter) use `RunState.rng`; systems whose placement must depend only on seed and time use a named stream from `RunState.stream("spawn")`; cosmetic randomness (shake) uses the global RNG; the arena floor derives its own RNG from the seed.
- Sprites are looked up **by name** through `SpriteAtlas` (Task 3), which reads `data/atlas.json`, generated from the tileset's `tile_list` file. Never hardcode pixel coordinates from the atlas in scenes or scripts. Names used: floors `floor_1`..`floor_8`, wall `wall_mid`, player `knight_m_idle_anim` / `knight_m_run_anim`, Chaser `imp_idle_anim` / `imp_run_anim`. Task 3 verifies these names exist and says what to do if one does not.
- Physics layers: 1 player (bit value 1), 2 enemies (2), 3 player_shots (4), 4 enemy_shots (8), 5 walls (16). A mask of 18 means enemies plus walls.
- gdUnit4 test files live in `tests/`, extend `GdUnitTestSuite`, and every test function starts with `test_`.
- Commit after every task with the message given. There is no global git identity on this machine, so each commit uses `-c user.name="Benjamin Zigh" -c user.email="78459259+beben-games@users.noreply.github.com"`. Define this once per shell:

```bash
alias gcommit='git -c user.name="Benjamin Zigh" -c user.email="78459259+beben-games@users.noreply.github.com" commit'
```

---

## Milestone 0: toolchain, scaffold, arena, player movement

### Task 1: Install Godot and create the project skeleton

**Files:**
- Create: `.gitignore`
- Create: `project.godot`
- Create: `scenes/main.tscn`
- Create: `tools/godot.sh`

**Step 1: Install Godot**

Run:
```bash
brew install --cask godot
```
Expected: ends with `godot was successfully installed!`. If macOS refuses to open it later with a "damaged" or "unverified developer" dialog, run `xattr -dr com.apple.quarantine /Applications/Godot.app` and retry.

**Step 2: Create the Godot path helper**

`tools/godot.sh`:
```bash
#!/bin/bash
# Source this file to get GODOT_BIN. Override by exporting GODOT_BIN before sourcing.
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
```

**Step 3: Verify the binary runs**

Run:
```bash
source tools/godot.sh && "$GODOT_BIN" --version
```
Expected: a line starting with `4.7.2.stable`.

**Step 4: Write .gitignore**

`.gitignore`:
```
.godot/
reports/
*.tmp
.DS_Store
```

**Step 5: Write project.godot**

`project.godot`:
*[63-line code block removed in the 2026-09-24 slim-down: `project.godot` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`default_texture_filter=0` is Nearest, which keeps pixel art crisp. `gl_compatibility` is the renderer that also works for a later web export.

**Step 6: Write a placeholder main scene**

`scenes/main.tscn`:
```
[gd_scene format=3]

[node name="Main" type="Node2D"]

[node name="Label" type="Label" parent="."]
offset_right = 200.0
offset_bottom = 30.0
text = "BOOT OK"
```

**Step 7: Boot the project headless**

Run:
```bash
source tools/godot.sh && "$GODOT_BIN" --headless --path . --import && "$GODOT_BIN" --headless --path . --quit; echo "exit=$?"
```
Expected: the import pass prints Godot version lines and exits; the second run prints `Godot Engine v4.7.2.stable...` and `exit=0`. No lines containing `ERROR`. A `.godot/` directory now exists and is ignored by git.

**Step 8: Commit**

```bash
git add .gitignore project.godot scenes/main.tscn tools/godot.sh
gcommit -m "chore: scaffold Godot 4.7 project with input map and physics layers"
```

---

### Task 2: Install gdUnit4, the headless test runner, and the boot gate

**Files:**
- Create: `addons/gdUnit4/` (copied from the v6.2.1 tag; commit Godot's generated `*.import` and `*.uid` metadata too)
- Modify: `project.godot` (add `[editor_plugins]` section)
- Modify: `tools/godot.sh` (harden)
- Create: `tools/test.sh`, `tools/check_boot.sh`
- Create: `tests/test_sanity.gd`, `tests/test_boot.gd`

**Step 1: Fetch the addon at the pinned tag**

Run:
```bash
git clone --depth 1 --branch v6.2.1 https://github.com/godot-gdunit-labs/gdUnit4 /tmp/gdunit4-src && mkdir -p addons && cp -R /tmp/gdunit4-src/addons/gdUnit4 addons/ && rm -rf /tmp/gdunit4-src && grep version addons/gdUnit4/plugin.cfg
```
Expected: `version="6.2.1"`.

**Step 2: Enable the plugin**

Add to `project.godot` after the `[display]` section:
```ini
[editor_plugins]

enabled=PackedStringArray("res://addons/gdUnit4/plugin.cfg")
```

**Step 3: Harden the Godot path helper**

`tools/godot.sh` (replace whole file):
```bash
#!/bin/bash
# Source this file to get GODOT_BIN. Override by exporting GODOT_BIN before sourcing.
export GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
[ -x "$GODOT_BIN" ] || GODOT_BIN="$(command -v godot 2>/dev/null || true)"
[ -x "$GODOT_BIN" ] || { echo "godot.sh: Godot binary not found; export GODOT_BIN" >&2; return 1 2>/dev/null || exit 1; }
```

**Step 4: Write the test runner**

Note: Godot 4.7.2 rejects gdUnit4's own `--remote-debug tcp://127.0.0.1:0` trick (port 0 is invalid) and prints ERROR lines for it, so the runner does not use it. Without `-d` Godot can never stop at an interactive `debug>` prompt. gdUnit4 exits 0 when it finds no tests, so the runner turns that into a failure.

`tools/test.sh`:
*[38-line code block removed in the 2026-09-24 slim-down: `tools/test.sh` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 5: Write the boot gate**

Godot exits 0 even when the main scene fails to load, so the gate greps the log.

`tools/check_boot.sh`:
*[29-line code block removed in the 2026-09-24 slim-down: `tools/check_boot.sh` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

Run: `chmod +x tools/test.sh tools/check_boot.sh`

**Step 6: Write a sanity test that must fail first**

`tests/test_sanity.gd`:
```gdscript
extends GdUnitTestSuite


func test_arithmetic_works() -> void:
	assert_int(1 + 1).is_equal(3)
```

**Step 7: Run it and confirm the failure is reported**

Run: `tools/test.sh`
Expected: output includes `test_arithmetic_works FAILED` and the final line `gdUnit4 exit code: 100 ...`. This proves failures are detected, not swallowed.

**Step 8: Fix the assertion** to `is_equal(2)` and run again. Expected: exit code 0.

**Step 9: Write the boot test**

It uses gdUnit4's scene runner so the main scene is added to the tree and `_ready` runs.

`tests/test_boot.gd`:
*[20-line code block removed in the 2026-09-24 slim-down: `tests/test_boot.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 10: Verify all gates**

- `tools/test.sh`: 2 test cases pass, exit 0.
- `tools/test.sh -a res://tests/does_not_exist.gd`: prints `test.sh: no test cases discovered`, exit 1.
- `tools/check_boot.sh`: `check_boot: ok`, exit 0.
- Temporarily point `run/main_scene` at a missing scene: `check_boot.sh` prints the ERROR lines and exits 1. Restore `project.godot` byte-identical.
- `git status --short` is clean after running the tools (any `.uid` files Godot generated must be committed).

**Step 11: Commit**

```bash
git add addons/gdUnit4 project.godot tools tests
gcommit -m "test: add gdUnit4 v6.2.1, headless runner, boot gate, and boot test"
```

---

### Task 3: Import the 0x72 Dungeon Tileset II and build the sprite atlas lookup

**Files:**
- Create: `assets/dungeon_tileset_ii/atlas.png`
- Create: `assets/dungeon_tileset_ii/tile_list.txt`
- Create: `assets/dungeon_tileset_ii/README.md`
- Create: `tools/gen_atlas.py`
- Create: `data/atlas.json`
- Create: `scripts/sprite_atlas.gd`
- Test: `tests/test_sprite_atlas.gd`

**Step 1 (USER ACTION): Download the tileset**

Ask the user to:
1. Sign in to itch.io and open https://0x72.itch.io/dungeontileset-ii
2. Click Download and get the latest zip (v1.7 at the time of writing; any 1.x works).
3. Leave it in `~/Downloads/`. The file is named like `0x72_DungeonTilesetII_v1.7.zip`.

Do not continue this task until the file exists. Check with:
```bash
ls ~/Downloads/0x72_DungeonTilesetII*.zip
```

**Step 2: Unpack and locate the atlas and tile list**

Run:
```bash
rm -rf /tmp/0x72 && mkdir -p /tmp/0x72 && unzip -o -q ~/Downloads/0x72_DungeonTilesetII*.zip -d /tmp/0x72 && find /tmp/0x72 -maxdepth 2 \( -iname "*.png" -o -iname "tile_list*" \) | grep -v "/frames/" | sort
```
Expected: one large atlas PNG named like `0x72_DungeonTilesetII_v1.7.png` and one text file named like `tile_list_v1.7`. There is also a `frames/` folder of individual PNGs which we do not use.

**Step 3: Copy them under stable names**

Run (adjust the two source paths to what Step 2 printed):
```bash
mkdir -p assets/dungeon_tileset_ii && cp "$(find /tmp/0x72 -maxdepth 2 -iname '0x72_DungeonTilesetII*.png' | head -1)" assets/dungeon_tileset_ii/atlas.png && cp "$(find /tmp/0x72 -maxdepth 2 -iname 'tile_list*' | head -1)" assets/dungeon_tileset_ii/tile_list.txt && head -5 assets/dungeon_tileset_ii/tile_list.txt && wc -l assets/dungeon_tileset_ii/tile_list.txt
```
Expected: lines of the form `name x y w h`, one per sprite or per animation frame. Animation frames carry an `_f<N>` suffix, for example `floor_1 16 64 16 16` and `knight_m_idle_anim_f0 128 100 16 28`, `knight_m_idle_anim_f1 144 100 16 28`. About 370 lines. The atlas PNG is 512x512.

**Step 4: Verify the sprite names this plan relies on**

Run:
```bash
grep -cE '^(floor_1|floor_2|floor_3|floor_4|floor_5|floor_6|floor_7|floor_8|wall_mid|knight_m_idle_anim_f0|knight_m_run_anim_f0|imp_idle_anim_f0|imp_run_anim_f0) ' assets/dungeon_tileset_ii/tile_list.txt
```
Expected: `13`. If it is lower, print the missing ones with `grep -E '^(floor|wall_mid|knight|imp)' assets/dungeon_tileset_ii/tile_list.txt`, pick the closest names, and use those names everywhere this plan mentions the missing one (the `REQUIRED` list in the test below, `Arena`, `player.gd`, and `chaser.tres`). Tell the user which names changed.

**Step 5: Write the attribution README**

`assets/dungeon_tileset_ii/README.md`:
*[22-line code block removed in the 2026-09-24 slim-down: `assets/dungeon_tileset_ii/README.md` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 6: Write the generator and run it**

`tools/gen_atlas.py`:
*[67-line code block removed in the 2026-09-24 slim-down: `tools/gen_atlas.py` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

Run:
```bash
chmod +x tools/gen_atlas.py && tools/gen_atlas.py && python3 -c "import json; d=json.load(open('data/atlas.json')); print(d['floor_1'], d['knight_m_idle_anim'])"
```
Expected: three stderr warnings (upstream `coin_anim` and `zombie_anim` are malformed and skipped; 24 16x16 sprites are off the 16 px grid and usable only via `texture()`), `wrote 175 sprites to .../data/atlas.json`, and two dicts: floor_1 is `{'x': 16, 'y': 64, 'w': 16, 'h': 16, 'frames': 1}` and the knight one is `{'x': 128, 'y': 100, 'w': 16, 'h': 28, 'frames': 4}`.

**Step 7: Write the failing test**

`tests/test_sprite_atlas.gd`:
*[50-line code block removed in the 2026-09-24 slim-down: `tests/test_sprite_atlas.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 8: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_sprite_atlas.gd`
Expected: `SpriteAtlas` not found.

**Step 9: Write SpriteAtlas**

`scripts/sprite_atlas.gd`:
*[72-line code block removed in the 2026-09-24 slim-down: `scripts/sprite_atlas.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 10: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_sprite_atlas.gd`
Expected: 6 pass, exit 0. `atlas.png.import` now exists next to the PNG; commit it.

**Step 10b: Make stray push_error calls fail tests**

Add to `project.godot` right after the `[editor_plugins]` section:
```ini
[gdunit4]

report/godot/push_error=true
```
Run `tools/test.sh` again: still exit 0.

**Step 11: Commit**

```bash
git add assets/dungeon_tileset_ii tools/gen_atlas.py data/atlas.json scripts/sprite_atlas.gd tests/test_sprite_atlas.gd project.godot
gcommit -m "assets: add 0x72 Dungeon Tileset II with generated atlas index and SpriteAtlas lookup"
```

---

### Task 4: Autoloads: Events bus and seeded RunState

**Files:**
- Create: `scripts/autoload/events.gd`
- Create: `scripts/autoload/run_state.gd`
- Modify: `project.godot` (add `[autoload]`)
- Test: `tests/test_run_state.gd`

**Step 1: Write the failing test**

`tests/test_run_state.gd`:
*[88-line code block removed in the 2026-09-24 slim-down: `tests/test_run_state.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_run_state.gd`
Expected: parse error or failures because `run_state.gd` does not exist.

**Step 3: Write the autoloads**

`scripts/autoload/events.gd`:
```gdscript
extends Node
## Global signal bus. Systems emit here and subscribe here instead of holding references to each other.

signal enemy_spawned(enemy: Node2D)
signal enemy_hit(enemy: Node2D, damage: float, hit_position: Vector2)
signal enemy_died(enemy: Node2D, death_position: Vector2)
signal shot_fired(muzzle_position: Vector2, direction: Vector2)
signal player_hit(damage: int, hp: int, max_hp: int)
signal player_died(death_position: Vector2)
```

`scripts/autoload/run_state.gd`:
*[42-line code block removed in the 2026-09-24 slim-down: `scripts/autoload/run_state.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`_ready` connects to `Events`, which exists only when running as an autoload. In the unit test the node is never added to the tree, so `_ready` never runs. That is intentional.

Add to `project.godot` after `[application]`:
```ini
[autoload]

Events="*res://scripts/autoload/events.gd"
RunState="*res://scripts/autoload/run_state.gd"
```
Order matters: `Events` must come before `RunState`.

**Step 4: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_run_state.gd`
Expected: 10 tests pass, exit 0. The two Events-driven tests use the live RunState autoload inside the test runner and reset it with `start_run(1)` first; never add a second RunState to the tree in a test, it would double-subscribe to Events.

**Step 5: Boot check**

Run: `tools/check_boot.sh`
Expected: `check_boot: ok`, exit 0.

**Step 6: Commit**

```bash
git add scripts/autoload project.godot tests/test_run_state.gd
gcommit -m "feat: add Events signal bus and seeded RunState autoloads"
```

---

### Task 5: Arena grid and tile rendering

**Files:**
- Create: `scripts/arena_grid.gd`
- Create: `scripts/arena.gd`
- Create: `scenes/arena.tscn`
- Modify: `scenes/main.tscn` (replace placeholder)
- Create: `scripts/main.gd`
- Test: `tests/test_arena_grid.gd`

**Step 1: Write the failing test**

`tests/test_arena_grid.gd`:
*[26-line code block removed in the 2026-09-24 slim-down: `tests/test_arena_grid.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_arena_grid.gd`
Expected: failure mentioning `ArenaGrid` not found.

**Step 3: Write ArenaGrid**

`scripts/arena_grid.gd`:
*[31-line code block removed in the 2026-09-24 slim-down: `scripts/arena_grid.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 4: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_arena_grid.gd`
Expected: 4 pass, exit 0.

**Step 5: Write the Arena scene and script**

`scenes/arena.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/arena.gd" id="1"]

[node name="Arena" type="Node2D"]
script = ExtResource("1")

[node name="Tiles" type="TileMapLayer" parent="."]

[node name="Walls" type="StaticBody2D" parent="." groups=["walls"]]
collision_layer = 16
collision_mask = 0
```

`scripts/arena.gd`:
*[68-line code block removed in the 2026-09-24 slim-down: `scripts/arena.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 6: Replace the main scene**

`scenes/main.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/arena.tscn" id="2"]

[node name="Main" type="Node2D"]
script = ExtResource("1")

[node name="Arena" parent="." instance=ExtResource("2")]

[node name="Enemies" type="Node2D" parent="."]

[node name="Camera" type="Camera2D" parent="."]
position = Vector2(320, 184)
zoom = Vector2(2, 2)
```

`scripts/main.gd`:
```gdscript
extends Node2D
## Root of a run. Owns the arena and restart logic.

@onready var arena: Arena = $Arena


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()


func restart() -> void:
	Juice.reset()
	RunState.start_run()
	get_tree().reload_current_scene()
```

The temporary fixed camera at the arena center, zoomed 2x, shows a 640x360 world window, so the top and bottom wall rows are clipped by 4 px each. That is expected in the Task 6 idle screenshot. The camera moves to the player in Task 7.

**Step 7: Boot check and scene test**

Run: `tools/check_boot.sh`
Expected: `check_boot: ok`, exit 0.

`tests/test_arena_scene.gd`:
*[60-line code block removed in the 2026-09-24 slim-down: `tests/test_arena_scene.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

Run: `tools/test.sh`
Expected: all suites pass, exit 0.

**Step 8: Commit**

```bash
git add scripts/arena_grid.gd scripts/arena.gd scenes/arena.tscn scenes/main.tscn scripts/main.gd tests/test_arena_grid.gd tests/test_arena_scene.gd
gcommit -m "feat: render a tiled arena with wall colliders"
```

---

### Task 6: Screenshot smoke tool

Godot's headless mode does not render, so the smoke tool opens a real window for about a second, drives the game with scripted input, saves a PNG, and quits. It also fails if Godot prints a script error.

**Files:**
- Create: `tools/smoke.gd`
- Create: `tools/smoke.tscn`
- Create: `tools/smoke.sh`

**Step 1: Write the smoke scene**

`tools/smoke.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/smoke.gd" id="1"]

[node name="Smoke" type="Node"]
script = ExtResource("1")
```

`tools/smoke.gd`:
*[100-line code block removed in the 2026-09-24 slim-down: `tools/smoke.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 2: Write the shell wrapper**

`tools/smoke.sh`:
*[48-line code block removed in the 2026-09-24 slim-down: `tools/smoke.sh` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

Run: `chmod +x tools/smoke.sh`

**Step 3: Run the idle scenario**

Run: `tools/smoke.sh idle`
Expected: a window flashes open and closes. Output includes `SMOKE_PHYSICS_TICKS 35`, `SMOKE_SCREENSHOT /Users/benjaminzigh/Claude/2d-game/reports/smoke_idle.png err=0`, `SMOKE_IMAGE size=1280x720 mean=0.1xx`, `SMOKE_DONE scenario=idle`, and `smoke: ok`. Scenario waits are counted in physics ticks (60 Hz), not render frames, so timings are the same on every machine.

**Step 4: Look at the screenshot**

Open `reports/smoke_idle.png` (with the Read tool, or `open reports/smoke_idle.png`). Expected: a muted brown-grey stone floor with scattered crack and pebble detail tiles, ringed by a brick wall, filling the frame. If the frame is black, the capture happened before the first draw; increase the `_frames(5)` warm-up to 15.

**Step 5: Commit**

```bash
git add tools/smoke.gd tools/smoke.tscn tools/smoke.sh
gcommit -m "tools: add screenshot smoke runner"
```

---

### Task 7: Player movement with animation and a following camera

**Files:**
- Create: `scripts/movement.gd`
- Create: `scripts/player.gd`
- Create: `scripts/camera.gd`
- Create: `scenes/player.tscn`
- Modify: `scenes/main.tscn`, `scripts/main.gd`
- Test: `tests/test_movement.gd`

**Step 1: Write the failing test**

`tests/test_movement.gd`:
*[44-line code block removed in the 2026-09-24 slim-down: `tests/test_movement.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_movement.gd`
Expected: `Movement` not found.

**Step 3: Write Movement**

`scripts/movement.gd`:
*[17-line code block removed in the 2026-09-24 slim-down: `scripts/movement.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 4: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_movement.gd`
Expected: 6 pass, exit 0.

**Step 5: Write the player scene, player script, and camera script**

`scenes/player.tscn`:
*[32-line code block removed in the 2026-09-24 slim-down: `scenes/player.tscn` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`motion_mode = 1` is Floating, the top-down mode with no notion of floor. The knight sprite is 16x28, so the sprite is offset up 6 px to put its feet near the collision circle.

The camera limits span 0..640 by 0..368 while the 2x view is 640x360, so the view can scroll 8 px vertically; that is intentional so both wall rows are reachable.

Also add to `project.godot` under `[rendering]` so moving sprites land on whole pixels at 2x zoom instead of shimmering:
```ini
2d/snap/snap_2d_transforms_to_pixel=true
```

`scripts/player.gd`:
*[46-line code block removed in the 2026-09-24 slim-down: `scripts/player.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`AnimatedSprite2D.play` with the animation that is already playing is a no-op, so calling it every frame is fine.

`scripts/camera.gd`:
```gdscript
extends Camera2D
## Follows the player (as its child) and leans a little toward the aim point so you see what you aim at.
## The lean goes through the local position (the player never rotates, so local == world direction)
## because Camera2D clamps position to limit_* but adds offset afterwards; offset stays free for screen shake.

const MAX_LEAN := 48.0
const LEAN_FACTOR := 0.3

@onready var player: Player = get_parent()


func _process(_delta: float) -> void:
	var to_aim: Vector2 = player.aim_position() - player.global_position
	# Limits and smoothing clamp position; offset stays free for screen shake.
	position = to_aim.limit_length(MAX_LEAN) * LEAN_FACTOR
```

**Step 6: Put the player in the main scene**

`scenes/main.tscn` (replace whole file):
```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/arena.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="3"]

[node name="Main" type="Node2D"]
script = ExtResource("1")

[node name="Arena" parent="." instance=ExtResource("2")]

[node name="Enemies" type="Node2D" parent="."]

[node name="Player" parent="." instance=ExtResource("3")]
```

`scripts/main.gd` (replace whole file):
*[22-line code block removed in the 2026-09-24 slim-down: `scripts/main.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 7: Smoke test movement**

Run: `tools/smoke.sh move`
Expected: `SMOKE_PLAYER_START (320, 184)`, `SMOKE_PHYSICS_TICKS 65`, and `SMOKE_PLAYER_DELTA (x, 0)` with x between 80 and 110 (60 physics ticks is one second at max speed 110 minus the acceleration ramp, about 103). `SMOKE_IMAGE mean` above 0.02. `smoke: ok`.

Then open `reports/smoke_move.png`. Expected: the knight standing on the stone floor right of center, mid-run-animation, walls visible, view zoomed 2x.

**Step 8: Player scene test and full suite**

`tests/test_player_scene.gd`:
*[71-line code block removed in the 2026-09-24 slim-down: `tests/test_player_scene.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

Run: `tools/test.sh`
Expected: all suites pass, exit 0.

**Step 9: Commit and tag Milestone 0**

```bash
git add scripts/movement.gd scripts/player.gd scripts/camera.gd scenes/player.tscn scenes/main.tscn scripts/main.gd tests/test_movement.gd tests/test_boot.gd tests/test_player_scene.gd tools/smoke.gd project.godot
gcommit -m "feat: animated player movement with following camera"
git tag m0
```

**Milestone 0 is done** when the move screenshot shows the hero on tiles and `tools/test.sh` exits 0.

---

## Milestone 1: shooting, Chaser enemy, juice

### Task 8: Weapon definition and projectiles

**Files:**
- Create: `scripts/defs/weapon_def.gd`
- Create: `data/weapons/pistol.tres`
- Create: `scripts/fire_controller.gd`
- Create: `scripts/projectile.gd`
- Create: `scenes/projectile.tscn`
- Modify: `scripts/player.gd`, `scenes/player.tscn`
- Test: `tests/test_weapon_def.gd`, `tests/test_fire_controller.gd`

**Step 1: Write the failing tests**

`tests/test_weapon_def.gd`:
*[27-line code block removed in the 2026-09-24 slim-down: `tests/test_weapon_def.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`tests/test_fire_controller.gd`:
*[36-line code block removed in the 2026-09-24 slim-down: `tests/test_fire_controller.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 2: Run to verify they fail**

Run: `tools/test.sh -a res://tests/test_weapon_def.gd -a res://tests/test_fire_controller.gd`
Expected: `WeaponDef` and `FireController` not found.

**Step 3: Write WeaponDef, the pistol resource, and FireController**

`scripts/defs/weapon_def.gd`:
*[40-line code block removed in the 2026-09-24 slim-down: `scripts/defs/weapon_def.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`data/weapons/pistol.tres`:
*[16-line code block removed in the 2026-09-24 slim-down: `data/weapons/pistol.tres` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`scripts/fire_controller.gd`:
*[19-line code block removed in the 2026-09-24 slim-down: `scripts/fire_controller.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 4: Run to verify they pass**

Run: `tools/test.sh -a res://tests/test_weapon_def.gd -a res://tests/test_fire_controller.gd`
Expected: 7 pass, exit 0.

**Step 5: Write the projectile**

`scenes/projectile.tscn`:
```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/projectile.gd" id="1"]

[sub_resource type="CircleShape2D" id="hit_shape"]
radius = 3.0

[node name="Projectile" type="Area2D"]
collision_layer = 4
collision_mask = 18
script = ExtResource("1")

[node name="Shape" type="CollisionShape2D" parent="."]
shape = SubResource("hit_shape")
```

`scripts/projectile.gd`:
*[60-line code block removed in the 2026-09-24 slim-down: `scripts/projectile.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`Health` does not exist yet; it arrives in Task 9. Until then the projectile only despawns on walls and on lifetime. GDScript resolves `as Health` at parse time, so add a one-line stub now to keep the project parsing:

`scripts/health.gd` (temporary stub, replaced in Task 9):
```gdscript
class_name Health
extends Node


func take_damage(_amount: float, _knockback: Vector2 = Vector2.ZERO) -> void:
	pass
```

**Step 6: Add shooting to the player**

`scenes/player.tscn`: change the header to `load_steps=5`, add the pistol ext_resource, and set `weapon` on the root node. The file's first lines become:
```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/player.gd" id="1"]
[ext_resource type="Script" path="res://scripts/camera.gd" id="3"]
[ext_resource type="Resource" path="res://data/weapons/pistol.tres" id="4"]

[sub_resource type="CircleShape2D" id="body_shape"]
radius = 6.0

[node name="Player" type="CharacterBody2D" groups=["player"]]
collision_layer = 1
collision_mask = 18
motion_mode = 1
script = ExtResource("1")
weapon = ExtResource("4")
```
Keep the Sprite, Shape, Muzzle, and Camera child nodes exactly as they were.

`scripts/player.gd` (replace whole file):
*[80-line code block removed in the 2026-09-24 slim-down: `scripts/player.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

Projectiles are added to the player's parent (Main) so they do not move with the player.

**Step 6c: Projectiles container**

Add `[node name="Projectiles" type="Node2D" parent="."]` to `scenes/main.tscn` after `Enemies`, and wire it in `scripts/main.gd` (replace whole file):
*[24-line code block removed in the 2026-09-24 slim-down: `scenes/main.tscn` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`tests/test_boot.gd` asserts the container exists (see its listing under Task 2).

**Step 6d: Projectile scene tests**

`tests/test_projectile.gd`:
*[86-line code block removed in the 2026-09-24 slim-down: `tests/test_projectile.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

The two-bodies-one-step test is the one that matters: without the `is_queued_for_deletion()` guard a pierce-0 shot damages both.

**Step 7: Smoke test combat**

Run: `tools/smoke.sh combat`
Expected: `smoke: ok`, `SMOKE_ENEMIES_ALIVE 0`, `SMOKE_PROJECTILES_ALIVE` around 6, `SMOKE_KILLS 0` (no enemies yet). Open `reports/smoke_combat.png`: a line of small yellow dots streaming right from the knight toward the wall.

**Step 7b: Scene test for shooting**

The `test_holding_shoot_spawns_projectiles_and_recoils` test in `tests/test_player_scene.gd` (listed under Task 7) holds `shoot` for 30 physics frames with aim to the right and expects 3 to 5 Projectile children under Main (cooldown 1/7 s is 8.57 ticks, so shots at ticks 0, 9, 18, 27) and the player pushed left by recoil.

**Step 8: Run all tests and commit**

Run: `tools/test.sh` (exit 0), then:
```bash
git add scripts/defs scripts/fire_controller.gd scripts/projectile.gd scripts/health.gd scenes/projectile.tscn data/weapons scripts/player.gd scenes/player.tscn scenes/main.tscn scripts/main.gd tests/test_weapon_def.gd tests/test_fire_controller.gd tests/test_player_scene.gd tests/test_projectile.gd tests/test_boot.gd tools/smoke.gd
gcommit -m "feat: pistol weapon def, fire cooldown, and projectiles"
```

---

### Task 9: Health component and the Chaser enemy

**Files:**
- Modify: `scripts/health.gd` (replace the stub)
- Create: `scripts/defs/enemy_def.gd`
- Create: `data/enemies/chaser.tres`
- Create: `scripts/enemy.gd`
- Create: `scenes/enemies/chaser.tscn`
- Create: `assets/shaders/flash.gdshader`
- Test: `tests/test_health.gd`, `tests/test_enemy_def.gd`, `tests/test_projectile.gd`, `tests/test_chaser_scene.gd`

**Step 1: Write the failing unit tests**

`tests/test_health.gd`:
*[44-line code block removed in the 2026-09-24 slim-down: `tests/test_health.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`tests/test_enemy_def.gd`:
*[27-line code block removed in the 2026-09-24 slim-down: `tests/test_enemy_def.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`tests/test_projectile.gd` (final, includes the Task 8 scene tests and the unit tests added here):
*[138-line code block removed in the 2026-09-24 slim-down: `tests/test_projectile.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`tests/test_chaser_scene.gd`:
*[118-line code block removed in the 2026-09-24 slim-down: `tests/test_chaser_scene.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 2: Run to verify they fail**

Run: `tools/test.sh`
Expected: failures for `EnemyDef` and `Enemy` not found, and `Health` lacking `setup`.

**Step 3: Write Health (replacing the stub)**

`scripts/health.gd`:
*[33-line code block removed in the 2026-09-24 slim-down: `scripts/health.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 4: Write EnemyDef and the chaser resource**

`scripts/defs/enemy_def.gd`:
*[29-line code block removed in the 2026-09-24 slim-down: `scripts/defs/enemy_def.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`data/enemies/chaser.tres`:
*[16-line code block removed in the 2026-09-24 slim-down: `data/enemies/chaser.tres` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 5: Write the flash shader**

`assets/shaders/flash.gdshader`:
```glsl
shader_type canvas_item;

// 0 = normal sprite, 1 = solid white silhouette. Juice tweens this on hit.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
```

**Step 6: Write the Enemy script and Chaser scene**

`scripts/enemy.gd`:
*[103-line code block removed in the 2026-09-24 slim-down: `scripts/enemy.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

A bare `Juice` identifier is a parse error until Task 11 registers the autoload, so the enemy looks it up dynamically with `get_node_or_null("/root/Juice")`. That form keeps working after Task 11 too.

`scenes/enemies/chaser.tscn`:
*[23-line code block removed in the 2026-09-24 slim-down: `scenes/enemies/chaser.tscn` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 7: Run all tests**

Run: `tools/test.sh`
Expected: every suite passes, exit 0. The chaser tests wait on physics frames, so they are deterministic on any machine.

**Step 8: Commit**

```bash
git add scripts/health.gd scripts/defs/enemy_def.gd data/enemies scripts/enemy.gd scenes/enemies assets/shaders tests/test_health.gd tests/test_enemy_def.gd tests/test_projectile.gd tests/test_chaser_scene.gd
gcommit -m "feat: Health component, EnemyDef, and animated Chaser enemy"
```

---

### Task 10: Spawner

**Files:**
- Create: `scripts/spawn_math.gd`
- Create: `scripts/spawner.gd`
- Modify: `scenes/main.tscn`, `scripts/main.gd`
- Test: `tests/test_spawn_math.gd`

**Step 1: Write the failing test**

`tests/test_spawn_math.gd`:
*[36-line code block removed in the 2026-09-24 slim-down: `tests/test_spawn_math.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_spawn_math.gd`
Expected: `SpawnMath` not found.

**Step 3: Write SpawnMath**

`scripts/spawn_math.gd`:
*[31-line code block removed in the 2026-09-24 slim-down: `scripts/spawn_math.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 4: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_spawn_math.gd`
Expected: 4 pass, exit 0.

**Step 5: Write the Spawner and wire it into Main**

`scripts/spawner.gd`:
*[61-line code block removed in the 2026-09-24 slim-down: `scripts/spawner.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`scenes/main.tscn` (replace whole file):
*[20-line code block removed in the 2026-09-24 slim-down: `scenes/main.tscn` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`scripts/main.gd` (replace whole file):
*[29-line code block removed in the 2026-09-24 slim-down: `scripts/main.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 5b: Keep existing main-scene tests quiet**

Every test that runs `scene_runner("res://scenes/main.tscn")` sets `main.get_node("Spawner").enabled = false` right after obtaining the scene (`test_boot.gd`, `test_player_scene.gd`, `test_projectile.gd`, `test_chaser_scene.gd`); `test_boot.gd` also asserts the `Spawner` child exists.

**Step 5c: Spawner scene test**

`tests/test_spawner_scene.gd`:
*[124-line code block removed in the 2026-09-24 slim-down: `tests/test_spawner_scene.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 6: Smoke test combat**

Run: `tools/smoke.sh combat`
Expected: `smoke: ok`. `SMOKE_ENEMIES_ALIVE` is 1 or more (150 frames is 2.5 s, so one or two spawns). `SMOKE_KILLS` may be 0 or more depending on whether an imp crossed the shot line. Open `reports/smoke_combat.png` and confirm at least one imp is on the floor.

**Step 7: Run all tests and commit**

Run: `tools/test.sh` (exit 0), then:
```bash
git add scripts/spawn_math.gd scripts/spawner.gd scenes/main.tscn scripts/main.gd tests/test_spawn_math.gd tests/test_spawner_scene.gd tests/test_boot.gd tests/test_player_scene.gd tests/test_projectile.gd tests/test_chaser_scene.gd
gcommit -m "feat: timed Chaser spawner with seeded placement"
```

---

### Task 11: Juice: screen shake, hitstop, hit flash, particles, muzzle flash

**Files:**
- Create: `scripts/juice_math.gd`
- Create: `scripts/autoload/juice.gd`
- Create: `scripts/muzzle_flash.gd`
- Create: `scripts/fx.gd`
- Modify: `project.godot` (autoload), `scripts/camera.gd`, `scenes/main.tscn`
- Test: `tests/test_juice_math.gd`

**Step 1: Write the failing test**

`tests/test_juice_math.gd`:
*[22-line code block removed in the 2026-09-24 slim-down: `tests/test_juice_math.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_juice_math.gd`
Expected: `JuiceMath` not found.

**Step 3: Write JuiceMath**

`scripts/juice_math.gd`:
```gdscript
class_name JuiceMath
extends RefCounted
## Pure math behind screen shake. Trauma is 0..1; shake scales with trauma squared so small hits
## barely register and big ones land hard.


static func shake_offset(trauma: float, max_offset: float, rx: float, ry: float) -> Vector2:
	var t := clampf(trauma, 0.0, 1.0)
	return Vector2(rx, ry) * max_offset * t * t


static func decay(trauma: float, rate: float, delta: float) -> float:
	return maxf(trauma - rate * delta, 0.0)
```

**Step 4: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_juice_math.gd`
Expected: 5 pass, exit 0.

**Step 5: Write the Juice autoload**

`scripts/autoload/juice.gd`:
*[61-line code block removed in the 2026-09-24 slim-down: `scripts/autoload/juice.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`create_timer(duration, true, false, true)`: process always, not in physics, ignore time scale. The last flag is what makes hitstop end while time is slowed.

Now that the autoload exists, replace the two dynamic `get_node_or_null("/root/Juice")` lookups in `scripts/enemy.gd` (`_on_damaged` and `_on_died`) with direct calls: `Juice.flash(flash_material)`, `Juice.add_trauma(0.12)`, and `Juice.add_trauma(0.3)`, `Juice.hitstop(0.06)`.

Add `Juice` to `project.godot` autoloads, after `RunState`:
```ini
[autoload]

Events="*res://scripts/autoload/events.gd"
RunState="*res://scripts/autoload/run_state.gd"
Juice="*res://scripts/autoload/juice.gd"
```

**Step 6: Add shake to the camera**

`scripts/camera.gd` (replace whole file):
*[17-line code block removed in the 2026-09-24 slim-down: `scripts/camera.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 7: Write the muzzle flash and the Fx node**

`scripts/muzzle_flash.gd`:
*[16-line code block removed in the 2026-09-24 slim-down: `scripts/muzzle_flash.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

`scripts/fx.gd`:
*[88-line code block removed in the 2026-09-24 slim-down: `scripts/fx.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

Add the Fx node to `scenes/main.tscn`. Change the header to `load_steps=6`, add the ext_resource, and add the node after Player so effects draw on top of the knight:
```
[ext_resource type="Script" path="res://scripts/fx.gd" id="5"]
```
```
[node name="Fx" type="Node2D" parent="."]
script = ExtResource("5")
```

**Step 7b: Juice and Fx scene tests**

`tests/test_juice_scene.gd`:
*[129-line code block removed in the 2026-09-24 slim-down: `tests/test_juice_scene.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 7c: Feel defaults and the kill freeze**

The numbers above were reviewed against the 2x camera: shake is quadratic in trauma, so a 0.12 hit produced 0.2 screen px and was invisible. Defaults now: `MAX_SHAKE` 12 world px, `TRAUMA_DECAY` 2.5, `HIT_TRAUMA` 0.2, `DEATH_TRAUMA` 0.45 (hit plus kill is 0.65, about 10 screen px). The kill hitstop holds the enemy's white-flashed pose for `DEATH_HITSTOP` (0.06 s of real time) before freeing it, instead of freezing on empty floor. `Juice._process` decays trauma by measured real time, because on the frame a hitstop starts Godot's delta is still unscaled. `Juice.reset()` clears trauma and any running freeze; `Main.restart()` and every damage-dealing test suite's `after_test` call it.

**Step 8: Smoke test and inspect**

Run: `tools/smoke.sh combat`
Expected: `smoke: ok`. Open `reports/smoke_combat.png`: projectiles streaming right, a muzzle flash at the knight, and if an imp was hit, sparks. The frame may be offset a few pixels by shake, which is expected.

Run: `tools/test.sh`
Expected: exit 0. The chaser scene test now exercises `Juice.flash` and `hitstop`.

**Step 9: Commit**

```bash
git add scripts/juice_math.gd scripts/autoload/juice.gd scripts/muzzle_flash.gd scripts/fx.gd project.godot scripts/camera.gd scenes/main.tscn tests/test_juice_math.gd scripts/enemy.gd scripts/autoload/run_state.gd tests/test_juice_scene.gd tests/test_boot.gd
gcommit -m "feat: screen shake, hitstop, hit flash, particles, muzzle flash"
```

---

### Task 12: Player health, contact damage, death, restart

**Files:**
- Create: `scripts/player_hit_rules.gd`
- Modify: `scripts/player.gd`, `scenes/player.tscn`, `scripts/main.gd`
- Test: `tests/test_player_hit_rules.gd`

**Step 1: Write the failing test**

Contact damage rules are pure: they live in a static helper so they are testable.

`tests/test_player_hit_rules.gd`:
*[25-line code block removed in the 2026-09-24 slim-down: `tests/test_player_hit_rules.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_player_hit_rules.gd`
Expected: `PlayerHitRules` not found.

**Step 3: Write the rules**

`scripts/player_hit_rules.gd`:
*[25-line code block removed in the 2026-09-24 slim-down: `scripts/player_hit_rules.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 4: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_player_hit_rules.gd`
Expected: 5 pass, exit 0.

**Step 5: Add a hurtbox to the player scene**

Collision model (decided in review): enemies pass through the player. Set the player root's `collision_mask` to 16 (walls only) so chasers overlap freely and only the hurtbox registers contact; that lets you walk out of a swarm during i-frames. Chasers keep mask 18 so they still collide with walls and each other. The hurtbox radius 5 plus the enemy body radius 5 triggers contact at 10 px, roughly when the 16 px sprites visibly overlap.

In `scenes/player.tscn`, bump `load_steps` to 6, add a second sub_resource, and add a Hurtbox node after Shape:
```
[sub_resource type="CircleShape2D" id="hurt_shape"]
radius = 5.0
```
```
[node name="Hurtbox" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 2

[node name="HurtShape" type="CollisionShape2D" parent="Hurtbox"]
shape = SubResource("hurt_shape")
```

**Step 6: Extend the player script**

`scripts/player.gd` (replace whole file):
*[131-line code block removed in the 2026-09-24 slim-down: `scripts/player.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

The one public entry point is `hurt(damage, from) -> bool`; it holds the i-frame gate, clamps hp at 0, and emits `player_hit(damage, hp, max_hp)`. Milestone 2 enemy projectiles call the same method. `player_died` carries the death position so Fx can burst there.

**Step 7: Make Main restart on death**

`restart()` emits `restart_requested` and only reloads when Main is the tree's current scene, so test harnesses and the smoke tool never reload themselves.

`scripts/main.gd` (replace whole file):
*[51-line code block removed in the 2026-09-24 slim-down: `scripts/main.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

The `Events.player_died` connection is made by a node that is freed on scene reload, so it does not accumulate across restarts.

**Step 7b: Scene tests**

`tests/test_player_damage_scene.gd`:
*[183-line code block removed in the 2026-09-24 slim-down: `tests/test_player_damage_scene.gd` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

The knockback test waits 20 ticks because the 0.09 s hit freeze shrinks physics delta for about five ticks. gdUnit frees the runner's scene at test end, so Main's pending 1 s restart never fires inside the test tree.

**Step 7c: Smoke**

`tools/smoke.gd` combat also prints `SMOKE_PLAYER_HP`.

**Step 8: Run everything**

Run: `tools/test.sh` (exit 0).
Run: `tools/smoke.sh combat` (`smoke: ok`).
Run: `tools/smoke.sh idle` and confirm the log has no `ERROR`.

**Step 9: Commit**

```bash
git add scripts/player_hit_rules.gd scripts/player.gd scenes/player.tscn scripts/main.gd tools/smoke.gd tests/test_player_hit_rules.gd tests/test_player_damage_scene.gd
gcommit -m "feat: player health, contact damage with i-frames, death and restart"
```

---

### Task 13: Playable build, feel checklist, and Milestone 1 handoff

**Files:**
- Create: `README.md`
- Create: `docs/plans/2026-09-02-m1-feel-checklist.md`

**Step 1: Write the README**

`README.md` (note the nested bash fence; the file is listed as-is):
```markdown
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
```

**Step 2: Write the feel checklist for the user's playtest**

`docs/plans/2026-09-02-m1-feel-checklist.md`:
*[19-line code block removed in the 2026-09-24 slim-down: `docs/plans/2026-09-02-m1-feel-checklist.md` as committed is the reference; the full text is `git show c4e6644:docs/plans/2026-09-02-arena-roguelike-m0-m1.md`.]*

**Step 3: Launch the game for a real playtest**

Run:
```bash
source tools/godot.sh && "$GODOT_BIN" --path .
```
Expected: a 1280x720 window, the animated knight in a stone room, imps fading in and chasing after half a second. Shooting, hits, kills, damage blink, death and auto-restart all work. Close the window to exit.

**Step 4: Final verification**

Run: `tools/test.sh` (exit 0) and `tools/smoke.sh combat` (`smoke: ok`).

**Step 5: Commit and tag**

```bash
git add README.md docs/plans/2026-09-02-m1-feel-checklist.md tests/test_player_damage_scene.gd
gcommit -m "docs: README and Milestone 1 feel checklist"
git tag m1-candidate
```

**Milestone 1 closes** when the user has played the build and reports shooting feels good. Tuning changes from the checklist are small commits on top of `m1-candidate`; tag `m1` once the user signs off.

---

## Out of scope for this plan (Milestone 2 onward)

Shooter enemy (`wizzard_m_*` sprites), waves and wave tables, HUD, run summary screen, upgrade picker, sound, rooms and doors, generated art. Each will get its own plan against the same design doc.
