class_name Character
extends Interactable
## A member of the cast standing in a grounds room (the room def's `people`): one CastFigure (the
## cast's sprite playing its idle, solid at the lower body, the wordless mark over its head while
## Story.has_new holds for its pool) inside an Interactable of kind "character" whose id is the
## cast id (E on it: Main plays the picker's event for its pool in the text box). The mark and the
## key cap share the head: the mark hides while the character has the focus, the cap standing
## there. The gladiator stands just below the feet to reach it (stand_position); the area reaches
## round the whole frame. Built by Grounds, never placed by hand.

var figure: CastFigure


## The cast member `cast_id` drawn as `sprite_atlas_name` with its feet (the frame's bottom
## centre) at `foot` (world pixels), the node at the frame's top-left on whole pixels; its area
## the frame grown by CastFigure.AREA_MARGIN, the key cap and the mark over its head.
func setup_character(cast_id: String, foot: Vector2, sprite_atlas_name: String) -> void:
	var size := SpriteAtlas.region(sprite_atlas_name).size
	figure = CastFigure.new()
	figure.setup(cast_id, Vector2(size.x * 0.5, size.y), sprite_atlas_name)  # the frame at the node's origin
	setup(cast_id, "character", (foot - Vector2(size.x * 0.5, size.y)).floor(), figure.reach())
	add_child(figure)
	prompt = figure.position + figure.head()


## Just below the feet, out of the solid body and in reach.
func stand_position() -> Vector2:
	return figure.stand_position()


func _focus_set() -> void:
	figure.focused = focused
