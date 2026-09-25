class_name Main
extends Node2D
## Root of a run. Owns the player and the one Room; a run is the series' rounds fought in it,
## the wave runner given the next round's table after each pick.

signal restart_requested

const ROOM := preload("res://scenes/room.tscn")
const COIN_PILE := preload("res://scenes/coin_pile.tscn")
const DEATH_SUMMARY_DELAY := 0.6
const WIN_SUMMARY_DELAY := 1.0
## A beat between the last kill and the picker, so the kill burst and freeze play out first.
const PICKER_DELAY := 0.8
## A beat between the pick and the next round's first wave: the crowd settling.
const ROUND_GAP := 1.0

static var _seed_arg_applied := false
## A restart reloads the scene, and the reload cannot carry state, so this one-shot flag says
## which of R and Quit to title caused it: R sets it and the new _ready goes straight into the
## run; Quit to title clears it so the reload shows the title.
static var _skip_title_once := false

## The run. The smoke tool and tests swap in small series before adding Main to the tree.
@export var series_def: SeriesDef = preload("res://data/series/tier_1.tres")
## The run starts behind the title. Tests and the smoke tool set this false before adding Main;
## a --seed argument skips the title too, so a replay is still one command.
@export var start_at_title := true

var room: Room
var round_index := 0
var _ended := false  ## the first ending (win or death) claims the run
## Refund rounds still owed after a weapon switch, and the round index for the seeded draw.
var _rounds_owed := 0
var _pick_round := 0
## The round's verdict for the picker: who grants the cards and how many, from the band at the
## round's end. A refund round keeps the same granter and count.
var _granter := ""
var _offer_count := FavourRules.OFFER_COUNT
## Bumped by restart(): an await started in the previous run must not act on this one. Only the
## harnesses need it; in the game a restart reloads the scene and the awaits die with the node.
var _run_serial := 0
## The round's stream for the piles' spots (RunState.stream("piles:<round>"), drawn from by every
## throw of the round), so a replay throws to the same spots.
var _pile_rng: RandomNumberGenerator

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera
## CanvasLayer order: HUD 1, UpgradeMenu and BuildScreen 10 (never shown together), Title 15, Fade 20, Summary 30: the menu sits over the HUD, the title over the menus, the fade covers them all, the summary reads over a fade.
@onready var summary: Summary = $Summary
@onready var upgrade_menu: UpgradeMenu = $UpgradeMenu
@onready var build_screen: BuildScreen = $BuildScreen
@onready var title: Title = $Title
@onready var hud: Hud = $HUD


func _ready() -> void:
	assert(series_def != null, "Main needs a SeriesDef")
	var errors := series_def.validate()
	assert(errors.is_empty(), "Invalid series: %s" % ", ".join(errors))
	var seeded := _apply_seed_argument()
	var skip := _skip_title_once
	_skip_title_once = false
	RunState.rounds_total = series_def.rounds.size()
	Events.player_died.connect(_on_player_died)
	Events.round_cleared.connect(_on_round_cleared)
	Events.enemy_died.connect(_on_enemy_died)
	upgrade_menu.chosen.connect(_on_upgrade_chosen)
	upgrade_menu.restart_pressed.connect(restart)
	build_screen.restart_pressed.connect(restart)
	build_screen.quit_pressed.connect(quit_to_title)
	summary.quit_requested.connect(quit_to_title)
	build_screen.blocked = func() -> bool: return upgrade_menu.is_open() or _ended or title.is_open()
	title.play_pressed.connect(play)
	# The two Quit buttons end the process; tests swap this connection for a counter before pressing.
	title.quit_requested.connect(get_tree().quit)
	build_screen.quit_requested.connect(get_tree().quit)
	_build_room()
	_enter_round(0)
	if start_at_title and not seeded and not skip:
		_show_title()


func _exit_tree() -> void:
	# Explicit, like Fx: a scene reload must never leave the global bus pointing at a dying node.
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	if Events.round_cleared.is_connected(_on_round_cleared):
		Events.round_cleared.disconnect(_on_round_cleared)
	if Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.disconnect(_on_enemy_died)


