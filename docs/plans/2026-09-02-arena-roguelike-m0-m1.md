# Arena Roguelike M0+M1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A playable single-arena build where the player moves, shoots, and fights Chaser enemies with full hit feedback, backed by headless tests and a screenshot smoke tool.

**Architecture:** Godot 4.7 project, all text files. Pure-logic classes (`Movement`, `FireController`, `ArenaGrid`, `SpawnMath`, `JuiceMath`, `Health`) hold every number-crunching rule and are unit-tested with gdUnit4. Scenes are thin wrappers that call those classes. Three autoloads (`Events` signal bus, `RunState` seeded RNG and score, `Juice` shake/hitstop/flash) decouple systems.

**Tech Stack:** Godot 4.7.2 (Homebrew cask), GDScript, gdUnit4 v6.2.1, Kenney Tiny Dungeon tileset (CC0), macOS arm64.

**Design doc:** `docs/plans/2026-09-02-action-roguelike-design.md`

**Asset note:** The design named the 0x72 Dungeon Tileset II. It is only available through itch.io's browser download, which cannot be scripted. This plan uses Kenney Tiny Dungeon instead: also CC0, also 16x16 pixel art, with a hero, monsters, floors and walls. The design doc has been updated to match.

---

## Conventions used throughout

- `GODOT_BIN` is `/Applications/Godot.app/Contents/MacOS/Godot`. Every script sources `tools/godot.sh` which sets it.
- Run all commands from the project root `/Users/benjaminzigh/Claude/2d-game`.
- gdUnit4 exit codes: `0` pass, `100` failures, `101` warnings. `tools/test.sh` prints the code.
- Godot rebuilds its class-name cache only when the editor imports the project. `tools/test.sh` and `tools/smoke.sh` both run `--import` first, so new `class_name` scripts are always picked up. If a test fails with "Identifier not found" for a class you just wrote, that import step did not run.
- Tile indices refer to `assets/kenney_tiny_dungeon/tilemap_packed.png`, a 12x11 grid of 16px tiles with no spacing. A region for tile (col, row) is `Rect2(col*16, row*16, 16, 16)`. Tiles used: sandy floor `(0..5, 4)`, grey brick wall `(0, 3)`, knight player `(1, 8)`, bat Chaser `(0, 10)`.
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
```ini
; Engine configuration file.
; Godot 4 project settings. Edited by hand; the editor rewrites it in the same format.
config_version=5

[application]

config/name="Arena Roguelike"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[input]

move_left={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)
]
}
move_up={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.2,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"location":0,"echo":false,"script":null)
]
}
shoot={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":1,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":true,"double_click":false,"script":null)
]
}
restart={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":82,"key_label":0,"unicode":114,"location":0,"echo":false,"script":null)
]
}

[layer_names]

2d_physics/layer_1="player"
2d_physics/layer_2="enemies"
2d_physics/layer_3="player_shots"
2d_physics/layer_4="enemy_shots"
2d_physics/layer_5="walls"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
```

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

### Task 2: Install gdUnit4 and the headless test runner

**Files:**
- Create: `addons/gdUnit4/` (copied from the v6.2.1 tag)
- Modify: `project.godot` (add `[editor_plugins]` section)
- Create: `tools/test.sh`
- Create: `tests/test_sanity.gd`

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

**Step 3: Write the test runner**

`tools/test.sh`:
```bash
#!/bin/bash
# Runs every gdUnit4 suite under tests/ headless.
# Usage: tools/test.sh            (all suites)
#        tools/test.sh -a res://tests/test_movement.gd   (one suite; -a overrides the default)
set -u
cd "$(dirname "$0")/.."
source tools/godot.sh

# Refresh the import cache so new class_name scripts and assets are visible.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1

if [ $# -eq 0 ]; then
  set -- -a res://tests
fi

"$GODOT_BIN" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -rd res://reports "$@"
code=$?
echo "gdUnit4 exit code: $code (0=pass, 100=failures, 101=warnings)"
exit $code
```

Run: `chmod +x tools/test.sh`

**Step 4: Write a sanity test that must fail first**

`tests/test_sanity.gd`:
```gdscript
extends GdUnitTestSuite


func test_arithmetic_works() -> void:
	assert_int(1 + 1).is_equal(3)
```

**Step 5: Run it and confirm the failure is reported**

Run: `tools/test.sh`
Expected: output includes `test_arithmetic_works` marked failed and the final line `gdUnit4 exit code: 100`. This proves failures are detected, not swallowed.

**Step 6: Fix the assertion**

Change `is_equal(3)` to `is_equal(2)`.

**Step 7: Run again**

Run: `tools/test.sh`
Expected: `gdUnit4 exit code: 0`.

**Step 8: Commit**

```bash
git add addons/gdUnit4 project.godot tools/test.sh tests/test_sanity.gd
gcommit -m "test: add gdUnit4 v6.2.1 and headless runner"
```

---

### Task 3: Add the Kenney Tiny Dungeon tileset

**Files:**
- Create: `assets/kenney_tiny_dungeon/tilemap_packed.png`
- Create: `assets/kenney_tiny_dungeon/License.txt`
- Create: `assets/kenney_tiny_dungeon/README.md`

**Step 1: Download and copy**

Run:
```bash
mkdir -p assets/kenney_tiny_dungeon /tmp/kenney && curl -sL -o /tmp/kenney/pack.zip "https://kenney.nl/media/pages/assets/tiny-dungeon/f8422efb44-1674742415/kenney_tiny-dungeon.zip" && unzip -o -q /tmp/kenney/pack.zip -d /tmp/kenney/x && cp /tmp/kenney/x/Tilemap/tilemap_packed.png /tmp/kenney/x/License.txt assets/kenney_tiny_dungeon/ && rm -rf /tmp/kenney && ls -la assets/kenney_tiny_dungeon
```
Expected: `tilemap_packed.png` about 5.3 KB and `License.txt`. If the URL has changed, open https://kenney.nl/assets/tiny-dungeon in a browser, download, and copy the same two files.

**Step 2: Document the tile map**

`assets/kenney_tiny_dungeon/README.md`:
```markdown
# Kenney Tiny Dungeon 1.0 (CC0)

Source: https://kenney.nl/assets/tiny-dungeon

`tilemap_packed.png` is 192x176: 12 columns x 11 rows of 16x16 tiles, no spacing.
Tile (col, row) is at `Rect2(col*16, row*16, 16, 16)`.

Tiles used by the game:

| Purpose        | (col,row)     |
|----------------|---------------|
| Sandy floor    | (0..5, 4)     |
| Grey brick wall| (0, 3)        |
| Player knight  | (1, 8)        |
| Chaser bat     | (0, 10)       |
| Shooter wizard | (3, 9)        |
| Green slime    | (0, 9)        |
```

**Step 3: Import and check the .import file appeared**

Run:
```bash
source tools/godot.sh && "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1; ls assets/kenney_tiny_dungeon/
```
Expected: `tilemap_packed.png.import` now exists. It is committed; it records import settings.

**Step 4: Commit**

```bash
git add assets/
gcommit -m "assets: add Kenney Tiny Dungeon tileset (CC0)"
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
```gdscript
extends GdUnitTestSuite

const RunStateScript := preload("res://scripts/autoload/run_state.gd")


func _new_state(seed_value: int) -> Node:
	var state: Node = auto_free(RunStateScript.new())
	state.start_run(seed_value)
	return state


func test_same_seed_gives_same_sequence() -> void:
	var a := _new_state(1234)
	var b := _new_state(1234)
	for i in 20:
		assert_float(a.rng.randf()).is_equal(b.rng.randf())


func test_different_seed_gives_different_sequence() -> void:
	var a := _new_state(1)
	var b := _new_state(2)
	assert_float(a.rng.randf()).is_not_equal(b.rng.randf())


func test_start_run_resets_counters() -> void:
	var state := _new_state(7)
	state.score = 50
	state.kills = 3
	state.elapsed = 12.0
	state.start_run(7)
	assert_int(state.score).is_equal(0)
	assert_int(state.kills).is_equal(0)
	assert_float(state.elapsed).is_equal(0.0)


func test_negative_seed_means_random_seed() -> void:
	var state := _new_state(-1)
	assert_int(state.seed_value).is_greater_equal(0)
```

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_run_state.gd`
Expected: parse error or failures because `run_state.gd` does not exist. Exit code 100 or a non-zero Godot error.

**Step 3: Write the autoloads**

