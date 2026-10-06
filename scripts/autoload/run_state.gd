extends Node
## Per-run state: the seed, the gameplay RNG, and score counters.
## Player-interleaved gameplay randomness (shot spread) uses RunState.rng; systems whose placement
## must depend only on seed and time use stream(name); cosmetic randomness (screen shake) uses the
## global RNG so it never disturbs the run.

## What the dives cheat's "rich" flag starts the run's coins at.
const RICH_COINS := 1000

var seed_value: int = 0
## The tier requested for the next run's series (Tiers): Main reads its series from it at a run's
## start. Not the tier fought: that is the series' own (Main.series_def.tier), which a test or a
## tool may set apart from this. It outlives start_run and the scene reload of a restart (R fights
## the same tier again); written through set_tier (the lift's), and back to 1 by reset_tier at a
## quit to the title and on entering the grounds.
var tier: int = 1
## The tier of the series being fought (Main.series_def.tier), set by Main as each run's first
## round begins; start_run leaves it. The seeded streams carry it (stream_name), so a tier's seed
## replays that tier's waves and offers and tier 1's keep the spelling they had before tier 2.
var run_tier: int = 1
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
## The current round's enemies (its table's total_enemies), set by Main's _enter_round before
## round_started: the Favour node shares the round's kill budget among them (FavourRules.kill_value).
## 0 until a round starts (a count below one reads as one).
var round_enemies: int = 0
## The summed max hp of the boss bodies the current round's table sends (BossFight.table_max_hp),
## set beside round_enemies: Favour pays a fight's hits over it from the round's start, before
## every body is in the tree. 0 for a round with no boss (and until a round starts).
var round_boss_hp: float = 0.0
## Hits taken in the current round; the Favour node counts them and clears it at round_started.
var hits_this_round: int = 0
## Hits taken this run, from player_hit: what the run's record logs and VerdictRules reads.
var hits_taken: int = 0
## The profile's training for this run (TrainingRules.apply at start_run; the bases without a
## profile): cards added to every offer's count (Main adds it to FavourRules.offer_count's),
## re-draws of an offer left (the picker's Reroll button, Main decrements), falls the emperor
## still spares (Player.hurt decrements: the fall becomes one heart), and how far a landed pile
## is drawn to the player (PileRules.PULL_RADIUS plus the Reach ranks).
var offer_bonus: int = 0
var rerolls_left: int = 0
var mercies_left: int = 0
var pull_radius: float = PileRules.PULL_RADIUS
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
	favour = FavourRules.START
	perfect = true
	hits_this_round = 0
	hits_taken = 0
	coins = RICH_COINS if bool(cheats.get("rich", false)) else 0
	round_tally = 0
	round_enemies = 0
	round_boss_hp = 0.0
	# The profile's training. Profile is a later autoload, but every autoload is a named global
	# before any _ready runs, so the boot's start_run here reads its default Save (no file yet:
	# nothing bought), and every later one the loaded profile.
	var given := TrainingRules.apply(Profile.save)
	offer_bonus = int(given["offer_bonus"])
	rerolls_left = int(given["rerolls"])
	mercies_left = int(given["mercies"])
	pull_radius = float(given["pull_radius"])
	clear_build()
	Events.run_started.emit()


## The tier the next run is fought in, when `new_tier` is one (Tiers.has); an unknown tier is
## refused (false) and the tier kept. Nothing else changes: start_run leaves the tier alone.
func set_tier(new_tier: int) -> bool:
	if not Tiers.has(new_tier):
		return false
	tier = new_tier
	return true


## The tier back to 1, written straight (never asking Tiers, so it holds even if a tier failed).
func reset_tier() -> void:
	tier = 1


## A fresh loadout: the last run's weapon and ranks go. start_run calls it, and so does
## Main.enter_grounds before the revive, so nothing a run gave is held in the grounds; it emits
## nothing (no run_started, no build_changed): nothing else resets.
func clear_build() -> void:
	build = Build.new()


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


## The name of the run's stream for `base` (spawn:<round>, piles:<round>, upgrades:..., lock:...):
## every caller of stream() for the run's placements and draws goes through it.
func stream_name(base: String) -> String:
	return stream_name_for(base, run_tier)


## `base` as tier `for_tier` spells it: tier 1's unchanged; a later tier's carries t<n> after the
## name's first part (spawn:t2:3, upgrades:t2:2:1:r1; a name of one part ends with it: o:t2).
static func stream_name_for(base: String, for_tier: int) -> String:
	if for_tier <= 1:
		return base
	var at := base.find(":")
	if at < 0:
		return "%s:t%d" % [base, for_tier]
	return "%s:t%d%s" % [base.substr(0, at), for_tier, base.substr(at)]


## A deterministic RNG for one system, derived from the run seed. Systems whose randomness
## should not interleave with others (spawning, later wave tables) use their own stream.
func stream(name: String) -> RandomNumberGenerator:
	var rng_for := RandomNumberGenerator.new()
	rng_for.seed = hash([seed_value, name])
	return rng_for
