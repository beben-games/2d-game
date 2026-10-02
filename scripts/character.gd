class_name Character
extends Interactable
## A member of the cast standing in a grounds room (the room def's `people`): the cast's sprite
## playing its idle at the spot, an Interactable of kind "character" whose id is the cast id (E
## on it: Main plays the picker's event for its pool in the text box), and a wordless StoryMark
## over its head while Story.has_new holds for its pool, read again on every story_changed. The
## mark and the key cap share the head: the mark hides while the character has the focus, the
## cap standing there. Solid at the lower body (a StaticBody2D on the walls' layer, BODY_SIZE at
## the frame's bottom centre, as the gladiator's own body circle sits low on its sprite): the
## gladiator, walking or dashing, stops against a character instead of walking through it; it
## stands just below the feet to reach it (stand_position), and the area reaches round the whole
## frame. Built by Grounds, never placed by hand.

## The area reaches this far past the sprite's frame, as a station's does past its art.
const AREA_MARGIN := 6.0
## The mark's tail this far over the head, world pixels.
const MARK_GAP := 2.0
## The solid lower body: this wide (the frame less a little each side) and this tall, its bottom
## the frame's.
const BODY_INSET := 2.0
const BODY_HEIGHT := 10.0
## Where the gladiator stands to talk: this far below the feet (its body circle, radius 6, just
## clear of the solid body, inside the area).
const STAND_BELOW := 7.0

## The sprite's atlas name (the cast's `sprite`).
var sprite_name := ""
var sprite: AnimatedSprite2D
var mark: StoryMark
## The lower body's StaticBody2D on the walls' layer.
var body: StaticBody2D
## Story.has_new for the pool, as last read.
var has_new := false


## The cast member `cast_id` drawn as `sprite_atlas_name` with its feet (the frame's bottom
## centre) at `foot` (world pixels), the node at the frame's top-left on whole pixels; its area
## the frame grown by AREA_MARGIN, the lower body solid, the key cap and the mark over its head.
func setup_character(cast_id: String, foot: Vector2, sprite_atlas_name: String) -> void:
	sprite_name = sprite_atlas_name
	var size := SpriteAtlas.region(sprite_name).size
	setup(cast_id, "character", (foot - Vector2(size.x * 0.5, size.y)).floor(), Rect2(Vector2.ZERO, size).grow(AREA_MARGIN))
	prompt = Vector2(size.x * 0.5, 0.0)
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = SpriteAtlas.frames({"idle": sprite_name})
	sprite.centered = false
	sprite.play("idle")
	add_child(sprite)
	body = StaticBody2D.new()
	body.name = "Body"
	body.collision_layer = Projectile.WALL_MASK  # the walls' layer (5): the player masks it walking and dashing
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(size.x - BODY_INSET * 2.0, BODY_HEIGHT)
	shape.shape = rectangle
	shape.position = Vector2(size.x * 0.5, size.y - BODY_HEIGHT * 0.5)
	body.add_child(shape)
	add_child(body)
	mark = StoryMark.new()
	mark.name = "Mark"
	mark.rest = prompt - Vector2(0.0, MARK_GAP)
	mark.visible = false
	add_child(mark)


## Just below the feet, out of the solid body and in reach.
func stand_position() -> Vector2:
	return to_global(Vector2(area.get_center().x, area.end.y - AREA_MARGIN + STAND_BELOW))


func _ready() -> void:
	super()
	Events.story_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if Events.story_changed.is_connected(refresh):
		Events.story_changed.disconnect(refresh)


## Reads Story.has_new for the pool again and shows the mark to match.
func refresh() -> void:
	has_new = Story.has_new(id)
	_show_mark()


func _focus_set() -> void:
	_show_mark()


func _show_mark() -> void:
	if mark != null:
		mark.visible = has_new and not focused