`scripts/autoload/events.gd`:
```gdscript
extends Node
## Global signal bus. Systems emit here and subscribe here instead of holding references to each other.

signal enemy_spawned(enemy: Node2D)
signal enemy_hit(enemy: Node2D, damage: float, hit_position: Vector2)
signal enemy_died(enemy: Node2D, death_position: Vector2)
signal shot_fired(muzzle_position: Vector2, direction: Vector2)
signal player_hit(damage: int)
signal player_died()
```

`scripts/autoload/run_state.gd`:
```gdscript
extends Node
## Per-run state: the seed, the gameplay RNG, and score counters.
## Gameplay randomness (spawns, spread) MUST use RunState.rng so a seed replays a run.
## Cosmetic randomness (screen shake) uses the global randf so it never disturbs the run.

var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var score: int = 0
var kills: int = 0
var elapsed: float = 0.0


func _ready() -> void:
	start_run()
	Events.enemy_died.connect(_on_enemy_died)


func _process(delta: float) -> void:
	elapsed += delta


func start_run(new_seed: int = -1) -> void:
	seed_value = new_seed if new_seed >= 0 else (randi() & 0x7FFFFFFF)
	rng.seed = seed_value
	score = 0
	kills = 0
	elapsed = 0.0


func _on_enemy_died(enemy: Node2D, _death_position: Vector2) -> void:
	kills += 1
	var def = enemy.get("def")
	score += def.score if def != null else 10
```

Note: `_ready` connects to `Events`, which exists only when running as an autoload. In the unit test the node is never added to the tree, so `_ready` never runs. That is intentional.

Add to `project.godot` after `[application]`:
```ini
[autoload]

Events="*res://scripts/autoload/events.gd"
RunState="*res://scripts/autoload/run_state.gd"
```
Order matters: `Events` must come before `RunState`.

**Step 4: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_run_state.gd`
Expected: 4 tests pass, exit code 0.

**Step 5: Boot check**

Run: `source tools/godot.sh && "$GODOT_BIN" --headless --path . --quit 2>&1 | grep -c "ERROR"; echo done`
Expected: `0` then `done`.

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
```gdscript
extends GdUnitTestSuite


func test_floor_cells_fill_interior() -> void:
	var cells := ArenaGrid.floor_cells(6, 4)
	assert_array(cells).has_size((6 - 2) * (4 - 2))
	assert_array(cells).contains([Vector2i(1, 1), Vector2i(4, 2)])
	assert_array(cells).not_contains([Vector2i(0, 0), Vector2i(5, 3), Vector2i(0, 2)])


func test_wall_cells_form_ring() -> void:
	var cells := ArenaGrid.wall_cells(6, 4)
	assert_array(cells).has_size(2 * 6 + 2 * (4 - 2))
	assert_array(cells).contains([Vector2i(0, 0), Vector2i(5, 3), Vector2i(3, 0)])
	assert_array(cells).not_contains([Vector2i(1, 1)])


func test_cell_center_is_pixel_center() -> void:
	assert_vector(ArenaGrid.cell_center(Vector2i(0, 0))).is_equal(Vector2(8, 8))
	assert_vector(ArenaGrid.cell_center(Vector2i(2, 1))).is_equal(Vector2(40, 24))


func test_bounds_exclude_walls() -> void:
	var b := ArenaGrid.bounds(40, 23)
	assert_vector(b.position).is_equal(Vector2(16, 16))
	assert_vector(b.size).is_equal(Vector2(38 * 16, 21 * 16))
```

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_arena_grid.gd`
Expected: failure mentioning `ArenaGrid` not found.

**Step 3: Write ArenaGrid**

`scripts/arena_grid.gd`:
```gdscript
class_name ArenaGrid
extends RefCounted
## Pure grid math for a rectangular room with a one-tile wall ring. No nodes, so it is unit-testable.

const TILE := 16


static func floor_cells(width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			cells.append(Vector2i(x, y))
	return cells


static func wall_cells(width: int, height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in height:
		for x in width:
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				cells.append(Vector2i(x, y))
	return cells


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2(TILE, TILE) * 0.5


## Playable interior in pixels (walls excluded).
static func bounds(width: int, height: int) -> Rect2:
	return Rect2(TILE, TILE, (width - 2) * TILE, (height - 2) * TILE)
```

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
```gdscript
class_name Arena
extends Node2D
## One rectangular room. Paints tiles in code from ArenaGrid and builds four wall colliders.

const WIDTH := 40
const HEIGHT := 23
const TILESHEET := preload("res://assets/kenney_tiny_dungeon/tilemap_packed.png")
const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4),
]
const WALL_TILE := Vector2i(0, 3)
const PLAIN_FLOOR_CHANCE := 0.85

@onready var tiles: TileMapLayer = $Tiles
@onready var walls: StaticBody2D = $Walls


func _ready() -> void:
	tiles.tile_set = _build_tile_set()
	_paint()
	_build_wall_bodies()


func bounds() -> Rect2:
	return ArenaGrid.bounds(WIDTH, HEIGHT)


func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(ArenaGrid.TILE, ArenaGrid.TILE)
	var source := TileSetAtlasSource.new()
	source.texture = TILESHEET
	source.texture_region_size = Vector2i(ArenaGrid.TILE, ArenaGrid.TILE)
	for coords in FLOOR_TILES:
		source.create_tile(coords)
	source.create_tile(WALL_TILE)
	tile_set.add_source(source, 0)
	return tile_set


func _paint() -> void:
	for cell in ArenaGrid.floor_cells(WIDTH, HEIGHT):
		var variant := FLOOR_TILES[0]
		if RunState.rng.randf() >= PLAIN_FLOOR_CHANCE:
			variant = FLOOR_TILES[RunState.rng.randi_range(1, FLOOR_TILES.size() - 1)]
		tiles.set_cell(cell, 0, variant)
	for cell in ArenaGrid.wall_cells(WIDTH, HEIGHT):
		tiles.set_cell(cell, 0, WALL_TILE)


func _build_wall_bodies() -> void:
	var t := float(ArenaGrid.TILE)
	var w := WIDTH * t
	var h := HEIGHT * t
	_add_wall(Rect2(0, 0, w, t))
	_add_wall(Rect2(0, h - t, w, t))
	_add_wall(Rect2(0, 0, t, h))
	_add_wall(Rect2(w - t, 0, t, h))


func _add_wall(rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.position + rect.size * 0.5
	walls.add_child(shape)
```

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
	Engine.time_scale = 1.0
	RunState.start_run()
	get_tree().reload_current_scene()
```

The temporary fixed camera at the arena center, zoomed 2x, shows the whole 640x368 room in the 1280x720 window. It moves to the player in Task 7.

**Step 7: Boot check**

Run: `source tools/godot.sh && "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1; "$GODOT_BIN" --headless --path . --quit 2>&1 | grep -E "ERROR|SCRIPT" ; echo "exit=${PIPESTATUS[0]}"`
Expected: no ERROR lines, `exit=0`.

**Step 8: Commit**

```bash
git add scripts/arena_grid.gd scripts/arena.gd scenes/arena.tscn scenes/main.tscn scripts/main.gd tests/test_arena_grid.gd
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
```gdscript
extends Node
## Boots the main scene, runs a named scenario with simulated input, saves a screenshot, quits.
## Usage: tools/smoke.sh <scenario>. Scenarios: idle, move, combat.
## Prints machine-readable lines prefixed SMOKE_ for tools/smoke.sh to check.

const MAIN := preload("res://scenes/main.tscn")

var scenario := "idle"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.get_slice("=", 1)
	var main := MAIN.instantiate()
	add_child(main)
	await _frames(5)
	await _run_scenario(main)
	await _capture("smoke_%s" % scenario)
	print("SMOKE_DONE scenario=%s" % scenario)
	get_tree().quit(0)


func _run_scenario(main: Node) -> void:
	match scenario:
		"idle":
			await _frames(30)
		"move":
			var player := _player()
			print("SMOKE_PLAYER_START %s" % player.global_position)
			Input.action_press("move_right")
			await _frames(60)
			Input.action_release("move_right")
			print("SMOKE_PLAYER_END %s" % player.global_position)
		"combat":
			var player := _player()
			player.aim_override = player.global_position + Vector2(200, 0)
			Input.action_press("shoot")
			await _frames(150)
			Input.action_release("shoot")
			print("SMOKE_ENEMIES_ALIVE %d" % main.get_node("Enemies").get_child_count())
			print("SMOKE_KILLS %d" % RunState.kills)
		_:
			push_error("unknown scenario %s" % scenario)
			get_tree().quit(2)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://reports")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s.png" % [dir, name]
	var err := image.save_png(path)
	print("SMOKE_SCREENSHOT %s err=%d" % [path, err])
