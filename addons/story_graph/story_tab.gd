@tool
extends VBoxContainer
## The Story tab, read only: the story in `dir` (data/story) as a graph. A lane per character (a
## frame, the cast's order), a node per event placed by StoryLayout (columns by depth in the chain
## of requires), the three kinds of edge from StoryLinks told apart by colour (the legend), every
## event the files hold even when the catalog left it out (StoryGraph: its errors as its badge).
## The toolbar reloads from disk, filters by character and act, and searches ids and text (a node
## that does not match dims); the catalog's errors list under it (a click selects the event); the
## side panel shows the selected event's text. Thin by design: what can be pure is in
## scripts/story (StoryGraph, StoryLayout, StoryLinks) and tested there; this draws.
##
## Room for the next tasks: editing (Task 13) adds to the side panel's Event tab and connects the
## graph's requests; What-if (Task 14) is another tab of the side panel; the lint's badges (Task
## 15) go through EventNode.show_event and the error list.

const EventNode := preload("res://addons/story_graph/event_node.gd")
## A cell of StoryLayout's grid in pixels (a node is MIN_WIDTH wide, about 110 tall).
const CELL := Vector2(300, 150)
## Above each lane: the lane frame's title.
const LANE_GAP := 56.0
const LANE_MARGIN := 24.0
const LANE_TINTS: Array[Color] = [Color(0.3, 0.45, 0.7, 0.10), Color(0.7, 0.55, 0.3, 0.10)]
const DIMMED := Color(1, 1, 1, 0.22)
const ACT_ITEMS := [["All acts", StoryGraph.ANY_ACT], ["Act 1", 1], ["Act 2", 2], ["Act 3", 3], ["No act", 0]]

## The story's directory.
var dir := StoryCatalog.DATA_DIR
var catalog: StoryCatalog = null
var model: StoryGraph = null
## Event id -> its EventNode.
var nodes: Dictionary = {}
## Pool -> its lane's GraphFrame.
var lanes: Dictionary = {}
## The id shown in the side panel ("" for none).
var selected := ""

@onready var graph: GraphEdit = %Graph
@onready var _reload: Button = %Reload
@onready var _character: OptionButton = %Character
@onready var _act: OptionButton = %Act
@onready var _search: LineEdit = %Search
@onready var _legend: HBoxContainer = %Legend
@onready var _status: Label = %Status
@onready var _errors: ItemList = %Errors
@onready var _title: Label = %Title
@onready var _facts: Label = %Facts
@onready var _text: TextEdit = %Text


func _ready() -> void:
	if is_part_of_edited_scene():
		return
	_build_legend()
	for item: Array in ACT_ITEMS:
		_act.add_item(item[0])
		_act.set_item_metadata(_act.item_count - 1, item[1])
	_reload.pressed.connect(reload)
	_character.item_selected.connect(_on_filter.unbind(1))
	_act.item_selected.connect(_on_filter.unbind(1))
	_search.text_changed.connect(_on_filter.unbind(1))
	graph.node_selected.connect(_on_node_selected)
	_errors.item_selected.connect(_on_error_selected)
	reload()


## The story read again from `dir`: a file edited outside shows.
func reload() -> void:
	show_catalog(StoryCatalog.load_dir(dir))


## Draws the catalog (the graph rebuilt, the filters and the selection kept where they still apply).
func show_catalog(story: StoryCatalog) -> void:
	catalog = story
	model = StoryGraph.of(story)
	_clear()
	_fill_characters()
	_draw_graph()
	_list_errors()
	apply_filters()
	show_event(selected if model.event(selected) != null else "")


## Dims every node the toolbar's filters and search leave out; returns how many pass.
func apply_filters() -> int:
	var pool: String = _character.get_item_metadata(_character.selected) if _character.selected >= 0 else ""
	var act: int = _act.get_item_metadata(_act.selected) if _act.selected >= 0 else StoryGraph.ANY_ACT
	var shown := 0
	for id: String in nodes:
		var passes := StoryGraph.passes(model.event(id), pool, act, _search.text)
		(nodes[id] as GraphNode).modulate = Color.WHITE if passes else DIMMED
		shown += 1 if passes else 0
	_status.text = "%d events, %d shown, %d errors" % [nodes.size(), shown, catalog.errors.size()]
	return shown


## Selects the event's node, scrolls to it, and shows it in the side panel.
func select_event(id: String) -> void:
	if not nodes.has(id):
		return
	var node: GraphNode = nodes[id]
	graph.set_selected(node)
	graph.scroll_offset = (node.position_offset + node.size / 2) * graph.zoom - graph.size / 2
	show_event(id)


## The side panel: the event's facts and its text, read only ("" clears it).
func show_event(id: String) -> void:
	selected = id
	var event := model.event(id) if model != null else null
	if event == null:
		_title.text = "No event selected"
		_facts.text = ""
		_text.text = ""
		return
	_title.text = event.id
	var facts: PackedStringArray = [
		"priority %s, %s, trigger %s%s" % [event.priority, "once" if event.once else "repeat", (event.trigger + " " + event.trigger_arg).strip_edges(), ", act %d" % event.act if event.act != 0 else ""],
	]
	if not model.is_loaded(id):
		facts.append("Not loaded: the game does not play it until its errors are fixed.")
	for message: String in model.errors_of.get(id, []):
		facts.append(message)
	_facts.text = "\n".join(facts)
	_text.text = model.text(id)


