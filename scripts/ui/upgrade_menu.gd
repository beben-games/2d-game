class_name UpgradeMenu
extends CanvasLayer
## The round-clear picker: the cards (three, or four when the crowd roars) over a dim with the
## tree paused underneath, the granter's name over them. Main opens it with the offers and the
## granter and reacts to `chosen`; the menu only draws cards and reads input. The crowd's fourth
## card arrives late when open() is told to reveal it: three cards at the open, the fourth built
## after FOURTH_CARD_DELAY and slid in from the view's right edge over FOURTH_CARD_SLIDE with
## the crowd's roar (card_revealed on the bus); its key and its click land only once it is in.
## Layer 10 sits over the HUD (1) and under the fade (20); process_mode ALWAYS keeps it running
## while paused. Restart is handled here because Main is paused with everything else.

## index is the slot the card sat in (Main counts picks from the heal slot).
signal chosen(card: UpgradeDef, index: int)
signal restart_pressed

const CARD_SIZE := Vector2(320, 400)
const CARD_SCALE := 4.0  ## nine-patch pixels to screen pixels
const CARD_INSET := 28.0  ## text box inset from the card edge
const ICON_SCALE := 6.0
const HOVER_MODULATE := Color(1.12, 1.12, 1.12)  ## a flat Button draws no hover state; the card brightens instead
const PICK_ACTIONS: Array[String] = ["pick_1", "pick_2", "pick_3", "pick_4"]
## The gap between cards; a row that would overflow the view shrinks it (four cards at 1280 wide
## touch), the cards keep CARD_SIZE.
const CARD_GAP := 40
## The granter's name sits this far over the cards row.
const GRANTER_GAP := 16.0
## The crowd's fourth card: the beat after the three land before it is built, and its slide in
## from the right edge. Real time under the pause (the tree is paused while the menu is up).
const FOURTH_CARD_DELAY := 0.6
const FOURTH_CARD_SLIDE := 0.25

var offers: Array[UpgradeDef] = []
## Bumped by every open and close: a reveal timer from an earlier open must not add its card.
var _open_serial := 0
## The name over the cards (who grants them); hidden when open() gets none.
var granter_label: Label

@onready var cards: HBoxContainer = $Center/Cards


func _ready() -> void:
	granter_label = UiTheme.title("", UiTheme.FONT_TITLE, UiTheme.PAPER)
	granter_label.name = "Granter"
	granter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	granter_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	# A full-width strip ending GRANTER_GAP over the centred cards row, whatever the view's size.
	granter_label.anchor_left = 0.0
	granter_label.anchor_right = 1.0
	granter_label.anchor_top = 0.5
	granter_label.anchor_bottom = 0.5
	granter_label.offset_top = -(CARD_SIZE.y / 2.0 + GRANTER_GAP + UiTheme.FONT_TITLE)
	granter_label.offset_bottom = -(CARD_SIZE.y / 2.0 + GRANTER_GAP)
	granter_label.visible = false
	add_child(granter_label)


## Shows the cards under the granter's name and pauses the tree. Safe to call again while open
## (a refund round). An empty granter shows no name. With `reveal_last` and four offers, the
## fourth card is held back and slid in after its delay (a menu already open, a refund round,
## shows all four at once).
func open(new_offers: Array[UpgradeDef], granter := "", reveal_last := false) -> void:
	var was_open := visible
	_open_serial += 1
	offers = new_offers
	granter_label.text = granter
	granter_label.visible = not granter.is_empty()
	var held := 1 if reveal_last and not was_open and offers.size() == 4 else 0
	_rebuild(offers.size() - held)
	Juice.reset()  # a kill freeze must not leave Engine.time_scale at 0.05 under the pause
	get_tree().paused = true
	visible = true
	if not was_open:
		Events.menu_opened.emit("upgrade")
	if held > 0:
		_reveal_last_later()


func close() -> void:
	var was_open := visible
	_open_serial += 1
	visible = false
	get_tree().paused = false
	if was_open:
		Events.menu_closed.emit("upgrade")


func is_open() -> bool:
	return visible


