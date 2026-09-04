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