func _clear() -> void:
	graph.clear_connections()
	# freed in place, not removed: GraphEdit's deferred reordering of a just-added element (frames
	# behind nodes) would find a removed one not its child. Renamed so the new nodes take the names.
	for child in graph.get_children():
		if child is GraphElement and not child.is_queued_for_deletion():
			child.name = "Old%d" % child.get_instance_id()
			child.queue_free()
	nodes.clear()
	lanes.clear()


func _draw_graph() -> void:
	var rows := StoryLayout.lanes(model.events, model.pools)
	var cells := StoryLayout.positions(model.events, model.pools)
	var columns := 1
	for cell: Vector2i in cells.values():
		columns = maxi(columns, cell.x + 1)
	for i in model.pools.size():  # the frames first: they draw under the nodes
		var pool := model.pools[i]
		var lane: Vector2i = rows[pool]
		var frame := GraphFrame.new()
		frame.name = "Lane%d" % i
		frame.title = _lane_title(pool)
		frame.autoshrink_enabled = false
		frame.draggable = false
		frame.selectable = false
		frame.tint_color_enabled = true
		frame.tint_color = LANE_TINTS[i % LANE_TINTS.size()]
		frame.position_offset = Vector2(-LANE_MARGIN, _lane_top(i, lane) - LANE_GAP + LANE_MARGIN / 2)
		frame.size = Vector2(columns * CELL.x + LANE_MARGIN, lane.y * CELL.y + LANE_GAP - LANE_MARGIN / 2)
		graph.add_child(frame)
		lanes[pool] = frame
	for index in model.events.size():
		var event := model.events[index]
		if not cells.has(event.id):
			continue
		var node := EventNode.new()
		node.name = "Event%d" % index
		graph.add_child(node)
		node.show_event(event, StoryGraph.placeholder_count(event), (model.errors_of.get(event.id, []) as Array).size(), model.is_loaded(event.id))
		var cell: Vector2i = cells[event.id]
		var lane_index := model.pools.find(event.pool)
		var lane: Vector2i = rows[event.pool]
		node.position_offset = Vector2(cell.x * CELL.x, _lane_top(lane_index, lane) + (cell.y - lane.x) * CELL.y)
		nodes[event.id] = node
	for edge: Dictionary in StoryLinks.edges(model.events):
		if nodes.has(edge["from"]) and nodes.has(edge["to"]):
			var port := EventNode.port(edge["kind"])
			graph.connect_node((nodes[edge["from"]] as Node).name, port, (nodes[edge["to"]] as Node).name, port)


## The lane's top in pixels: its first row, below every lane's title above it and its own.
static func _lane_top(index: int, lane: Vector2i) -> float:
	return lane.x * CELL.y + (index + 1) * LANE_GAP


func _lane_title(pool: String) -> String:
	var entry: Variant = catalog.cast.get(pool, {})
	var name := str(entry.get("name", "")) if entry is Dictionary else ""
	name = StoryScript.strip_marker(name)
	return pool if name == "" or name.to_lower() == pool else "%s (%s)" % [pool, name]


func _fill_characters() -> void:
	var kept: String = _character.get_item_metadata(_character.selected) if _character.selected >= 0 else ""
	_character.clear()
	_character.add_item("All characters")
	_character.set_item_metadata(0, "")
	for pool in model.pools:
		_character.add_item(pool)
		_character.set_item_metadata(_character.item_count - 1, pool)
		if pool == kept:
			_character.select(_character.item_count - 1)
	if _character.selected < 0:
		_character.select(0)


func _list_errors() -> void:
	_errors.clear()
	for message in catalog.errors:
		var index := _errors.add_item(message)
		_errors.set_item_metadata(index, model.error_target(message))
		_errors.set_item_custom_fg_color(index, EventNode.ERROR_COLOR)
	_errors.visible = not catalog.errors.is_empty()


func _build_legend() -> void:
	for kind: String in StoryLinks.KINDS:
		_legend.add_child(_swatch(EventNode.PORT_COLORS[kind]))
		_legend.add_child(_legend_label(kind))
	_legend.add_child(VSeparator.new())
	for priority: String in StoryScript.PRIORITIES:
		_legend.add_child(_swatch(EventNode.PRIORITY_COLORS[priority]))
		_legend.add_child(_legend_label(priority))


static func _swatch(color: Color) -> ColorRect:
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return swatch


static func _legend_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _on_filter() -> void:
	apply_filters()


func _on_node_selected(node: Node) -> void:
	var id: Variant = node.get("id")
	if id is String:
		show_event(id)


func _on_error_selected(index: int) -> void:
	var id: String = _errors.get_item_metadata(index)
	if id != "":
		select_event(id)
