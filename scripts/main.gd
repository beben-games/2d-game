class_name Main
extends Node2D
## Root of the game. Owns the player and one stage at child index 0: the Room (the arena; a run
## is the series' rounds fought in it, the wave runner given the next round's table after each
## pick) or the Grounds (one room of the grounds between runs, built from its GroundsRoomDef:
## the Ludus with the training post, the Armamentarium with the rack, the Hypogeum with the lift,
## the Sanitarium, the Spoliarium, joined by doors; every station and door acted on with the one
## interact key); never both (enter_arena and enter_grounds swap them, _go_to_room swaps one
## room for the next). The run ends in the verdict scene (the fall with the thumb over the
## box, or the boss's corpse hold with no thumb: a win asks no emperor; then the fade, the gate
## screen), which banks the run into the profile; the gate screen's continue leads to the
## Ludus (after a thumbs down, the Spoliarium: the gladiator wakes there lying), and the
## Hypogeum's lift is the only way into the next run. The first run of a profile
## starts in the arena straight from the title (the grounds are seen only after it:
## flags.returned). R, Restart, and Quit to title mid-run are a yield (the coins lost, a fall
## counted, no verdict); in the grounds R and Restart do nothing and Quit to title yields nothing.

signal restart_requested
## A room of the grounds is up and the black has lifted: the last step of every arrival (Play on
## a returned profile, the gate screen's pass, a door), from _room_shown. Not on the bus: what
## plays as a room is first seen hooks it here.
signal room_shown(id: String)

const ROOM := preload("res://scenes/room.tscn")
const GROUNDS := preload("res://scenes/grounds.tscn")
const COIN_PILE := preload("res://scenes/coin_pile.tscn")
## The verdict scene, real time by design: the beat on the corpse (the win's, after the boss's
## corpse hold; the fall's, after the hush), then on a fall the build-up (the camera's drift
## from the gladiator to the emperor's box under the drum roll, zooming in by VERDICT_ZOOM so
## the box sits at the top of the frame with the arena under it, and the held pause on the
## box, the roll still going) before the thumb, the thumb's stay (long enough to read the
## narrator's line under it), and the fade. A win's stay (WIN_SHOW) is its own: no thumb and no
## line to read, only the sweep's flights landing.
const WIN_HOLD := 1.0
const WIN_SHOW := 1.2
const VERDICT_HOLD := 1.0
const VERDICT_DRIFT := 1.5
const VERDICT_ZOOM := 1.5
const VERDICT_PAUSE := 1.2
const VERDICT_SHOW := 2.5
const FADE_TIME := 0.15
## A beat between the last kill and the picker, so the kill burst and freeze play out first.
const PICKER_DELAY := 0.8
## A beat between the pick and the next round's first wave: the crowd settling.
const ROUND_GAP := 1.0
## After the gap, how long the next round waits for the piles still on the floor to be picked up.
const PILE_WAIT_CAP := 6.0
## How long a timed pool's entry line (the narrator's as the gladiator wakes in the Spoliarium)
## stays in the timed window once the black has lifted, real time.
const ENTRY_LINE_TIME := 3.0

static var _seed_arg_applied := false
## A restart reloads the scene, and the reload cannot carry state, so this one-shot flag says
## which of R and Quit to title caused it: R sets it and the new _ready goes straight into the
## run; Quit to title clears it so the reload shows the title.
static var _skip_title_once := false

## The series fought: its `tier` is the tier the run is in (the record, the bests, the unlocks
## read it there; RunState.tier is only the request for the next run's series). Left unset it is
## the tier's (Tiers.series(RunState.tier)), read again at every run's start; a series set from
## code (a test's, the smoke tool's, before or after Main is in the tree) is kept for every later
## run of this Main (their restart never reloads the scene: Main is not the current scene there).
## Set to null, the tier's again. Not an export: the inspector never pins one by accident.
var series_def: SeriesDef:
	get:
		return _series
	set(value):
		_series = value
		_series_from_tier = value == null
## The run starts behind the title. Tests and the smoke tool set this false before adding Main;
## a --seed argument skips the title too, so a replay is still one command.
@export var start_at_title := true

## The stage: exactly one of the two is under Main at a time, the other null.
var room: Room
var grounds: Grounds
var round_index := 0
## series_def's value; the tier's read writes it here, so the read never counts as a set series.
var _series: SeriesDef
## True while no series was set (the game): each run's start reads series_def from the tier.
var _series_from_tier := true
var _ended := false  ## the first ending (win or fall) claims the run; a verdict or a yield follows once
## The band at each round's end this run, in order: the run's record logs them.
var round_bands: Array[int] = []
## What the killing hit came from ("" for a win): deaths_by names it on a thumb down.
var _fall_attacker := ""
## RunState.elapsed when the boss became active (-1 before), and the fight's length once it
## died: the profile keeps the fastest on a win.
var _boss_spawn_elapsed := -1.0
var _boss_time := 0.0
## Refund rounds still owed after a weapon switch, the round index for the seeded draw, and the
## re-draws taken this round (each names its own stream; cleared with the pick round).
var _rounds_owed := 0
var _pick_round := 0
var _rerolls := 0
## The round's verdict for the picker: how many cards (the band's count plus the profile's
## Offer ranks, RunState.offer_bonus, UpgradeMenu.MAX_CARDS at most), and whether the crowd
## roared (one card is then the crowd's). A refund round or a reroll keeps both.
var _offer_count := FavourRules.OFFER_COUNT
var _roar := false
## How many cards the crowd takes from each of the round's offers (FavourRules.lock_count: one at
## a Boo); every open of the round's picker, a reroll and a refund round too, draws its own.
var _locks := 0
## The crowd's judgement of the round for the picker: the round's end as the story reads it
## (round_band, round_loss), taken at the clear, and the line said at the first open ("" for
## none), kept through a reroll and a refund round.
var _crowd_facts: Dictionary = {}
var _crowd_line := ""
## Bumped by restart(): an await started in the previous run must not act on this one. Only the
## harnesses need it; in the game a restart reloads the scene and the awaits die with the node.
var _run_serial := 0
## The round's stream for the piles' spots (RunState.stream("piles:<round>"), drawn from by every
## throw of the round), so a replay throws to the same spots. Set in _enter_round, so a harness
## restart() without a reload keeps the previous run's stream until its next round (the same
## harness-only staleness as the awaits _run_serial guards).
var _pile_rng: RandomNumberGenerator
## The title's seed and cheats, kept for the run the lift starts (Play on a returned profile goes
## to the grounds first; a walk between their rooms keeps them); used once, then random and none.
var _pending_seed := Cheats.RANDOM_SEED
var _pending_cheats: Dictionary = {}
## True from E on the lift until the run is started, and from E on a door until the next room is
## up and the black has lifted: E again during the fade changes nothing. Cleared by _room_shown
## (an arrival's end) and by enter_grounds (a bare arrival, and the net under a walk a quit left).
var _leaving_grounds := false
## The process frame in which Esc closed a grounds panel: the pause screen, polling the same
## press later in that frame, stays shut for it.
var _pause_spent_frame := -1
## The station whose panel is open (null with none): E on it again shuts the panel, and the panel
## shuts when the focus is anything else.
var _panel_owner: Station
## Bumped by every entry line shown, every stage swap, _forget_run, and the pause screen's opening:
## an entry line's timer that ends after any of them takes nothing down (the line went with its
## room or with the pause screen's opening, or a later line is up).
var _entry_line := 0

