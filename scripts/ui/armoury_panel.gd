class_name ArmouryPanel
extends CanvasLayer
## The rack's panel: the gladiator's idle animation at 4x, the handgun's icon in a lit framed
## slot, and two empty framed slots beside it, greyed. Nothing to click: the empty slots are the
## whole of what it says. Opened and closed by Main on the rack's area; the grounds are never
## paused under it. Layer 10 like the training panel.

const PANEL_SCALE := 4.0
const INSET := 32.0
const GLADIATOR_SCALE := 4.0
const GLADIATOR_AIR := Vector2(32, 16)  ## around the frame at GLADIATOR_SCALE, on each side
const SLOT_SIZE := Vector2(88, 88)  ## whole nine-patch pixels at PANEL_SCALE
const SLOT_GAP := 8
const SLOT_COUNT := 3
const ICON_SCALE := 3.0
const GLADIATOR_GAP := 24.0
const EMPTY_MODULATE := Color(0.55, 0.55, 0.55)

var panel: Control
var gladiator: AnimatedSprite2D
## The gladiator's box: the idle frame at GLADIATOR_SCALE with GLADIATOR_AIR around it (the
## 16x28 frame gives 128 x 144); the panel is the inset, the box, the gap, three slots with
## their gaps, the inset (496 x 208 at those numbers, whole nine-patch pixels).
var gladiator_box: Vector2
var panel_size: Vector2

var _slots: Array[Control] = []


func _ready() -> void:
	var frames := SpriteAtlas.frames({"idle": Player.ANIMATIONS["idle"]})
	gladiator_box = frames.get_frame_texture("idle", 0).get_size() * GLADIATOR_SCALE + GLADIATOR_AIR * 2.0
	panel_size = Vector2(INSET * 2.0 + gladiator_box.x + GLADIATOR_GAP + SLOT_SIZE.x * SLOT_COUNT + SLOT_GAP * (SLOT_COUNT - 1), INSET * 2.0 + gladiator_box.y)
	var centre := CenterContainer.new()
	centre.name = "Center"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	panel = Control.new()
	panel.name = "Panel"
	panel.custom_minimum_size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.framed_panel(panel, panel_size, PANEL_SCALE)
	centre.add_child(panel)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.position = Vector2(INSET, INSET)
	row.size = panel_size - Vector2(INSET, INSET) * 2.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(GLADIATOR_GAP))
	panel.add_child(row)
	var box := Control.new()
	box.name = "Gladiator"
	box.custom_minimum_size = gladiator_box
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	gladiator = AnimatedSprite2D.new()
	gladiator.name = "Sprite"
	gladiator.position = gladiator_box * 0.5
	gladiator.scale = Vector2(GLADIATOR_SCALE, GLADIATOR_SCALE)
	gladiator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gladiator.sprite_frames = frames
	box.add_child(gladiator)
	var slots_box := HBoxContainer.new()
	slots_box.name = "Slots"
	slots_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots_box.add_theme_constant_override("separation", SLOT_GAP)
	row.add_child(slots_box)
	for i in SLOT_COUNT:
		var slot := _slot(i)
		_slots.append(slot)
		slots_box.add_child(slot)
	visible = false


func open() -> void:
	_fill()
	gladiator.play("idle")
	visible = true


func close() -> void:
	gladiator.stop()
	visible = false


func is_open() -> bool:
	return visible


func slots() -> Array[Control]:
	return _slots


## True when the slot holds a weapon (drawn lit); an empty slot is greyed.
func slot_lit(index: int) -> bool:
	return _slots[index].modulate == Color.WHITE


## The weapon's icon in the slot, or null for an empty one.
func slot_icon(index: int) -> TextureRect:
	return _slots[index].get_node_or_null("Icon") as TextureRect


func _slot(index: int) -> Control:
	var slot := Control.new()
	slot.name = "Slot%d" % (index + 1)
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.framed_panel(slot, SLOT_SIZE, PANEL_SCALE)
	return slot


## The next run's weapon in the first slot (every run starts with Build.STARTING_WEAPON: the
## last run's switch does not carry over); the rest empty.
func _fill() -> void:
	for i in SLOT_COUNT:
		var slot := _slots[i]
		var old := slot.get_node_or_null("Icon")
		if old != null:
			slot.remove_child(old)
			old.queue_free()
		var weapon_id := Build.STARTING_WEAPON if i == 0 else ""
		if weapon_id.is_empty():
			slot.modulate = EMPTY_MODULATE
			continue
		slot.modulate = Color.WHITE
		var icon := IconAtlas.rect(UpgradeCatalog.weapon(weapon_id).icon, ICON_SCALE)
		icon.name = "Icon"
		icon.position = (SLOT_SIZE - icon.custom_minimum_size) * 0.5
		icon.size = icon.custom_minimum_size
		slot.add_child(icon)
