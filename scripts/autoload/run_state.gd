extends Node
## Per-run state: the seed, the gameplay RNG, and score counters.
## Player-interleaved gameplay randomness (shot spread) uses RunState.rng; systems whose placement
## must depend only on seed and time use stream(name); cosmetic randomness (screen shake) uses the
## global RNG so it never disturbs the run.

var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var score: int = 0
var kills: int = 0
## 0-based index of the current round, set by Main.
var round: int = 0
## Rounds whose last wave died this run.
var rounds_cleared: int = 0
## Rounds in the series; Main sets it, start_run leaves it.
var rounds_total: int = 1
## 0-based index of the current wave in the current round, set by WaveRunner.
var wave: int = 0
var elapsed: float = 0.0
## The loadout: weapon and upgrade ranks. Replaced by start_run; the player resolves from it.
var build := Build.new()
## The cheat flags for this run (Cheats.CODES rows, from the title's seed field), empty in a real
## run; start_run takes them with the seed and resets them otherwise. Player.hurt reads
## "immortal"; the summary and the run line name whatever is on.
var cheats: Dictionary = {}


func _ready() -> void:
	start_run()
	Events.enemy_died.connect(_on_enemy_died)


func _physics_process(delta: float) -> void:
	elapsed += delta


func start_run(new_seed: int = -1, new_cheats: Dictionary = {}) -> void:
	seed_value = new_seed if new_seed >= 0 else (randi() & 0x7FFFFFFF)
	cheats = new_cheats.duplicate()
	rng.seed = seed_value
	score = 0
	kills = 0
	round = 0
	rounds_cleared = 0
	wave = 0
	elapsed = 0.0
	build = Build.new()
	Events.run_started.emit()


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