@onready var player: Player = $Player
@onready var camera: Camera = $Player/Camera
## CanvasLayer order: HUD 1, Prompt (the key cap) 2, UpgradeMenu, TrainingPanel, ArmouryPanel, DialogueBox, and BuildScreen 10 (never two shown together but a panel under the pause screen, which is later in the tree), Title 15, Fade 20, GateScreen 30: the menus sit over the HUD and the key cap, the title over the menus, the fade covers them all, the gate screen reads over the fade.
@onready var gate_screen: GateScreen = $GateScreen
@onready var fade: ColorRect = $Fade/Black
@onready var upgrade_menu: UpgradeMenu = $UpgradeMenu
@onready var build_screen: BuildScreen = $BuildScreen
@onready var training_panel: TrainingPanel = $TrainingPanel
@onready var armoury_panel: ArmouryPanel = $ArmouryPanel
@onready var dialogue_box: DialogueBox = $DialogueBox
@onready var title: Title = $Title
@onready var hud: Hud = $HUD
@onready var key_cap: KeyCap = $Prompt/KeyCap
@onready var favour: Favour = $Favour


func _ready() -> void:
	if not _read_tier_series():
		return  # pushed: a build without tier 1's series has nothing to run (an export strips asserts)
	assert(series_def != null, "Main needs a SeriesDef")
	var errors := series_def.validate()
	assert(errors.is_empty(), "Invalid series: %s" % ", ".join(errors))
	var seeded := _apply_seed_argument()
	var skip := _skip_title_once
	_skip_title_once = false
	RunState.rounds_total = series_def.rounds.size()
	Events.player_fell.connect(_on_player_fell)
	Events.round_cleared.connect(_on_round_cleared)
	Events.enemy_died.connect(_on_enemy_died)
	Events.boss_spawned.connect(_on_boss_spawned)
	upgrade_menu.chosen.connect(_on_upgrade_chosen)
	upgrade_menu.reroll_requested.connect(_on_reroll_requested)
	upgrade_menu.restart_pressed.connect(restart)
	build_screen.restart_pressed.connect(restart)
	build_screen.quit_pressed.connect(quit_to_title)
	gate_screen.continue_requested.connect(_pass_gate)
	gate_screen.restart_pressed.connect(restart)
	gate_screen.quit_requested.connect(quit_to_title)
	build_screen.blocked = func() -> bool:
		return upgrade_menu.is_open() or _ended or title.is_open() or dialogue_box.is_open() or _pause_spent_frame == Engine.get_process_frames()
	title.play_pressed.connect(play)
	# The two Quit buttons end the process; tests swap this connection for a counter before pressing.
	title.quit_requested.connect(get_tree().quit)
	build_screen.quit_requested.connect(get_tree().quit)
	Events.menu_opened.connect(_on_menu_opened)
	_start_first_round()
	if start_at_title and not seeded and not skip:
		_show_title()


func _exit_tree() -> void:
	# Explicit, like Fx: a scene reload must never leave the global bus pointing at a dying node.
	if Events.player_fell.is_connected(_on_player_fell):
		Events.player_fell.disconnect(_on_player_fell)
	if Events.round_cleared.is_connected(_on_round_cleared):
		Events.round_cleared.disconnect(_on_round_cleared)
	if Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.disconnect(_on_enemy_died)
	if Events.boss_spawned.is_connected(_on_boss_spawned):
		Events.boss_spawned.disconnect(_on_boss_spawned)
	if Events.menu_opened.is_connected(_on_menu_opened):
		Events.menu_opened.disconnect(_on_menu_opened)


## The tier's series as the run's, when none was set (the game): RunState.tier's, or tier 1's for a
## tier with no series (pushed: the lift offers only tiers that have one). A set series stays.
## False (pushed) when there is no series at all, tier 1's own having failed to load: the caller
## starts nothing.
func _read_tier_series() -> bool:
	if not _series_from_tier:
		return _series != null
	_series = Tiers.series(RunState.tier)
	if _series == null:
		push_error("Main: tier %d has no series; tier 1 is fought" % RunState.tier)
		RunState.reset_tier()
		_series = Tiers.series(1)
	if _series == null:
		push_error("Main: tier 1 has no series (%s): no run can start" % Tiers.path(1))
		return false
	return true


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


## The arena as the stage: the run's one Room mounted around the player (its floor art keys on
## the seed, so every run rebuilds it), the trigger live, the HUD shown. The body is whole
## already: every caller comes from a run's start (RunState.start_run revived it) or from the
## grounds (enter_grounds did). Never inside a physics callback (a stage holds physics nodes).
func enter_arena() -> void:
	var next: Room = ROOM.instantiate()
	next.width = series_def.arena_width
	next.height = series_def.arena_height
	_mount_stage(next)
	room = next
	room.spawner.player = player
	player.can_fire = true
	hud.visible = true
	build_screen.set_restart_visible(true)


