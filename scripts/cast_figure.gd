class_name CastFigure
extends Node2D
## A member of the cast drawn in the grounds: the cast's sprite playing its idle, its feet (the
## frame's bottom centre) at the foot point the owner gives, solid at the lower body (a
## StaticBody2D on the walls' layer, the frame's width less BODY_INSET a side and BODY_HEIGHT
## tall at its bottom, as the gladiator's own body circle sits low on its sprite: the gladiator,
## walking or dashing, stops against it), and a wordless StoryMark over its head while
## Story.has_new holds for its pool, read again on every story_changed. Owned by an Interactable
## that is the one thing the key acts on: a Character (the figure is the whole of it) or a kept
## Station (its keeper beside its art). The owner tells it when it is the focus (`focused`); a
## figure whose head carries the key cap (a Character's) hides its mark then, one whose owner's
## cap stands elsewhere (a keeper's: over the station's art) keeps it. Built by its owner, never
## placed by hand.

## The figure's reach (its owner's area round it) goes this far past the sprite's frame, as a
## station's does past its art.
const AREA_MARGIN := 6.0
## The mark's tail this far over the head, world pixels.
const MARK_GAP := 2.0
## The solid lower body: this much narrower than the frame each side, and this tall, its bottom
## the frame's.
const BODY_INSET := 2.0
const BODY_HEIGHT := 10.0
## Where the gladiator stands to talk: this far below the feet (its body circle, radius 6, just
## clear of the solid body, inside the reach).
const STAND_BELOW := 7.0

## The cast id: the pool whose news the mark shows.
var cast_id := ""
## The sprite's atlas name (the cast's `sprite`).
var sprite_name := ""
## The frame's size, world pixels.
var frame_size := Vector2.ZERO
var sprite: AnimatedSprite2D
var mark: StoryMark
## The lower body's StaticBody2D on the walls' layer.
var body: StaticBody2D
## Story.has_new for the pool, as last read.
var has_new := false
## True when the owner's key cap stands over this head: the mark gives way to it under the focus.
var hides_mark_when_focused := true
## True while the owner is the grounds' focus (the owner sets it).
var focused := false:
	set(value):
		focused = value
		_show_mark()


## The cast member `member_id` drawn as `sprite_atlas_name` with its feet at `foot_local` (the
## owner's own pixels); the node at the frame's top-left on whole pixels.
func setup(member_id: String, foot_local: Vector2, sprite_atlas_name: String) -> void:
	cast_id = member_id
	sprite_name = sprite_atlas_name
	name = "Figure"
	frame_size = SpriteAtlas.region(sprite_name).size
	position = (foot_local - Vector2(frame_size.x * 0.5, frame_size.y)).floor()
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
	rectangle.size = Vector2(frame_size.x - BODY_INSET * 2.0, BODY_HEIGHT)
	shape.shape = rectangle
	shape.position = Vector2(frame_size.x * 0.5, frame_size.y - BODY_HEIGHT * 0.5)
	body.add_child(shape)
	add_child(body)
	mark = StoryMark.new()
	mark.name = "Mark"
	mark.rest = head() - Vector2(0.0, MARK_GAP)
	mark.visible = false
	add_child(mark)


## The top centre of the frame, in the figure's own pixels: the head the mark stands over.
func head() -> Vector2:
	return Vector2(frame_size.x * 0.5, 0.0)


## The frame in the owner's pixels.
func frame() -> Rect2:
	return Rect2(position, frame_size)


## The frame grown by AREA_MARGIN, in the owner's pixels: the reach the owner's area takes in.
func reach() -> Rect2:
	return frame().grow(AREA_MARGIN)


## Just below the feet, out of the solid body and in reach, world pixels.
func stand_position() -> Vector2:
	return to_global(Vector2(frame_size.x * 0.5, frame_size.y + STAND_BELOW))


func _ready() -> void:
	Events.story_changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if Events.story_changed.is_connected(refresh):
		Events.story_changed.disconnect(refresh)


## Reads Story.has_new for the pool again and shows the mark to match.
func refresh() -> void:
	has_new = Story.has_new(cast_id)
	_show_mark()


func _show_mark() -> void:
	if mark != null:
		mark.visible = has_new and not (focused and hides_mark_when_focused)
