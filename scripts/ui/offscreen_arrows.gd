class_name OffscreenArrows
extends Control
## The arrows at the screen's edge (the M7 design's "Off-screen arrows"): one for each living
## enemy (the group `enemies`; a corpse leaves it at once) that is not View.on_screen, on the line
## from the player to it, ARROW_INSET inside the screen. Code-drawn, no text: a triangle, larger
## for the boss, with a small flag for a standard-bearer. An enemy is on the screen (and may
## attack: rule 2) or has an arrow, never neither; tier 1 never shows one (its walls are on the
## screen wherever the camera sits).
## - The world is mapped onto the screen through View.bare_rect: unshaken (the arrows hold still
##   under a shake) and held through the verdict's drift (no run is live by then anyway).
## - An enemy fading in off screen has its arrow at once: it exists, though it may not attack yet.
## - Hidden under a pause and while no run is live (after a fall or a win, and in the grounds,
##   until the next run or round starts: Favour's own list). Read again every frame (_process,
##   running under a pause so that the arrows go when it begins); redrawn only when they change.
## Full-rect, the HUD's last child (drawn over its parts), and ignores the mouse.

## How far inside the screen's edge an arrow's centre sits, screen px (the HUD's 1280x720).
const ARROW_INSET := 28.0
## Past the screen's edge (and View.SIGHT_SLACK) an arrow fades in over this far, world px: an
## enemy leaving the screen brings its arrow up as it goes, one entering takes it down.
const ARROW_FADE := 32.0
## The least distance between two arrows along the edge, screen px; closer ones are nudged apart.
const ARROW_GAP := 30.0
## The arrowhead's length (tip to base) by kind, screen px; its base is BASE_RATIO of it, and the
## base is notched NOTCH_RATIO of the length toward the tip (a dart: a plain triangle near
## equilateral read as a heap, not a heading, in the first capture).
const ARROW_SIZE := {"enemy": 24.0, "banner": 24.0, "boss": 36.0}
const BASE_RATIO := 0.75
const NOTCH_RATIO := 0.3
const OUTLINE := 3.0
const FILL := {"enemy": UiTheme.PAPER, "banner": UiTheme.PAPER, "boss": Hud.BOSS_BAR_FILL}
const EDGE := UiTheme.INK
## The standard-bearer's arrow: a shaft FLAG_POLE long behind the head, inward, and a small red
## banner flying upright off its end, screen px.
const FLAG_POLE := 18.0
const FLAG_SIZE := Vector2(12, 9)
const FLAG_FILL := Hud.BOSS_BAR_FILL

## The HUD's boss bar: while it is up the arrows' top edge sits ARROW_INSET under it.
var boss_bar: Control
## The arrows as last read: {"at", "angle", "kind", "alpha", "size"}, screen px and radians.
var _arrows: Array[Dictionary] = []
var _live := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	for pair: Array in _bus():
		(pair[0] as Signal).connect(pair[1])


func _exit_tree() -> void:
	for pair: Array in _bus():
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])


func _bus() -> Array:
	return [
		[Events.run_started, _set_live.bind(true)], [Events.round_started, _on_round_started],
		[Events.player_fell, _on_player_fell], [Events.run_won, _set_live.bind(false)],
		[Events.run_ended, _on_run_ended], [Events.grounds_entered, _set_live.bind(false)],
	]


func _set_live(live: bool) -> void:
	_live = live


func _on_round_started(_index: int, _total: int) -> void:
	_live = true


func _on_player_fell(_at: Vector2, _attacker_id: String) -> void:
	_live = false


func _on_run_ended(_outcome: String) -> void:
	_live = false


func _process(_delta: float) -> void:
	refresh()


## Reads the arrows again and redraws if they changed. Every frame; a test calls it to read now.
func refresh() -> void:
	var shown := _live and not get_tree().paused
	visible = shown
	var arrows: Array[Dictionary] = []
	if shown:
		arrows = _read()
	if arrows != _arrows:
		_arrows = arrows
		queue_redraw()


func arrow_count() -> int:
	return _arrows.size()


## The `i`th arrow as last read: {"at", "angle", "kind", "alpha", "size"}.
func arrow_at(i: int) -> Dictionary:
	return _arrows[i]


## The length of a kind's arrow, screen px (an unknown kind is an enemy's).
static func size_of(kind: String) -> float:
	return ARROW_SIZE.get(kind, ARROW_SIZE["enemy"])


func _read() -> Array[Dictionary]:
	var arrows: Array[Dictionary] = []
	var world := View.bare_rect(self)
	if not world.has_area():
		return arrows
	var screen := get_viewport().get_visible_rect()
	var scale := screen.size / world.size
	var sight := world.grow(View.SIGHT_SLACK)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var from := screen.get_center()
	if player != null:
		from = screen.position + (player.global_position - world.position) * scale
	var edge := screen
	if boss_bar != null and boss_bar.is_visible_in_tree():
		var below := boss_bar.get_global_rect().end.y - screen.position.y
		edge = Rect2(screen.position.x, screen.position.y + below, screen.size.x, screen.size.y - below)
	var points: Array[Vector2] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null or not enemy.is_inside_tree() or enemy.is_queued_for_deletion():
			continue
		if View.on_screen(enemy):
			continue
		var kind := str(enemy.call("arrow_kind")) if enemy.has_method("arrow_kind") else "enemy"
		var to := screen.position + (enemy.global_position - world.position) * scale
		var placed := ArrowRules.place(edge, from, to, ARROW_INSET)
		points.append(placed.at)
		arrows.append({"at": placed.at, "angle": placed.angle, "kind": kind,
			"alpha": ArrowRules.alpha(sight, enemy.global_position, ARROW_FADE), "size": size_of(kind)})
	if arrows.size() > 1:
		var spread := ArrowRules.spread(edge.grow(-ARROW_INSET), points, ARROW_GAP)
		for i in arrows.size():
			arrows[i].at = spread[i]
	return arrows


func _draw() -> void:
	for arrow in _arrows:
		_draw_arrow(arrow)


func _draw_arrow(arrow: Dictionary) -> void:
	var kind: String = arrow.kind
	var at: Vector2 = arrow.at
	var length: float = arrow.size
	var heading := Vector2.from_angle(arrow.angle)
	var across := heading.orthogonal() * length * BASE_RATIO * 0.5
	var tip := at + heading * length * 0.5
	var back := at - heading * length * 0.5
	var notch := back + heading * length * NOTCH_RATIO
	var points := PackedVector2Array([tip, back + across, notch, back - across])
	var alpha: float = arrow.alpha
	if kind == "banner":
		# The shaft runs back from the notch, inward (the arrow points out, at the enemy), and the
		# flag flies upright off its end, clear of the head.
		var tail := notch - heading * FLAG_POLE
		draw_line(notch, tail, Color(EDGE, alpha), OUTLINE)
		var flag := Rect2(tail - Vector2(0.0, FLAG_SIZE.y), FLAG_SIZE)
		draw_rect(flag, Color(FLAG_FILL, alpha))
		draw_rect(flag, Color(EDGE, alpha), false, OUTLINE * 0.5)
	var fill: Color = FILL.get(kind, FILL["enemy"])
	draw_colored_polygon(points, Color(fill, alpha))
	var ring := points.duplicate()
	ring.append(points[0])
	draw_polyline(ring, Color(EDGE, alpha), OUTLINE)
