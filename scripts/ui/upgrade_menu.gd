class_name UpgradeMenu
extends CanvasLayer
## The round-clear picker: the cards (three, one more when the crowd roars, one more per Offer
## rank, MAX_CARDS at most) over a dim with the tree paused underneath, HEADING over them on
## every band. Main opens it with the offers and reacts to `chosen`; the menu only draws cards
## and reads input. On a Roar one card is the crowd's (crowd_slot: the last, or the one before
## the heal card when the player is hurt), drawn apart in FRAME_CROWD with the crowd's heads
## over its title. On a first open it arrives late: every other card at the open (an Offer
## rank's too) and its slot held by an empty Control of the card's size, then the card built
## after CROWD_CARD_DELAY and dropped in from above the view's top edge over CROWD_CARD_DROP
## (the stands are above) with card_revealed on the bus (the crowd's roar); its key and its
## click land once it is built (it can be taken while it drops). An open over an open menu (a
## refund round, a reroll) builds every card at once. A row too wide for the view shrinks its
## cards (card_scale). Under the cards, while RunState.rerolls_left is above zero, the Reroll
## button with a lit pip per re-draw left: a press emits reroll_requested and Main redraws the
## offer (the menu never draws cards itself). Over the heading, the crowd's line when Main hands
## one to open (its judgement of the round: the crowd speaks, then the heading, then the cards);
## with none the strip is hidden and nothing else moves. At a Boo one card may be the crowd's
## taking (`locked`, Main's from UpgradeCatalog.locked_index): built in its slot like any other,
## its face greyed (LOCKED_MODULATE) under the crowd's chain (CHAIN_*), and never taken: its key
## and a click emit pick_denied (the refusal's sound) and the menu stays open.
## Layer 10 sits over the HUD (1) and under the fade (20); process_mode ALWAYS keeps it running
## while paused. Restart is handled here because Main is paused with everything else.

## index is the slot the card sat in (Main counts picks from the heal slot).
signal chosen(card: UpgradeDef, index: int)
signal restart_pressed
## The Reroll button pressed: Main redraws the offer and spends the re-draw.
signal reroll_requested

