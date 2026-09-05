extends Node2D
## Root of a run. Owns the arena, the player, the spawner, and restart logic.

const RESTART_DELAY := 1.0

signal restart_requested

@onready var arena: Arena = $Arena
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera
@onready var spawner: Spawner = $Spawner
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles


func _ready() -> void:
	player.global_position = arena.bounds().get_center()
	_apply_camera_limits(arena.bounds().grow(ArenaGrid.TILE))
	camera.reset_smoothing()
	player.projectile_parent = projectiles
	spawner.arena = arena
	spawner.player = player
	spawner.enemies_parent = enemies
	Events.player_died.connect(_on_player_died)


## The view may show the wall ring but never the void past it. Rooms will call this per room.
func _apply_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)


func _exit_tree() -> void:
	# Explicit, like Fx: a scene reload must never leave the global bus pointing at a dying node.
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)


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


func _on_player_died(_death_position: Vector2) -> void:
	spawner.enabled = false  # no new enemies around a corpse during the restart delay
	print("RUN_OVER kills=%d score=%d seed=%d elapsed=%.1f" % [RunState.kills, RunState.score, RunState.seed_value, RunState.elapsed])
	await get_tree().create_timer(RESTART_DELAY, true, false, true).timeout
	restart()
