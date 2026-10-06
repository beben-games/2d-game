class_name Station
extends Interactable
## One of the grounds' stations: its sprites from the tileset over an Interactable's area.
## Nothing written on it: the object is the explanation, the panel that opens on E is the rest.
## The key cap stands over the top centre of its art. A kept station (the room's `keepers`: the
## post's lanista, the rack's armourer) draws its keeper beside its art as a CastFigure, the mark
## over the keeper's head while the keeper has something new; the station and its keeper are one
## interactable (the area takes in the keeper's reach as a second shape; the stand position stays
## the station's own), and E on it is Main's: the keeper's new word, then the panel. The keeper's
## mark stays up while the station has the focus: the key cap stands over the station's art, not
## the keeper's head, so the two never meet, and the mark then says the next E brings a word
## before the panel. Built by Grounds._add_station from the grid, never placed by hand.

## The art's rect in the station's own pixels (the union of its sprites).
var art := Rect2()
## The keeper's figure, or null for a station nobody keeps.
var keeper: CastFigure


## The station at `top_left` (the grid's pixels): `sprites` is a list of [name, offset] pairs
## drawn with their top-left at the offset; `rect` the area in the station's own pixels.
func setup_station(station_id: String, top_left: Vector2, sprites: Array, rect: Rect2) -> void:
	setup(station_id, "station", top_left, rect)
	art = add_sprites(self, sprites)
	if not sprites.is_empty():
		prompt = Vector2(art.get_center().x, art.position.y)


## The sprites (a list of [name, offset] pairs, each a Sprite2D named for its sprite with its
## top-left at the offset) under `node`, in order; the union of what they draw, in the node's own
## pixels (an empty rect for none). A station's art, and a shut lift bay's (Lift.shut_bay).
static func add_sprites(node: Node2D, sprites: Array) -> Rect2:
	var drawn_all := Rect2()
	for i in sprites.size():
		var pair: Array = sprites[i]
		var sprite := Sprite2D.new()
		sprite.name = str(pair[0])
		sprite.texture = SpriteAtlas.texture(str(pair[0]))
		sprite.centered = false
		sprite.position = pair[1]
		node.add_child(sprite)
		var drawn := Rect2(sprite.position, SpriteAtlas.region(str(pair[0])).size)
		drawn_all = drawn if i == 0 else drawn_all.merge(drawn)
	return drawn_all


## The keeper `cast_id`, drawn as `sprite_atlas_name` with its feet at `foot_local` (the
## station's own pixels); its reach joins the station's area.
func add_keeper(cast_id: String, foot_local: Vector2, sprite_atlas_name: String) -> void:
	keeper = CastFigure.new()
	keeper.setup(cast_id, foot_local, sprite_atlas_name)
	keeper.hides_mark_when_focused = false
	add_child(keeper)
	add_reach(keeper.reach(), "KeeperShape")


## The keeper's cast id, "" for a station nobody keeps.
func keeper_id() -> String:
	return "" if keeper == null else keeper.cast_id


func _focus_set() -> void:
	if keeper != null:
		keeper.focused = focused
