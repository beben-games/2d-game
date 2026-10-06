class_name Favour
extends Node
## The crowd's judgement of the run, under Main: one detector per act on the bus (the table's
## FavourRules.ACTS and the kill, whose value is its share of the round's budget), each scoring
## RunState.favour through FavourRules and telling the HUD with favour_changed; beside them the
## decay (a rate each tick) and the settle (the meter brought down to the gate at a round's start;
## the boss round's start instead sets it to the top, `wild`, and caps the round's gains).
## Nothing scores once the run is no longer live (after the fall, the win, or in the grounds).
## Time is RunState.elapsed (it stops under a pause; wall time would not). The handlers only
## change numbers and emit signals, so they are safe inside the physics callbacks enemy_died and
## round_cleared arrive in. A child of Main, so its round_cleared handler runs before Main's:
## the clean-round bonus is in the meter when Main reads the round's band. Beside the meter, the
## round's losses by source (round_losses: a hit's drop, a drain near or far from the enemies),
## whose largest is the crowd's judgement at the pick (round_loss).

## RunState.elapsed at the last kill: a kill within CHAIN_WINDOW of it is a chain.
var last_kill_time := -INF
## When the last dash through danger (a dare) ends (its start plus DashRules.DURATION): a kill
## within DASH_WINDOW after it is daring. -INF until a dash goes through danger.
var last_daring_dash_end := -INF
## The favour the current round's kills, and the boss's hits, have paid (their shares of
## FavourRules.KILL_BUDGET): the boss's kill pays what its hits left, and the clamp guards kills
## beyond the table's count (none in the shipped series; a summon pays and spends nothing). 0 at a
## round's and a run's start.
var round_kill_paid := 0.0
## The round's gate: closed at a round's (and a run's) start, opened by the round's first daring
## kill; while closed the capped acts stop at FavourRules.ROAR_GATE, once open they add in full.
var gate_open := false
## True through the boss round (FavourRules.is_boss_round: the series' last), from its start to the
## next round's or run's: the round opened at BOSS_START with the gate open, and its gains capped.
var boss_round := false
## The boss round's gains so far: the sum of the positive changes its acts applied (FavourRules
## .gain_allowed trims each to what BOSS_GAIN_CAP leaves). 0 at a round's and a run's start, and
## counted only in the boss round.
var round_gain := 0.0
## True from the boss round's start until the boss turns harmful (boss_spawned): the crowd holds its
## breath through the entrance (the wave's breather, the boss's fade-in: about 2.7 s shipped, past
## the grace), so nothing decays before a shot can land; the grace counts from the boss's arrival.
## The rule is positional (the series' last round), so a last round with no boss would hold the
## decay off all round; none is shipped.
var entrance_held := false
## RunState.elapsed at the last scoring act (a kill, a chain, a dare, a daring, a clean round:
## any act that raises the meter, FavourRules.is_scoring); the decay's grace counts from it. A
## hit on an enemy that does not kill is not one and holds the decay off no longer: fighting
## keeps the meter only by killing. The boss is the exception (_on_enemy_hit): a hit on it pays its
## share of the round's budget as a kill does, and so restarts the grace.
var last_scoring_time := 0.0
## RunState.elapsed at the last shot landed on any enemy (a loud enemy_hit, a shot_blocked on a
## shield, or a shot_deflected off one: a status tick is not one): within DECAY_GRACE of it the gladiator is fighting, so a
## drain far from every enemy is `slow`, not `fled`. -INF until a run's first.
var last_hit_time := -INF
## The favour the round has lost, by source (FavourRules.LOSS_SOURCES to points): a hit adds
## what the meter really dropped, a drain while a harmful enemy lives adds its drop under the
## source FavourRules.drain_source names. Only while the run is live; cleared at a round's (and a
## run's) start, before the settle, which is no loss. Main reads it at the round's clear
## (round_loss), after this node's own handler.
var round_losses: Dictionary = {}
## The bus signals that make a run live (LIVE_ON) and end it (LIVE_OFF), each handled below
## (_on_run_started, _on_round_started; _on_player_fell, _on_run_won, _on_run_ended,
## _on_grounds_entered). OffscreenArrows connects these same lists for its own "a run is live":
## a new ending goes in LIVE_OFF and gets a handler here, and the arrows follow (a test in
## test_arrows_scene.gd checks both connect every name listed).
const LIVE_ON: Array[String] = ["run_started", "round_started"]
const LIVE_OFF: Array[String] = ["player_fell", "run_won", "run_ended", "grounds_entered"]