```

**Step 2: Write the shell wrapper**

`tools/smoke.sh`:
```bash
#!/bin/bash
# Usage: tools/smoke.sh [idle|move|combat]
# Opens a window briefly, saves reports/smoke_<scenario>.png, exits 1 on any Godot script error.
set -u
cd "$(dirname "$0")/.."
source tools/godot.sh
scenario="${1:-idle}"
mkdir -p reports

"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1

log="reports/smoke_${scenario}.log"
"$GODOT_BIN" --path . --resolution 1280x720 --position 0,0 res://tools/smoke.tscn -- "--scenario=${scenario}" >"$log" 2>&1
code=$?
grep -E "SMOKE_|SCRIPT ERROR|ERROR:" "$log"

if grep -qE "SCRIPT ERROR|ERROR:" "$log"; then
  echo "smoke: Godot reported errors (see $log)"
  exit 1
fi
if ! grep -q "SMOKE_DONE" "$log"; then
  echo "smoke: scenario did not finish (exit $code, see $log)"
  exit 1
fi
echo "smoke: ok"
```

Run: `chmod +x tools/smoke.sh`

**Step 3: Run the idle scenario**

Run: `tools/smoke.sh idle`
Expected: a window flashes open and closes. Output includes `SMOKE_SCREENSHOT /Users/benjaminzigh/Claude/2d-game/reports/smoke_idle.png err=0`, `SMOKE_DONE scenario=idle`, and `smoke: ok`.

**Step 4: Look at the screenshot**

Open `reports/smoke_idle.png` (with the Read tool, or `open reports/smoke_idle.png`). Expected: a sandy floor with an occasional detail tile, surrounded by a grey brick wall ring, filling the frame. If the frame is black, the capture happened before the first draw; increase the `_frames(5)` warm-up to 15.

**Step 5: Commit**

```bash
git add tools/smoke.gd tools/smoke.tscn tools/smoke.sh
gcommit -m "tools: add screenshot smoke runner"
```

---

### Task 7: Player movement with acceleration and a following camera

**Files:**
- Create: `scripts/movement.gd`
- Create: `scripts/player.gd`
- Create: `scripts/camera.gd`
- Create: `scenes/player.tscn`
- Modify: `scenes/main.tscn`, `scripts/main.gd`
- Test: `tests/test_movement.gd`

**Step 1: Write the failing test**

`tests/test_movement.gd`:
```gdscript
extends GdUnitTestSuite

const EPS := Vector2(0.001, 0.001)


func test_accelerates_toward_wish_direction() -> void:
	var v := Movement.step(Vector2.ZERO, Vector2.RIGHT, 100.0, 500.0, 800.0, 0.1)
	assert_vector(v).is_equal_approx(Vector2(50, 0), EPS)


func test_speed_is_capped_at_max() -> void:
	var v := Movement.step(Vector2.ZERO, Vector2.RIGHT, 100.0, 5000.0, 800.0, 0.1)
	assert_vector(v).is_equal_approx(Vector2(100, 0), EPS)


func test_diagonal_input_is_normalized() -> void:
	var v := Movement.step(Vector2.ZERO, Vector2(1, 1), 100.0, 5000.0, 800.0, 0.1)
	assert_float(v.length()).is_equal_approx(100.0, 0.001)


func test_friction_slows_when_no_input() -> void:
	var v := Movement.step(Vector2(100, 0), Vector2.ZERO, 100.0, 500.0, 800.0, 0.1)
	assert_vector(v).is_equal_approx(Vector2(20, 0), EPS)


func test_friction_stops_at_zero() -> void:
	var v := Movement.step(Vector2(10, 0), Vector2.ZERO, 100.0, 500.0, 800.0, 0.1)
	assert_vector(v).is_equal(Vector2.ZERO)
```

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_movement.gd`
Expected: `Movement` not found.

**Step 3: Write Movement**

`scripts/movement.gd`:
```gdscript
class_name Movement
extends RefCounted
## Top-down velocity integration shared by the player and enemies.


## Returns the new velocity after one step. wish_dir is the raw input vector (any length).
static func step(velocity: Vector2, wish_dir: Vector2, max_speed: float, accel: float, friction: float, delta: float) -> Vector2:
	if wish_dir.length_squared() > 0.0:
		return velocity.move_toward(wish_dir.normalized() * max_speed, accel * delta)
	return velocity.move_toward(Vector2.ZERO, friction * delta)
```

**Step 4: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_movement.gd`
Expected: 5 pass, exit 0.

**Step 5: Write the player scene, player script, and camera script**

`scenes/player.tscn`:
```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/player.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/kenney_tiny_dungeon/tilemap_packed.png" id="2"]
[ext_resource type="Script" path="res://scripts/camera.gd" id="3"]

[sub_resource type="CircleShape2D" id="body_shape"]
radius = 6.0

[node name="Player" type="CharacterBody2D" groups=["player"]]
collision_layer = 1
collision_mask = 18
motion_mode = 1
script = ExtResource("1")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2")
region_enabled = true
region_rect = Rect2(16, 128, 16, 16)

[node name="Shape" type="CollisionShape2D" parent="."]
shape = SubResource("body_shape")

[node name="Muzzle" type="Marker2D" parent="."]
position = Vector2(8, 0)

[node name="Camera" type="Camera2D" parent="."]
zoom = Vector2(2, 2)
limit_left = 0
limit_top = 0
limit_right = 640
limit_bottom = 368
position_smoothing_enabled = true
position_smoothing_speed = 10.0
script = ExtResource("3")
```

`motion_mode = 1` is Floating, the top-down mode with no notion of floor.

`scripts/player.gd`:
```gdscript
extends CharacterBody2D
## The hero. Movement only for now; shooting and health arrive in later tasks.

const MAX_SPEED := 110.0
const ACCEL := 900.0
const FRICTION := 1100.0

## Tests and the smoke tool set this to aim without a mouse. INF means "use the mouse".
var aim_override: Vector2 = Vector2.INF

var move_vel := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle


func _physics_process(delta: float) -> void:
	var wish := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_vel = Movement.step(move_vel, wish, MAX_SPEED, ACCEL, FRICTION, delta)
	velocity = move_vel
	move_and_slide()

	var aim_dir := aim_direction()
	sprite.flip_h = aim_dir.x < 0.0
	muzzle.position = aim_dir * 8.0


func aim_position() -> Vector2:
	if aim_override != Vector2.INF:
		return aim_override
	return get_global_mouse_position()


func aim_direction() -> Vector2:
	var dir := aim_position() - global_position
	return dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
```

`scripts/camera.gd`:
```gdscript
extends Camera2D
## Follows the player (as its child) and leans a little toward the aim point so you see what you aim at.

const MAX_LEAN := 48.0
const LEAN_FACTOR := 0.3

@onready var player: Node2D = get_parent()


func _process(_delta: float) -> void:
	var to_aim: Vector2 = player.aim_position() - player.global_position
	offset = to_aim.limit_length(MAX_LEAN) * LEAN_FACTOR
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
```gdscript
extends Node2D
## Root of a run. Owns the arena, the player, and restart logic.

@onready var arena: Arena = $Arena
@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	player.global_position = arena.bounds().get_center()
	player.get_node("Camera").reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()


func restart() -> void:
	Engine.time_scale = 1.0
	RunState.start_run()
	get_tree().reload_current_scene()
```

**Step 7: Smoke test movement**

Run: `tools/smoke.sh move`
Expected: `SMOKE_PLAYER_START (320, 184)` and `SMOKE_PLAYER_END (x, 184)` with x noticeably larger, roughly 80 to 110 more. `smoke: ok`.

Then open `reports/smoke_move.png`. Expected: the knight sprite standing on the sandy floor, right of center, walls visible, view zoomed 2x.

**Step 8: Run the full test suite**

Run: `tools/test.sh`
Expected: all suites pass, exit 0.

**Step 9: Commit and tag Milestone 0**

```bash
git add scripts/movement.gd scripts/player.gd scripts/camera.gd scenes/player.tscn scenes/main.tscn scripts/main.gd tests/test_movement.gd
gcommit -m "feat: player movement with acceleration and following camera"
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
```gdscript
extends GdUnitTestSuite


func test_pistol_resource_is_valid() -> void:
	var pistol: WeaponDef = load("res://data/weapons/pistol.tres")
	assert_object(pistol).is_not_null()
	assert_array(pistol.validate()).is_empty()


func test_validate_reports_bad_values() -> void:
	var def := WeaponDef.new()
	def.damage = 0.0
	def.fire_rate = -1.0
	def.projectile_count = 0
	var errors := def.validate()
	assert_array(errors).has_size(3)


