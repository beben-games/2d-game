@tool
extends GraphNode
## One event in the Story tab: its name in a title bar of its priority's colour, three rows (its
## trigger; once or repeat, and its act; its badges: the placeholder lines left, its errors), and a
## port each side of each row, one row per kind of edge (StoryLinks.KINDS in order), so an edge's
## colour is its kind's. A node drawn from the file alone (the catalog left it out) has a red
## border. Read only: the tab never connects a drag (Task 13 does).

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
const PLACEHOLDER_COLOR := Color(0.95, 0.8, 0.35)
const ERROR_COLOR := Color(1.0, 0.4, 0.4)
const MIN_WIDTH := 220.0

## The event's id ("<pool>.<name>").
var id := ""


## The port (on either side) the edges of `kind` use.
static func port(kind: String) -> int:
	return StoryLinks.KINDS.find(kind)


## Fills the node for the event: `placeholders` lines left marked, `errors` the catalog's errors in
## its block, `loaded` false for one drawn from the file alone.
func show_event(event: StoryEvent, placeholders: int, errors: int, loaded: bool) -> void:
	id = event.id
	title = event.name if event.name != "" else "(no name)"
	tooltip_text = event.id
	custom_minimum_size.x = MIN_WIDTH
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var trigger := (event.trigger + " " + event.trigger_arg).strip_edges()
	_row(trigger)
	_row(("once" if event.once else "repeat") + ("   act %d" % event.act if event.act != 0 else ""))
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 12)
	if placeholders > 0:
		badges.add_child(_label("%d placeholder" % placeholders, PLACEHOLDER_COLOR))
	if errors > 0:
		badges.add_child(_label("%d error%s" % [errors, "" if errors == 1 else "s"], ERROR_COLOR))
	elif not loaded:
		badges.add_child(_label("not loaded", ERROR_COLOR))
	if badges.get_child_count() == 0:
		badges.add_child(_label(" ", Color.WHITE))
	add_child(badges)
	for kind: String in StoryLinks.KINDS:
		var color: Color = PORT_COLORS[kind]
		set_slot(port(kind), true, 0, color, true, 0, color)
	_style(PRIORITY_COLORS.get(event.priority, PRIORITY_COLORS["normal"]), loaded and errors == 0)


func _row(text: String) -> void:
	add_child(_label(text, Color(0.85, 0.85, 0.85)))


static func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


## The title bar in the priority's colour; a red border on a node with an error.
func _style(color: Color, clean: bool) -> void:
	for name: String in ["titlebar", "titlebar_selected"]:
		var bar := StyleBoxFlat.new()
		bar.bg_color = color if name == "titlebar" else color.lightened(0.25)
		bar.content_margin_left = 8
		bar.content_margin_right = 8
		bar.content_margin_top = 4
		bar.content_margin_bottom = 4
		bar.corner_radius_top_left = 4
		bar.corner_radius_top_right = 4
		add_theme_stylebox_override(name, bar)
	for name: String in ["panel", "panel_selected"]:
		if clean:
			remove_theme_stylebox_override(name)
			continue
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.16, 0.12, 0.12)
		panel.border_color = ERROR_COLOR if name == "panel" else ERROR_COLOR.lightened(0.4)
		panel.set_border_width_all(2)
		panel.content_margin_left = 8
		panel.content_margin_right = 8
		panel.content_margin_top = 4
		panel.content_margin_bottom = 4
		add_theme_stylebox_override(name, panel)