## True from run_started (or a round's start) until the fall, the win (run_won), or run_ended,
## and never in the grounds: the decay runs and the acts score only while a run is live
## (LIVE_ON, LIVE_OFF).
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
		[Events.enemy_hit, _on_enemy_hit], [Events.enemy_died, _on_enemy_died],
		[Events.player_dashed, _on_player_dashed], [Events.player_hit, _on_player_hit],
		[Events.round_cleared, _on_round_cleared], [Events.round_started, _on_round_started],
		[Events.run_started, _on_run_started], [Events.player_fell, _on_player_fell],
		[Events.run_ended, _on_run_ended], [Events.grounds_entered, _on_grounds_entered],
		[Events.run_won, _on_run_won], [Events.shot_blocked, _on_shot_blocked],
		[Events.shot_deflected, _on_shot_blocked], [Events.boss_spawned, _on_boss_spawned],
	]


## The decay: while a run is live and no scoring act has landed for DECAY_GRACE, the meter loses
## DECAY_PER_SECOND. Running away and idling both decay, and so do the gap between rounds (coins
## collected slowly cost favour) and a wave's spawn-in. Nothing decays under a pause (the picker,
## the pause screen: no tick), after the fall, or in the grounds. What a drain takes is tallied
## by its source (_drain_source, a scan of the enemies on draining ticks only).
func _physics_process(delta: float) -> void:
	if not _run_live or entrance_held:
		return
	var drain := FavourRules.decay(RunState.elapsed - last_scoring_time, delta)
	if drain != 0.0:
		var before := RunState.favour
		_change(FavourRules.clamp_value(before + drain), FavourRules.DECAY_ACT)
		if RunState.favour < before:
			_tally(_drain_source(), before - RunState.favour)


## The kill, chain, and daring detectors, in that order. The kill pays its share of the round's
## budget over RunState.round_enemies, what is left of it once the round's kills have had it all.
## A summon (the boss's, in the group `summoned`) is not in the round's table and pays no share,
## but its kill is still a kill: it chains, it can be daring, and it holds the decay off. The
## daring opens the round's gate after the kill and the chain it rides on were scored under it.
## After the run stops being live (the boss's summons dying after the win, a shot in flight
## after the fall) nothing scores: the band the verdict reads stays.
func _on_enemy_died(enemy: Node2D, _at: Vector2) -> void:
	if not _run_live:
		return
	var now := RunState.elapsed
	var summoned := enemy.is_in_group("summoned")
	var share := FavourRules.kill_share(RunState.round_enemies, round_kill_paid, summoned)
	round_kill_paid += share
	_score_kill(share)
	if now - last_kill_time <= FavourRules.CHAIN_WINDOW:
		_score("chain")
	if now - last_daring_dash_end <= FavourRules.DASH_WINDOW:
		_score("daring")
		gate_open = true
	last_kill_time = now


## A shot landing on an enemy (killing or not; enemy_hit comes before enemy_died) is the
## gladiator fighting: its time is last_hit_time, which a drain's source reads. On the boss it
## also pays the round's budget as the boss bleeds: the hit's share of its max hp
## (FavourRules.boss_hit_share), scored as the kill act under the round's gate, spent from
## round_kill_paid up to the reserve line, so the boss's own kill pays the reserve and what its hits
## left (FavourRules.BOSS_KILL_RESERVE). Scoring, it holds the decay off:
## against the boss there is little else to kill, so fighting it counts as fighting. A status tick
## (the burn's quiet hit, Health.last_hit_quiet) is not fighting and counts for neither; every
## other enemy's hit, the boss's summons' included, pays and holds nothing.
func _on_enemy_hit(enemy: Node2D, damage: float, _at: Vector2) -> void:
	if not _run_live:
		return
	var health := enemy.get_node_or_null("Health") as Health
	if health != null and health.last_hit_quiet:
		return
	last_hit_time = RunState.elapsed
	if enemy.is_in_group("boss"):
		if health == null:
			return  # nothing to bleed: a boss with no Health pays nothing, never the whole budget
		var share := FavourRules.boss_hit_share(damage, health.max_hp, round_kill_paid)
		round_kill_paid += share
		_score_kill(share)