## The arrival in the grounds from outside (the gate screen's continue, Play on a returned
## profile), into the room `room_id`: mounted with the player (a whole body again: the fallen
## gladiator walks here) at its entry, the last run's build cleared first so the revive reads the
## bases (no boon is held in the grounds: the base hearts, one charge, the handgun), the trigger
## off (no shots there), the HUD hidden (no run is live: RunState keeps the last run's numbers
## (the build aside) and nothing reads them here), the pause screen's Restart hidden, the tier back
## to 1 (the lift a run starts from sets it), and grounds_entered (the profile's clock), then
## room_entered (the music), out on the bus. Never inside a physics callback.
func enter_grounds(room_id := "ludus") -> void:
	if GroundsRooms.room(room_id) == null:
		push_error("Main: no room '%s' to enter" % room_id)
		return
	RunState.clear_build()
	RunState.reset_tier()
	player.revive()
	mount_room(GroundsRooms.room(room_id), "")
	_leaving_grounds = false
	player.can_fire = false
	hud.visible = false
	build_screen.set_restart_visible(false)
	Events.grounds_entered.emit()
	Events.room_entered.emit(room_id)


## A Grounds built from `def` as the stage, the player at its entry (before the door back to
## `arrived_from`, "" from outside), the camera held to its size. Mounts only: the callers emit
## (enter_grounds, _go_to_room); a test mounts a def of its own. Never inside a physics callback.
func mount_room(def: GroundsRoomDef, arrived_from: String) -> void:
	var next: Grounds = GROUNDS.instantiate()
	next.room_def = def
	next.arrived_from = arrived_from
	next.player = player
	next.focus_changed.connect(_on_focus_changed)
	next.interacted.connect(_on_interacted)
	_mount_stage(next)
	grounds = next


## The one stage slot: whichever stage is up goes (the Room with its piles, its thumb, and its
## runner; the Grounds with their stations, the panels closed; a timed line in the box with
## it), `stage` takes child index 0
## (under the player and the effects), and the player is put at its entry with the stage's
## Projectiles node (read once the stage is in the tree; the grounds have none, and no shot
## there) as the parent of its shots and the camera held to its rect. The stages answer
## entry_position() and full_rect() alike (duck-typed: neither extends the other).
func _mount_stage(stage: Node2D) -> void:
	_close_panels()
	key_cap.target = null
	dialogue_box.hide_timed()  # a timed line belongs to the stage it was said on
	_entry_line += 1
	for old: Node2D in [room, grounds]:
		if old != null:
			remove_child(old)
			old.queue_free()
	room = null
	grounds = null
	add_child(stage)
	move_child(stage, 0)
	player.global_position = stage.call("entry_position")
	player.projectile_parent = stage.get_node_or_null("Projectiles")
	_apply_camera_limits(stage.call("full_rect"))
	camera.reset_smoothing()


## The arena and its first round: the boot (under the title) and every run's start.
func _start_first_round() -> void:
	enter_arena()
	_enter_round(0)


## E on the grounds' focus, by its kind: a station by its id (the post toggles the training
## panel, the rack the armoury, each after its keeper's new word; the lift starts the run), a
## door walks to the room behind it, a character talks. Nothing acts once a fade (the lift's, a
## door's) has begun, while the box is up (the tree is paused under it: a guard for a caller
## outside the input path), or while the gladiator lies (the E that rises reaches the grounds as
## an event before the physics tick that rises the body: it is spent on rising, whatever is in
## reach).
func _on_interacted(item: Interactable) -> void:
	if _leaving_grounds or dialogue_box.is_open() or player.prone:
		return
	match item.kind:
		"station":
			_on_station(item as Station)
		"door":
			_close_panels()
			_go_to_room((item as Door).to)
		"character":
			_talk(item.id)


## E on a character: the event the picker gives for its pool on `talk` (something new, else the
## filler bark), played in the box. With no eligible event, nothing happens.
func _talk(cast_id: String) -> void:
	var event := Story.next(cast_id, "talk")
	if event == null:
		return
	_close_panels()
	await _play_event(event)


## The one way Main plays a story event in the box: refused (false, nothing marked played) when
## there is none, the box is up, or the tree is paused (a menu: the box would refuse it); else it
## counts as played from its start (Story.begin), plays on the side of the view away from the
## gladiator (_box_at_top), and once the box has shut its end effects run and the save is written
## (Story.finish); true.
func _play_event(event: StoryEvent, facts: Dictionary = {}) -> bool:
	if event == null or dialogue_box.is_open() or get_tree().paused:
		return false
	Story.begin(event)
	await dialogue_box.play(event, facts, _box_at_top())
	Story.finish(event)
	return true


## The room's entry event, if the story has one for it (`enter <room>`: the first return's
## arrival in the Ludus, the narrator's as the gladiator wakes in the Spoliarium), once the black
## has lifted, picked and played with the moment's fact `arrival` (how the gladiator came in:
## `gate`, `door`, or `start`): a timed pool's in the timed window (_show_entry_line: no pause, no
## input; the gladiator may lie there, needing the first press to rise), any other's played in the
## box. Most arrivals have none and show nothing (no pause, no box).
func _play_entry(room_id: String, arrival: String) -> void:
	var facts := {"arrival": arrival}
	var event := Story.next("", "enter", room_id, facts)
	if event == null:
		return
	if Story.catalog.is_timed(event):
		_show_entry_line(event, facts)
		return
	await _play_event(event, facts)


## A timed entry event's first shown line in the timed window, on the side of the view away from
## the gladiator (_box_at_top: the top for the wake at the bottom centre), for ENTRY_LINE_TIME real
## seconds. Played at once, as every timed line is (_say: begun and finished, its end effects
## run, the save written: nothing in the grounds commits after it). Taken down after its time
## only while it is still the line on show (_entry_line: a stage swap took it down with its room,
## the pause screen's opening took it down, or a later line replaced it), so no exit leaves it
## up and no late timer takes a later line down. Nothing when the box is up or no line shows.
func _show_entry_line(event: StoryEvent, facts: Dictionary) -> void:
	if dialogue_box.is_open():
		return
	var line := _say(event, facts, true)
	if line.is_empty():
		return
	dialogue_box.show_timed(line["speaker"], line["text"], _box_at_top())
	_entry_line += 1
	var token := _entry_line
	await get_tree().create_timer(ENTRY_LINE_TIME, true, false, true).timeout
	if is_inside_tree() and token == _entry_line:
		dialogue_box.hide_timed()


## The pause screen opening takes a timed line down (both are on layer 10, the pause screen drawn
## after the box: the window would show around it). Only the entry line can be up then: the
## verdict's narrator comes after the run has ended (the pause screen is blocked), and the crowd's
## line is the picker's.
func _on_menu_opened(menu: String) -> void:
	if menu == "build":
		dialogue_box.hide_timed()
		_entry_line += 1


