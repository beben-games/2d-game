extends Node
## The player's profile across runs: one Save loaded from `path` at boot, filled from the bus
## (one handler per signal, like Favour and Audio), and written only by commit(), which the
## verdict, the grounds' purchases, and the first pass through the gate screen call. The listeners never touch the disk, so a crash
## mid-run loses only that run. Tests point `path` at a scratch file and reset() before and
## after each test (SceneSuite), so the player's user://save.cfg is never read into a test's
## numbers nor written by one. time_played counts here in _process: the autoload pauses with
## the tree, so a menu adds nothing; time_in_grounds counts while the grounds are up. Shots and
## dashes count only while a run is live: the body can dash in the grounds and they are no
## deed there.

var save: Save = Save.new()
var path: String = Save.DEFAULT_PATH
## True from run_started to run_ended or grounds_entered. True at boot: RunState starts its run
## in its own _ready, before this autoload listens.
var _in_run := true
## True from grounds_entered to run_started.
var _in_grounds := false


func _ready() -> void:
	reload()
	for pair: Array in _handlers():
		var sig: Signal = pair[0]
		sig.connect(pair[1])


func _exit_tree() -> void:
	for pair: Array in _handlers():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


func _process(delta: float) -> void:
	save.add_stat("time_played", delta)
	if _in_grounds:
		save.add_stat("time_in_grounds", delta)


## Drops the live Save for the one on disk at `path` (the defaults when there is none). A file
## that could not be used was backed up by Save; this is where the player hears of it.
func reload() -> void:
	save = Save.load_from(path)
	if save.backup_note != "":
		push_warning("Profile: " + save.backup_note)


## A test's clean slate: the file reloaded and the flags as at boot (a run live, no grounds).
func reset() -> void:
	reload()
	_in_run = true
	_in_grounds = false


## The one write: the live Save to `path`. A failure is reported, never raised: the run goes on.
func commit() -> Error:
	var err := save.save_to(path)
	if err != OK:
		push_warning("Profile: could not save %s (%s)" % [path, error_string(err)])
	return err


## The stat fillers, one row per bus signal; _ready connects them and _exit_tree disconnects them.
func _handlers() -> Array[Array]:
	return [
		[Events.shot_fired, _on_shot_fired], [Events.enemy_hit, _on_enemy_hit],
		[Events.enemy_died, _on_enemy_died], [Events.player_hit, _on_player_hit],
		[Events.player_dashed, _on_player_dashed], [Events.favour_changed, _on_favour_changed],
		[Events.upgrade_chosen, _on_upgrade_chosen], [Events.round_cleared, _on_round_cleared],
		[Events.round_ended, _on_round_ended], [Events.pile_collected, _on_pile_collected],
		[Events.run_started, _on_run_started], [Events.run_ended, _on_run_ended],
		[Events.grounds_entered, _on_grounds_entered],
	]


func _on_run_started() -> void:
	_in_run = true
	_in_grounds = false


func _on_run_ended(_outcome: String) -> void:
	_in_run = false


func _on_grounds_entered() -> void:
	_in_run = false
	_in_grounds = true


func _on_shot_fired(_at: Vector2, _direction: Vector2, weapon_id: String) -> void:
	if _in_run:
		save.add_stat("shots_fired", 1, _known(weapon_id))


func _on_enemy_hit(enemy: Node2D, _damage: float, _at: Vector2) -> void:
	save.add_stat("shots_hit")
	save.add_stat("hits_landed", 1, _id_of(enemy))


func _on_enemy_died(enemy: Node2D, _at: Vector2) -> void:
	save.add_stat("kills", 1, _id_of(enemy))
	if enemy.is_in_group("boss"):
		save.add_stat("boss_kills")


func _on_player_hit(_damage: int, _hp: int, _max_hp: int, attacker_id: String) -> void:
	save.add_stat("hits_taken", 1, _known(attacker_id))


func _on_player_dashed(_at: Vector2, _direction: Vector2) -> void:
	if _in_run:
		save.add_stat("dashes")


## "daring" is scored per kill inside the window after a dash through danger (Favour), so this
## counts daring kills; the peak is the meter's high-water mark across every run.
func _on_favour_changed(value: float, _band: int, act: String) -> void:
	if act == "daring":
		save.add_stat("dashes_through_danger")
	save.raise_stat("favour_peak", value)


func _on_upgrade_chosen(card: UpgradeDef, _rank: int) -> void:
	save.add_stat("cards_taken", 1, _known(card.id))
	if card.kind == UpgradeDef.Kind.SWITCH:
		save.add_stat("switches")


func _on_round_cleared() -> void:
	save.add_stat("rounds_cleared")


## Arrives right after round_cleared, before the next round clears hits_this_round.
func _on_round_ended(band: int) -> void:
	save.add_stat("rounds_by_band", 1, FavourRules.band_name(band))
	if RunState.hits_this_round == 0:
		save.add_stat("clean_rounds")


func _on_pile_collected(_at: Vector2, _value: int) -> void:
	save.add_stat("piles_collected")


## The enemy's def id, duck-typed like Audio (a test's stub has no def): "unknown" when absent.
func _id_of(enemy: Node2D) -> String:
	var def: Variant = enemy.get("def")
	var id: Variant = def.get("id") if def != null else null
	return _known(str(id) if id != null else "")


## A per-id stat needs a name: an empty id (no source known) counts under UNKNOWN_ID.
func _known(id: String) -> String:
	return id if id != "" else Save.UNKNOWN_ID
