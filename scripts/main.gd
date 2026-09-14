extends Node2D
## Root of a run. Owns the player and the floor; swaps Room scenes as the player advances.

signal restart_requested

const ROOM := preload("res://scenes/room.tscn")
const FADE_TIME := 0.15
const DEATH_SUMMARY_DELAY := 0.6
const WIN_SUMMARY_DELAY := 1.0
## The entry opening shows for a beat after arriving, then bricks up behind the player.
const ENTRY_SEAL_DELAY := 0.4

static var _seed_arg_applied := false

## The run. The smoke tool and tests swap in small floors before adding Main to the tree.
@export var floor_def: FloorDef = preload("res://data/floors/floor_1.tres")

var room: Room
var room_index := 0
var room_open := false  ## the current room's exit is open
var _transitioning := false
var _ended := false  ## the first ending (win or death) claims the run
## Refund rounds still owed after a weapon switch, and the round index for the seeded draw.
var _rounds_owed := 0
var _pick_round := 0

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera
## CanvasLayer order: HUD 1, UpgradeMenu and BuildScreen 10 (never shown together), Fade 20, Summary 30: the menu sits over the HUD, the fade covers both, the summary reads over a fade.
@onready var fade: ColorRect = $Fade/Black
@onready var summary: CanvasLayer = $Summary
@onready var upgrade_menu: UpgradeMenu = $UpgradeMenu
@onready var build_screen: BuildScreen = $BuildScreen


func _ready() -> void:
	assert(floor_def != null, "Main needs a FloorDef")
	var errors := floor_def.validate()
	assert(errors.is_empty(), "Invalid floor: %s" % ", ".join(errors))
	_apply_seed_argument()
	RunState.rooms_total = floor_def.rooms.size()
	Events.player_died.connect(_on_player_died)
	Events.room_cleared.connect(_on_room_cleared)
	Events.room_exit_requested.connect(_on_room_exit_requested)
	upgrade_menu.chosen.connect(_on_upgrade_chosen)
	upgrade_menu.restart_pressed.connect(restart)
	build_screen.restart_pressed.connect(restart)
	build_screen.blocked = func() -> bool: return upgrade_menu.is_open() or _ended or _transitioning
	_enter_room(0)


func _exit_tree() -> void:
	# Explicit, like Fx: a scene reload must never leave the global bus pointing at a dying node.
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	if Events.room_cleared.is_connected(_on_room_cleared):
		Events.room_cleared.disconnect(_on_room_cleared)
	if Events.room_exit_requested.is_connected(_on_room_exit_requested):
		Events.room_exit_requested.disconnect(_on_room_exit_requested)


## `--seed=N` after `--` on the command line replays a run. Applied once per process, so R still
## gives a fresh seed afterwards.
func _apply_seed_argument() -> void:
	if _seed_arg_applied:
		return
	_seed_arg_applied = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var value: String = arg.get_slice("=", 1)
			if not value.is_valid_int() or int(value) < 0:
				push_warning("--seed=%s ignored: expected a non-negative integer" % value)
				continue
			RunState.start_run(int(value))


## Frees the current room (and everything in it) and builds room `index` around the player.
func _enter_room(index: int) -> void:
	if room != null:
		remove_child(room)
		room.queue_free()
	room_index = index
	room_open = false
	room = ROOM.instantiate()
	room.def = floor_def.rooms[index]
	room.entry_side = FloorRules.entry_side(floor_def, index)
	RunState.room = index  # before add_child: the arena floor RNG and spawner stream key on it
	add_child(room)
	move_child(room, 0)  # draws under the player and effects
	player.global_position = room.entry_position()
	player.projectile_parent = room.projectiles
	room.spawner.player = player
	_apply_camera_limits(room.full_rect())
	camera.reset_smoothing()
	Events.room_entered.emit(index, floor_def.rooms.size())
	# Started last so wave_started arrives after room_entered and with the spawner's player set.
	room.wave_runner.start(room.def.waves)
	if room.entry_side != FloorRules.NO_DOOR:
		_seal_entry_later(room)