## True when the gladiator stands in the lower half of the view: the box then takes the top, so
## it covers neither the gladiator nor whoever the gladiator talks to (they stand within reach).
func _box_at_top() -> bool:
	var at := get_viewport().get_canvas_transform() * player.global_position
	return at.y > get_viewport().get_visible_rect().get_center().y


## E on a station: the lift starts the run; the post and the rack toggle their panels. A panel
## opens after its keeper's new word, when the keeper has one (Story.has_new's event: a merchant's
## bark never plays, with nothing new the panel opens at once); the E that ends the word is the
## box's, so the panel it opens stays open.
func _on_station(item: Station) -> void:
	if item.id == "lift":
		_close_panels()
		_take_the_lift()
		return
	if _panel_owner == item and _panel_open():
		_close_panels()
		return
	_close_panels()
	var word: StoryEvent = Story.next(item.keeper_id(), "talk") if item.keeper != null else null
	if word != null and word.uses_turn():
		if not await _play_event(word):
			return
		# A defence only: the tree is paused under the box, so neither the focus nor the room can
		# change before it shuts.
		if not is_instance_valid(item) or grounds == null or grounds.focus != item:
			return
	_open_panel(item)


## The station's panel open, the station its owner (the caller closed any other panel).
func _open_panel(item: Station) -> void:
	match item.id:
		"post":
			training_panel.open(Profile.save)
		"rack":
			armoury_panel.open()
		_:
			return
	_panel_owner = item


## The key cap follows the focus; an open panel closes once its station is not the focus (moved
## off, or freed: a freed owner is no longer valid).
func _on_focus_changed(_id: String) -> void:
	key_cap.target = grounds.focus if grounds != null else null
	if _panel_open() and (grounds == null or not is_instance_valid(_panel_owner) or grounds.focus != _panel_owner):
		_close_panels()


func _panel_open() -> bool:
	return training_panel.is_open() or armoury_panel.is_open()


## The open grounds panel's frame, or null with none open.
func _open_frame() -> Control:
	if training_panel.is_open():
		return training_panel.panel
	if armoury_panel.is_open():
		return armoury_panel.panel
	return null


## Closes the grounds' panels; true when one was open.
func _close_panels() -> bool:
	var was_open := _panel_open()
	training_panel.close()
	armoury_panel.close()
	_panel_owner = null
	return was_open


## The walk through a door to the room `room_id` (E on it, from input): the fade to black, a fresh
## Grounds for the room with the gladiator before its door back, room_entered, the fade back; no
## revive and no grounds_entered (no arrival from outside: the title's pending seed and cheats
## ride along). A second E during the fade does nothing (_leaving_grounds, cleared by
## _room_shown once the black has lifted: enter_grounds is not called). A quit during the fade
## wins, as at the lift: the serial moved on, no room is mounted (or, during the fade back, the
## arrival never ends in _room_shown), and the black is lifted (R and Restart do nothing in the
## grounds). An unknown room is an error and walks nowhere.
func _go_to_room(room_id: String) -> void:
	if _leaving_grounds:
		return
	if GroundsRooms.room(room_id) == null:
		push_error("Main: no room '%s' to walk to" % room_id)
		return
	_leaving_grounds = true
	var run := _run_serial
	var from := grounds.room_def.id
	await _fade_to(1.0)
	if not is_inside_tree():
		return
	if run != _run_serial or grounds == null:
		fade.color.a = 0.0
		return
	mount_room(GroundsRooms.room(room_id), from)
	Events.room_entered.emit(room_id)
	if await _fade_back(run):
		_room_shown("door")


## The room is up and the black has lifted: an arrival's last step (Play on a returned profile,
## the gate screen's pass, a door: `arrival` names it, "start", "gate", or "door", the entry
## event's moment fact). E acts again; room_shown out; the room's entry event, if any, plays (never
## at room_entered: that is the mount, under the black).
func _room_shown(arrival: String) -> void:
	_leaving_grounds = false
	room_shown.emit(grounds.room_def.id)
	_play_entry(grounds.room_def.id, arrival)


## The fade back after a stage swap; true when the room it lifted on is still the one up (no quit
## or restart moved the serial on meanwhile).
func _fade_back(run: int) -> bool:
	await _fade_to(0.0)
	return is_inside_tree() and run == _run_serial and grounds != null


## Down the lift (E on it, from input): the fade to black, the arena, the run on the title's
## seed and cheats if Play left any (once), the fade back. A second E during the fade does
## nothing (_leaving_grounds). A restart or a quit during the fade wins: the serial moved on, and
## the black its tween was still painting is lifted (in the game the reload took the fade with
## the scene).
func _take_the_lift() -> void:
	if _leaving_grounds:
		return
	_leaving_grounds = true
	var run := _run_serial
	await _fade_to(1.0)
	if not is_inside_tree():
		return
	if run != _run_serial or grounds == null:
		fade.color.a = 0.0
		return
	_start_run(_pending_seed, _pending_cheats)
	await _fade_to(0.0)


## Round `index` in the one Room, the player standing where they are: the spawner re-seeds on
## the round and the runner takes its table. The round's tally starts over here (Main owns the
## round flow and is the tally's one reader, in _pay_bonus), as does the piles' stream. The
## round's enemy count is set before round_started: Favour shares the kill budget among them.
func _enter_round(index: int) -> void:
	round_index = index
	RunState.round_index = index
	RunState.round_tally = 0
	RunState.round_enemies = series_def.rounds[index].waves.total_enemies()
	_pile_rng = RunState.stream("piles:%d" % index)
	room.spawner.start_round()
	Events.round_started.emit(index, series_def.rounds.size())
	# Started last so wave_started arrives after round_started.
	room.wave_runner.start(series_def.rounds[index].waves)