## `--seed=N` after `--` on the command line replays a run. Applied once per process, so R still
## gives a fresh seed afterwards. Returns true when a seed was applied (the title is skipped).
func _apply_seed_argument() -> bool:
	if _seed_arg_applied:
		return false
	_seed_arg_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var value: String = arg.get_slice("=", 1)
			if not value.is_valid_int() or int(value) < 0:
				push_warning("--seed=%s ignored: expected a non-negative integer" % value)
				continue
			RunState.start_run(int(value))
			return true
	return false


## Frees the previous run's Room (and everything in it) and builds the run's one Room around
## the player: its floor art keys on the seed, so Play from the title rebuilds it.
func _build_room() -> void:
	if room != null:
		remove_child(room)
		room.queue_free()
	room = ROOM.instantiate()
	room.width = series_def.arena_width
	room.height = series_def.arena_height
	add_child(room)
	move_child(room, 0)  # draws under the player and effects
	player.global_position = room.entry_position()
	player.projectile_parent = room.projectiles
	room.spawner.player = player
	_apply_camera_limits(room.full_rect())
	camera.reset_smoothing()


## Round `index` in the one Room, the player standing where they are: the spawner re-seeds on
## the round and the runner takes its table. The round's tally starts over here (Main owns the
## round flow and is the tally's one reader, in _pay_bonus), as does the piles' stream.
func _enter_round(index: int) -> void:
	round_index = index
	RunState.round_index = index
	RunState.round_tally = 0
	_pile_rng = RunState.stream("piles:%d" % index)
	room.spawner.start_round()
	Events.round_started.emit(index, series_def.rounds.size())
	# Started last so wave_started arrives after round_started.
	room.wave_runner.start(series_def.rounds[index].waves)


## Favour's own round_cleared handler ran first (it is a child), so the clean-round bonus is in
## the meter when the band is read here: the verdict goes out on the bus (the crowd's sound) and
## sets who grants the cards and how many.
func _on_round_cleared() -> void:
	RunState.rounds_cleared += 1
	var band := FavourRules.band(RunState.favour)
	Events.round_ended.emit(band)
	_pay_bonus(band)
	_clear_projectiles.call_deferred(room)  # the last kill ends the fight: shots and bolts vanish with it
	if series_def.is_last(round_index):
		_win()
		return
	_pick_round = 0
	_rounds_owed = 0
	_granter = FavourRules.granter(band)
	_offer_count = FavourRules.offer_count(band)
	_offer_upgrade_later(room)


## The band's bonus on the round's tally: a Cheer pays half of it to the counter with one flight
## from the emperor's box; a Roar throws all of it on the floor around the player. Boo and Quiet
## pay nothing. Inside the round_cleared physics callback, so the throw is deferred (a pile is a
## physics body); the flight is a sprite on the HUD and may start here.
func _pay_bonus(band: int) -> void:
	var tally := RunState.round_tally
	match band:
		FavourRules.CHEER:
			@warning_ignore("integer_division")
			var half: int = tally / 2
			if half > 0:
				_pay(half, room.emperor_box.centre())
		FavourRules.ROAR:
			throw_piles.call_deferred(player.global_position, tally)


## A kill's coins: the boss's are always thrown on the floor where it fell (deferred out of the
## physics callback enemy_died arrives in); any other enemy's go to the counter and the round's
## tally with a flight from the corpse. Duck-typed: a test's stub has no def, the boss's is a
## BossDef.
func _on_enemy_died(enemy: Node2D, death_position: Vector2) -> void:
	var coins := _coins_of(enemy)
	if coins <= 0:
		return
	if enemy.is_in_group("boss"):
		throw_piles.call_deferred(death_position, coins)
		return
	RunState.round_tally += coins
	_pay(coins, death_position)


func _coins_of(enemy: Node2D) -> int:
	var def: Variant = enemy.get("def")
	var coins: Variant = def.get("coins") if def != null else null
	return int(coins) if coins != null else 0


