class_name TrainingPanel
extends CanvasLayer
## The training post's panel: the money held at its top (a number beside a coin, over the
## prices' column), then a framed column of the training lines, one row each on one line: its
## icon (TrainingRules.icon: a Raven icon, or the tileset's coin for COIN_ICON), its name
## (TrainingRules.name_of), its rank pips in the HUD's style, and the next rank's price beside a
## coin (the icon in a slot of ICON_SLOT, so the names line up). Under the rows a description strip, one font line, shows the hovered row's text
## (TrainingRules.text: what a rank buys, named, never explained) and is empty otherwise; a
## greyed row's text shows too (a disabled Button still reports the hover). A row the money does
## not cover, or one at its cap, is greyed. A click on a row buys the rank (the money out, the
## rank up, the profile committed, the money line refreshed) or is refused on the bus
## (purchase_denied: its sound). UI may name, never narrate: the names, the numbers, and the
## hovered line, nothing else.
## Opened and closed by Main on the post's area; the grounds are never paused under it, so the
## layer keeps the tree's process mode. Layer 10 like the menus; the pause screen, later in the
## tree at the same layer, draws over it.

const PANEL_SCALE := 4.0
const INSET := 32.0
const PRICE_FONT_SIZE := 32  ## the pixel font's grid, twice
const LINE_FONT_SIZE := UiTheme.FONT_SMALL  ## the row's name and the strip's text
const LINE_HEIGHT := float(LINE_FONT_SIZE)  ## one font line
## A row is one line: the icon, the name, the pips, the price. Wide enough for the longest text
## in the strip at LINE_FONT_SIZE.
const ROW_SIZE := Vector2(400, 56)
const ROW_GAP := 8
## The money line over the rows, as tall as a row.
const MONEY_HEIGHT := ROW_SIZE.y
## The description strip under the rows: one font line, the rows' width.
const DESCRIPTION_HEIGHT := LINE_HEIGHT
## The rows' column, a gap between rows.
static func rows_height() -> float:
	return (ROW_SIZE.y + ROW_GAP) * TrainingRules.LINES.size() - ROW_GAP
## 2 * INSET around the money line, the rows, and the strip, a ROW_GAP between each: 464 x 416
## for four lines, whole nine-patch pixels (a function: the table's size is no constant expression).
static func panel_size() -> Vector2:
	return Vector2(ROW_SIZE.x + INSET * 2.0,
		MONEY_HEIGHT + ROW_GAP + rows_height() + ROW_GAP + DESCRIPTION_HEIGHT + INSET * 2.0)

const ICON_SCALE := 3.0
## The icons' column: a Raven icon's size at ICON_SCALE, so the names line up; the tileset's coin,
## smaller, is centred in it.
const ICON_SLOT := IconAtlas.SIZE * ICON_SCALE
const COIN_SCALE := 3.0
const ROW_SEPARATION := 16  ## between the icon, the name, the pips, and the price
const HOVER_MODULATE := Color(1.12, 1.12, 1.12)
const GREY_MODULATE := Color(0.55, 0.55, 0.55)

var save: Save
var panel: Control
var money_box: HBoxContainer
var money_label: Label
var rows_box: VBoxContainer
var description: Label

var _rows: Dictionary = {}  ## line -> Button


func _ready() -> void:
	var centre := CenterContainer.new()
	centre.name = "Center"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	panel = Control.new()
	panel.name = "Panel"
	var size := panel_size()
	panel.custom_minimum_size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.framed_panel(panel, size, PANEL_SCALE)
	centre.add_child(panel)
	money_box = HBoxContainer.new()
	money_box.name = "Money"
	money_box.position = Vector2(INSET, INSET)
	money_box.size = Vector2(ROW_SIZE.x, MONEY_HEIGHT)
	money_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money_box.alignment = BoxContainer.ALIGNMENT_END
	money_box.add_theme_constant_override("separation", ROW_SEPARATION)
	money_label = UiTheme.label("", PRICE_FONT_SIZE)
	money_label.name = "Amount"
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_box.add_child(money_label)
	var money_coin := SpriteAtlas.rect("coin_anim", COIN_SCALE)
	money_coin.name = "Coin"
	money_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_box.add_child(money_coin)
	panel.add_child(money_box)
	rows_box = VBoxContainer.new()
	rows_box.name = "Rows"
	rows_box.position = Vector2(INSET, INSET + MONEY_HEIGHT + ROW_GAP)
	rows_box.size = Vector2(ROW_SIZE.x, rows_height())
	rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_box.add_theme_constant_override("separation", ROW_GAP)
	panel.add_child(rows_box)
	description = UiTheme.label("", LINE_FONT_SIZE)
	description.name = "Description"
	description.position = Vector2(INSET, rows_box.position.y + rows_height() + ROW_GAP)
	description.size = Vector2(ROW_SIZE.x, DESCRIPTION_HEIGHT)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(description)
	visible = false