## Favour's own round_cleared handler ran first (it is a child), so the clean-round bonus is in
## the meter when the band is read here: the verdict goes out on the bus (the crowd's sound) and
## sets how many cards the picker offers; with the round's main loss it is what the crowd's line
## at the pick reads.
func _on_round_cleared() -> void:
	RunState.rounds_cleared += 1
	var band := FavourRules.band(RunState.favour)
	round_bands.append(band)
	Events.round_ended.emit(band)
	_pay_bonus(band)
	_clear_projectiles.call_deferred(room)  # the last kill ends the fight: shots and bolts vanish with it
	if series_def.is_last(round_index):
		_win()
		return
	_pick_round = 0
	_rerolls = 0
	_rounds_owed = 0
	_offer_count = mini(FavourRules.offer_count(band) + RunState.offer_bonus, UpgradeMenu.MAX_CARDS)
	_roar = band >= FavourRules.ROAR
	_locks = FavourRules.lock_count(band)
	_crowd_facts = {"round_band": FavourRules.band_name(band), "round_loss": favour.round_loss()}
	_crowd_line = ""
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
			_throw_piles_in.call_deferred(room, player.global_position, tally)


## A kill's coins: the boss's are always thrown on the floor where it fell (deferred out of the
## physics callback enemy_died arrives in); any other enemy's go to the counter and the round's
## tally with a flight from the corpse. Duck-typed: a test's stub has no def, the boss's is a
## BossDef.
func _on_enemy_died(enemy: Node2D, death_position: Vector2) -> void:
	var coins := _coins_of(enemy)
	if coins <= 0:
		return
	if enemy.is_in_group("boss"):
		if _boss_spawn_elapsed >= 0.0:
			_boss_time = RunState.elapsed - _boss_spawn_elapsed
		_throw_piles_in.call_deferred(room, death_position, coins)
		return
	RunState.round_tally += coins
	_pay(coins, death_position)


## The first boss's: a summoned or second boss must not restart the fight's clock.
func _on_boss_spawned(_boss: Node2D) -> void:
	if _boss_spawn_elapsed < 0.0:
		_boss_spawn_elapsed = RunState.elapsed


func _coins_of(enemy: Node2D) -> int:
	var def: Variant = enemy.get("def")
	var coins: Variant = def.get("coins") if def != null else null
	return int(coins) if coins != null else 0


## `coins` onto the counter now, with one flight from `from` (a world position) to show it.
func _pay(coins: int, from: Vector2) -> void:
	RunState.add_coins(coins)
	hud.fly_coin(from)


## The deferred throws' target, guarded on the room like _clear_projectiles: a restart or Play in
## the frame of the kill or the clear rebuilds the Room, and the piles must not land in the new run.
func _throw_piles_in(target: Room, at: Vector2, total: int) -> void:
	if not is_instance_valid(target) or target != room:
		return
	throw_piles(at, total)


## `total` coins on the floor around `at` as PileRules piles, each tossed to a seeded spot in the
## ring past the pull's reach, inside the floor's part on the screen (the arena's rule 2's
## corollary: piles land where they can be seen); one coin_toss for the throw. Nothing for a total
## of 0. Never inside a physics callback: a pile is an Area2D, so the callers defer through
## _throw_piles_in.
func throw_piles(at: Vector2, total: int) -> void:
	var count := PileRules.pile_count(total)
	if count == 0:
		return
	var values := PileRules.split(total, count)
	# The screen (View.bare_rect, not View.rect's margin) grown by PileRules.EDGE, which spots
	# takes back in: every spot is on the screen. Tier 1 is unchanged: the screen's left edge is at
	# most 21.33 px, less EDGE (8): 13.33, still left of the floor's 16; the right edge mirrors it
	# (the screen is the arena's full height), so the rect is the floor itself.
	var on_screen := SpawnMath.floor_in_view(room.global_bounds(), View.bare_rect(room).grow(PileRules.EDGE))
	var spots := PileRules.spots(at, count, on_screen, _pile_rng)
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
## the gap must not open a menu. A round with nothing to offer goes to the gap at once. The
## crowd's line is said at the round's first open (a refund round's re-open keeps it); at a Boo
## every open locks a card of its own (_lock_in).
func _offer_upgrade(target: Room) -> void:
	if not is_instance_valid(target) or target != room or _ended:
		return
	var offers := _draw_offers("upgrades:%d:%d" % [round_index, _pick_round])
	if build_screen.is_open():
		build_screen.close()
	if offers.is_empty():
		upgrade_menu.close()
		_next_round_later(target)
		return
	if _pick_round == 0:
		_crowd_line = str(_say_timed("crowd", "pick", _crowd_facts).get("text", ""))
	var lock := _lock_in(offers, "lock:%d:%d" % [round_index, _pick_round])
	upgrade_menu.open(offers, _roar, _right_slot_held(), _crowd_line, lock)  # on a first open the crowd's card arrives late


## The offer's cards from the named stream: the count and the heal-slot rule (the heal card
## last while the right slot is held: UpgradeCatalog.right_slot_held) hold for a first draw and a
## re-draw alike.
func _draw_offers(stream_name: String) -> Array[UpgradeDef]:
	return UpgradeCatalog.offers(RunState.build, _hurt(), RunState.stream(stream_name), _offer_count)


## The card the crowd takes from `offers` (-1 for none), drawn from the named stream: the lock's
## own (lock:<round>:<pick round>, :r<n> for a re-draw), so a seed replays it and the offers'
## stream is never drawn from.
func _lock_in(offers: Array[UpgradeDef], stream_name: String) -> int:
	return UpgradeCatalog.locked_index(offers, _locks, RunState.stream(stream_name), _right_slot_held())


## Whether the player is hurt: the heal-slot rule's input (offers() reads it with the build).
func _hurt() -> bool:
	return player.hp < player.max_hp


## The heal-slot rule (UpgradeCatalog.right_slot_held) for the open offer: the lock spares the
## right slot and the menu puts the crowd's card before it by the same answer offers() used.
func _right_slot_held() -> bool:
	return UpgradeCatalog.right_slot_held(RunState.build, _hurt())


## The Reroll button: with a re-draw left, the same round's offer drawn again from its own
## stream (upgrades:<round>:<pick round>:r<n>, so a seed replays the re-draws too), the count
## and the Roar kept, the re-draw spent, and offer_rerolled on the bus. Deferred: the press
## arrives inside the Button's pressed emission, and the cards are rebuilt after it.
func _on_reroll_requested() -> void:
	if RunState.rerolls_left <= 0 or not upgrade_menu.is_open() or _ended:
		return
	RunState.rerolls_left -= 1
	_rerolls += 1
	_reroll.call_deferred(room, _rerolls)


