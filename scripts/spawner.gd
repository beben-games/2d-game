class_name Spawner
extends Node
## Spawns Chasers on a timer that speeds up over the run. Waves replace this in Milestone 2.

const CHASER := preload("res://scenes/enemies/chaser.tscn")

## Tests set this false to keep the arena quiet.
@export var enabled := true
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
	if not enabled:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SpawnMath.interval(interval_start, interval_min, ramp_seconds, RunState.elapsed)
	if _alive >= max_alive or not is_instance_valid(player):
		return
	spawn_one()


func alive_count() -> int:
	return _alive


func spawn_one() -> Enemy:
	var pos := SpawnMath.pick_position(arena.bounds(), player.global_position, min_player_distance, RunState.rng)
	var enemy: Enemy = CHASER.instantiate()
	enemy.target = player
	enemies_parent.add_child(enemy)
	enemy.global_position = pos
	_alive += 1
	enemy.tree_exited.connect(func() -> void: _alive -= 1)
	Events.enemy_spawned.emit(enemy)
	return enemy
