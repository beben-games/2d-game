@tool
extends GraphNode
## One event in the Story tab: its name in a title bar of its priority's colour, three rows (its
## trigger; once or repeat, and its act; its badges: the placeholder lines left, its errors), and a
## port each side of each row, one row per kind of edge (StoryLinks.KINDS in order), so an edge's
## colour is its kind's. A node drawn from the file alone (the catalog left it out) has a red
## border; a stub (the parser dropped it) says "not parsed" in place of facts it does not have.
## Dimmed while any reason holds (set_dim: the toolbar's "filter", What-if's later), so one dimming
## never undoes another. Each kind's ports have their own type (the kind's index), so a drag joins
## only a row to the same row: the tab reads the edge's kind from its port. A menu in the title bar
## (also on a right-click) asks the tab to rename or delete the event. Every pixel size here is at
## the editor's scale (editor_scale).

signal rename_requested(id: String)
signal delete_requested(id: String)

## The edges' colours, by kind; the row (and port) of a kind is its place in StoryLinks.KINDS.
const PORT_COLORS := {
	StoryLinks.REQUIRES: Color(0.78, 0.82, 0.92),
	StoryLinks.UNLESS: Color(0.92, 0.32, 0.3),
	StoryLinks.FLAG: Color(0.45, 0.82, 0.45),
}
const PRIORITY_COLORS := {
	"story": Color(0.72, 0.55, 0.15),
	"high": Color(0.68, 0.3, 0.22),
	"normal": Color(0.25, 0.38, 0.55),
	"filler": Color(0.3, 0.3, 0.3),
}
## The title's colour on every priority's bar (all four are dark).
const TITLE_COLOR := Color(1, 1, 1)
const PLACEHOLDER_COLOR := Color(0.95, 0.8, 0.35)
const ERROR_COLOR := Color(1.0, 0.4, 0.4)
const DIMMED := Color(1, 1, 1, 0.22)
## At scale 1; editor_scale() times these.
const MIN_WIDTH := 220.0
const BADGE_SEPARATION := 12
const MARGIN := 8
const MARGIN_TOP := 4
const CORNER := 4
const BORDER := 2
const MENU_RENAME := 0
const MENU_DELETE := 1

## The event's id ("<pool>.<name>").
var id := ""
## The reasons the node is dimmed (reason -> true).
var _dims: Dictionary = {}
var _menu: MenuButton = null


## The editor's display scale (2 on a Retina screen at the default setting), 1 outside the editor
## (the test runner): every pixel size the tab sets is multiplied by it, as the editor theme is.
static func editor_scale() -> float:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		return float(Engine.get_singleton("EditorInterface").call("get_editor_scale"))
	return 1.0


## The port (on either side) the edges of `kind` use.
static func port(kind: String) -> int:
	return StoryLinks.KINDS.find(kind)


## Fills the node for the event from StoryGraph.badges: {"placeholders": lines left marked,
## "errors": the catalog's errors on it, "loaded": false for one drawn from the file alone,
## "parsed": false for a stub}. A later badge (the lint's) is another key.
func show_event(event: StoryEvent, badges: Dictionary) -> void:
	var factor := editor_scale()
	id = event.id
	title = event.name if event.name != "" else "(no name)"
	tooltip_text = event.id
	custom_minimum_size.x = MIN_WIDTH * factor
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var parsed: bool = badges.get("parsed", true)
	if parsed:
		_row((event.trigger + " " + event.trigger_arg).strip_edges())
		_row(("once" if event.once else "repeat") + ("   act %d" % event.act if event.act != 0 else ""))
	else:
		_row("not parsed")
		_row(" ")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(BADGE_SEPARATION * factor))
	var placeholders: int = badges.get("placeholders", 0)
	var errors: int = badges.get("errors", 0)
	var loaded: bool = badges.get("loaded", true)
	if placeholders > 0:
		row.add_child(_label("%d placeholder" % placeholders, PLACEHOLDER_COLOR))
	if errors > 0:
		row.add_child(_label("%d error%s" % [errors, "" if errors == 1 else "s"], ERROR_COLOR))
	elif not loaded:
		row.add_child(_label("not loaded", ERROR_COLOR))
	if row.get_child_count() == 0:
		row.add_child(_label(" "))
	add_child(row)
	for kind: String in StoryLinks.KINDS:
		var color: Color = PORT_COLORS[kind]
		set_slot(port(kind), true, port(kind), color, true, port(kind), color)
	var bar_color: Color = PRIORITY_COLORS.get(event.priority, PRIORITY_COLORS["normal"]) if parsed else PRIORITY_COLORS["filler"]
	_style(bar_color, loaded and errors == 0, factor)
	_add_menu()