const CARD_SIZE := Vector2(320, 400)
const CARD_SCALE := 4.0  ## nine-patch pixels to screen pixels
const CARD_INSET := 28.0  ## text box inset from the card edge
const ICON_SCALE := 6.0
const HOVER_MODULATE := Color(1.12, 1.12, 1.12)  ## a flat Button draws no hover state; the card brightens instead
const PICK_ACTIONS: Array[String] = ["pick_1", "pick_2", "pick_3", "pick_4", "pick_5"]
## The most cards an offer holds (the Roar's four plus an Offer rank, or three plus two): the
## key row has five digits and five cards fit the view at SCALE_STEP down.
const MAX_CARDS := 5
## The gap between cards; a row that would overflow the view shrinks it (four cards at 1280 wide
## touch), and once no gap is left the cards themselves shrink by SCALE_STEP at a time
## (card_scale: five at 1280 wide draw at three quarters, with the gap that frees).
const CARD_GAP := 40
const SCALE_STEP := 0.25
## The heading over the cards, the same on every band (playtest 2, note 4: the user's words).
const HEADING := "Pick a boon"
## The heading sits this far over the cards row.
const HEADING_GAP := 16.0
## The crowd's line, when there is one (one line of UiTheme.FONT_SMALL), ends this far over the
## heading's strip; the heading and the cards stay where they are.
const CROWD_LINE_GAP := 8.0
## The Reroll button (the pause screen's button size) sits this far under the cards row, its
## pips (the HUD's) this far to its right.
const REROLL_SIZE := Vector2(240, 56)
const REROLL_GAP := 24.0
const REROLL_PIP_GAP := 16
## The crowd's card on a Roar: the beat after the rest land before it is built, and its drop
## from above the view's top edge into its slot. Real time under the pause (the tree is paused
## while the menu is up).
const CROWD_CARD_DELAY := 0.6
const CROWD_CARD_DROP := 0.25
## The crowd's two heads (Hud.crowd_placeholder, at the frame's pixel scale) on the crowd's
## card: their drawn part centred on the card and standing on the bottom of its frame's top bar
## (CROWD_BAR: the sheet's bar rows at CARD_SCALE), peeking over the card's top edge up to the
## heading's gap, clear of the column: the tallest cards (the switches) leave the column no room
## for another row.
const CROWD_HEADS_SCALE := CARD_SCALE
const CROWD_BAR := UiTheme.FRAME_CROWD_BAR_ROWS * CARD_SCALE
## The crowd frame's tint, to gold: the crowd's card must read as extra at a glance (the frame
## alone, the same orange with three small gems, did not in the roar capture). A modulate only
## multiplies, so green is lifted past 1 to turn the orange gold.
const CROWD_FRAME_TINT := Color(1.2, 1.6, 0.7)
## The card the crowd took at a Boo: its paper, frame, and column greyed (the training post's
## grey for a row out of reach), the chain left bright over them.
const LOCKED_MODULATE := TrainingPanel.GREY_MODULATE
## PLACEHOLDER until M8's art: the crowd's chain over a locked card, the Raven sheet's two links
## ("chain", climbing from bottom left to top right) tiled along both diagonals through
## CHAIN_CROSS, an X clipped to the card. The X crosses over the icon (the boon is what is
## chained), so the name and the effect under it are crossed only near their ends and stay
## readable. CHAIN_STEP is one tile's offset along the climb in sheet pixels (two links on: the
## links' holes are four pixels apart, so every link sits as far from the next); a mirrored tile
## climbs the other way.
const CHAIN_ICON := "chain"
const CHAIN_SCALE := 3.0
const CHAIN_STEP := Vector2(8, -8)
const CHAIN_CROSS := Vector2(CARD_SIZE.x / 2.0, 112.0)

var offers: Array[UpgradeDef] = []
## Bumped by every open and close: a reveal timer from an earlier open must not add its card.
var _open_serial := 0
## The cards' scale for the open offer (card_scale), read by every card built for it.
var _card_scale := 1.0
## The open offer's crowd slot (crowd_slot), -1 without a Roar.
var _crowd_slot := -1
## The open offer's card the crowd took (a Boo's lock), -1 for none: drawn chained, never taken.
var locked := -1
## The slot held by a placeholder until the crowd's card is built; -1 when every card is in.
var _held := -1
## HEADING over the cards.
var heading_label: Label
## The crowd's line over the heading: hidden without one.
var crowd_label: Label
## The Reroll strip under the cards (the centred box holds the button and its pips), shown only
## with a re-draw left.
var reroll_strip: CenterContainer
var reroll_box: HBoxContainer
var reroll_button: Button
var reroll_pips_box: HBoxContainer

@onready var cards: HBoxContainer = $Center/Cards