## The boss turning harmful ends the boss round's entrance hold: the decay's grace starts from its
## arrival. A boss spawned outside the hold (a test's, any round but the boss's) changes nothing.
func _on_boss_spawned(_boss: Node2D) -> void:
	if entrance_held:
		entrance_held = false
		last_scoring_time = RunState.elapsed


## A shot stopped by a shield, or deflected off one (shot_deflected), landed on the fight all the
## same: the gladiator is engaged.
func _on_shot_blocked(_at: Vector2) -> void:
	if _run_live:
		last_hit_time = RunState.elapsed


## The dare detector: the dash's path against every harmful enemy's position and every enemy
## bolt in flight (a narrow escape). A dash through danger scores the one dare at once (the meter
## answers the dash), whatever it passed, and opens the daring window. The path is the nominal
## straight segment (SPEED times DURATION from the start): the real dash runs nine or ten ticks,
## carries any hit knockback, and stops at a wall, so this is an estimate taken at the dash's
## start, which is when the player committed to it; each bolt is advanced along its velocity
## from where it is then.
func _on_player_dashed(position: Vector2, direction: Vector2) -> void:
	if not _run_live:
		return
	var to := position + direction.normalized() * DashRules.SPEED * DashRules.DURATION
	if _passes_an_enemy(position, to) or _passes_a_bolt(position, to):
		last_daring_dash_end = RunState.elapsed + DashRules.DURATION
		_score("dare")


## Every harmful enemy body against DANGER_RADIUS (a corpse has left the group): one standing or
## walking where it is at the dash's start; one moving under its own momentum (a charger's run:
## `dare_velocity()`, asked duck-typed, not zero) swept along that velocity over the dash as a
## bolt is (dash_past_bolt's closest approach), so a sidestep out of a run's lane begun while the
## body is still bearing down is a dare.
func _passes_an_enemy(from: Vector2, to: Vector2) -> bool:
	var positions: Array[Vector2] = []
	var movers: Array[Array] = []
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if not _is_harmful(enemy):
			continue
		var velocity := Vector2.ZERO
		if enemy.has_method("dare_velocity"):
			velocity = enemy.call("dare_velocity")
		if velocity == Vector2.ZERO:
			positions.append(enemy.global_position)
		else:
			movers.append([enemy.global_position, velocity])
	return FavourRules.dash_through_danger(from, to, positions, FavourRules.DANGER_RADIUS) \
		or FavourRules.dash_past_bolt(from, to, DashRules.DURATION, movers, FavourRules.DANGER_RADIUS)


## Every enemy bolt in flight (Projectile.ENEMY_BOLT_GROUP; one already spent is not), as the
## rule's [position, velocity] pairs. The player's own shots are never in the group.
func _passes_a_bolt(from: Vector2, to: Vector2) -> bool:
	var bolts: Array[Array] = []
	for bolt: Projectile in get_tree().get_nodes_in_group(Projectile.ENEMY_BOLT_GROUP):
		if not bolt.is_queued_for_deletion():
			bolts.append([bolt.global_position, bolt.velocity()])
	return FavourRules.dash_past_bolt(from, to, DashRules.DURATION, bolts, FavourRules.BOLT_RADIUS)


## The hit detector: the act, the end of the perfect run, and the drop tallied under `hit` (what
## the meter really lost: less than the act's value near 0).
func _on_player_hit(_damage: int, _hp: int, _max_hp: int, _attacker_id: String) -> void:
	RunState.perfect = false
	RunState.hits_this_round += 1
	var before := RunState.favour
	_score("hit")
	_tally("hit", before - RunState.favour)


## The clean-round detector, then the verdict's mark on the perfect run: a round that ends
## below Roar ends it.
func _on_round_cleared() -> void:
	if RunState.hits_this_round == 0:
		_score("clean_round")
	if FavourRules.band(RunState.favour) < FavourRules.ROAR:
		RunState.perfect = false


