class_name Door
extends Node2D
## A doorway in the top or bottom wall: a wall collider over the gap while closed, and a trigger
## that asks Main for the next room once open. On the top wall the tileset's frame and leaf are
## drawn set into the two-row wall band (the gap cells are unpainted, so the open leaf shows a
## dark passage). The tileset only has front-facing door art, so a bottom door draws nothing: the
## arena paints shaded wall ends around its dark opening. A BOTTOM exit is allowed by the data
## model but unused; it opens by disabling its collider with no visual change.

var side: int = RoomDef.Side.TOP
var is_exit := false
var is_open := false

var _leaf: Sprite2D
var _collider: CollisionShape2D


## Call before adding to the tree. width/height are the room size in tiles.
func setup(door_side: int, width: int, height: int, exit: bool) -> void:
	side = door_side
	is_exit = exit
	var gap := ArenaGrid.door_gap(width, height, side)
	if side == RoomDef.Side.TOP:
		# Frames and leaf are 32 tall, the height of the band, so they sit flush in the wall.
		_leaf = _sprite("doors_leaf_closed", gap.position)
		add_child(_sprite("doors_frame_left", Vector2(gap.position.x - ArenaGrid.TILE, gap.position.y)))
		add_child(_sprite("doors_frame_right", Vector2(gap.end.x, gap.position.y)))
		add_child(_leaf)

	var body := StaticBody2D.new()
	body.collision_layer = 16
	body.collision_mask = 0
	body.add_to_group("walls")
	_collider = _rect_shape(gap)
	body.add_child(_collider)
	add_child(body)

	if is_exit:
		var trigger := Area2D.new()
		trigger.collision_layer = 0
		trigger.collision_mask = 65  # player (1) or dashing player (64)
		trigger.add_child(_rect_shape(gap))
		trigger.body_entered.connect(_on_trigger_entered)
		add_child(trigger)


func open() -> void:
	if is_open:
		return
	is_open = true
	if _leaf != null:
		_leaf.texture = SpriteAtlas.texture("doors_leaf_open")
	_collider.set_deferred("disabled", true)


func _on_trigger_entered(body: Node) -> void:
	if is_open and body is Player:
		# Deferred: body_entered runs inside the physics flush, and the listener frees this room's colliders.
		Events.room_exit_requested.emit.call_deferred()


func _sprite(name: String, top_left: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SpriteAtlas.texture(name)
	s.centered = false
	s.position = top_left
	return s


func _rect_shape(rect: Rect2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.get_center()
	return shape