func _ready() -> void:
	heading_label = UiTheme.title(HEADING, UiTheme.FONT_TITLE, UiTheme.PAPER)
	heading_label.name = "Heading"
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	# A full-width strip ending HEADING_GAP over the centred cards row, whatever the view's size.
	heading_label.anchor_left = 0.0
	heading_label.anchor_right = 1.0
	heading_label.anchor_top = 0.5
	heading_label.anchor_bottom = 0.5
	add_child(heading_label)
	crowd_label = UiTheme.label("", UiTheme.FONT_SMALL, UiTheme.PAPER)
	crowd_label.name = "CrowdLine"
	crowd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crowd_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	crowd_label.anchor_left = 0.0
	crowd_label.anchor_right = 1.0
	crowd_label.anchor_top = 0.5
	crowd_label.anchor_bottom = 0.5
	crowd_label.visible = false
	add_child(crowd_label)
	reroll_strip = CenterContainer.new()
	reroll_strip.name = "RerollStrip"
	reroll_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reroll_strip.anchor_left = 0.0
	reroll_strip.anchor_right = 1.0
	reroll_strip.anchor_top = 0.5
	reroll_strip.anchor_bottom = 0.5
	add_child(reroll_strip)
	reroll_box = HBoxContainer.new()
	reroll_box.name = "Reroll"
	reroll_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reroll_box.add_theme_constant_override("separation", REROLL_PIP_GAP)
	reroll_box.visible = false
	reroll_strip.add_child(reroll_box)
	reroll_button = UiTheme.button("Reroll", REROLL_SIZE)
	reroll_button.name = "Button"
	reroll_button.pressed.connect(func() -> void: reroll_requested.emit())
	reroll_box.add_child(reroll_button)
	reroll_pips_box = HBoxContainer.new()
	reroll_pips_box.name = "Pips"
	reroll_pips_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reroll_pips_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reroll_box.add_child(reroll_pips_box)
	_place_strips()


## The heading's strip ends HEADING_GAP over the cards row, the crowd's line's strip
## CROWD_LINE_GAP over the heading's, and the Reroll strip starts REROLL_GAP under the row; the
## row's height follows the scale.
func _place_strips() -> void:
	var half_height := CARD_SIZE.y * _card_scale / 2.0
	var heading_bottom := half_height + HEADING_GAP
	heading_label.offset_top = -(heading_bottom + UiTheme.FONT_TITLE)
	heading_label.offset_bottom = -heading_bottom
	var line_bottom := heading_bottom + UiTheme.FONT_TITLE + CROWD_LINE_GAP
	crowd_label.offset_top = -(line_bottom + UiTheme.FONT_SMALL)
	crowd_label.offset_bottom = -line_bottom
	reroll_strip.offset_top = half_height + REROLL_GAP
	reroll_strip.offset_bottom = half_height + REROLL_GAP + REROLL_SIZE.y


## The Reroll strip from RunState.rerolls_left: hidden at none, else a lit pip per re-draw.
func _refresh_reroll() -> void:
	UiTheme.clear_children(reroll_pips_box)
	var left := RunState.rerolls_left
	reroll_box.visible = left > 0
	for i in left:
		var pip := ColorRect.new()
		pip.name = "lit%d" % i
		pip.custom_minimum_size = Hud.PIP_SIZE
		pip.color = Hud.PIP_LIT
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reroll_pips_box.add_child(pip)


## Lit pips on the Reroll strip (the re-draws left, as drawn).
func reroll_pips() -> int:
	return reroll_pips_box.get_child_count()


## Shows the cards under the heading and pauses the tree. Safe to call again while open
## (a refund round, a reroll). With `roar` and more than one offer, one card is the crowd's
## (crowd_slot; `hurt` says the heal card holds the last slot): on a first open its slot is held
## and the card dropped in after its delay; over an open menu it is built at once with the rest.
## `line` is the crowd's line over the heading ("" for none: the strip is hidden). `lock` is the
## slot the crowd took at a Boo (-1 for none): greyed and chained, refused on a pick.
func open(new_offers: Array[UpgradeDef], roar := false, hurt := false, line := "", lock := -1) -> void:
	var was_open := visible
	_open_serial += 1
	offers = new_offers
	locked = lock if lock >= 0 and lock < new_offers.size() else -1
	crowd_label.text = line
	crowd_label.visible = not line.is_empty()
	assert(offers.size() <= MAX_CARDS, "UpgradeMenu: %d cards on offer, %d at most" % [offers.size(), MAX_CARDS])
	_crowd_slot = crowd_slot(offers.size(), hurt) if roar else -1
	_held = _crowd_slot if not was_open else -1
	_rebuild()
	_refresh_reroll()
	Juice.reset()  # a kill freeze must not leave Engine.time_scale at 0.05 under the pause
	get_tree().paused = true
	visible = true
	if not was_open:
		Events.menu_opened.emit("upgrade")
	if _held >= 0:
		_drop_crowd_card_later()


