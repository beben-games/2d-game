class_name EmperorBox
extends Node2D
## The emperor's box, set into the top wall where the exit door stood: the tileset's closed door
## leaf between its two frame pieces, 32 tall like the wall band so they sit flush in it, and
## never opening. The box until it gets art of its own.

## The box's rect in the arena, set by setup.
var gap: Rect2


## The box's top-left in the arena: the top wall's door gap of a width by height arena.
static func position_of(width: int, height: int) -> Vector2:
	return ArenaGrid.door_gap(width, height, ArenaGrid.Side.TOP).position


## Call from the Room once its size is known (a child's _ready runs before its parent's).
func setup(width: int, height: int) -> void:
	gap = ArenaGrid.door_gap(width, height, ArenaGrid.Side.TOP)
	position = gap.position
	add_child(_sprite("doors_frame_left", Vector2(-ArenaGrid.TILE, 0)))
	add_child(_sprite("doors_frame_right", Vector2(gap.size.x, 0)))
	add_child(_sprite("doors_leaf_closed", Vector2.ZERO))


## The box's middle in world space: where a Cheer's bonus flies from.
func centre() -> Vector2:
	return global_position + gap.size * 0.5


func _sprite(name: String, top_left: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SpriteAtlas.texture(name)
	s.centered = false
	s.position = top_left
	return s