## Takes the card in the slot; a slot whose card is not built yet (the fourth, before its
## reveal) is nothing to take.
func choose(index: int) -> void:
	if not visible or index < 0 or index >= cards.get_child_count():
		return
	chosen.emit(offers[index], index)


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


## The first `count` cards; the row's gap is set for the whole offer, so a held card's slot is
## laid out where it will land.
func _rebuild(count: int) -> void:
	UiTheme.clear_children(cards)
	cards.add_theme_constant_override("separation", card_gap(offers.size(), get_viewport().get_visible_rect().size.x))
	for i in count:
		cards.add_child(_card(offers[i], i))


## After the delay, still on the same open: the last card built, the roar, and the slide of its
## body from the view's right edge into its slot (the button holds the slot; the body moves).
func _reveal_last_later() -> void:
	var serial := _open_serial
	await get_tree().create_timer(FOURTH_CARD_DELAY, true, false, true).timeout
	if not is_inside_tree() or not visible or serial != _open_serial:
		return
	var index := cards.get_child_count()
	var button := _card(offers[index], index)
	var body: Control = button.get_node("Body")
	var view_width := get_viewport().get_visible_rect().size.x
	body.position.x = view_width  # off the right edge until the row has laid the slot out
	cards.add_child(button)
	Events.card_revealed.emit()
	await get_tree().process_frame  # the row lays the new slot out
	if serial != _open_serial:
		return
	body.position.x = view_width - button.global_position.x
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(body, "position:x", 0.0, FOURTH_CARD_SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## CARD_GAP, or less when `count` cards at CARD_SIZE would overflow `view_width`: the gaps shrink
## before the cards do. Pure.
static func card_gap(count: int, view_width: float) -> int:
	if count <= 1:
		return CARD_GAP
	var room := (view_width - count * CARD_SIZE.x) / float(count - 1)
	return maxi(0, mini(CARD_GAP, int(room)))


## A card: the beige panel under the orange frame, and a column of icon, name, effect, rank, all
## on a Body control (the face) inside the Button (the row places the button; the face slides). No
## key digit: 1 to 4 work silently (playtest 1 found the numbers redundant). The name is on the
## title font; a wide one wraps to two lines rather than shrinking to the description's size (the
## fit test runs every card). An empty rank line (a heal) adds no label. The Button is the click
## target; everything inside ignores the mouse.
func _card(card: UpgradeDef, index: int) -> Button:
	var button := Button.new()
	button.name = "Card%d" % (index + 1)
	button.custom_minimum_size = CARD_SIZE
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: choose(index))
	button.mouse_entered.connect(func() -> void:
		button.modulate = HOVER_MODULATE
		Events.card_hovered.emit())
	button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	var face := Control.new()
	face.name = "Body"
	face.size = CARD_SIZE
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(face)
	UiTheme.framed_panel(face, CARD_SIZE, CARD_SCALE)
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
	var column: Array[Control] = [icon, title, body]
	var line := rank_line(card, RunState.build)
	if not line.is_empty():
		column.append(UiTheme.label(line, UiTheme.FONT_SMALL))
	for node: Control in column:
		if node is Label:
			node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			node.autowrap_mode = TextServer.AUTOWRAP_WORD
		box.add_child(node)
	face.add_child(box)
	return button


## The third line: the rank this pick reaches, or what a switch costs. A switch always states the
## count of upgrades the swap re-picks, zero included (playtest 1 wanted it spelled out). Empty
## for a heal, whose description already says what it does (playtest 1 read "One heart" as a
## repeat). Pure in the build.
static func rank_line(card: UpgradeDef, build: Build) -> String:
	match card.kind:
		UpgradeDef.Kind.HEAL:
			return ""
		UpgradeDef.Kind.SWITCH:
			var n := build.weapon_upgrade_count()
			if n == 0:
				return "Swap now, nothing to re-pick"
			return "Swap and re-pick %d upgrade%s" % [n, "" if n == 1 else "s"]
	return "Rank %d of %d" % [build.rank_of(card.id) + 1, card.max_rank]
