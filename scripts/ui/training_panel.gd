class_name TrainingPanel
extends CanvasLayer
## The training post's panel: a framed column of the three training lines, one row each with
## its icon (a heart container, a dash charge, a coin), its rank pips in the HUD's style, and
## the next rank's price beside a coin. A row the money does not cover, or one at its cap, is
## greyed. A click on a row buys the rank (the money out, the rank up, the profile committed)
## or is refused on the bus (purchase_denied: its sound). Not a word on it beyond the numbers.
## Opened and closed by Main on the post's area; the grounds are never paused under it, so the
## layer keeps the tree's process mode. Layer 10 like the menus; the pause screen, later in the
## tree at the same layer, draws over it.

const LINE_ICONS := {"hearts": "heart_container", "breath": "dash_charge"}  # renown's is the coin sprite
const PANEL_SCALE := 4.0
const INSET := 32.0
const ROW_SIZE := Vector2(336, 56)
const ROW_GAP := 8
## 2 * INSET around the rows: 400 x 248, whole nine-patch pixels.
const PANEL_SIZE := Vector2(ROW_SIZE.x + INSET * 2.0, ROW_SIZE.y * 3.0 + ROW_GAP * 2.0 + INSET * 2.0)
const ICON_SCALE := 3.0
const COIN_SCALE := 3.0
const PRICE_FONT_SIZE := 32  ## the pixel font's grid, twice
const HOVER_MODULATE := Color(1.12, 1.12, 1.12)
const GREY_MODULATE := Color(0.55, 0.55, 0.55)

var save: Save
var panel: Control
var rows_box: VBoxContainer

var _rows: Dictionary = {}  ## line -> Button


func _ready() -> void:
	var centre := CenterContainer.new()
	centre.name = "Center"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	panel = Control.new()
	panel.name = "Panel"
	panel.custom_minimum_size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.framed_panel(panel, PANEL_SIZE, PANEL_SCALE)
	centre.add_child(panel)
	rows_box = VBoxContainer.new()
	rows_box.name = "Rows"
	rows_box.position = Vector2(INSET, INSET)
	rows_box.size = PANEL_SIZE - Vector2(INSET, INSET) * 2.0
	rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows_box.add_theme_constant_override("separation", ROW_GAP)
	panel.add_child(rows_box)
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


func _rebuild() -> void:
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
	if can_buy:
		button.mouse_entered.connect(func() -> void: button.modulate = HOVER_MODULATE)
		button.mouse_exited.connect(func() -> void: button.modulate = Color.WHITE)
	var box := HBoxContainer.new()
	box.name = "Box"
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	var icon: TextureRect = _coin_rect(ICON_SCALE) if not LINE_ICONS.has(line) else IconAtlas.rect(LINE_ICONS[line], ICON_SCALE)
	icon.name = "Icon"
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var pips := HBoxContainer.new()
	pips.name = "Pips"
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rank := TrainingRules.rank(save, line)
	for i in TrainingRules.max_rank(line):
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
	var coin := _coin_rect(COIN_SCALE)
	coin.name = "Coin"
	coin.visible = not capped
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(coin)
	button.add_child(box)
	return button


## The coin sprite's first frame as a container-sized rect (the HUD's counter draws it the same
## way; those lines are repeated here rather than shared, the HUD's counter being a node of its own).
static func _coin_rect(scale: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = SpriteAtlas.texture("coin_anim")
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = SpriteAtlas.region("coin_anim").size * scale
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A left press on a row, greyed or not (a disabled Button still receives gui_input, and a
## refused click has its own sound).
func _on_row_input(line: String, event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		click(line)
