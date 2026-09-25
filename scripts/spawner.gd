class_name Spawner
extends Node
## Places enemies at seed-driven floor spots away from the player. Waves decide what and when.

@export var min_player_distance := 96.0

var arena: Arena
var player: Node2D
var enemies_parent: Node
var projectiles_parent: Node

var _rng: RandomNumberGenerator


func _ready() -> void:
	start_round()


## Re-seeds the placement stream on RunState.round, so each round of a series spawns in its own
## spots and a replay of the seed puts them back. Main calls it as every round begins.
func start_round() -> void:
	_rng = RunState.stream("spawn:%d" % RunState.round)


func pick_position() -> Vector2:
	var avoid := player.global_position if is_instance_valid(player) else arena.bounds().get_center()
	return SpawnMath.pick_position(arena.bounds(), avoid, min_player_distance, _rng)


## Instances scene in the arena. at defaults to a picked position; a boss (group "boss") takes the
## top centre of the floor instead, so the fight opens the same way every run. Returns the node
## as a Node2D: enemies and the boss share the target and projectile_parent properties, not a class.
func spawn(scene: PackedScene, at: Vector2 = Vector2.INF) -> Node2D:
	var enemy: Node2D = scene.instantiate()
	assert(enemy.has_method("is_harmful"), "Spawner: %s is not an enemy scene" % scene.resource_path)
	if at == Vector2.INF:
		at = boss_position() if enemy.is_in_group("boss") else pick_position()
	enemy.set("target", player)
	enemy.set("projectile_parent", projectiles_parent)
	enemies_parent.add_child(enemy)
	enemy.global_position = at
	Events.enemy_spawned.emit(enemy)
	return enemy


## A tile and a half below the top wall, centred.
func boss_position() -> Vector2:
	var b := arena.bounds()
	return Vector2(b.get_center().x, b.position.y + ArenaGrid.TILE * 1.5)
