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
## The pixel layout is measured, so it holds at any editor scale: StoryLayout's grid cell is the
## widest and the tallest node's combined minimum size plus a gap, a lane's title room is its
## frame's title bar; the gaps and the scene's minimum sizes are multiplied by the editor's scale.
## Built on the first showing (ensure_built: the plugin's _make_visible), never at editor start.
##
## Room for the next tasks: editing (Task 13) adds to the side panel's Event tab and connects the
## graph's requests; What-if (Task 14) is another tab of the side panel and dims by its own reason
## (EventNode.set_dim); the lint's badges (Task 15) are more keys of StoryGraph.badges.

const EventNode := preload("res://addons/story_graph/event_node.gd")
## At scale 1 (EventNode.editor_scale() times these): the room between columns (the edges run
## there), between rows, and around a lane's nodes inside its frame.
const COLUMN_GAP := 72.0
const ROW_GAP := 20.0
const LANE_MARGIN := 16.0
const SWATCH := 14.0
const LANE_TINTS: Array[Color] = [Color(0.3, 0.45, 0.7, 0.10), Color(0.7, 0.55, 0.3, 0.10)]
## The dimming reason of the toolbar's filters and search.
const FILTER := "filter"

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
## A floor under every node's minimum size (none at Vector2.ZERO): a test's way to make the nodes
## big, as a larger editor scale or font does.
var node_floor := Vector2.ZERO
## StoryLayout's grid cell in pixels, as last measured.
var cell := Vector2.ZERO
var built := false
var _building := false

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
	var factor := EventNode.editor_scale()
	for control: Control in [_search, _errors, %Side, _facts]:
		control.custom_minimum_size *= factor
	_build_legend(factor)
	for item: Array in act_items():
		_act.add_item(item[0])
		_act.set_item_metadata(_act.item_count - 1, item[1])
	_reload.pressed.connect(reload)
	_character.item_selected.connect(_on_filter.unbind(1))
	_act.item_selected.connect(_on_filter.unbind(1))
	_search.text_changed.connect(_on_filter.unbind(1))
	graph.node_selected.connect(_on_node_selected)
	graph.node_deselected.connect(_on_node_deselected)
	_errors.item_selected.connect(_on_error_chosen)
	_errors.item_clicked.connect(_on_error_clicked)
	show_event("")


## The act filter's items, [text, act]: every act, each act to StoryScript.ACT_MAX, no act.
static func act_items() -> Array[Array]:
	var items: Array[Array] = [["All acts", StoryGraph.ANY_ACT]]
	for act in range(1, StoryScript.ACT_MAX + 1):
		items.append(["Act %d" % act, act])
	items.append(["No act", 0])
	return items


## Builds the graph once (the tab's first showing).
func ensure_built() -> void:
	if not built:
		reload()


## The story read again from `dir`: a file edited outside shows.
func reload() -> void:
	show_catalog(StoryCatalog.load_dir(dir))


## Draws the catalog: the graph rebuilt, the filters kept, the selected event selected again (the
## side panel cleared when it is gone).
func show_catalog(story: StoryCatalog) -> void:
	built = true
	_building = true
	var keep := selected
	catalog = story
	model = StoryGraph.of(story)
	_clear()
	_fill_characters()
	_draw_graph()
	_list_errors()
	apply_filters()
	if nodes.has(keep):
		graph.set_selected(nodes[keep])
	_building = false
	show_event(keep if nodes.has(keep) else "")


## Dims every node the toolbar's filters and search leave out; returns how many pass.
func apply_filters() -> int:
	var pool: String = _character.get_item_metadata(_character.selected) if _character.selected >= 0 else ""
	var act: int = _act.get_item_metadata(_act.selected) if _act.selected >= 0 else StoryGraph.ANY_ACT
	var shown := 0
	for id: String in nodes:
		var passes := model.shows(id, pool, act, _search.text)
		(nodes[id] as EventNode).set_dim(FILTER, not passes)
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
		selected = ""
		_title.text = "No event selected"
		_facts.text = ""
		_text.text = ""
		return
	_title.text = event.id
	var facts: PackedStringArray = []
	if model.is_parsed(id):
		var trigger := (event.trigger + " " + event.trigger_arg).strip_edges()
		var act := ", act %d" % event.act if event.act != 0 else ""
		facts.append("priority %s, %s, trigger %s%s" % [event.priority, "once" if event.once else "repeat", trigger, act])
	else:
		facts.append("Not parsed: its header is unknown until its errors are fixed.")
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
	var factor := EventNode.editor_scale()
	var depths := StoryLayout.depths(model.events)
	var rows := StoryLayout.lanes(model.events, model.pools, depths)
	var cells := StoryLayout.positions(model.events, model.pools, depths)
	var columns := 1
	for at: Vector2i in cells.values():
		columns = maxi(columns, at.x + 1)
	for i in model.pools.size():  # the frames first: they draw under the nodes
		var frame := GraphFrame.new()
		frame.name = "Lane%d" % i
		frame.title = _lane_title(model.pools[i])
		frame.autoshrink_enabled = false
		frame.draggable = false
		frame.selectable = false
		frame.tint_color_enabled = true
		frame.tint_color = LANE_TINTS[i % LANE_TINTS.size()]
		graph.add_child(frame)
		lanes[model.pools[i]] = frame
	for index in model.events.size():
		var event := model.events[index]
		if not cells.has(event.id):
			continue
		var node := EventNode.new()
		node.name = "Event%d" % index
		graph.add_child(node)
		node.show_event(event, model.badges(event.id))
		node.custom_minimum_size = node.custom_minimum_size.max(node_floor)
		nodes[event.id] = node
	_place(rows, cells, columns, factor)
	for edge: Dictionary in StoryLinks.edges(model.events):
		if nodes.has(edge["from"]) and nodes.has(edge["to"]):
			var port := EventNode.port(edge["kind"])
			graph.connect_node((nodes[edge["from"]] as Node).name, port, (nodes[edge["to"]] as Node).name, port)


