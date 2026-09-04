extends Node2D
## Root of a run. Owns the arena, the player, the spawner, and restart logic.

const RESTART_DELAY := 1.0

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
	Events.player_died.connect(_on_player_died)


func _exit_tree() -> void:
	# Explicit, like Fx: a scene reload must never leave the global bus pointing at a dying node.
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()


func restart() -> void:
	Juice.reset()
	RunState.start_run()
	get_tree().reload_current_scene()


func _on_player_died() -> void:
	spawner.enabled = false  # no new enemies around a corpse during the restart delay
	print("RUN_OVER kills=%d score=%d seed=%d elapsed=%.1f" % [RunState.kills, RunState.score, RunState.seed_value, RunState.elapsed])
	await get_tree().create_timer(RESTART_DELAY, true, false, true).timeout
	restart()
