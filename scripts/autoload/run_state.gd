extends Node
## Per-run state: the seed, the gameplay RNG, and score counters.
## Player-interleaved gameplay randomness (shot spread) uses RunState.rng; systems whose placement
## must depend only on seed and time use stream(name); cosmetic randomness (screen shake) uses the
## global RNG so it never disturbs the run.

## What the dives cheat's "rich" flag starts the run's coins at.
const RICH_COINS := 1000

var seed_value: int = 0
var rng := RandomNumberGenerator.new()
var score: int = 0
var kills: int = 0
## 0-based index of the current round, set by Main (round_index: a bare `round` shadows the built-in).
var round_index: int = 0
## Rounds whose last wave died this run.
var rounds_cleared: int = 0
## Rounds in the series; Main sets it, start_run leaves it.
var rounds_total: int = 1
## 0-based index of the current wave in the current round, set by WaveRunner.
var wave: int = 0
var elapsed: float = 0.0
## The crowd's favour, 0 to FavourRules.MAX, changed only by the Favour node's detectors.
var favour: float = FavourRules.START
## True until the first hit taken or the first round ended below Roar (the perfect run).
var perfect: bool = true
## Hits taken in the current round; the Favour node counts them and clears it at round_started.
var hits_this_round: int = 0
## Hits taken this run, from player_hit: what the run's record logs and VerdictRules reads.
var hits_taken: int = 0
## How far a landed pile is drawn to the player (CoinPile.PULL_RADIUS at a run's start; a
## training line widens it later).
var pull_radius: float = CoinPile.PULL_RADIUS
## The run's coins: kills' coins flown to the counter and piles picked up. They reach the profile
## only at the verdict (banked on a thumb up, lost on a thumb down or a yield).
var coins: int = 0
## The current round's kill coins, the base of the round's bonus. Main clears it in _enter_round:
## it owns the round flow and is the tally's one reader.
var round_tally: int = 0
## The loadout: weapon and upgrade ranks. Replaced by start_run; the player resolves from it.
var build := Build.new()
## The cheat flags for this run (Cheats.CODES rows, from the title's seed field), empty in a real
## run; start_run takes them with the seed and resets them otherwise. Player.hurt reads
## "immortal", start_run "rich" (the one place), VerdictRules "thumbs_down"; the gate screen and
## the run line name whatever is on.
var cheats: Dictionary = {}


func _ready() -> void:
	start_run()
	Events.enemy_died.connect(_on_enemy_died)
	Events.player_hit.connect(_on_player_hit)


func _physics_process(delta: float) -> void:
	elapsed += delta


func start_run(new_seed: int = -1, new_cheats: Dictionary = {}) -> void:
	seed_value = new_seed if new_seed >= 0 else (randi() & 0x7FFFFFFF)
	cheats = new_cheats.duplicate()
	rng.seed = seed_value
	score = 0
	kills = 0
	round_index = 0
	rounds_cleared = 0
	wave = 0
	elapsed = 0.0
	# The profile's training: the build's bases and the starting favour. Profile is a later
	# autoload, but every autoload is a named global before any _ready runs, so the boot's
	# start_run here reads its default Save (no file yet: the bases), and every later one the
	# loaded profile.
	var given := TrainingRules.apply(Profile.save)
	favour = float(given["favour"])
	perfect = true
	hits_this_round = 0
	hits_taken = 0
	coins = RICH_COINS if bool(cheats.get("rich", false)) else 0
	round_tally = 0
	pull_radius = CoinPile.PULL_RADIUS
	build = Build.starting(Profile.save)
	Events.run_started.emit()


func _on_enemy_died(enemy: Node2D, _death_position: Vector2) -> void:
	kills += 1
	var def: Variant = enemy.get("def")
	score += int(def.get("score")) if def != null and def.get("score") != null else 10


func _on_player_hit(_damage: int, _hp: int, _max_hp: int, _attacker_id: String) -> void:
	hits_taken += 1


## The one way coins join the run (a kill's pay, the Cheer bonus, a pile picked up): the counter
## hears the new total through coins_changed.
func add_coins(value: int) -> void:
	coins += value
	Events.coins_changed.emit(coins)


## A deterministic RNG for one system, derived from the run seed. Systems whose randomness
## should not interleave with others (spawning, later wave tables) use their own stream.
func stream(name: String) -> RandomNumberGenerator:
	var rng_for := RandomNumberGenerator.new()
	rng_for.seed = hash([seed_value, name])
	return rng_for