func _reroll(target: Room, serial: int) -> void:
	if not is_instance_valid(target) or target != room or _ended or not upgrade_menu.is_open():
		return
	var offers := _draw_offers("upgrades:%d:%d:r%d" % [round_index, _pick_round, serial])
	var lock := _lock_in(offers, "lock:%d:%d:r%d" % [round_index, _pick_round, serial])
	upgrade_menu.open(offers, _roar, _right_slot_held(), _crowd_line, lock)  # already open: every card lands at once
	Events.offer_rerolled.emit()


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
## while still ignoring the time scale so a kill freeze cannot stall it. After the gap the next
## round waits for the piles still on the floor, up to PILE_WAIT_CAP on a timer that pauses with
## the tree too (physics_frame fires under a pause, so a tick count would not), polled each
## physics tick.
func _next_round_later(target: Room) -> void:
	var run := _run_serial
	await get_tree().create_timer(ROUND_GAP, false, false, true).timeout
	var cap := get_tree().create_timer(PILE_WAIT_CAP, false, false, true)
	while _gap_holds(target, run) and cap.time_left > 0.0 and target.piles.get_child_count() > 0:
		await get_tree().physics_frame
	if _gap_holds(target, run):
		_enter_round(round_index + 1)


## The gap's guard: still in the tree, the same room up, the run not ended, no restart since.
func _gap_holds(target: Room, run: int) -> bool:
	return is_inside_tree() and is_instance_valid(target) and target == room and not _ended and run == _run_serial


## The last clear: a beat on the boss's corpse (its own hold has passed: the runner counts the
## clear after it), then the verdict. Inside the round_cleared physics callback until the await.
func _win() -> void:
	if _ended:
		return
	_ended = true
	Events.run_won.emit()
	var run := _run_serial
	await get_tree().create_timer(WIN_HOLD, true, false, true).timeout
	if is_inside_tree() and run == _run_serial:
		_verdict(true)


## The fall: the runner stays off so nothing crowds the body, the hush plays (Audio, on
## player_fell), a beat, the build-up, then the verdict. A fall after the win changes nothing:
## the round is cleared and the win's own beat is running.
func _on_player_fell(_fall_position: Vector2, attacker_id: String) -> void:
	if _ended:
		return
	_ended = true
	_fall_attacker = attacker_id
	room.wave_runner.enabled = false
	var run := _run_serial
	await get_tree().create_timer(VERDICT_HOLD, true, false, true).timeout
	if not is_inside_tree() or run != _run_serial:
		return
	await _build_up()
	if is_inside_tree() and run == _run_serial:
		_verdict(false)


## The verdict's build-up, wordless: the crowd is quiet already (the hush at the fall), the
## drum roll starts (Audio, on verdict_drum) as the camera drifts from the gladiator to the
## emperor's box, zooming in, the box framed at the top of the view (the limits hold, so the
## arena fills the rest; the gladiator is out of frame below only when the fall was in the
## arena's bottom third: the emperor is the subject), then a held pause on the box with the
## roll still going. About four seconds from the fall to the thumb. The camera comes back at
## the next run's start (_forget_run), under the black. The awaits are timers, not the tween:
## a Main freed mid-drift (a harness) drops the coroutine either way, and the caller's guard
## reads the serial after this returns. The narrator's window carries its verdict_wait line from
## the drift's start through the pause (the thumb swaps it).
func _build_up() -> void:
	var run := _run_serial
	Events.verdict_drum.emit()
	camera.drift_to_top(room.emperor_box.centre(), VERDICT_DRIFT, VERDICT_ZOOM)
	_narrate("verdict_wait")
	await get_tree().create_timer(VERDICT_DRIFT, true, false, true).timeout
	if not is_inside_tree() or run != _run_serial:
		return
	await get_tree().create_timer(VERDICT_PAUSE, true, false, true).timeout


## The run's end. On a fall the emperor decides (VerdictRules), the thumb shows over the box with
## its sound (verdict_given), and the piles still on the floor are swept into the run's coins on a
## thumb up (lost with the rest on a down). A win asks no emperor: no thumb, no verdict_given (the
## fanfare plays on run_won), the sweep and the banking as up. Then the run is banked and
## recorded, and after the stay (the flights land) the fade to black and the gate screen.
## On a fall the narrator's line under the thumb replaces the wait's (none, and the window goes),
## chosen before the run is banked and gone before the fade; a win has no narrator.
## Never inside a physics callback: both callers awaited first, so the piles can be freed here.
func _verdict(won: bool) -> void:
	var up := true if won else VerdictRules.decide(
		FavourRules.band(RunState.favour), RunState.hits_taken, Profile.save.flags, RunState.cheats)
	if not won:
		_narrate("verdict_up" if up else "verdict_down")
	if up:
		_sweep_piles()
	var outcome := "win" if won else "fall"
	var record := _bank(outcome, up)
	if not won:
		room.thumb_sign.show_thumb(up)
		Events.verdict_given.emit(up)
	print("RUN_END outcome=%s verdict=%s kills=%d rounds=%d coins=%d seed=%d elapsed=%.1f%s" % [
		outcome, "up" if up else "down", RunState.kills, RunState.rounds_cleared, RunState.coins,
		RunState.seed_value, RunState.elapsed, _cheats_suffix()])
	var run := _run_serial
	await get_tree().create_timer(WIN_SHOW if won else VERDICT_SHOW, true, false, true).timeout
	if not is_inside_tree() or run != _run_serial:
		return
	dialogue_box.hide_timed()
	await _fade_to(1.0)
	if not is_inside_tree() or run != _run_serial:
		return
	Audio.stop_game_sounds()  # a bolt frozen under the pause must not resume next to the next run
	gate_screen.show_gate(up, record, Profile.save)


## The narrator's line for the verdict's `trigger` in the box's timed window at the bottom of the
## view (the camera frames the emperor's box at the top), replacing any line up; with no eligible
## event (or none of its lines shown) the window goes. The moment's fact is the run's band (the one
## the emperor reads); the profile's counts and the last run's facts are the runs before this one
## (it is chosen before the run is banked). Never through _play_event: the window takes no
## input and pauses nothing.
func _narrate(trigger: String) -> void:
	var facts := {"run_band": FavourRules.band_name(FavourRules.band(RunState.favour))}
	var line := _say_timed("narrator", trigger, facts)
	if line.is_empty():
		dialogue_box.hide_timed()
		return
	dialogue_box.show_timed(line["speaker"], line["text"], false)