## Places the nodes and the frames from measured sizes: a cell is the widest and the tallest node
## plus the gaps; a lane's title room is the tallest frame title bar plus a margin either side.
func _place(rows: Dictionary, cells: Dictionary, columns: int, factor: float) -> void:
	var gap := Vector2(COLUMN_GAP, ROW_GAP) * factor
	var margin := LANE_MARGIN * factor
	var biggest := Vector2.ZERO
	for node: GraphNode in nodes.values():
		biggest = biggest.max(node.get_combined_minimum_size())
	cell = biggest + gap
	var title_room := 0.0
	for frame: GraphFrame in lanes.values():
		var bar := frame.get_theme_stylebox("titlebar")
		var bar_height := frame.get_titlebar_hbox().get_combined_minimum_size().y + (bar.get_minimum_size().y if bar != null else 0.0)
		title_room = maxf(title_room, bar_height)
	var lane_gap := title_room + 2 * margin
	for i in model.pools.size():
		var lane: Vector2i = rows[model.pools[i]]
		var frame: GraphFrame = lanes[model.pools[i]]
		var top := _lane_top(i, lane, lane_gap)
		frame.position_offset = Vector2(-margin, top - lane_gap + margin)
		frame.size = Vector2(columns * cell.x - gap.x + 2 * margin, lane.y * cell.y - gap.y + lane_gap)
	for id: String in nodes:
		var event := model.event(id)
		var lane_index := model.pools.find(event.pool)
		var lane: Vector2i = rows[event.pool]
		var at: Vector2i = cells[id]
		(nodes[id] as GraphNode).position_offset = Vector2(at.x * cell.x, _lane_top(lane_index, lane, lane_gap) + (at.y - lane.x) * cell.y)


## The lane's top in pixels: its first row, below every lane's title room above it and its own.
func _lane_top(index: int, lane: Vector2i, lane_gap: float) -> float:
	return lane.x * cell.y + (index + 1) * lane_gap


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
	for entry: Dictionary in model.errors:
		var index := _errors.add_item(entry["message"])
		_errors.set_item_metadata(index, entry["target"])
		_errors.set_item_custom_fg_color(index, EventNode.ERROR_COLOR)
	_errors.visible = not model.errors.is_empty()


func _build_legend(factor: float) -> void:
	for kind: String in StoryLinks.KINDS:
		_legend.add_child(_swatch(EventNode.PORT_COLORS[kind], factor))
		_legend.add_child(_legend_label(kind))
	_legend.add_child(VSeparator.new())
	for priority: String in StoryScript.PRIORITIES:
		_legend.add_child(_swatch(EventNode.PRIORITY_COLORS[priority], factor))
		_legend.add_child(_legend_label(priority))


static func _swatch(color: Color, factor: float) -> ColorRect:
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(SWATCH, SWATCH) * factor
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return swatch


static func _legend_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _on_filter() -> void:
	apply_filters()


func _on_node_selected(node: Node) -> void:
	if node is EventNode and not _building:
		show_event((node as EventNode).id)


## Nothing selected any more: the side panel clears (a click elsewhere also deselects first and
## then selects, so it only clears while no node is selected).
func _on_node_deselected(_node: Node) -> void:
	if _building:
		return
	for node: GraphNode in nodes.values():
		if node.selected:
			return
	show_event("")


func _on_error_chosen(index: int) -> void:
	var id: String = _errors.get_item_metadata(index)
	if id != "":
		select_event(id)


## A click on an error, the selected one too (item_selected fires only on a change).
func _on_error_clicked(index: int, _at: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		_on_error_chosen(index)