func close() -> void:
	var was_open := visible
	_open_serial += 1
	_held = -1
	visible = false
	get_tree().paused = false
	if was_open:
		Events.menu_closed.emit("upgrade")


func is_open() -> bool:
	return visible


## Takes the card in the slot; a held slot (the crowd's card, before its reveal) is nothing to
## take; a built one is taken even while it drops. The locked slot is refused (pick_denied).
func choose(index: int) -> void:
	if not visible or index < 0 or index >= offers.size() or index == _held:
		return
	if index == locked:
		Events.pick_denied.emit()
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


## Every card of the offer, the held slot an empty Control of the card's size (the row is laid
## out as it will be once the crowd's card is in); the row's scale and gap are set for the whole
## offer.
func _rebuild() -> void:
	UiTheme.clear_children(cards)
	var view_width := get_viewport().get_visible_rect().size.x
	_card_scale = card_scale(offers.size(), view_width)
	_place_strips()
	cards.add_theme_constant_override("separation", card_gap(offers.size(), view_width))
	for i in offers.size():
		if i == _held:
			var slot := Control.new()
			slot.name = "Held"
			slot.custom_minimum_size = CARD_SIZE * _card_scale
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cards.add_child(slot)
		else:
			cards.add_child(_card(offers[i], i, i == _crowd_slot, i == locked))


