class_name UpgradeMenu
extends CanvasLayer
## The room-clear picker: three cards over a dim with the tree paused underneath. Main opens it
## with the offers and reacts to `chosen`; the menu only draws cards and reads input. Layer 10
## sits over the HUD (1) and under the fade (20); process_mode ALWAYS keeps it running while
## paused. Restart is handled here because Main is paused with everything else.

signal chosen(card: UpgradeDef)
signal restart_pressed

const CARD_SIZE := Vector2(320, 400)
const CARD_SCALE := 4.0  ## nine-patch pixels to screen pixels
const CARD_INSET := 28.0  ## text box inset from the card edge
const ICON_SCALE := 6.0
const HOVER_MODULATE := Color(1.12, 1.12, 1.12)  ## a flat Button draws no hover state; the card brightens instead
const PICK_ACTIONS: Array[String] = ["pick_1", "pick_2", "pick_3"]

var offers: Array[UpgradeDef] = []

@onready var cards: HBoxContainer = $Center/Cards


## Shows the cards and pauses the tree. Safe to call again while open (a refund round).
func open(new_offers: Array[UpgradeDef]) -> void:
	offers = new_offers
	_rebuild()
	Juice.reset()  # a kill freeze must not leave Engine.time_scale at 0.05 under the pause
	get_tree().paused = true
	visible = true


func close() -> void:
	visible = false
	get_tree().paused = false


func is_open() -> bool:
	return visible


func choose(index: int) -> void:
	if not visible or index < 0 or index >= offers.size():
		return
	chosen.emit(offers[index])


func _process(_delta: float) -> void:
	if not visible:
		return
	if Input.is_action_just_pressed("restart"):
		restart_pressed.emit()
		return
	for i in PICK_ACTIONS.size():
		if Input.is_action_just_pressed(PICK_ACTIONS[i]):
			choose(i)
			return


func _rebuild() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	for i in offers.size():
		cards.add_child(_card(offers[i], i))


## A card: the beige panel under the orange frame, and a column of icon, name, effect, rank. No
## key digit: 1, 2, 3 work silently (playtest 1 found the numbers redundant). The name is on the
## title font; a wide one wraps to two lines rather than shrinking to the description's size (the
## fit test runs every card). The Button is the click target; everything inside ignores the mouse.
func _card(card: UpgradeDef, index: int) -> Button:
	var button := Button.new()
	button.name = "Card%d" % (index + 1)
	button.custom_minimum_size = CARD_SIZE
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: choose(index))
	button.mouse_entered.connect(func() -> void: button.modulate = HOVER_MODULATE)
	button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	var panel := UiTheme.nine_patch(UiTheme.PANEL, UiTheme.PANEL_MARGIN, CARD_SIZE - Vector2(24, 24), CARD_SCALE)
	panel.position = Vector2(12, 12)
	button.add_child(panel)
	button.add_child(UiTheme.nine_patch(UiTheme.FRAME, UiTheme.FRAME_MARGIN, CARD_SIZE, CARD_SCALE))
	var box := VBoxContainer.new()
	box.position = Vector2(CARD_INSET, CARD_INSET)
	box.size = CARD_SIZE - Vector2(CARD_INSET, CARD_INSET) * 2.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	var icon := IconAtlas.rect(card.icon, ICON_SCALE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title := UiTheme.title(card.name)
	var body := UiTheme.label(card.description, UiTheme.FONT_SMALL)
	var rank := UiTheme.label(rank_line(card, RunState.build), UiTheme.FONT_SMALL)
	for label: Label in [title, body, rank]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
	for node: Control in [icon, title, body, rank]:
		box.add_child(node)
	button.add_child(box)
	return button


## The third line: the rank this pick reaches, or what a heal or switch does. Pure in the build.
static func rank_line(card: UpgradeDef, build: Build) -> String:
	match card.kind:
		UpgradeDef.Kind.HEAL:
			return "One heart"
		UpgradeDef.Kind.SWITCH:
			var n := build.weapon_upgrade_count()
			if n == 0:
				return "Fresh start"
			return "Re-pick %d upgrade%s" % [n, "" if n == 1 else "s"]
	return "Rank %d of %d" % [build.rank_of(card.id) + 1, card.max_rank]