func test_single_shot_has_no_offset() -> void:
	assert_array(WeaponDef.spread_offsets(1, 0.5)).is_equal([0.0])


func test_three_shots_fan_symmetrically() -> void:
	var offsets := WeaponDef.spread_offsets(3, 0.4)
	assert_float(offsets[0]).is_equal_approx(-0.2, 0.0001)
	assert_float(offsets[1]).is_equal_approx(0.0, 0.0001)
	assert_float(offsets[2]).is_equal_approx(0.2, 0.0001)
```

`tests/test_fire_controller.gd`:
```gdscript
extends GdUnitTestSuite


func test_first_shot_fires_immediately() -> void:
	var fc := FireController.new()
	assert_bool(fc.try_fire(10.0)).is_true()


func test_second_shot_waits_for_cooldown() -> void:
	var fc := FireController.new()
	fc.try_fire(10.0)
	assert_bool(fc.try_fire(10.0)).is_false()
	fc.tick(0.05)
	assert_bool(fc.try_fire(10.0)).is_false()
	fc.tick(0.05)
	assert_bool(fc.try_fire(10.0)).is_true()


func test_fire_rate_over_one_second() -> void:
	var fc := FireController.new()
	var shots := 0
	for i in 60:
		if fc.try_fire(10.0):
			shots += 1
		fc.tick(1.0 / 60.0)
	assert_int(shots).is_between(9, 11)
```

**Step 2: Run to verify they fail**

Run: `tools/test.sh -a res://tests/test_weapon_def.gd -a res://tests/test_fire_controller.gd`
Expected: `WeaponDef` and `FireController` not found.

**Step 3: Write WeaponDef, the pistol resource, and FireController**

`scripts/defs/weapon_def.gd`:
```gdscript
class_name WeaponDef
extends Resource
## Data for one weapon. Upgrades will later mutate a copy of this.

@export var damage: float = 1.0
@export var fire_rate: float = 6.0  ## shots per second
@export var projectile_speed: float = 320.0
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0  ## total arc across all projectiles when count > 1
@export var inaccuracy_degrees: float = 2.0  ## random jitter per shot
@export var lifetime: float = 1.2  ## seconds before a projectile despawns
@export var knockback: float = 120.0  ## applied to the enemy hit
@export var recoil: float = 25.0  ## applied to the shooter
@export var pierce: int = 0  ## extra enemies a projectile passes through


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if damage <= 0.0:
		errors.append("damage must be > 0")
	if fire_rate <= 0.0:
		errors.append("fire_rate must be > 0")
	if projectile_count < 1:
		errors.append("projectile_count must be >= 1")
	if projectile_speed <= 0.0:
		errors.append("projectile_speed must be > 0")
	if lifetime <= 0.0:
		errors.append("lifetime must be > 0")
	return errors


## Angle offsets (radians) for count projectiles fanned evenly across spread_radians.
static func spread_offsets(count: int, spread_radians: float) -> Array[float]:
	var offsets: Array[float] = []
	if count <= 1:
		offsets.append(0.0)
		return offsets
	for i in count:
		offsets.append((float(i) / float(count - 1) - 0.5) * spread_radians)
	return offsets
```

`data/weapons/pistol.tres`:
```
[gd_resource type="Resource" script_class="WeaponDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/defs/weapon_def.gd" id="1"]

[resource]
script = ExtResource("1")
damage = 1.0
fire_rate = 7.0
projectile_speed = 340.0
projectile_count = 1
spread_degrees = 0.0
inaccuracy_degrees = 2.5
lifetime = 1.1
knockback = 140.0
recoil = 25.0
pierce = 0
```

`scripts/fire_controller.gd`:
```gdscript
class_name FireController
extends RefCounted
## Tracks the cooldown between shots. Pure logic so it is testable without a scene.

var cooldown := 0.0


func tick(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)


## Returns true and starts the cooldown if a shot is allowed now.
func try_fire(fire_rate: float) -> bool:
	if cooldown > 0.0:
		return false
	cooldown = 1.0 / fire_rate
	return true
```

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
```gdscript
class_name Projectile
extends Area2D
## A player shot. Moves in a straight line, damages the first thing with a Health child it touches.

var direction := Vector2.RIGHT
var speed := 300.0
var damage := 1.0
var knockback := 100.0
var pierce := 0
var life := 1.0

var _hits := 0


func setup(def: WeaponDef, dir: Vector2) -> void:
	direction = dir.normalized()
	speed = def.projectile_speed
	damage = def.damage
	knockback = def.knockback
	pierce = def.pierce
	life = def.lifetime
	rotation = direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2(-4, 0), 2.0, Color(1.0, 0.6, 0.2, 0.6))
	draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.95, 0.6))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("walls"):
		queue_free()
		return
	var health := body.get_node_or_null("Health") as Health
	if health == null:
		return
	health.take_damage(damage, direction * knockback)
	_hits += 1
	if _hits > pierce:
		queue_free()
```

`Health` does not exist yet; it arrives in Task 9. Until then the projectile only despawns on walls and on lifetime.

**Step 6: Add shooting to the player**

`scenes/player.tscn`: add a weapon export and reference the pistol. Replace the header and the root node block:
```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/player.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/kenney_tiny_dungeon/tilemap_packed.png" id="2"]
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
```gdscript
extends CharacterBody2D
## The hero: movement and shooting. Health arrives in Task 12.

const PROJECTILE := preload("res://scenes/projectile.tscn")
const MAX_SPEED := 110.0
const ACCEL := 900.0
const FRICTION := 1100.0
const KNOCKBACK_DECAY := 900.0

@export var weapon: WeaponDef

## Tests and the smoke tool set this to aim without a mouse. INF means "use the mouse".
var aim_override: Vector2 = Vector2.INF

var move_vel := Vector2.ZERO
var knockback := Vector2.ZERO
var fire := FireController.new()

@onready var sprite: Sprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle


func _ready() -> void:
	assert(weapon != null, "Player needs a WeaponDef")
	var errors := weapon.validate()
	assert(errors.is_empty(), "Invalid weapon: %s" % ", ".join(errors))


func _physics_process(delta: float) -> void:
	var wish := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_vel = Movement.step(move_vel, wish, MAX_SPEED, ACCEL, FRICTION, delta)
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	velocity = move_vel + knockback
	move_and_slide()

	var aim_dir := aim_direction()
	sprite.flip_h = aim_dir.x < 0.0
	muzzle.position = aim_dir * 8.0

	fire.tick(delta)
	if Input.is_action_pressed("shoot") and fire.try_fire(weapon.fire_rate):
		_shoot(aim_dir)


func aim_position() -> Vector2:
	if aim_override != Vector2.INF:
		return aim_override
	return get_global_mouse_position()


func aim_direction() -> Vector2:
	var dir := aim_position() - global_position
	return dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT


func _shoot(dir: Vector2) -> void:
	var base_angle := dir.angle()
	var jitter := deg_to_rad(weapon.inaccuracy_degrees)
	for offset in WeaponDef.spread_offsets(weapon.projectile_count, deg_to_rad(weapon.spread_degrees)):
		var angle := base_angle + offset + RunState.rng.randf_range(-jitter, jitter)
		var shot: Projectile = PROJECTILE.instantiate()
		shot.setup(weapon, Vector2.from_angle(angle))
		shot.global_position = muzzle.global_position
		get_parent().add_child(shot)
	knockback -= dir * weapon.recoil
	Events.shot_fired.emit(muzzle.global_position, dir)
```

Projectiles are added to the player's parent (Main) so they do not move with the player.

**Step 7: Smoke test combat**

Run: `tools/smoke.sh combat`
Expected: `smoke: ok`, `SMOKE_ENEMIES_ALIVE 0`, `SMOKE_KILLS 0` (no enemies yet). Open `reports/smoke_combat.png`: a line of small yellow dots streaming right from the knight toward the wall.

**Step 8: Run all tests and commit**

Run: `tools/test.sh` (exit 0), then:
```bash
git add scripts/defs scripts/fire_controller.gd scripts/projectile.gd scenes/projectile.tscn data scripts/player.gd scenes/player.tscn tests/test_weapon_def.gd tests/test_fire_controller.gd
gcommit -m "feat: pistol weapon def, fire cooldown, and projectiles"
```

---

### Task 9: Health component and the Chaser enemy

**Files:**
- Create: `scripts/health.gd`
- Create: `scripts/defs/enemy_def.gd`
- Create: `data/enemies/chaser.tres`
- Create: `scripts/enemy.gd`
- Create: `scenes/enemies/chaser.tscn`
- Create: `assets/shaders/flash.gdshader`
- Test: `tests/test_health.gd`, `tests/test_enemy_def.gd`, `tests/test_projectile.gd`, `tests/test_chaser_scene.gd`

**Step 1: Write the failing unit tests**

`tests/test_health.gd`:
```gdscript
extends GdUnitTestSuite