## Shows the lines for `profile_save` (the live one: a purchase writes to it and commits).
func open(profile_save: Save) -> void:
	save = profile_save
	_rebuild()
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


## The rows by line, in the table's order.
func rows() -> Dictionary:
	return _rows


func row(line: String) -> Button:
	return _rows[line]


func lit_pips(line: String) -> int:
	var lit := 0
	for pip in row(line).get_node("Box/Pips").get_children():
		if pip.name.begins_with("lit"):
			lit += 1
	return lit


## The money held, as the top line shows it.
func money_text() -> String:
	return money_label.text


## The row's name beside its icon (the table's).
func name_text(line: String) -> String:
	return (row(line).get_node("Box/Name") as Label).text


## The strip's text: the hovered row's, "" when no row is hovered.
func description_text() -> String:
	return description.text


## The next price shown on the row ("" when the line is capped).
func price_text(line: String) -> String:
	return (row(line).get_node("Box/Price") as Label).text


## A click on the line's row: the rank bought when the money covers it and the line has one
## left, else refused on the bus. The rows redraw after a purchase.
func click(line: String) -> void:
	if not visible or save == null:
		return
	if not TrainingRules.can_buy(save, line):
		Events.purchase_denied.emit(line)
		return
	TrainingRules.buy(save, line)
	Events.training_bought.emit(line, TrainingRules.rank(save, line))
	Profile.commit()
	_rebuild()


## The money line and the rows from the save, on open and after a purchase. The strip empties
## with the rows: the hovered row goes with them, and the cursor's next report over the new one
## fills it again.
func _rebuild() -> void:
	money_label.text = str(save.money)
	description.text = ""
	UiTheme.clear_children(rows_box)
	_rows = {}
	for line: String in TrainingRules.LINES:
		var button := _row(line)
		_rows[line] = button
		rows_box.add_child(button)


func _row(line: String) -> Button:
	var button := Button.new()
	button.name = line
	button.custom_minimum_size = ROW_SIZE
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	var can_buy := TrainingRules.can_buy(save, line)
	button.disabled = not can_buy
	button.modulate = Color.WHITE if can_buy else GREY_MODULATE
	button.gui_input.connect(func(event: InputEvent) -> void: _on_row_input(line, event))
	button.mouse_entered.connect(func() -> void:
		description.text = TrainingRules.text(line)
		if can_buy:
			button.modulate = HOVER_MODULATE)
	button.mouse_exited.connect(func() -> void:
		description.text = ""
		if can_buy:
			button.modulate = Color.WHITE)
	var box := HBoxContainer.new()
	box.name = "Box"
	box.position = Vector2.ZERO
	box.size = ROW_SIZE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", ROW_SEPARATION)
	var icon_name := TrainingRules.icon(line)
	var icon: TextureRect = SpriteAtlas.rect("coin_anim", ICON_SCALE) if icon_name == TrainingRules.COIN_ICON else IconAtlas.rect(icon_name, ICON_SCALE)
	icon.name = "Icon"
	var slot := CenterContainer.new()
	slot.name = "Slot"
	slot.custom_minimum_size = Vector2.ONE * ICON_SLOT
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_child(icon)
	box.add_child(slot)
	var line_name := UiTheme.label(TrainingRules.name_of(line), LINE_FONT_SIZE)
	line_name.name = "Name"
	line_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line_name)
	var pips := HBoxContainer.new()
	pips.name = "Pips"
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rank := TrainingRules.rank(save, line)
	for i: int in TrainingRules.max_rank(line):
		var pip := ColorRect.new()
		var lit := i < rank
		pip.name = "%s%d" % ["lit" if lit else "dim", i]
		pip.custom_minimum_size = Hud.PIP_SIZE
		pip.color = Hud.PIP_LIT if lit else Hud.PIP_DIM
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	box.add_child(pips)
	var spacer := Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	var capped := TrainingRules.capped(save, line)
	var price := UiTheme.label("" if capped else str(TrainingRules.next_price(save, line)), PRICE_FONT_SIZE)
	price.name = "Price"
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(price)
	var coin := SpriteAtlas.rect("coin_anim", COIN_SCALE)
	coin.name = "Coin"
	coin.visible = not capped
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(coin)
	button.add_child(box)
	return button


## A left press on a row, greyed or not (a disabled Button still receives gui_input, and a
## refused click has its own sound).
func _on_row_input(line: String, event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		click(line)
