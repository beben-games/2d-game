class_name Favour
extends Node
## The crowd's judgement of the run, under Main: one detector per act in FavourRules.ACTS on the
## bus, each scoring RunState.favour through FavourRules and telling the HUD with favour_changed.
## Time is RunState.elapsed (it stops under a pause; wall time would not). The handlers only
## change numbers and emit signals, so they are safe inside the physics callbacks enemy_died and
## round_cleared arrive in. A child of Main, so its round_cleared handler runs before Main's:
## the clean-round bonus is in the meter when Main reads the round's band.

## RunState.elapsed at the last kill: a kill within CHAIN_WINDOW of it is a chain.
var last_kill_time := -INF
## When the last dash through danger ends (its start plus DashRules.DURATION): a kill within
## DASH_WINDOW after it is daring. -INF until a dash goes through danger.
var last_daring_dash_end := -INF
## RunState.elapsed at the last scoring act (a kill, a chain, a daring, a clean round: any act
## that raises the meter, FavourRules.is_scoring); the decay's grace counts from it. A hit on an
## enemy that does not kill is not one and holds the decay off no longer: fighting keeps the
## meter only by killing.
var last_scoring_time := 0.0
## True from run_started (or a round's start) until the fall or run_ended, and never in the
## grounds: the decay runs only while a run is live.
var _run_live := false


func _ready() -> void:
	for pair: Array in _handlers():
		var sig: Signal = pair[0]
		sig.connect(pair[1])


func _exit_tree() -> void:
	# Explicit, like Fx: a scene reload must never leave the global bus pointing at a dying node.
	for pair: Array in _handlers():
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


## The detectors, one row per bus signal; _ready connects them and _exit_tree disconnects them.
func _handlers() -> Array[Array]:
	return [
		[Events.enemy_died, _on_enemy_died],
		[Events.player_dashed, _on_player_dashed], [Events.player_hit, _on_player_hit],
		[Events.round_cleared, _on_round_cleared], [Events.round_started, _on_round_started],
		[Events.run_started, _on_run_started], [Events.player_fell, _on_player_fell],
		[Events.run_ended, _on_run_ended], [Events.grounds_entered, _on_grounds_entered],
		[Events.run_won, _on_run_won],
	]


## The decay: while a run is live and no scoring act has landed for DECAY_GRACE, the meter loses
## DECAY_PER_SECOND. Running away and idling both decay, and so do the gap between rounds (coins
## collected slowly cost favour) and a wave's spawn-in. Nothing decays under a pause (the picker,
## the pause screen: no tick), after the fall, or in the grounds.
func _physics_process(delta: float) -> void:
	if not _run_live:
		return
	var drain := FavourRules.decay(RunState.elapsed - last_scoring_time, delta)
	if drain != 0.0:
		_change(FavourRules.clamp_value(RunState.favour + drain), FavourRules.DECAY_ACT)


## The kill, chain, and daring detectors, in that order.
func _on_enemy_died(_enemy: Node2D, _at: Vector2) -> void:
	var now := RunState.elapsed
	_score("kill")
	if now - last_kill_time <= FavourRules.CHAIN_WINDOW:
		_score("chain")
	if now - last_daring_dash_end <= FavourRules.DASH_WINDOW:
		_score("daring")
	last_kill_time = now


## The dash-through-danger detector: the dash's path against every harmful enemy's position.
## The path is the nominal straight segment (SPEED times DURATION from the start): the real dash
## runs nine or ten ticks, carries any hit knockback, and stops at a wall, so this is an estimate
## taken at the dash's start, which is when the player committed to it.
func _on_player_dashed(position: Vector2, direction: Vector2) -> void:
	var to := position + direction.normalized() * DashRules.SPEED * DashRules.DURATION
	var positions: Array[Vector2] = []
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if _is_harmful(enemy):
			positions.append(enemy.global_position)
	if FavourRules.dash_through_danger(position, to, positions, FavourRules.DANGER_RADIUS):
		last_daring_dash_end = RunState.elapsed + DashRules.DURATION


## The hit detector: the act, and the end of the perfect run.
func _on_player_hit(_damage: int, _hp: int, _max_hp: int, _attacker_id: String) -> void:
	RunState.perfect = false
	RunState.hits_this_round += 1
	_score("hit")


## The clean-round detector, then the verdict's mark on the perfect run: a round that ends
## below Roar ends it.
func _on_round_cleared() -> void:
	if RunState.hits_this_round == 0:
		_score("clean_round")
	if FavourRules.band(RunState.favour) < FavourRules.ROAR:
		RunState.perfect = false


func _on_round_started(_index: int, _total: int) -> void:
	RunState.hits_this_round = 0
	last_scoring_time = RunState.elapsed
	_run_live = true


## A new run puts elapsed back to 0: a kill or a dash remembered from before it would otherwise
## chain with, or make daring, the next run's first kill (start_run resets the meter itself).
func _on_run_started() -> void:
	last_kill_time = -INF
	last_daring_dash_end = -INF
	last_scoring_time = 0.0
	_run_live = true


func _on_player_fell(_fall_position: Vector2, _attacker_id: String) -> void:
	_run_live = false


func _on_run_ended(_outcome: String) -> void:
	_run_live = false


## A win ends the fight before the run closes (WIN_HOLD, the sweep): the crowd stops cooling at the roar.
func _on_run_won() -> void:
	_run_live = false


func _on_grounds_entered() -> void:
	_run_live = false


## Scores the act; a scoring act also restarts the decay's grace.
func _score(act: String) -> void:
	if FavourRules.is_scoring(act):
		last_scoring_time = RunState.elapsed
	_change(FavourRules.apply(RunState.favour, act), act)


func _change(value: float, act: String) -> void:
	RunState.favour = value
	Events.favour_changed.emit(value, FavourRules.band(value), act)


## Duck-typed: the boss and the enemies both answer is_harmful; a corpse has left the group.
func _is_harmful(enemy: Node2D) -> bool:
	return enemy.has_method("is_harmful") and enemy.is_harmful()
