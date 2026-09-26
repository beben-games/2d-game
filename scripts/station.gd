class_name Station
extends Area2D
## One of the grounds' stations: its sprites from the tileset and an area (layer 0, mask 65: the
## player's body walking or dashing) that reports the player stepping on and off it by the
## station's id. Nothing written on it: the object is the explanation, the panel that opens is
## the rest. Built by Grounds._add_station from the grid, never placed by hand.

signal entered(id: String)
signal exited(id: String)

## The player's body, walking (layer 1) or dashing (layer 64).
const PLAYER_MASK := 65

var id := ""
## The area, local to the station: its centre is where the player stands to be on it.
var area: Rect2

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_MASK
	body_entered.connect(func(_body: Node2D) -> void: entered.emit(id))
	body_exited.connect(func(_body: Node2D) -> void: exited.emit(id))


## The station at `top_left` (the grid's pixels): `sprites` is a list of [name, offset] pairs
## drawn with their top-left at the offset; `rect` the area in the station's own pixels.
func setup(station_id: String, top_left: Vector2, sprites: Array, rect: Rect2) -> void:
	id = station_id
	name = station_id
	position = top_left
	area = rect
	for pair: Array in sprites:
		var sprite := Sprite2D.new()
		sprite.name = str(pair[0])
		sprite.texture = SpriteAtlas.texture(str(pair[0]))
		sprite.centered = false
		sprite.position = pair[1]
		add_child(sprite)
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	_shape.shape = rectangle
	_shape.position = rect.get_center()
	add_child(_shape)


## Where the player stands to be on the station, in world pixels: the area's centre.
func stand_position() -> Vector2:
	return to_global(area.get_center())