func _health(max_hp: float) -> Health:
	var h: Health = auto_free(Health.new())
	h.setup(max_hp)
	return h


func test_take_damage_reduces_hp() -> void:
	var h := _health(3.0)
	h.take_damage(1.0)
	assert_float(h.hp).is_equal(2.0)
	assert_bool(h.dead).is_false()


func test_overkill_clamps_to_zero_and_dies_once() -> void:
	var h := _health(3.0)
	var deaths := [0]
	h.died.connect(func() -> void: deaths[0] += 1)
	h.take_damage(10.0)
	h.take_damage(1.0)
	assert_float(h.hp).is_equal(0.0)
	assert_bool(h.dead).is_true()
	assert_int(deaths[0]).is_equal(1)


func test_damaged_signal_carries_knockback() -> void:
	var h := _health(3.0)
	var received := []
	h.damaged.connect(func(amount: float, kb: Vector2) -> void: received.append([amount, kb]))
	h.take_damage(1.0, Vector2(5, 0))
	assert_array(received).is_equal([[1.0, Vector2(5, 0)]])
```

`tests/test_enemy_def.gd`:
```gdscript
extends GdUnitTestSuite


func test_chaser_resource_is_valid() -> void:
	var def: EnemyDef = load("res://data/enemies/chaser.tres")
	assert_object(def).is_not_null()
	assert_array(def.validate()).is_empty()
	assert_str(def.id).is_equal("chaser")


func test_validate_reports_bad_values() -> void:
	var def := EnemyDef.new()
	def.max_hp = 0.0
	def.speed = -5.0
	assert_array(def.validate()).has_size(2)
```

`tests/test_projectile.gd`:
```gdscript
extends GdUnitTestSuite

const ProjectileScene := preload("res://scenes/projectile.tscn")


func _target() -> Node2D:
	var body: Node2D = auto_free(Node2D.new())
	var health := Health.new()
	health.name = "Health"
	health.setup(3.0)
	body.add_child(health)
	return body


func test_hit_damages_health_and_frees_projectile() -> void:
	var shot: Projectile = auto_free(ProjectileScene.instantiate())
	shot.damage = 2.0
	shot.pierce = 0
	var body := _target()
	shot._on_body_entered(body)
	assert_float(body.get_node("Health").hp).is_equal(1.0)
	assert_bool(shot.is_queued_for_deletion()).is_true()


func test_pierce_keeps_projectile_alive_for_extra_hits() -> void:
	var shot: Projectile = auto_free(ProjectileScene.instantiate())
	shot.pierce = 1
	shot._on_body_entered(_target())
	assert_bool(shot.is_queued_for_deletion()).is_false()
	shot._on_body_entered(_target())
	assert_bool(shot.is_queued_for_deletion()).is_true()


func test_body_without_health_is_ignored() -> void:
	var shot: Projectile = auto_free(ProjectileScene.instantiate())
	var plain: Node2D = auto_free(Node2D.new())
	shot._on_body_entered(plain)
	assert_bool(shot.is_queued_for_deletion()).is_false()
```

Note: `is_queued_for_deletion()` only becomes true after `queue_free()` on a node that is inside the tree. `auto_free` does not add it, so add the projectile with `add_child(shot)` right after instantiating in each test. Update the three tests accordingly: after `auto_free(...)`, call `add_child(shot)`.

`tests/test_chaser_scene.gd`:
```gdscript
extends GdUnitTestSuite
## Scene test: a Chaser moves toward its target once its spawn delay has passed.


func test_chaser_moves_toward_target() -> void:
	var target: Node2D = auto_free(Node2D.new())
	target.position = Vector2(0, 0)
	add_child(target)

	var runner := scene_runner("res://scenes/enemies/chaser.tscn")
	var enemy: Enemy = runner.scene()
	enemy.target = target
	enemy.global_position = Vector2(120, 0)

	await runner.await_millis(1500)

	assert_float(enemy.global_position.x).is_less(100.0)
	assert_int(enemy.state).is_equal(Enemy.State.ACTIVE)
```

**Step 2: Run to verify they fail**

Run: `tools/test.sh`
Expected: failures for `Health`, `EnemyDef`, `Enemy` not found.

**Step 3: Write Health**

`scripts/health.gd`:
```gdscript
class_name Health
extends Node
## Hit points for anything that can be damaged. Emits signals; owners react.

signal damaged(amount: float, knockback: Vector2)
signal died()

@export var max_hp: float = 3.0

var hp: float = -1.0
var dead := false


func _ready() -> void:
	if hp < 0.0:
		hp = max_hp


## Owners call this before the node is ready when the max comes from a definition.
func setup(max_hp_value: float) -> void:
	max_hp = max_hp_value
	hp = max_hp_value
	dead = false


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	hp = maxf(hp - amount, 0.0)
	damaged.emit(amount, knockback)
	if hp == 0.0:
		dead = true
		died.emit()
```

**Step 4: Write EnemyDef and the chaser resource**

`scripts/defs/enemy_def.gd`:
```gdscript
class_name EnemyDef
extends Resource
## Data for one enemy type. Behavior lives in enemy.gd; numbers live here.

@export var id: String = "enemy"
@export var max_hp: float = 3.0
@export var speed: float = 70.0
@export var accel: float = 600.0
@export var contact_damage: int = 1
@export var spawn_delay: float = 0.5  ## seconds of fade-in before it can move or hurt
@export var sprite_region: Rect2 = Rect2(0, 160, 16, 16)
@export var score: int = 10


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if max_hp <= 0.0:
		errors.append("max_hp must be > 0")
	if speed < 0.0:
		errors.append("speed must be >= 0")
	if accel <= 0.0:
		errors.append("accel must be > 0")
	if spawn_delay < 0.0:
		errors.append("spawn_delay must be >= 0")
	return errors
```

`data/enemies/chaser.tres`:
```
[gd_resource type="Resource" script_class="EnemyDef" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/defs/enemy_def.gd" id="1"]

[resource]
script = ExtResource("1")
id = "chaser"
max_hp = 3.0
speed = 72.0
accel = 650.0
contact_damage = 1
spawn_delay = 0.5
sprite_region = Rect2(0, 160, 16, 16)
score = 10
```

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
```gdscript
class_name Enemy
extends CharacterBody2D
## Generic enemy body driven by an EnemyDef. The Chaser is this script with the chaser def.
## State machine: SPAWNING (fade in, harmless) -> ACTIVE (chase) -> DEAD.

enum State { SPAWNING, ACTIVE, DEAD }

const FLASH_SHADER := preload("res://assets/shaders/flash.gdshader")
const KNOCKBACK_DECAY := 700.0

@export var def: EnemyDef

var target: Node2D
var state := State.SPAWNING
var move_vel := Vector2.ZERO
var knockback := Vector2.ZERO
var flash_material: ShaderMaterial

var _state_time := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var health: Health = $Health


func _ready() -> void:
	assert(def != null, "Enemy needs an EnemyDef")
	health.setup(def.max_hp)
	sprite.region_rect = def.sprite_region
	flash_material = ShaderMaterial.new()
	flash_material.shader = FLASH_SHADER
	sprite.material = flash_material
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if target == null:
		target = get_tree().get_first_node_in_group("player")
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, def.spawn_delay)


func is_harmful() -> bool:
	return state == State.ACTIVE


func _physics_process(delta: float) -> void:
	_state_time += delta
	match state:
		State.SPAWNING:
			if _state_time >= def.spawn_delay:
				_enter(State.ACTIVE)
		State.ACTIVE:
			var wish := Vector2.ZERO
			if is_instance_valid(target):
				wish = target.global_position - global_position
			move_vel = Movement.step(move_vel, wish, def.speed, def.accel, def.accel, delta)
			knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
			velocity = move_vel + knockback
			move_and_slide()
			if wish.x != 0.0:
				sprite.flip_h = wish.x < 0.0
		State.DEAD:
			pass


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0


func _on_damaged(amount: float, kb: Vector2) -> void:
	knockback += kb
	if is_inside_tree() and has_node("/root/Juice"):
		Juice.flash(flash_material)
		Juice.add_trauma(0.12)
	Events.enemy_hit.emit(self, amount, global_position)


