class_name Spawner
extends Node
## Places enemies at seed-driven spots on the floor's part inside the view, away from the player.
## Waves decide what and when. Asks View, so it places only while in the tree.

@export var min_player_distance := 96.0

var arena: Arena
var player: Node2D
var enemies_parent: Node
var projectiles_parent: Node

var _rng: RandomNumberGenerator
## The wave's boss seats (seat_bosses): how many bodies the fight has and the next one's place.
var _boss_seats := 1
var _boss_next := 0


func _ready() -> void:
	start_round()  # a Room built without Main (a test's) can still place; Main re-seeds per round


## Seeds the placement stream on RunState.round_index (spawn:<round>, carrying the tier:
## RunState.stream_name), so each round of a series spawns in its own spots and a replay of the
## seed puts them back. Main calls it as every round begins.
func start_round() -> void:
	_rng = RunState.stream(RunState.stream_name("spawn:%d" % RunState.round_index))
	seat_bosses(1)


## The wave about to be placed holds `count` bodies of a boss fight (the runner counts them as
## each wave is queued): they take seats 0 to count - 1 along the top, in the order placed.
func seat_bosses(count: int) -> void:
	_boss_seats = maxi(count, 1)
	_boss_next = 0


## A seeded spot in the floor's part inside the view (the arena's rule 2: a spawn fades in at the
## edge of the view, never beyond it), min_player_distance from the player, near an edge of the
## view that cuts the floor (SpawnMath.pick_in_view). Where the view covers the floor (tier 1) it
## is the floor-only pick, draw for draw.
func pick_position() -> Vector2:
	var floor_rect := global_bounds()
	var avoid := player.global_position if is_instance_valid(player) else floor_rect.get_center()
	return SpawnMath.pick_in_view(floor_rect, View.rect(self), avoid, min_player_distance, _rng)


## Instances scene in the arena. at defaults to a picked position; a boss (group "boss") takes the
## top centre of the floor in view instead, so the fight opens the same way every run (the next of
## the wave's seats when the fight is several bodies: seat_bosses). Returns the
## node as a Node2D: enemies and the boss share the target and projectile_parent properties, not a
## class.
func spawn(scene: PackedScene, at: Vector2 = Vector2.INF) -> Node2D:
	var enemy: Node2D = scene.instantiate()
	assert(enemy.has_method("is_harmful"), "Spawner: %s is not an enemy scene" % scene.resource_path)
	if at == Vector2.INF:
		if enemy.is_in_group("boss"):
			at = boss_position(_boss_next, _boss_seats)
			_boss_next += 1
		else:
			at = pick_position()
	enemy.set("target", player)
	enemy.set("projectile_parent", projectiles_parent)
	enemies_parent.add_child(enemy)
	enemy.global_position = at
	Events.enemy_spawned.emit(enemy)
	return enemy


## The top centre of the floor in view at the spawn (SpawnMath.boss_seat): in tier 1 a tile and a
## half below the top wall, centred, as before. Body `index` of a fight of `count` sits along that
## row, spread across the floor in view.
func boss_position(index := 0, count := 1) -> Vector2:
	return SpawnMath.boss_seat(global_bounds(), View.rect(self), View.bare_rect(self), index, count)


## The arena's floor in world space (the Room may move the arena with it), where placements are.
func global_bounds() -> Rect2:
	var local := arena.bounds()
	return Rect2(arena.to_global(local.position), local.size)
