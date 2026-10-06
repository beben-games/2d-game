class_name Lift
extends Station
## A lift to the arena, one a tier, standing in a bay of the top wall of the room that holds the
## lifts (GroundsRoomDef.lift_tiers: the Hypogeum's, its bays left to right from
## ArenaGrid.bay_gaps). An open lift is this station: the frame either side of the open leaf, the
## wall's art cut under it (the void shows through, as at a door's gap; the wall's collision kept:
## E takes it, never a walk), its area the floor row under the bay, its id LiftRules.id_for(tier). A
## bay whose tier the save may not fight yet, or which has no series, is no station at all: the
## same frame round the shut leaf, darkened (shut_bay), no area, so no focus, no key cap, and E
## does nothing there. The bay of a tier newly opened is built as this station shut and disabled
## (shut_for_rise) and rises open once when the room is first shown (rise): the darkening lifts and
## the shut leaf draws up out of the bay over LIFT_RISE, with the lift's sound; then it is enabled
## and `risen` goes out. Nothing written on a bay: the rise is the whole announcement. The rules (the ids, which
## bays are open, which rises) are LiftRules'.

## The lift has risen open (once, from shut_for_rise): the shut leaf has drawn up and E takes it.
signal risen(tier: int)

## The open bay's art, as the emperor's box draws its door, the leaf open.
const OPEN_SPRITES: Array[String] = ["doors_frame_left", "doors_frame_right", "doors_leaf_open"]
## The leaf of a shut bay, drawn over the open one while a bay waits to rise.
const SHUT_LEAF := "doors_leaf_closed"
## A shut bay's darkening (frames and leaf alike), lifted as it rises.
const SHUT_MODULATE := Color(0.32, 0.30, 0.36)
## How long a newly opened bay takes to rise open, in seconds (the tree's time: it holds under a
## pause).
const LIFT_RISE := 1.0

## The tier this lift fights.
var tier := 0
## The bay's gap in the top wall, world pixels (the wall's art cut under it once open).
var gap := Rect2()
## True from shut_for_rise until rise() starts.
var waiting := false
## The shut leaf over the open one while the bay waits or rises; null once risen (and for a bay
## that was open when it was built).
var _shut_leaf: Sprite2D


## The [name, offset] pairs of a bay's art at a gap of `gap_size`, local to the gap's top-left:
## the frame a tile either side, the leaf (`leaf`) over the gap.
static func bay_sprites(gap_size: Vector2, leaf: String) -> Array:
	var t := float(ArenaGrid.TILE)
	return [[OPEN_SPRITES[0], Vector2(-t, 0.0)], [OPEN_SPRITES[1], Vector2(gap_size.x, 0.0)], [leaf, Vector2.ZERO]]


## A bay that is shut for good while the save cannot fight its tier (or the tier has no series):
## the frame round the shut leaf, darkened, at the gap. No Interactable: nothing to focus or press.
## Named as its lift would be, so the room finds either by tier.
static func shut_bay(lift_tier: int, bay_gap: Rect2) -> Node2D:
	var bay := Node2D.new()
	bay.name = LiftRules.id_for(lift_tier).validate_node_name()
	bay.position = bay_gap.position
	bay.modulate = SHUT_MODULATE
	Station.add_sprites(bay, bay_sprites(bay_gap.size, SHUT_LEAF))
	return bay


## The open lift of `lift_tier` in the bay at `gap` (world pixels): its area the floor row under
## the bay, grown by `margin`.
func setup_lift(lift_tier: int, bay_gap: Rect2, margin: float) -> void:
	tier = lift_tier
	gap = bay_gap
	var t := float(ArenaGrid.TILE)
	setup_station(LiftRules.id_for(lift_tier), gap.position, bay_sprites(gap.size, OPEN_SPRITES[2]),
		Rect2(0.0, gap.size.y, gap.size.x, t).grow(margin))


## The lift shut, dark, and disabled until rise(): its bay looks as a shut bay does.
func shut_for_rise() -> void:
	waiting = true
	enabled = false
	modulate = SHUT_MODULATE
	var leaf := get_node(OPEN_SPRITES[2]) as Sprite2D
	_shut_leaf = Sprite2D.new()
	_shut_leaf.name = SHUT_LEAF
	_shut_leaf.texture = SpriteAtlas.texture(SHUT_LEAF)
	_shut_leaf.centered = false
	_shut_leaf.position = leaf.position
	_shut_leaf.region_enabled = true
	_shut_leaf.region_rect = Rect2(Vector2.ZERO, SpriteAtlas.region(SHUT_LEAF).size)
	add_child(_shut_leaf)


## The rise, once, for a lift waiting since shut_for_rise: the darkening lifted and the shut leaf
## drawn up into the lintel over LIFT_RISE (its lower edge climbing: the region shrinks from the
## bottom, the open leaf behind it), then the leaf gone, the lift enabled, and `risen`. The sound
## (lift_rising on the bus) goes out at the tween's first step, not here: the tween is the lift's,
## so it holds under a pause (a box event at the arrival, the pause screen) and the cage is never
## heard before it moves. False (nothing done) when it is not waiting.
func rise() -> bool:
	if not waiting:
		return false
	waiting = false
	var full := _shut_leaf.region_rect.size.y
	var tween := create_tween().set_parallel()
	tween.tween_callback(func() -> void: Events.lift_rising.emit(tier))
	tween.tween_property(self, "modulate", Color.WHITE, LIFT_RISE)
	tween.tween_method(func(height: float) -> void:
		_shut_leaf.region_rect.size.y = height, full, 0.0, LIFT_RISE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_on_risen)
	return true


func _on_risen() -> void:
	_shut_leaf.queue_free()
	_shut_leaf = null
	enabled = true
	risen.emit(tier)
