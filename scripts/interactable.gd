class_name Interactable
extends Area2D
## Something in the grounds the one key acts on: a station, a door, a character. An area on
## layer 0 masking the player's body walking (1) or dashing (64); the Grounds make the nearest
## enabled one the body overlaps the focus (by the distance to its stand position), the key cap
## stands over its prompt position, and E on it raises Grounds.interacted with it. Nothing opens
## on contact: the area only says the body is in reach. Knows nothing of what it is for; Main
## decides by the kind and the id (a door by the room behind it). Looked up by `id` only, never
## by the node's name: an id may hold a character a name cannot (a door's "door:<room>").

## The group every interactable joins; the Grounds look for theirs among its members.
const GROUP := "interactable"
## The player's body, walking (layer 1) or dashing (layer 64).
const PLAYER_MASK := 65
## What an interactable may be; Main dispatches on the kind: a station by its id, a door by the
## room behind it, a character by its cast id.
const KINDS: Array[String] = ["station", "door", "character"]

var id := ""
## One of KINDS.
var kind := "station"
## The area, local to the node: its centre is where the player stands to be in reach. A kept
## station's Area2D also takes in its keeper's reach (a second shape, add_reach); `area` stays the
## station's own.
var area: Rect2
## The point the key cap stands over, local to the node: the area's top centre unless the
## subclass puts it over its art.
var prompt := Vector2.ZERO
## A disabled interactable is never the focus.
var enabled := true
## True while it is the grounds' focus (Grounds sets it as the focus moves); a subclass hears of
## it through _focus_set (a character hides its mark under the key cap).
var focused := false:
	set(value):
		if focused != value:
			focused = value
			_focus_set()


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_MASK
	add_to_group(GROUP)


## The interactable at `top_left` (world pixels), its area `rect` in its own pixels.
func setup(item_id: String, item_kind: String, top_left: Vector2, rect: Rect2) -> void:
	assert(item_kind in KINDS, "Interactable: unknown kind %s" % item_kind)
	id = item_id
	kind = item_kind
	name = item_id.validate_node_name()  # a ':' or '/' is no name's; the id stays whole
	position = top_left
	area = rect
	prompt = Vector2(rect.get_center().x, rect.position.y)
	add_reach(rect, "Shape")


## A rectangle `rect` (the node's own pixels) the area reaches over, as a shape named
## `shape_name`: the area itself (setup), or a kept station's keeper beside its art.
func add_reach(rect: Rect2, shape_name: String) -> void:
	var shape := CollisionShape2D.new()
	shape.name = shape_name
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.get_center()
	add_child(shape)


## Where the player stands to be in reach, in world pixels: the area's centre.
func stand_position() -> Vector2:
	return to_global(area.get_center())


## Where the key cap stands, in world pixels: over the art.
func prompt_position() -> Vector2:
	return to_global(prompt)


## Called when `focused` changes; nothing by default.
func _focus_set() -> void:
	pass
