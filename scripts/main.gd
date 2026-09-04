extends Node2D
## Root of a run. Owns the arena, the player, and restart logic.

@onready var arena: Arena = $Arena
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera
@onready var projectiles: Node2D = $Projectiles


func _ready() -> void:
	player.projectile_parent = projectiles
	player.global_position = arena.bounds().get_center()
	camera.reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()


func restart() -> void:
	Engine.time_scale = 1.0
	RunState.start_run()
	get_tree().reload_current_scene()