## Real time so a kill freeze cannot stall it. Guarded on the room, not just the node: a restart
## or a quick second transition swaps `room` under the await, and the seal must not land on the
## wrong one (the old target is freed by then; is_instance_valid keeps the compare safe).
func _seal_entry_later(target: Room) -> void:
	await get_tree().create_timer(ENTRY_SEAL_DELAY, true, false, true).timeout
	if is_inside_tree() and is_instance_valid(target) and target == room:
		target.seal_entry()


func _on_room_cleared() -> void:
	RunState.rooms_cleared += 1
	if FloorRules.is_last(floor_def, room_index):
		_win()
		return
	_pick_round = 0
	_rounds_owed = 0
	_offer_upgrade.call_deferred(room)


## Deferred: room_cleared can arrive from inside a physics callback (a shot's body_entered), and
## pausing the tree or adding nodes there trips "can't change this state while flushing queries".
## Guarded on the room and the ending: a death or a restart in the gap must not open a menu.
func _offer_upgrade(target: Room) -> void:
	if not is_instance_valid(target) or target != room or _ended:
		return
	var pool := UpgradeCatalog.pool(RunState.build, player.hp, player.max_hp)
	var offers := UpgradeCatalog.draw(pool, RunState.stream("upgrades:%d:%d" % [room_index, _pick_round]))
	if offers.is_empty():
		upgrade_menu.close()
		_open_exit()
		return
	if build_screen.is_open():
		build_screen.close()
	upgrade_menu.open(offers)


## Applies a card. Refund rounds accumulate: a pick in a refund round spends one owed round, and a
## switch adds one round per upgrade the old weapon had, so a switch taken during a refund round
## keeps the rounds still owed. The menu closes and the exit opens once nothing is owed.
func _on_upgrade_chosen(card: UpgradeDef) -> void:
	if _pick_round > 0:
		_rounds_owed -= 1  # this pick spent a refund round
	match card.kind:
		UpgradeDef.Kind.HEAL:
			player.heal(HeartRules.HP_PER_HEART)
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
	_open_exit()


func _open_exit() -> void:
	room.open_exit()
	room_open = true


func _on_room_exit_requested() -> void:
	if not room_open or _transitioning:
		return
	_transition_to(room_index + 1)


## Fade to black, swap the room, fade back. Real time so a kill freeze cannot stall it.
## Door emits the request deferred and the swap sits behind a tween await, so _enter_room
## runs in idle time, never inside a physics callback. If Main is freed mid-fade the awaits
## simply never resume; _transitioning dies with the node, so it cannot stick.
func _transition_to(index: int) -> void:
	_transitioning = true
	await _fade_to(1.0)
	if player.dead:
		_transitioning = false
		return  # died to a bolt during the fade: hold on the corpse, the summary draws over the black
	_enter_room(index)
	await _fade_to(0.0)
	_transitioning = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(fade, "color:a", alpha, FADE_TIME)
	await tween.finished


func _win() -> void:
	if _ended:
		return
	_ended = true
	print("RUN_WON kills=%d rooms=%d seed=%d elapsed=%.1f" % [RunState.kills, RunState.rooms_cleared, RunState.seed_value, RunState.elapsed])
	Events.run_won.emit()
	await get_tree().create_timer(WIN_SUMMARY_DELAY, true, false, true).timeout
	if is_inside_tree():
		summary.show_run("Floor cleared")


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
	restart_requested.emit()
	Juice.reset()
	RunState.start_run()
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


## Death holds on the corpse until R. The wave runner stays off so nothing crowds the corpse; the
## summary waits for the freeze and burst to play, then reads over whatever is on screen.
func _on_player_died(_death_position: Vector2) -> void:
	if _ended:
		return  # a death after the win changes nothing: the room is cleared, the runner is idle
	_ended = true
	room.wave_runner.enabled = false
	print("RUN_OVER kills=%d rooms=%d seed=%d elapsed=%.1f" % [RunState.kills, RunState.rooms_cleared, RunState.seed_value, RunState.elapsed])
	await get_tree().create_timer(DEATH_SUMMARY_DELAY, true, false, true).timeout
	if is_inside_tree():
		summary.show_run("You died")