func _on_died() -> void:
	_enter(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	Events.enemy_died.emit(self, global_position)
	if has_node("/root/Juice"):
		Juice.add_trauma(0.3)
		Juice.hitstop(0.06)
	queue_free()
```

The `has_node("/root/Juice")` guards let this script run before Task 11 adds the Juice autoload, and keep the unit tests independent of it.

`scenes/enemies/chaser.tscn`:
```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/enemy.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/kenney_tiny_dungeon/tilemap_packed.png" id="2"]
[ext_resource type="Resource" path="res://data/enemies/chaser.tres" id="3"]
[ext_resource type="Script" path="res://scripts/health.gd" id="4"]

[sub_resource type="CircleShape2D" id="body_shape"]
radius = 5.0

[node name="Chaser" type="CharacterBody2D" groups=["enemies"]]
collision_layer = 2
collision_mask = 18
motion_mode = 1
script = ExtResource("1")
def = ExtResource("3")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2")
region_enabled = true
region_rect = Rect2(0, 160, 16, 16)

[node name="Shape" type="CollisionShape2D" parent="."]
shape = SubResource("body_shape")

[node name="Health" type="Node" parent="."]
script = ExtResource("4")
```

**Step 7: Run all tests**

Run: `tools/test.sh`
Expected: every suite passes, exit 0. The chaser scene test takes about 1.5 seconds. If it fails with the enemy still at x=120, check that `state` reached ACTIVE; if it did not, physics is not stepping in the test process, and the fallback is to call `enemy._physics_process(1.0 / 60.0)` in a loop of 90 iterations instead of `await_millis`.

**Step 8: Commit**

```bash
git add scripts/health.gd scripts/defs/enemy_def.gd data/enemies scripts/enemy.gd scenes/enemies assets/shaders tests/test_health.gd tests/test_enemy_def.gd tests/test_projectile.gd tests/test_chaser_scene.gd
gcommit -m "feat: Health component, EnemyDef, and Chaser enemy"
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
```gdscript
extends GdUnitTestSuite

const BOUNDS := Rect2(16, 16, 608, 336)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_interval_ramps_from_start_to_min() -> void:
	assert_float(SpawnMath.interval(2.0, 0.5, 60.0, 0.0)).is_equal(2.0)
	assert_float(SpawnMath.interval(2.0, 0.5, 60.0, 30.0)).is_equal(1.25)
	assert_float(SpawnMath.interval(2.0, 0.5, 60.0, 60.0)).is_equal(0.5)
	assert_float(SpawnMath.interval(2.0, 0.5, 60.0, 500.0)).is_equal(0.5)


func test_positions_stay_inside_bounds_and_away_from_player() -> void:
	var rng := _rng(42)
	var player := BOUNDS.get_center()
	for i in 200:
		var p := SpawnMath.pick_position(BOUNDS, player, 96.0, rng)
		assert_bool(BOUNDS.has_point(p)).is_true()
		assert_float(p.distance_to(player)).is_greater_equal(96.0)


func test_same_seed_same_positions() -> void:
	var a := SpawnMath.pick_position(BOUNDS, Vector2.ZERO, 50.0, _rng(9))
	var b := SpawnMath.pick_position(BOUNDS, Vector2.ZERO, 50.0, _rng(9))
	assert_vector(a).is_equal(b)


func test_impossible_distance_still_returns_a_point_in_bounds() -> void:
	var p := SpawnMath.pick_position(BOUNDS, BOUNDS.get_center(), 10000.0, _rng(1))
	assert_bool(BOUNDS.has_point(p)).is_true()
```

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_spawn_math.gd`
Expected: `SpawnMath` not found.

**Step 3: Write SpawnMath**

`scripts/spawn_math.gd`:
```gdscript
class_name SpawnMath
extends RefCounted
## Pure helpers for when and where enemies appear.

const EDGE_MARGIN := 12.0


## Seconds between spawns, easing linearly from start to min_interval over ramp_seconds.
static func interval(start: float, min_interval: float, ramp_seconds: float, elapsed: float) -> float:
	var t := clampf(elapsed / ramp_seconds, 0.0, 1.0)
	return lerpf(start, min_interval, t)


## A random point inside bounds at least min_distance from avoid. Falls back to the
## farthest candidate found when no candidate satisfies the distance.
static func pick_position(bounds: Rect2, avoid: Vector2, min_distance: float, rng: RandomNumberGenerator, attempts: int = 24) -> Vector2:
	var inner := bounds.grow(-EDGE_MARGIN)
	var best := inner.get_center()
	var best_distance := -1.0
	for i in attempts:
		var p := Vector2(
			rng.randf_range(inner.position.x, inner.end.x),
			rng.randf_range(inner.position.y, inner.end.y),
		)
		var d := p.distance_to(avoid)
		if d >= min_distance:
			return p
		if d > best_distance:
			best = p
			best_distance = d
	return best
```

**Step 4: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_spawn_math.gd`
Expected: 4 pass, exit 0.

**Step 5: Write the Spawner and wire it into Main**

`scripts/spawner.gd`:
```gdscript
class_name Spawner
extends Node
## Spawns Chasers on a timer that speeds up over the run. Waves replace this in Milestone 2.

const CHASER := preload("res://scenes/enemies/chaser.tscn")

@export var interval_start := 1.6
@export var interval_min := 0.45
@export var ramp_seconds := 90.0
@export var max_alive := 14
@export var min_player_distance := 96.0
@export var initial_delay := 1.0

var arena: Arena
var player: Node2D
var enemies_parent: Node

var _timer := 0.0
var _alive := 0


func _ready() -> void:
	_timer = initial_delay


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SpawnMath.interval(interval_start, interval_min, ramp_seconds, RunState.elapsed)
	if _alive >= max_alive or not is_instance_valid(player):
		return
	spawn_one()


func spawn_one() -> Enemy:
	var pos := SpawnMath.pick_position(arena.bounds(), player.global_position, min_player_distance, RunState.rng)
	var enemy: Enemy = CHASER.instantiate()
	enemy.target = player
	enemy.global_position = pos
	enemies_parent.add_child(enemy)
	_alive += 1
	enemy.tree_exited.connect(func() -> void: _alive -= 1)
	Events.enemy_spawned.emit(enemy)
	return enemy
```

`scenes/main.tscn` (replace whole file):
```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/arena.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="3"]
[ext_resource type="Script" path="res://scripts/spawner.gd" id="4"]

[node name="Main" type="Node2D"]
script = ExtResource("1")

[node name="Arena" parent="." instance=ExtResource("2")]

[node name="Enemies" type="Node2D" parent="."]

[node name="Player" parent="." instance=ExtResource("3")]

[node name="Spawner" type="Node" parent="."]
script = ExtResource("4")
```

`scripts/main.gd` (replace whole file):
```gdscript
extends Node2D
## Root of a run. Owns the arena, the player, the spawner, and restart logic.

@onready var arena: Arena = $Arena
@onready var player: CharacterBody2D = $Player
@onready var spawner: Spawner = $Spawner
@onready var enemies: Node2D = $Enemies


func _ready() -> void:
	player.global_position = arena.bounds().get_center()
	player.get_node("Camera").reset_smoothing()
	spawner.arena = arena
	spawner.player = player
	spawner.enemies_parent = enemies


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()


func restart() -> void:
	Engine.time_scale = 1.0
	RunState.start_run()
	get_tree().reload_current_scene()
```

**Step 6: Smoke test combat**

Run: `tools/smoke.sh combat`
Expected: `smoke: ok`. `SMOKE_ENEMIES_ALIVE` is 1 or more (150 frames is 2.5 s, so one or two spawns). `SMOKE_KILLS` may be 0 or more depending on whether a bat crossed the shot line. Open `reports/smoke_combat.png` and confirm at least one bat sprite is on the floor.

**Step 7: Run all tests and commit**

Run: `tools/test.sh` (exit 0), then:
```bash
git add scripts/spawn_math.gd scripts/spawner.gd scenes/main.tscn scripts/main.gd tests/test_spawn_math.gd
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
```gdscript
extends GdUnitTestSuite


func test_no_trauma_no_shake() -> void:
	assert_vector(JuiceMath.shake_offset(0.0, 8.0, 1.0, 1.0)).is_equal(Vector2.ZERO)


func test_full_trauma_uses_full_offset() -> void:
	assert_vector(JuiceMath.shake_offset(1.0, 8.0, 1.0, -1.0)).is_equal(Vector2(8, -8))


func test_shake_is_quadratic_in_trauma() -> void:
	assert_vector(JuiceMath.shake_offset(0.5, 8.0, 1.0, 1.0)).is_equal(Vector2(2, 2))


func test_trauma_above_one_is_clamped() -> void:
	assert_vector(JuiceMath.shake_offset(3.0, 8.0, 1.0, 1.0)).is_equal(Vector2(8, 8))


func test_decay_floors_at_zero() -> void:
	assert_float(JuiceMath.decay(0.5, 2.0, 0.1)).is_equal_approx(0.3, 0.0001)
	assert_float(JuiceMath.decay(0.1, 2.0, 1.0)).is_equal(0.0)
```

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
```gdscript
extends Node
## Central impact feedback: trauma for screen shake, hitstop, and sprite flash.
## Every tunable feel number lives here so balancing feel means editing one file.

const TRAUMA_DECAY := 1.8
const HITSTOP_SCALE := 0.05
const FLASH_DURATION := 0.08

var trauma := 0.0

var _hitstop_id := 0


func _process(delta: float) -> void:
	# delta is already scaled by Engine.time_scale, so use the unscaled frame time for decay.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	trauma = JuiceMath.decay(trauma, TRAUMA_DECAY, real_delta)


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


## Freezes the game for duration real seconds. Overlapping calls extend to the latest one.
func hitstop(duration: float) -> void:
	_hitstop_id += 1
	var my_id := _hitstop_id
	Engine.time_scale = HITSTOP_SCALE
	await get_tree().create_timer(duration, true, false, true).timeout
	if my_id == _hitstop_id:
		Engine.time_scale = 1.0


## Flashes a sprite white via the flash shader uniform.
func flash(material: ShaderMaterial) -> void:
	material.set_shader_parameter("flash", 1.0)
	var tween := create_tween()
	tween.tween_property(material, "shader_parameter/flash", 0.0, FLASH_DURATION)
```

`create_timer(duration, true, false, true)`: process always, not in physics, ignore time scale. The last flag is what makes hitstop end while time is slowed.

Add `Juice` to `project.godot` autoloads, after `RunState`:
```ini
[autoload]

Events="*res://scripts/autoload/events.gd"
RunState="*res://scripts/autoload/run_state.gd"
Juice="*res://scripts/autoload/juice.gd"
```

**Step 6: Add shake to the camera**

`scripts/camera.gd` (replace whole file):
```gdscript
extends Camera2D
## Follows the player (as its child), leans toward the aim point, and shakes from Juice.trauma.
## Shake randomness uses the global RNG on purpose: it is cosmetic and must not disturb the run seed.

const MAX_LEAN := 48.0
const LEAN_FACTOR := 0.3
const MAX_SHAKE := 7.0

@onready var player: Node2D = get_parent()


func _process(_delta: float) -> void:
	var to_aim: Vector2 = player.aim_position() - player.global_position
	var lean := to_aim.limit_length(MAX_LEAN) * LEAN_FACTOR
	var shake := JuiceMath.shake_offset(Juice.trauma, MAX_SHAKE, randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	offset = lean + shake
```

**Step 7: Write the muzzle flash and the Fx node**

`scripts/muzzle_flash.gd`:
```gdscript
class_name MuzzleFlash
extends Node2D
## A bright blob at the muzzle that shrinks away over a few frames.

const DURATION := 0.06


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), DURATION)
	tween.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2(3, 0), 5.0, Color(1.0, 0.85, 0.4, 0.9))
	draw_circle(Vector2(3, 0), 2.5, Color(1.0, 1.0, 1.0))
