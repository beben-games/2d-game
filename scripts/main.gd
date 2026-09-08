extends Node2D
## Root of a run. Owns the player and the floor; swaps Room scenes as the player advances.

signal restart_requested

const ROOM := preload("res://scenes/room.tscn")

## The run. The smoke tool and tests swap in small floors before adding Main to the tree.
@export var floor_def: FloorDef = preload("res://data/floors/floor_1.tres")

var room: Room
var room_index := 0

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera


func _ready() -> void:
	assert(floor_def != null, "Main needs a FloorDef")
	var errors := floor_def.validate()
	assert(errors.is_empty(), "Invalid floor: %s" % ", ".join(errors))
	Events.player_died.connect(_on_player_died)
	_enter_room(0)


func _exit_tree() -> void:
	# Explicit, like Fx: a scene reload must never leave the global bus pointing at a dying node.
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)


## Frees the current room (and everything in it) and builds room `index` around the player.
func _enter_room(index: int) -> void:
	if room != null:
		remove_child(room)
		room.queue_free()
	room_index = index
	room = ROOM.instantiate()
	room.def = floor_def.rooms[index]
	room.entry_side = FloorRules.entry_side(floor_def, index)
	add_child(room)
	move_child(room, 0)  # draws under the player and effects
	player.global_position = room.entry_position()
	player.projectile_parent = room.projectiles
	room.spawner.player = player
	_apply_camera_limits(room.bounds().grow(ArenaGrid.TILE))
	camera.reset_smoothing()
	RunState.room = index
	Events.room_entered.emit(index, floor_def.rooms.size())
	# Started last so wave_started arrives after room_entered and with the spawner's player set.
	room.wave_runner.start(room.def.waves)


## The view may show the wall ring but never the void past it.
func _apply_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()


## Reloads only when Main is the current scene: test harnesses and the smoke tool instance Main
## as a child of themselves, and must not be reloaded out from under their own script.
func restart() -> void:
	restart_requested.emit()
	Juice.reset()
	RunState.start_run()
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


## Death holds on the corpse until R. The wave runner stays off so nothing crowds the corpse.
func _on_player_died(_death_position: Vector2) -> void:
	room.wave_runner.enabled = false
	print("RUN_OVER kills=%d score=%d seed=%d elapsed=%.1f" % [RunState.kills, RunState.score, RunState.seed_value, RunState.elapsed])
