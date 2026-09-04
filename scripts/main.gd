extends Node2D
## Root of a run. Owns the arena, the player, the spawner, and restart logic.

@onready var arena: Arena = $Arena
@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera
@onready var spawner: Spawner = $Spawner
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles


func _ready() -> void:
	player.global_position = arena.bounds().get_center()
	camera.reset_smoothing()
	player.projectile_parent = projectiles
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