## The line a timed moment says (the narrator's at the verdict, the crowd's at the pick): the
## first shown line of the pool's event for the trigger, the entry StoryPicker.lines gives ({}
## with no eligible event, or one whose lines all drop). Only that line is said (a timed event is
## one line); the event counts as played once a line will show (one whose lines all drop is not
## played) and its end runs at once (no input to wait for), unwritten: the run's close commits.
func _say_timed(pool: String, trigger: String, facts: Dictionary) -> Dictionary:
	return _say(Story.next(pool, trigger, "", facts), facts, false)


## The timed event's first shown line ({} for no event, or one whose lines all drop), the event
## begun and finished at once when a line will show, the save written when `commit` (an entry
## line in the grounds; the verdict's and the pick's wait for the run's close).
func _say(event: StoryEvent, facts: Dictionary, commit: bool) -> Dictionary:
	if event == null:
		return {}
	for entry: Dictionary in Story.lines(event, facts):
		if entry["kind"] == "line":
			Story.begin(event)
			Story.finish(event, commit)
			return entry
	return {}


## Every pile on the floor into the run's coins, each with a flight to the counter.
func _sweep_piles() -> void:
	for pile: CoinPile in room.piles.get_children():
		RunState.add_coins(pile.value)
		hud.fly_coin(pile.global_position)
		room.piles.remove_child(pile)
		pile.queue_free()


## The verdict into the profile: up banks the coins, down loses them and counts a death by the
## fall's attacker (the unknown id when none was named); the win or the fall, a perfect win,
## the best run, and the fastest boss on a win; then the run is closed. Returns the record (the
## gate screen shows it).
func _bank(outcome: String, up: bool) -> Dictionary:
	var won := outcome == "win"
	var save := Profile.save
	var coins := RunState.coins
	if up:
		save.money += coins
		save.add_stat("coins_earned", coins)
	else:
		save.add_stat("coins_lost", coins)
		save.bump_flag("deaths")
		save.add_stat("deaths_by", 1, _fall_attacker if _fall_attacker != "" else Save.UNKNOWN_ID)
	save.bump_flag("wins" if won else "falls")
	if won and RunState.perfect:
		save.bump_flag("perfect_runs")
		save.add_stat("perfect_runs")
	if won and _boss_time > 0.0:
		save.set_boss_time(_boss_time)
	save.set_best_run({"rounds": RunState.rounds_cleared, "kills": RunState.kills, "time": RunState.elapsed})
	return _close_run(outcome, "up" if up else "down", coins if up else 0)


## A yield: the run ends with no verdict, its coins lost and a fall counted, then closed with
## outcome "yield" and no verdict.
func _yield() -> void:
	Profile.save.add_stat("coins_lost", RunState.coins)
	Profile.save.bump_flag("falls")
	_close_run("yield", "", 0)


## What every ending shares: the run counted, its record logged, the save written, and
## run_ended out on the bus (the one place it is emitted). Returns the record.
func _close_run(outcome: String, verdict: String, coins_kept: int) -> Dictionary:
	Profile.save.bump_flag("runs")
	var record := _record(outcome, verdict, coins_kept)
	Profile.save.log_run(record)
	Profile.commit()
	Events.run_ended.emit(outcome)
	return record


## The run's record for the profile's log: the seed and the cheats (Cheats.describe's line), the
## outcome and the verdict ("" for a yield), the enemy that felled the gladiator (felled_by: the
## fall's attacker id, "" for a win, a yield, or an unknown attacker; the story's last_killer),
## the rounds cleared of the total, the kills, the time,
## the coins earned and kept, the hits taken, the band at each round's end, the build (the weapon
## and every rank by upgrade id), the training ranks at the time, and the date.
func _record(outcome: String, verdict: String, coins_kept: int) -> Dictionary:
	var build := RunState.build
	var ranks := build.weapon_ranks.duplicate()
	ranks.merge(build.player_ranks)
	return {
		"seed": RunState.seed_value, "cheats": Cheats.describe(RunState.cheats),
		"outcome": outcome, "verdict": verdict, "felled_by": _fall_attacker,
		"rounds": RunState.rounds_cleared, "rounds_total": RunState.rounds_total,
		"kills": RunState.kills, "time": RunState.elapsed,
		"coins_earned": RunState.coins, "coins_kept": coins_kept, "hits": RunState.hits_taken,
		"bands": round_bands.duplicate(), "build": {"weapon": build.weapon_id, "ranks": ranks},
		"training": Profile.save.training.duplicate(), "date": Time.get_datetime_string_from_system(),
	}


## The black over everything (under the gate screen) to `alpha` in FADE_TIME, ignoring a freeze.
func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(fade, "color:a", alpha, FADE_TIME)
	await tween.finished


## Enter or a click on the gate screen: the gate is passed (its sound), the screen closes over
## the black, the grounds replace the arena under it, the profile remembers the return
## (flags.returned: every Play from now on lands in the Ludus), and the black lifts. The room is
## the verdict's, as the screen showed it (GateScreen.up): an up stands in the Ludus; a down
## wakes in the Spoliarium, the gladiator lying at the floor's bottom centre (Player.lie: the first
## press rises), the room seen from now on (flags.spoliarium_seen, set before the Hypogeum is next
## built: its door back reads it). The run is over and recorded already (_close_run); nothing is
## yielded, and _ended stays set through the fade so the verdict still counts as pending (R and
## Quit to title do nothing under it). The fade to black is a no-op after the verdict's (already
## black) and covers a harness that opened the screen bare.
func _pass_gate() -> void:
	var woken := not gate_screen.up
	Events.menu_closed.emit("gate")
	gate_screen.close()
	Juice.reset()
	await _fade_to(1.0)
	if not is_inside_tree():
		return
	_forget_run()
	_run_serial += 1
	var run := _run_serial
	if woken:
		Profile.save.set_flag("spoliarium_seen", true)
		enter_grounds("spoliarium")
		player.lie()
	else:
		enter_grounds()
	Profile.save.set_flag("returned", true)
	Profile.commit()
	if await _fade_back(run):
		_room_shown("gate")


## The view may show the walls but never the void past them.
func _apply_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)


## A left press outside the open grounds panel's frame closes the panel, as Esc does, and is spent
## here, before the GUI and the unhandled pass; a press inside is the panel's own (a row's
## purchase). The frame's rect is in its layer's coordinates, the press in the viewport's: the
## press goes through the frame's transform with its canvas. Under a pause (the pause screen, the
## text box) Main takes no input, so a click there never reaches the panel under it.
func _input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	var frame := _open_frame()
	if frame == null:
		return
	var local := frame.get_global_transform_with_canvas().affine_inverse() * press.position
	if Rect2(Vector2.ZERO, frame.size).has_point(local):
		return
	_close_panels()
	get_viewport().set_input_as_handled()