## `coins` onto the counter now, with one flight from `from` (a world position) to show it.
func _pay(coins: int, from: Vector2) -> void:
	RunState.coins += coins
	Events.coins_changed.emit(RunState.coins)
	hud.fly_coin(from)


## `total` coins on the floor around `at` as PileRules piles, each tossed to a seeded spot inside
## the floor; one coin_toss for the throw. Nothing for a total of 0. Never inside a physics
## callback: a pile is an Area2D, so the callers defer.
func throw_piles(at: Vector2, total: int) -> void:
	var count := PileRules.pile_count(total)
	if count == 0:
		return
	var values := PileRules.split(total, count)
	var floor_rect := room.bounds()
	var spots := PileRules.spots(at, PileRules.PILE_RADIUS, count,
		Rect2(room.to_global(floor_rect.position), floor_rect.size), _pile_rng)
	for i in count:
		var pile: CoinPile = COIN_PILE.instantiate()
		pile.value = values[i]
		room.piles.add_child(pile)
		pile.toss(at, spots[i])
	Events.coins_thrown.emit(at, total)


## Real time, so the kill freeze cannot stall it; the await also takes the open out of the
## physics callback round_cleared arrives in. Guarded after the await on the node, the room, the
## ending, and the run: a death, a restart, or Play from the title (which rebuilds the room)
## during the beat must not open a menu (_offer_upgrade re-checks the room and the ending).
func _offer_upgrade_later(target: Room) -> void:
	var run := _run_serial
	await get_tree().create_timer(PICKER_DELAY, true, false, true).timeout
	if is_inside_tree() and is_instance_valid(target) and target == room and not _ended and run == _run_serial:
		_offer_upgrade(target)


## Deferred and guarded on the room like _offer_upgrade: round_cleared arrives from a shot's
## body_entered, where freeing physics nodes trips the flushing-queries error.
func _clear_projectiles(target: Room) -> void:
	if not is_instance_valid(target) or target != room:
		return
	for shot in target.projectiles.get_children():
		target.projectiles.remove_child(shot)
		shot.queue_free()


## Never inside a physics callback: a round clear waits the beat above, a refund round is
## deferred (pausing the tree or adding nodes in a shot's body_entered trips "can't change this
## state while flushing queries"). Guarded on the room and the ending: a death or a restart in
## the gap must not open a menu. A round with nothing to offer goes to the gap at once.
func _offer_upgrade(target: Room) -> void:
	if not is_instance_valid(target) or target != room or _ended:
		return
	var hurt := player.hp < player.max_hp
	var offers := UpgradeCatalog.offers(RunState.build, hurt,
		RunState.stream("upgrades:%d:%d" % [round_index, _pick_round]), _offer_count)
	if build_screen.is_open():
		build_screen.close()
	if offers.is_empty():
		upgrade_menu.close()
		_next_round_later(target)
		return
	upgrade_menu.open(offers, _granter)


## Applies a card. Refund rounds accumulate: a pick in a refund round spends one owed round, and a
## switch adds one round per upgrade the old weapon had, so a switch taken during a refund round
## keeps the rounds still owed. The menu closes and the gap begins once nothing is owed.
func _on_upgrade_chosen(card: UpgradeDef, _index: int) -> void:
	if _pick_round > 0:
		_rounds_owed -= 1  # this pick spent a refund round
	match card.kind:
		UpgradeDef.Kind.HEAL:
			player.heal(HeartRules.heal_amount(player.max_hp))
		UpgradeDef.Kind.SWITCH:
			_rounds_owed += RunState.build.switch_weapon(card.weapon_id)
		_:
			RunState.build.add_rank(card)
	Events.upgrade_chosen.emit(card, RunState.build.rank_of(card.id))
	Events.build_changed.emit()
	if _rounds_owed > 0:
		_pick_round += 1
		_offer_upgrade.call_deferred(room)  # a click arrives inside the Button's pressed emission; rebuild the cards after it
		return
	upgrade_menu.close()
	_next_round_later(room)