## After the delay, still on the same open: the crowd's card built in the held slot, its sound
## (card_revealed), and the drop of its face from above the view's top edge into the slot (the
## button takes the placeholder's place in the row; the face moves).
func _drop_crowd_card_later() -> void:
	var serial := _open_serial
	await get_tree().create_timer(CROWD_CARD_DELAY, true, false, true).timeout
	if not is_inside_tree() or not visible or serial != _open_serial:
		return
	var index := _held
	var slot := cards.get_child(index) as Control
	var button := _card(offers[index], index, true)
	var face: Control = button.get_node("Face")
	face.position.y = drop_start(slot.global_position.y, CARD_SIZE.y * _card_scale)
	cards.remove_child(slot)
	slot.queue_free()
	cards.add_child(button)
	cards.move_child(button, index)
	_held = -1
	Events.card_revealed.emit()
	var tween := face.create_tween().set_ignore_time_scale(true)
	tween.tween_property(face, "position:y", 0.0, CROWD_CARD_DROP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## The crowd's slot for `count` cards: the last, or the one before it when the heal card holds
## the last (`hurt`: UpgradeCatalog.offers keeps it there); -1 for a single card. Pure.
static func crowd_slot(count: int, hurt: bool) -> int:
	if count <= 1:
		return -1
	return count - 2 if hurt else count - 1


## Where the crowd's face starts, in its slot's frame: its bottom edge on the view's top edge,
## for a slot whose top is `slot_top` in the view and a card `card_height` tall. Pure.
static func drop_start(slot_top: float, card_height: float) -> float:
	return -(slot_top + card_height)


## CARD_GAP, or less when `count` cards at their scale would overflow `view_width`: the gaps
## shrink before the cards do. Pure.
static func card_gap(count: int, view_width: float) -> int:
	if count <= 1:
		return CARD_GAP
	var room := (view_width - count * CARD_SIZE.x * card_scale(count, view_width)) / float(count - 1)
	return maxi(0, mini(CARD_GAP, int(room)))


## The cards' scale: 1 while `count` cards at CARD_SIZE fit `view_width` with no gap, else the
## largest step of SCALE_STEP down at which they do (never under one step). Pure.
static func card_scale(count: int, view_width: float) -> float:
	var scale := 1.0
	while scale > SCALE_STEP and count * CARD_SIZE.x * scale > view_width:
		scale -= SCALE_STEP
	return scale


## A card: the beige panel under the orange frame, and a column of icon, name, effect, rank, all
## on a Face control inside the Button (the row places the button at the offer's scale; the
## face is drawn at CARD_SIZE and scaled, and drops). The crowd's card wears FRAME_CROWD and
## carries the crowd's two heads on its top bar, over its name. No key digit: 1 to 5 work silently
## (playtest 1 found the numbers redundant). The name is on the
## title font; a wide one wraps to two lines rather than shrinking to the description's size (the
## fit test runs every card). An empty rank line (a heal) adds no label. The Button is the click
## target; everything inside ignores the mouse. A `locked` card is a disabled Button (no hover,
## no press) whose left click still reaches choose through gui_input, to be refused; its face is
## greyed under the chain.
func _card(card: UpgradeDef, index: int, crowd := false, locked_card := false) -> Button:
	var button := Button.new()
	button.name = "Card%d" % (index + 1)
	button.custom_minimum_size = CARD_SIZE * _card_scale
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	if locked_card:
		button.disabled = true
		button.gui_input.connect(func(event: InputEvent) -> void: _on_locked_input(index, event))
	else:
		button.pressed.connect(func() -> void: choose(index))
		button.mouse_entered.connect(func() -> void:
			button.modulate = HOVER_MODULATE
			Events.card_hovered.emit())
		button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	var face := Control.new()
	face.name = "Face"
	face.size = CARD_SIZE
	face.scale = Vector2.ONE * _card_scale
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(face)
	UiTheme.framed_panel(face, CARD_SIZE, CARD_SCALE, UiTheme.FRAME_CROWD if crowd else UiTheme.FRAME)
	if crowd:
		(face.get_node("Frame") as CanvasItem).modulate = CROWD_FRAME_TINT
	var box := VBoxContainer.new()
	box.name = "Column"
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
	if crowd:
		var tex := Hud.crowd_placeholder()
		var heads := IconAtlas.rect_of(tex, CROWD_HEADS_SCALE)
		heads.name = "Crowd"
		heads.size = heads.custom_minimum_size
		var drawn := Rect2(tex.get_image().get_used_rect())
		heads.position = Vector2(CARD_SIZE.x / 2.0 - drawn.get_center().x * CROWD_HEADS_SCALE, CROWD_BAR - drawn.end.y * CROWD_HEADS_SCALE)
		face.add_child(heads)
	if locked_card:
		for part: String in ["Paper", "Frame", "Column"]:
			(face.get_node(part) as CanvasItem).modulate = LOCKED_MODULATE
		face.add_child(_chain())
	return button


## A left press on the locked card (a disabled Button still receives gui_input): refused.
func _on_locked_input(index: int, event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		choose(index)


## PLACEHOLDER: the crowd's chain, an X of chain tiles across the card's face crossing at
## CHAIN_CROSS (CHAIN_*), clipped to it; ignores the mouse.
func _chain() -> Control:
	var chain := Control.new()
	chain.name = "Chain"
	chain.size = CARD_SIZE
	chain.clip_contents = true
	chain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := IconAtlas.SIZE * CHAIN_SCALE
	var step := CHAIN_STEP * CHAIN_SCALE
	var centre := CHAIN_CROSS
	# Enough tiles either side of the crossing to reach past the card's corners on both diagonals.
	var reach := ceili(CARD_SIZE.length() / step.length()) + 1
	var card := Rect2(Vector2.ZERO, CARD_SIZE)
	for mirrored: bool in [false, true]:
		for n in range(-reach, reach + 1):
			var along := Vector2(-step.x if mirrored else step.x, step.y) * n
			var at := centre + along - Vector2(tile, tile) / 2.0
			if not card.intersects(Rect2(at, Vector2(tile, tile))):
				continue
			var link := IconAtlas.rect(CHAIN_ICON, CHAIN_SCALE)
			link.flip_h = mirrored
			link.position = at
			link.size = link.custom_minimum_size
			chain.add_child(link)
	return chain


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
