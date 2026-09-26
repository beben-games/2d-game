class_name GateScreen
extends CanvasLayer
## The screen after the verdict, the run's last card: the gate's name for a title, the run's
## numbers beside the all-time numbers, and the deadliest enemy (the id with the most hits landed
## on the gladiator over every run) as its idle animation, or nothing when no hit was ever taken.
## Nothing on it says what a gate, a thumb, or a number means: the name and the figures are the
## whole of it. Enter (ui_accept) or a click continues (continue_requested: Main takes it on),
## R restarts (restart_pressed) and Esc returns to the title (quit_requested), handled here
## because Main is paused underneath. A menu like the picker: layer 30 so it reads over the fade
## (20), process_mode ALWAYS, the tree paused while it is up.

signal continue_requested
signal restart_pressed
signal quit_requested

const ENEMY_DIR := "res://data/enemies"  ## <id>.tres holds the idle_anim the portrait plays
const PORTRAIT_SCALE := 4.0
const PORTRAIT_SIZE := 160.0  ## the portrait's box: the boss's 36 px frame at 4x fits
const BLOCK_GAP := 96  ## between the run's column and the all-time column
const FONT_GATE := 64

var title: Label
var run_label: Label
var all_time_label: Label
var portrait_box: Control
var portrait: AnimatedSprite2D
## True for the frame the screen appears in: a click landing as it opens (the frame's input runs
## before _process) must not pass the gate; _process clears it.
var _just_opened := false

@onready var box: VBoxContainer = $Center/Box


func _ready() -> void:
	title = UiTheme.title("", FONT_GATE, UiTheme.PAPER)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var blocks := HBoxContainer.new()
	blocks.name = "Blocks"
	blocks.add_theme_constant_override("separation", BLOCK_GAP)
	blocks.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(blocks)
	run_label = UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.PAPER)
	run_label.name = "Run"
	blocks.add_child(run_label)
	all_time_label = UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.PAPER)
	all_time_label.name = "AllTime"
	blocks.add_child(all_time_label)
	portrait_box = Control.new()
	portrait_box.name = "Portrait"
	portrait_box.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portrait_box)
	portrait = AnimatedSprite2D.new()
	portrait.name = "Sprite"
	portrait.position = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE) * 0.5
	portrait.scale = Vector2(PORTRAIT_SCALE, PORTRAIT_SCALE)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_box.add_child(portrait)


## The gate for the verdict, the run's record (Main's, the one it logs) and the profile's save.
## Pauses the tree: the arena under the black is done.
func show_gate(up: bool, run: Dictionary, save: Save) -> void:
	title.text = VerdictRules.gate_name(up)
	var texts := blocks(run, save)
	run_label.text = texts[0]
	all_time_label.text = texts[1]
	_just_opened = true
	_show_portrait(deadliest(save))
	Juice.reset()  # a kill freeze must not leave Engine.time_scale low under the pause
	get_tree().paused = true
	visible = true
	Events.menu_opened.emit("gate")


## Hides and unpauses. Main emits menu_closed("gate") when the gate is passed (continue), not
## on a quit to the title or a restart.
func close() -> void:
	visible = false
	get_tree().paused = false


func is_open() -> bool:
	return visible


func _process(_delta: float) -> void:
	if not visible:
		return
	_just_opened = false
	if Input.is_action_just_pressed("pause"):
		quit_requested.emit()
	elif Input.is_action_just_pressed("restart"):
		restart_pressed.emit()
	elif Input.is_action_just_pressed("ui_accept"):
		continue_requested.emit()


func _input(event: InputEvent) -> void:
	if not visible or _just_opened:
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		continue_requested.emit()


func _show_portrait(id: String) -> void:
	var path := "%s/%s.tres" % [ENEMY_DIR, id]
	portrait_box.visible = id != "" and ResourceLoader.exists(path)
	if not portrait_box.visible:
		portrait.stop()
		return
	var def: Resource = load(path)
	portrait.sprite_frames = SpriteAtlas.frames({"idle": str(def.get("idle_anim"))})
	portrait.play("idle")


static func format_time(seconds: float) -> String:
	var whole := int(seconds)
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]


## The two blocks: the run (from its record: rounds, rounds_total, kills, time, coins_earned,
## coins_kept, seed, cheats as Cheats.describe's line, named only when any was on) and all time
## from the save (the flags' counts and the per-id stats' totals).
static func blocks(run: Dictionary, save: Save) -> PackedStringArray:
	var run_text := "Rounds %d/%d\nKills %d\nTime %s\nCoins earned %d\nCoins kept %d\nSeed %d" % [
		int(run.get("rounds", 0)), int(run.get("rounds_total", 0)), int(run.get("kills", 0)),
		format_time(float(run.get("time", 0.0))), int(run.get("coins_earned", 0)),
		int(run.get("coins_kept", 0)), int(run.get("seed", 0))]
	var cheats := str(run.get("cheats", ""))
	if not cheats.is_empty():
		run_text += "\nCheats " + cheats
	var all_time := "Runs %d\nWins %d\nFalls %d\nDeaths %d\nKills %d\nHits taken %d\nShots fired %d" % [
		int(save.flags["runs"]), int(save.flags["wins"]), int(save.flags["falls"]), int(save.flags["deaths"]),
		save.total("kills"), save.total("hits_taken"), save.total("shots_fired")]
	return PackedStringArray([run_text, all_time])


## The blocks as one text, a blank line between.
static func body(run: Dictionary, save: Save) -> String:
	return "\n\n".join(blocks(run, save))


## The id with the most hits landed on the gladiator (hits_taken), a tie going to the first in
## name order; "" when no hit was ever taken.
static func deadliest(save: Save) -> String:
	var table: Dictionary = save.stats["hits_taken"]
	var ids: Array = table.keys()
	ids.sort()
	var best := ""
	var most := 0
	for id: String in ids:
		if int(table[id]) > most:
			most = int(table[id])
			best = id
	return best
