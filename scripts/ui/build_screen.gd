class_name BuildScreen
extends CanvasLayer
## Tab: the whole build over a dim with the tree paused. The weapon, every owned weapon upgrade
## with rank and effect, the player upgrades. Tab or Escape closes; R restarts, handled here like
## the picker does because Main is paused with everything else. Main sets `blocked` so it never
## opens over the picker, during the room fade, or after the run has ended. Same layer and
## process mode as the picker; the two never show together.

signal restart_pressed

## 1000 x 560 holds the widest catalog row (icon, a 216 px name, the rank, a 452 px effect) and
## the seven rows an eight-room floor can give, at whole nine-patch pixels (multiples of 4).
const PANEL_SIZE := Vector2(1000, 560)
const PANEL_SCALE := 4.0
const INSET := 36.0
const ICON_SCALE := 3.0

## Main sets this; open() refuses while it returns true.
var blocked: Callable = func() -> bool: return false
var lines: VBoxContainer

@onready var panel: Control = $Center/Panel


func _ready() -> void:
	var paper := UiTheme.nine_patch(UiTheme.PANEL, UiTheme.PANEL_MARGIN, PANEL_SIZE - Vector2(24, 24), PANEL_SCALE)
	paper.position = Vector2(12, 12)
	panel.add_child(paper)
	panel.add_child(UiTheme.nine_patch(UiTheme.FRAME, UiTheme.FRAME_MARGIN, PANEL_SIZE, PANEL_SCALE))
	lines = VBoxContainer.new()
	lines.name = "Lines"
	lines.position = Vector2(INSET, INSET)
	lines.size = PANEL_SIZE - Vector2(INSET, INSET) * 2.0
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 8)
	panel.add_child(lines)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("build_screen"):
		if visible:
			close()
		else:
			open()
	elif visible and Input.is_action_just_pressed("ui_cancel"):
		close()
	elif visible and Input.is_action_just_pressed("restart"):
		restart_pressed.emit()


func open() -> void:
	if blocked.call():
		return
	_rebuild()
	Juice.reset()
	get_tree().paused = true
	visible = true


func close() -> void:
	visible = false
	get_tree().paused = false


func is_open() -> bool:
	return visible


func _rebuild() -> void:
	for child in lines.get_children():
		lines.remove_child(child)
		child.queue_free()
	var build := RunState.build
	var catalog := UpgradeCatalog.upgrades()
	var weapon := UpgradeCatalog.weapon(build.weapon_id)
	lines.add_child(_row("Row_weapon", weapon.icon, weapon.display_name, "", ""))
	var owned := build.owned_weapon_ids()
	for id in owned:
		var u: UpgradeDef = catalog[id]
		lines.add_child(_row("Row_" + id, u.icon, u.name, "%d of %d" % [build.rank_of(id), u.max_rank], u.description))
	var player_ids := build.owned_player_ids()
	for id in player_ids:
		var u: UpgradeDef = catalog[id]
		lines.add_child(_row("Row_" + id, u.icon, u.name, "%d of %d" % [build.rank_of(id), u.max_rank], u.description))
	if owned.is_empty() and player_ids.is_empty():
		lines.add_child(UiTheme.label("No upgrades yet", UiTheme.FONT_SMALL))
	var hint := UiTheme.label("Tab to close", UiTheme.FONT_SMALL)
	hint.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	lines.add_child(hint)


func _row(row_name: String, icon: String, title: String, rank: String, description: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = row_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	row.add_child(IconAtlas.rect(icon, ICON_SCALE))
	var is_weapon := rank.is_empty() and description.is_empty()
	var name_label := UiTheme.title(title) if is_weapon else UiTheme.label(title, UiTheme.FONT_SMALL)
	name_label.custom_minimum_size = Vector2(240, 0)
	row.add_child(name_label)
	if is_weapon:
		return row  # the weapon row is the heading: the icon and the name on the title font
	var rank_label := UiTheme.label(rank, UiTheme.FONT_SMALL)
	rank_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(rank_label)
	row.add_child(UiTheme.label(description, UiTheme.FONT_SMALL))
	return row
