class_name Spawner
extends Node
## Places enemies at seed-driven floor spots away from the player. Waves decide what and when.

@export var min_player_distance := 96.0

var arena: Arena
var player: Node2D
var enemies_parent: Node

var _rng: RandomNumberGenerator


func _ready() -> void:
	_rng = RunState.stream("spawn")


func pick_position() -> Vector2:
	var avoid := player.global_position if is_instance_valid(player) else arena.bounds().get_center()
	return SpawnMath.pick_position(arena.bounds(), avoid, min_player_distance, _rng)


## Instances scene in the room. at defaults to a picked position.
func spawn(scene: PackedScene, at: Vector2 = Vector2.INF) -> Enemy:
	if at == Vector2.INF:
		at = pick_position()
	var enemy: Enemy = scene.instantiate()
	enemy.target = player
	enemies_parent.add_child(enemy)
	enemy.global_position = at
	Events.enemy_spawned.emit(enemy)
	return enemy