## A round's start: its counters, its budget, and its gate start over, and the crowd settles to
## the gate (a Roar carried over comes down to it, told as `settle` only when it changes). The boss
## round instead goes wild: the meter to BOSS_START as `wild` (always told: Audio's roar), the gate
## open at once, its gains capped from here (_gain).
func _on_round_started(index: int, total: int) -> void:
	RunState.hits_this_round = 0
	_reset_round()
	if FavourRules.is_boss_round(index, total):
		boss_round = true
		gate_open = true
		entrance_held = true
		_change(FavourRules.BOSS_START, FavourRules.WILD_ACT)
	else:
		var settled := FavourRules.settle(RunState.favour)
		if settled != RunState.favour:
			_change(settled, FavourRules.SETTLE_ACT)
	last_scoring_time = RunState.elapsed
	_run_live = true


## A new run puts elapsed back to 0: a kill or a dash remembered from before it would otherwise
## chain with, or make daring, the next run's first kill (start_run resets the meter itself).
func _on_run_started() -> void:
	last_kill_time = -INF
	last_daring_dash_end = -INF
	last_scoring_time = 0.0
	last_hit_time = -INF
	_reset_round()
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


## The round's budget and gate start over: at every round's start, and at a run's (round_started(0)
## follows it in the game; a run started without a round, as a test may, starts clean too).
func _reset_round() -> void:
	round_kill_paid = 0.0
	gate_open = false
	round_losses = {}
	boss_round = false
	round_gain = 0.0
	entrance_held = false


## The round's main loss for the crowd's judgement: hit, fled, slow, or none (FavourRules.main_loss).
func round_loss() -> String:
	return FavourRules.main_loss(round_losses)


## Adds `lost` points to the round's tally under `source` while the run is live ("" is nobody's).
func _tally(source: String, lost: float) -> void:
	if not _run_live or source.is_empty() or lost <= 0.0:
		return
	round_losses[source] = float(round_losses.get(source, 0.0)) + lost


## The source of a drain now: the nearest harmful enemy's distance to the gladiator (found by
## its group, as the coin piles find it) and whether a shot landed within DECAY_GRACE, through
## FavourRules.drain_source; "" with no harmful enemy alive or no gladiator.
func _drain_source() -> String:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return ""
	var nearest := INF
	for enemy: Node2D in get_tree().get_nodes_in_group("enemies"):
		if _is_harmful(enemy):
			nearest = minf(nearest, enemy.global_position.distance_to(player.global_position))
	var engaged := RunState.elapsed - last_hit_time <= FavourRules.DECAY_GRACE
	return FavourRules.drain_source(nearest, engaged)


## Scores the table's act; a scoring act also restarts the decay's grace.
func _score(act: String) -> void:
	if FavourRules.is_scoring(act):
		last_scoring_time = RunState.elapsed
	_gain(FavourRules.apply(RunState.favour, act, gate_open), act)


## Scores a kill paying `share`; a kill is a scoring act even when it pays nothing.
func _score_kill(share: float) -> void:
	last_scoring_time = RunState.elapsed
	_gain(FavourRules.apply_kill(RunState.favour, share, gate_open), FavourRules.KILL_ACT)


## An act's result: in the boss round a rise is trimmed to what BOSS_GAIN_CAP leaves of the round's
## gains (FavourRules.gain_allowed) and counted into round_gain; a drop, and any other round's
## change, passes as it is. The decay, the settle, and the wild start never come through here.
func _gain(value: float, act: String) -> void:
	if boss_round:
		var allowed := FavourRules.gain_allowed(round_gain, value - RunState.favour)
		round_gain += maxf(allowed, 0.0)
		value = RunState.favour + allowed
	_change(value, act)


func _change(value: float, act: String) -> void:
	RunState.favour = value
	Events.favour_changed.emit(value, FavourRules.band(value), act)


## Duck-typed: the boss and the enemies both answer is_harmful; a corpse has left the group.
func _is_harmful(enemy: Node2D) -> bool:
	return enemy.has_method("is_harmful") and enemy.is_harmful()