```

`scripts/fx.gd`:
```gdscript
extends Node2D
## Listens to Events and spawns visual effects. Nothing here affects gameplay.


func _ready() -> void:
	Events.shot_fired.connect(_on_shot_fired)
	Events.enemy_hit.connect(_on_enemy_hit)
	Events.enemy_died.connect(_on_enemy_died)


func _on_shot_fired(muzzle_position: Vector2, direction: Vector2) -> void:
	var flash := MuzzleFlash.new()
	flash.global_position = muzzle_position
	flash.rotation = direction.angle()
	add_child(flash)


func _on_enemy_hit(_enemy: Node2D, _damage: float, hit_position: Vector2) -> void:
	_burst(hit_position, 6, Color(1.0, 0.9, 0.5), 70.0, 0.18)


func _on_enemy_died(_enemy: Node2D, death_position: Vector2) -> void:
	_burst(death_position, 18, Color(1.0, 0.45, 0.35), 130.0, 0.4)


func _burst(at: Vector2, amount: int, color: Color, speed: float, life: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 2.0
	p.damping_max = speed * 3.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.global_position = at
	add_child(p)
	p.finished.connect(p.queue_free)
	p.emitting = true
```

Add the Fx node to `scenes/main.tscn`. Change the header to `load_steps=6`, add the ext_resource, and add the node after Enemies:
```
[ext_resource type="Script" path="res://scripts/fx.gd" id="5"]
```
```
[node name="Fx" type="Node2D" parent="."]
script = ExtResource("5")
```

**Step 8: Smoke test and inspect**

Run: `tools/smoke.sh combat`
Expected: `smoke: ok`. Open `reports/smoke_combat.png`: projectiles streaming right, a muzzle flash at the knight, and if a bat was hit, sparks. The frame may also be offset a few pixels by shake, which is expected.

Run: `tools/test.sh`
Expected: exit 0. The chaser scene test now exercises `Juice.flash` and `hitstop` guards.

**Step 9: Commit**

```bash
git add scripts/juice_math.gd scripts/autoload/juice.gd scripts/muzzle_flash.gd scripts/fx.gd project.godot scripts/camera.gd scenes/main.tscn tests/test_juice_math.gd
gcommit -m "feat: screen shake, hitstop, hit flash, particles, muzzle flash"
```

---

### Task 12: Player health, contact damage, death, restart

**Files:**
- Modify: `scripts/player.gd`, `scenes/player.tscn`, `scripts/main.gd`
- Test: `tests/test_player_hit_rules.gd`

**Step 1: Write the failing test**

Contact damage rules are pure: pull them into a static helper so they are testable.

`tests/test_player_hit_rules.gd`:
```gdscript
extends GdUnitTestSuite


func test_hit_allowed_when_not_invulnerable() -> void:
	assert_bool(PlayerHitRules.can_take_hit(0.0)).is_true()


func test_hit_blocked_during_invulnerability() -> void:
	assert_bool(PlayerHitRules.can_take_hit(0.3)).is_false()


func test_knockback_points_away_from_attacker() -> void:
	var kb := PlayerHitRules.knockback_from(Vector2(10, 0), Vector2(0, 0), 100.0)
	assert_vector(kb).is_equal(Vector2(100, 0))


func test_knockback_with_overlapping_positions_still_has_length() -> void:
	var kb := PlayerHitRules.knockback_from(Vector2(5, 5), Vector2(5, 5), 100.0)
	assert_float(kb.length()).is_equal_approx(100.0, 0.001)


func test_blink_is_visible_half_the_time() -> void:
	assert_bool(PlayerHitRules.blink_visible(0.0)).is_true()
	assert_bool(PlayerHitRules.blink_visible(0.03)).is_false()
	assert_bool(PlayerHitRules.blink_visible(0.08)).is_true()
```

**Step 2: Run to verify it fails**

Run: `tools/test.sh -a res://tests/test_player_hit_rules.gd`
Expected: `PlayerHitRules` not found.

**Step 3: Write the rules**

`scripts/player_hit_rules.gd`:
```gdscript
class_name PlayerHitRules
extends RefCounted
## Pure rules for taking contact damage.

const BLINK_PERIOD := 0.1


static func can_take_hit(invuln_left: float) -> bool:
	return invuln_left <= 0.0


## Knockback pushing the player away from the attacker. Falls back to a fixed direction if they overlap.
static func knockback_from(player_position: Vector2, attacker_position: Vector2, strength: float) -> Vector2:
	var away := player_position - attacker_position
	if away.length_squared() == 0.0:
		away = Vector2.UP
	return away.normalized() * strength


## While invulnerable the sprite blinks: visible for the first half of each period, hidden for the second.
static func blink_visible(invuln_left: float) -> bool:
	if invuln_left <= 0.0:
		return true
	return fmod(invuln_left, BLINK_PERIOD) < BLINK_PERIOD * 0.5
```

**Step 4: Run to verify it passes**

Run: `tools/test.sh -a res://tests/test_player_hit_rules.gd`
Expected: 5 pass, exit 0.

**Step 5: Add a hurtbox to the player scene**

In `scenes/player.tscn`, bump `load_steps` to 7, add a second sub_resource, and add a Hurtbox node after Shape:
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
```gdscript
extends CharacterBody2D
## The hero: movement, shooting, and taking contact damage.

const PROJECTILE := preload("res://scenes/projectile.tscn")
const MAX_SPEED := 110.0
const ACCEL := 900.0
const FRICTION := 1100.0
const KNOCKBACK_DECAY := 900.0
const MAX_HP := 6
const INVULN_TIME := 0.8
const HIT_KNOCKBACK := 200.0

@export var weapon: WeaponDef

## Tests and the smoke tool set this to aim without a mouse. INF means "use the mouse".
var aim_override: Vector2 = Vector2.INF

var hp: int = MAX_HP
var dead := false
var invuln_left := 0.0
var move_vel := Vector2.ZERO
var knockback := Vector2.ZERO
var fire := FireController.new()

@onready var sprite: Sprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	assert(weapon != null, "Player needs a WeaponDef")
	var errors := weapon.validate()
	assert(errors.is_empty(), "Invalid weapon: %s" % ", ".join(errors))


func _physics_process(delta: float) -> void:
	if dead:
		return
	var wish := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_vel = Movement.step(move_vel, wish, MAX_SPEED, ACCEL, FRICTION, delta)
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	velocity = move_vel + knockback
	move_and_slide()

	var aim_dir := aim_direction()
	sprite.flip_h = aim_dir.x < 0.0
	muzzle.position = aim_dir * 8.0

	fire.tick(delta)
	if Input.is_action_pressed("shoot") and fire.try_fire(weapon.fire_rate):
		_shoot(aim_dir)

	invuln_left = maxf(invuln_left - delta, 0.0)
	sprite.visible = PlayerHitRules.blink_visible(invuln_left)
	_check_contact()


func aim_position() -> Vector2:
	if aim_override != Vector2.INF:
		return aim_override
	return get_global_mouse_position()


func aim_direction() -> Vector2:
	var dir := aim_position() - global_position
	return dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT


func _shoot(dir: Vector2) -> void:
	var base_angle := dir.angle()
	var jitter := deg_to_rad(weapon.inaccuracy_degrees)
	for offset in WeaponDef.spread_offsets(weapon.projectile_count, deg_to_rad(weapon.spread_degrees)):
		var angle := base_angle + offset + RunState.rng.randf_range(-jitter, jitter)
		var shot: Projectile = PROJECTILE.instantiate()
		shot.setup(weapon, Vector2.from_angle(angle))
		shot.global_position = muzzle.global_position
		get_parent().add_child(shot)
	knockback -= dir * weapon.recoil
	Events.shot_fired.emit(muzzle.global_position, dir)


## Polls overlaps every physics frame so an enemy that stays on top of us keeps hurting after i-frames end.
func _check_contact() -> void:
	if not PlayerHitRules.can_take_hit(invuln_left):
		return
	for body in hurtbox.get_overlapping_bodies():
		var enemy := body as Enemy
		if enemy != null and enemy.is_harmful():
			_take_hit(enemy.def.contact_damage, enemy.global_position)
			return


func _take_hit(damage: int, from: Vector2) -> void:
	hp -= damage
	invuln_left = INVULN_TIME
	knockback = PlayerHitRules.knockback_from(global_position, from, HIT_KNOCKBACK)
	Juice.add_trauma(0.5)
	Juice.hitstop(0.09)
	Events.player_hit.emit(damage)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	sprite.visible = false
	hurtbox.monitoring = false
	Juice.add_trauma(1.0)
	Juice.hitstop(0.25)
	Events.player_died.emit()
```

**Step 7: Make Main restart on death**

`scripts/main.gd` (replace whole file):
```gdscript
extends Node2D
## Root of a run. Owns the arena, the player, the spawner, and restart logic.

const RESTART_DELAY := 1.0

@onready var arena: Arena = $Arena
@onready var player: CharacterBody2D = $Player
@onready var spawner: Spawner = $Spawner
@onready var enemies: Node2D = $Enemies


func _ready() -> void:
	player.global_position = arena.bounds().get_center()
	player.get_node("Camera").reset_smoothing()
	spawner.arena = arena
	spawner.player = player
	spawner.enemies_parent = enemies
	Events.player_died.connect(_on_player_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()


func _on_player_died() -> void:
	print("RUN_OVER kills=%d score=%d seed=%d elapsed=%.1f" % [RunState.kills, RunState.score, RunState.seed_value, RunState.elapsed])
	await get_tree().create_timer(RESTART_DELAY, true, false, true).timeout
	restart()


func restart() -> void:
	Engine.time_scale = 1.0
	RunState.start_run()
	get_tree().reload_current_scene()
```

The `Events.player_died` connection is made by a node that is freed on scene reload, so it does not accumulate across restarts.

**Step 8: Run everything**

Run: `tools/test.sh` (exit 0).
Run: `tools/smoke.sh combat` (`smoke: ok`).
Run: `tools/smoke.sh idle` and confirm the log has no `ERROR`.

**Step 9: Commit**

```bash
git add scripts/player_hit_rules.gd scripts/player.gd scenes/player.tscn scripts/main.gd tests/test_player_hit_rules.gd
gcommit -m "feat: player health, contact damage with i-frames, death and restart"
```

---

### Task 13: Playable build, feel checklist, and Milestone 1 handoff

**Files:**
- Create: `README.md`
- Create: `docs/plans/2026-09-02-m1-feel-checklist.md`

**Step 1: Write the README**

`README.md`:
```markdown
# Arena Roguelike

A top-down real-time action roguelike built in Godot 4.7 as a Claude Code experiment.
Design: `docs/plans/2026-09-02-action-roguelike-design.md`.

## Play

```bash
source tools/godot.sh && "$GODOT_BIN" --path .
```

WASD to move, mouse to aim, left click to shoot, R to restart.

## Develop

- `tools/test.sh` runs all gdUnit4 suites headless (exit 0 on pass, 100 on failures).
- `tools/smoke.sh [idle|move|combat]` boots the game with scripted input and saves `reports/smoke_<scenario>.png`.
- Tuning numbers live in `data/` (weapons, enemies), `scripts/autoload/juice.gd` (feel), and `scripts/spawner.gd` exports (pacing).

## Assets

Kenney Tiny Dungeon (CC0), see `assets/kenney_tiny_dungeon/README.md`.
```

**Step 2: Write the feel checklist for the user's playtest**

`docs/plans/2026-09-02-m1-feel-checklist.md`:
```markdown
# Milestone 1 feel checklist

Play for five minutes, then rate each line: good / meh / bad, with a note.
The milestone closes when shooting is "good".

- Movement: does the hero feel responsive but weighty? (tune MAX_SPEED, ACCEL, FRICTION in scripts/player.gd)
- Shooting cadence: too slow, too fast? (fire_rate in data/weapons/pistol.tres)
- Shot impact: can you feel each hit? (Juice trauma amounts in scripts/enemy.gd, FLASH_DURATION in juice.gd)
- Kill impact: is a kill satisfying? (hitstop duration in enemy.gd, death burst in fx.gd)
- Screen shake: enough, too much, nauseating? (MAX_SHAKE in camera.gd, TRAUMA_DECAY in juice.gd)
- Recoil and knockback: does the pistol push you, does the bat get shoved? (recoil, knockback in pistol.tres)
- Getting hit: is it clear when you take damage, and is the i-frame blink readable? (INVULN_TIME, HIT_KNOCKBACK in player.gd)
- Chaser: readable, dodgeable, fair? (speed, accel, spawn_delay in data/enemies/chaser.tres)
- Spawn pacing: boring early, overwhelming late? (interval_start, interval_min, ramp_seconds, max_alive in spawner.gd)
- Camera lean: helpful or disorienting? (MAX_LEAN, LEAN_FACTOR in camera.gd)
```

**Step 3: Launch the game for a real playtest**

Run:
```bash
source tools/godot.sh && "$GODOT_BIN" --path .
```
Expected: a 1280x720 window, the knight in a sandy room, bats fading in and chasing after a second. Shooting, hits, kills, damage blink, death and auto-restart all work. Close the window to exit.

**Step 4: Final verification**

Run: `tools/test.sh` (exit 0) and `tools/smoke.sh combat` (`smoke: ok`).

**Step 5: Commit and tag**

```bash
git add README.md docs/plans/2026-09-02-m1-feel-checklist.md
gcommit -m "docs: README and Milestone 1 feel checklist"
git tag m1-candidate
```

**Milestone 1 closes** when the user has played the build and reports shooting feels good. Tuning changes from the checklist are small commits on top of `m1-candidate`; tag `m1` once the user signs off.

---

## Out of scope for this plan (Milestone 2 onward)

Shooter enemy, waves and wave tables, HUD, run summary screen, upgrade picker, sound, rooms and doors, generated art. Each will get its own plan against the same design doc.
