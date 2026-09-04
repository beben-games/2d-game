extends Node
## Per-run state: the seed, the gameplay RNG, and score counters.
## Gameplay randomness (spawns, spread) MUST use RunState.rng so a seed replays a run.
## Cosmetic randomness (screen shake) uses the global randf so it never disturbs the run.

var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var score: int = 0
var kills: int = 0
var elapsed: float = 0.0


func _ready() -> void:
	start_run()
	Events.enemy_died.connect(_on_enemy_died)


func _physics_process(delta: float) -> void:
	elapsed += delta


func start_run(new_seed: int = -1) -> void:
	seed_value = new_seed if new_seed >= 0 else (randi() & 0x7FFFFFFF)
	rng.seed = seed_value
	score = 0
	kills = 0
	elapsed = 0.0


func _on_enemy_died(enemy: Node2D, _death_position: Vector2) -> void:
	kills += 1
	var def: Variant = enemy.get("def")
	score += int(def.get("score")) if def != null and def.get("score") != null else 10


## A deterministic RNG for one system, derived from the run seed. Systems whose randomness
## should not interleave with others (spawning, later wave tables) use their own stream.
func stream(name: String) -> RandomNumberGenerator:
	var rng_for := RandomNumberGenerator.new()
	rng_for.seed = hash([seed_value, name])
	return rng_for