## The beat between the pick and the next round, guarded like the picker's: a death, a restart,
## or Play from the title in the gap leaves the round where it is. Unlike the picker's beat it
## pauses with the game (a pause screen opened in the gap holds the next round until it closes),
## while still ignoring the time scale so a kill freeze cannot stall it.
func _next_round_later(target: Room) -> void:
	var run := _run_serial
	await get_tree().create_timer(ROUND_GAP, false, false, true).timeout
	if is_inside_tree() and is_instance_valid(target) and target == room and not _ended and run == _run_serial:
		_enter_round(round_index + 1)


func _win() -> void:
	if _ended:
		return
	_ended = true
	print("RUN_WON kills=%d rounds=%d seed=%d elapsed=%.1f%s" % [RunState.kills, RunState.rounds_cleared, RunState.seed_value, RunState.elapsed, _cheats_suffix()])
	Events.run_won.emit()
	await get_tree().create_timer(WIN_SUMMARY_DELAY, true, false, true).timeout
	if is_inside_tree():
		summary.show_run("Floor cleared", true)


## The view may show the walls but never the void past them.
func _apply_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()


## Reloads only when Main is the current scene: test harnesses and the smoke tool instance Main
## as a child of themselves, and must not be reloaded out from under their own script.
func restart() -> void:
	upgrade_menu.close()  # hides and unpauses: both are state a scene reload would keep, and without a reload the menu would stay up
	build_screen.close()
	summary.visible = false  # the same: a harness has no reload to clear the card
	_run_serial += 1
	restart_requested.emit()
	Juice.reset()
	RunState.start_run()
	if get_tree().current_scene == self:
		_skip_title_once = true
		get_tree().reload_current_scene()


## The title over the arena, paused. R and Tab do nothing here (Main is paused; the build screen
## is blocked).
func _show_title() -> void:
	Juice.reset()
	get_tree().paused = true
	Audio.stop_game_sounds()  # the boot's round_start and wave_start, or Play would resume them next to the rebuilt arena's
	hud.visible = false  # the boot's hearts and counters have nothing to say under the dim
	title.open()


## " cheats=<flags>" for the RUN_OVER/RUN_WON line when any cheat is on, else "".
func _cheats_suffix() -> String:
	var cheats := Cheats.describe(RunState.cheats)
	return "" if cheats.is_empty() else " cheats=" + cheats


## Play from the title: a fresh run on the seed from the field (or random) in a Room rebuilt for
## it, since the floor art keyed on the old seed when the boot's Room was built; the field's
## cheat flags, if it held a code word, go with the seed.
func play(seed_value: int = -1, cheats: Dictionary = {}) -> void:
	_ended = false
	RunState.start_run(seed_value, cheats)
	RunState.rounds_total = series_def.rounds.size()
	title.close()
	hud.visible = true
	get_tree().paused = false
	_build_room()
	_enter_round(0)


## Quit to title from the pause screen or the summary: a restart, then the title over it. In the
## game the restart reloads the scene and _ready shows the title; in a harness (no reload) it is
## shown here. The reload takes Main out of the tree at once (get_tree() is null after it), so the
## check comes first.
func quit_to_title() -> void:
	var reloads := get_tree().current_scene == self
	restart()  # hides the summary too
	_skip_title_once = false  # the reload restart() queued must land on the title
	if not reloads:
		_show_title()


## Death holds on the corpse until R. The wave runner stays off so nothing crowds the corpse; the
## summary waits for the freeze and burst to play, then reads over whatever is on screen.
func _on_player_died(_death_position: Vector2) -> void:
	if _ended:
		return  # a death after the win changes nothing: the round is cleared, the runner is idle
	_ended = true
	room.wave_runner.enabled = false
	print("RUN_OVER kills=%d rounds=%d seed=%d elapsed=%.1f%s" % [RunState.kills, RunState.rounds_cleared, RunState.seed_value, RunState.elapsed, _cheats_suffix()])
	await get_tree().create_timer(DEATH_SUMMARY_DELAY, true, false, true).timeout
	if is_inside_tree():
		summary.show_run("You died", false)