## The menu's items enabled (the story can be edited) or not.
func set_editable(on: bool) -> void:
	if _menu != null:
		for index in _menu.get_popup().item_count:
			_menu.get_popup().set_item_disabled(index, not on)


## The node's menu in its title bar: Rename and Delete, each a request the tab answers.
func _add_menu() -> void:
	if _menu != null:
		return
	_menu = MenuButton.new()
	_menu.flat = true
	_menu.tooltip_text = "Rename or delete this event"
	if has_theme_icon("GuiTabMenuHl", "EditorIcons"):
		_menu.icon = get_theme_icon("GuiTabMenuHl", "EditorIcons")
	else:
		_menu.text = "..."
	var popup := _menu.get_popup()
	popup.add_item("Rename...", MENU_RENAME)
	popup.add_item("Delete...", MENU_DELETE)
	popup.id_pressed.connect(_on_menu)
	get_titlebar_hbox().add_child(_menu)


func _on_menu(item: int) -> void:
	match item:
		MENU_RENAME:
			rename_requested.emit(id)
		MENU_DELETE:
			delete_requested.emit(id)


## A right-click on the node opens its menu there.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and _menu != null:
		var at := Vector2i(get_screen_transform() * click.position)
		_menu.get_popup().popup(Rect2i(at, Vector2i.ZERO))
		accept_event()


## Dims the node while `reason` holds (on), or lifts that reason (off); dimmed while any holds.
func set_dim(reason: String, on: bool) -> void:
	if on:
		_dims[reason] = true
	else:
		_dims.erase(reason)
	modulate = DIMMED if not _dims.is_empty() else Color.WHITE


func is_dimmed() -> bool:
	return not _dims.is_empty()


func _row(text: String) -> void:
	add_child(_label(text))


## A label in the theme's font colour, or in `color` when given.
static func _label(text: String, color := Color(0, 0, 0, 0)) -> Label:
	var label := Label.new()
	label.text = text
	if color.a > 0:
		label.add_theme_color_override("font_color", color)
	return label


## The title bar in the priority's colour with a light title; a red border on a node with an error.
func _style(color: Color, clean: bool, factor: float) -> void:
	for child in get_titlebar_hbox().get_children():
		if child is Label:
			(child as Label).add_theme_color_override("font_color", TITLE_COLOR)
	for slot: String in ["titlebar", "titlebar_selected"]:
		var bar := _box(color if slot == "titlebar" else color.lightened(0.25), factor)
		bar.corner_radius_top_left = int(CORNER * factor)
		bar.corner_radius_top_right = int(CORNER * factor)
		add_theme_stylebox_override(slot, bar)
	for slot: String in ["panel", "panel_selected"]:
		if clean:
			remove_theme_stylebox_override(slot)
			continue
		var panel := _box(Color(0.16, 0.12, 0.12), factor)
		panel.border_color = ERROR_COLOR if slot == "panel" else ERROR_COLOR.lightened(0.4)
		panel.set_border_width_all(int(BORDER * factor))
		add_theme_stylebox_override(slot, panel)


static func _box(color: Color, factor: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = MARGIN * factor
	box.content_margin_right = MARGIN * factor
	box.content_margin_top = MARGIN_TOP * factor
	box.content_margin_bottom = MARGIN_TOP * factor
	return box