## R restarts (nothing in the grounds). Esc with a grounds panel open closes the panel and is
## spent there: handled, and the pause screen (which polls the press) is blocked for the frame.
## Under the text box nothing reaches here (Main is paused while it is up; the pause screen is
## blocked).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _close_panels():
			_pause_spent_frame = Engine.get_process_frames()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		restart()


## R, the pause screen's Restart, or the gate screen's R: a live run (one neither the verdict
## nor a yield has ended, and not the title's idle arena) is yielded first. Nothing in the
## grounds: the lift is the only way into the arena (the pause screen hides Restart there). The
## verdict scene cannot be skipped: between the run's end and the gate screen nothing restarts
## (the screen's own R, Esc, and pass arrive with it open). Reloads only when Main is the
## current scene: test harnesses and the smoke tool instance Main as a child of themselves, and
## must not be reloaded out from under their own script. The tier is kept (RunState.tier outlives
## the reload, and the reloaded _ready reads its series): R fights the same tier again.
func restart() -> void:
	if _verdict_pending() or grounds != null:
		return
	if not _ended and not title.is_open():
		_yield()
	upgrade_menu.close()  # hides and unpauses: both are state a scene reload would keep, and without a reload the menu would stay up
	build_screen.close()
	gate_screen.close()  # the same: a harness has no reload to clear the screen
	fade.color.a = 0.0  # and the black under it
	_forget_run()
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


## True from the run's end (the fall, the last clear) until the gate screen is up: the verdict
## scene is running and must play out.
func _verdict_pending() -> bool:
	return _ended and not gate_screen.is_open()


## The run's bookkeeping back to a fresh run's (the harness's restart has no reload to do it),
## the camera back from the box, the narrator's window down, and the title's seed and cheats
## spent: they live from Play to the next run's start or restart, whichever comes first
## (_start_run reads them before calling this).
func _forget_run() -> void:
	_ended = false
	camera.end_drift()
	dialogue_box.hide_timed()
	_entry_line += 1
	round_bands = []
	_crowd_facts = {}
	_crowd_line = ""
	_fall_attacker = ""
	_boss_spawn_elapsed = -1.0
	_boss_time = 0.0
	_pending_seed = Cheats.RANDOM_SEED
	_pending_cheats = {}


## " cheats=<flags>" for the RUN_END line when any cheat is on, else "".
func _cheats_suffix() -> String:
	var cheats := Cheats.describe(RunState.cheats)
	return "" if cheats.is_empty() else " cheats=" + cheats


## Play from the title: the first run of a profile starts in the arena at once (the grounds
## are seen only after it); a profile that has returned from a run goes to the Ludus, and the
## Hypogeum's lift starts the run on the field's seed and cheat flags, kept until then. The action
## (Cheats.ACTIONS) comes first: "wipe" backs the save up and replaces it with the defaults
## (Profile.wipe), so what follows is a first run; an act ("act:2") does the wipe and then writes
## the act's preset over the defaults (_start_from_act), so what follows is that act's return (a
## preset with `returned` lands in the Ludus). A backup that fails wipes and applies nothing, and
## Play goes on with the save as it was.
func play(seed_value: int = Cheats.RANDOM_SEED, cheats: Dictionary = {}, action := "") -> void:
	title.close()
	get_tree().paused = false
	if action == "wipe":
		Profile.wipe()
	elif Cheats.act_of(action) > 0:
		_start_from_act(Cheats.act_of(action))
	if bool(Profile.save.flags["returned"]):
		_pending_seed = seed_value
		_pending_cheats = cheats
		enter_grounds()
		_room_shown("start")  # no fade: the title lifts on the room
		return
	_start_run(seed_value, cheats)


## The act cheat (actus2, actus3): the save backed up and wiped (Profile.wipe), the act's preset
## written over the defaults (Story.apply_act), and that committed. A backup that fails applies
## nothing, as the wipe; an act with no preset (an acts.json error, pushed at load) wipes nothing.
func _start_from_act(act: int) -> void:
	if not Story.has_act(act):
		push_warning("Main: no preset for act %d (%s): the save is kept as it was" % [act, StoryCatalog.ACTS_FILE])
		return
	if Profile.wipe():
		Story.apply_act(act)
		Profile.commit()


## A fresh run on the seed (or random) and the cheat flags, in a Room rebuilt for it (the floor
## art keys on the seed); the run's numbers and the build from the profile through
## RunState.start_run (which revives the player), then the arena and round 0. Shared by Play and
## the lift; the arguments are read before _forget_run clears the pending ones (the
## lift passes those).
func _start_run(seed_value: int, cheats: Dictionary) -> void:
	if not _read_tier_series():
		return  # pushed: no series to fight
	var run_seed := seed_value
	var run_cheats := cheats.duplicate()
	_forget_run()
	RunState.start_run(run_seed, run_cheats)
	RunState.rounds_total = series_def.rounds.size()
	_start_first_round()


## Quit to title from the pause screen or the gate screen: a restart (a yield when the run is
## live), then the title. From the grounds (where restart() does nothing) the title comes up
## over them, nothing yielded; in the game the reload then rebuilds the boot's arena under it.
## In the game the restart reloads the scene and _ready shows the title; in a harness (no
## reload) it is shown here. The reload takes Main out of the tree at once (get_tree() is null
## after it), so the check comes first. Either way the tier goes back to 1 (the title's arena and
## Play's first run are tier 1's): after the restart, whose yield is the run's tier's, and before
## the reloaded scene's _ready, which runs a frame later.
func quit_to_title() -> void:
	if _verdict_pending():
		return
	var reloads := get_tree().current_scene == self
	if grounds != null:
		RunState.reset_tier()
		build_screen.close()
		_forget_run()  # the title's seed is spent
		_run_serial += 1  # a lift's or a door's fade under way must not act under the title
		if reloads:
			get_tree().reload_current_scene()
		else:
			_show_title()
		return
	restart()  # hides the gate screen too
	RunState.reset_tier()
	_skip_title_once = false  # the reload restart() queued must land on the title
	if not reloads:
		_show_title()
