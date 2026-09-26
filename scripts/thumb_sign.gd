class_name ThumbSign
extends Node2D
## The emperor's thumb over the box at the verdict. PLACEHOLDER: the tileset has no thumb, so a
## 24x24 Image is drawn in code until M8's art: a fist (a rounded block with four knuckle bumps
## along its top and a cuff line across its wrist) and a thumb (three wide, six tall) standing
## above it for up, the whole sign mirrored top to bottom for down; two skin tones (the thumb's
## far side, the knuckle valleys, and the cuff in the shade) and a one-pixel edge, on a
## nearest-filtered Sprite2D at SCALE (48 px on screen). Hidden until show_thumb(up); hidden
## again at round_started and run_started. A child of the Room, placed over the emperor's box
## by place_over: its top flush with the box's (the arena's top edge, and the screen's), centred
## on the box, so the whole sign is on screen (a sign above the arena's edge would be off it).

const SIZE := 24
const SCALE := 2.0
const FILL := Color("e8b48a")
const SHADE := Color("c9865e")
const EDGE := Color("3b2a22")
## The parts for a thumb up (y down the image); every rect is mirrored for a thumb down. The
## edge pass darkens the silhouette, so the shade lies inside it (a shaded pixel on the rim
## would turn to edge).
const THUMB := Rect2i(6, 3, 3, 6)  ## standing on the fist's top, left of the knuckles
const FIST := Rect2i(5, 9, 16, 12)  ## the block; its bottom corners are rounded off two pixels deep
const KNUCKLES: Array[Rect2i] = [Rect2i(10, 7, 2, 2), Rect2i(13, 7, 2, 2), Rect2i(16, 7, 2, 2), Rect2i(19, 7, 2, 2)]
## The shade: the crease at the thumb's base, the fist's far column, the cuff line across the wrist.
const SHADES: Array[Rect2i] = [Rect2i(6, 9, 3, 1), Rect2i(19, 11, 1, 6), Rect2i(5, 18, 16, 1)]
## Cleared after the fill: the thumb's tip corners, the fist's top-left corner (the last knuckle
## sits on the top-right one), and its bottom corners.
const CLEARED: Array[Vector2i] = [
	Vector2i(6, 3), Vector2i(8, 3), Vector2i(5, 9),
	Vector2i(5, 20), Vector2i(6, 20), Vector2i(5, 19), Vector2i(20, 20), Vector2i(19, 20), Vector2i(20, 19),
]

## The last verdict shown (true is up); meaningful while visible.
var up := true

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	visible = false
	Events.round_started.connect(_on_round_started)
	Events.run_started.connect(_on_run_started)


func _exit_tree() -> void:
	if Events.round_started.is_connected(_on_round_started):
		Events.round_started.disconnect(_on_round_started)
	if Events.run_started.is_connected(_on_run_started):
		Events.run_started.disconnect(_on_run_started)


## Over the box: horizontally on its middle, the sign's top on the box's top edge.
func place_over(box: EmperorBox) -> void:
	position = box.position + Vector2(box.gap.size.x * 0.5, SIZE * SCALE * 0.5)


func show_thumb(new_up: bool) -> void:
	up = new_up
	_sprite.texture = ImageTexture.create_from_image(image(up))
	visible = true


func _on_round_started(_index: int, _total: int) -> void:
	visible = false


func _on_run_started() -> void:
	visible = false


## The SIZE x SIZE sign: the fist, its knuckles, and the thumb filled, the corners cleared,
## the shade laid on, then every filled pixel that borders an empty one (or the edge of the
## image) turned to EDGE. Every part is mirrored top to bottom for a thumb down.
static func image(thumb_up: bool) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var parts: Array[Rect2i] = [FIST, THUMB]
	parts.append_array(KNUCKLES)
	for rect: Rect2i in parts:
		img.fill_rect(rect if thumb_up else _mirrored(rect), FILL)
	for cleared: Vector2i in CLEARED:
		var c := cleared if thumb_up else Vector2i(cleared.x, SIZE - 1 - cleared.y)
		img.set_pixel(c.x, c.y, Color(0, 0, 0, 0))
	for rect: Rect2i in SHADES:
		img.fill_rect(rect if thumb_up else _mirrored(rect), SHADE)
	var filled := img.duplicate() as Image
	for y in SIZE:
		for x in SIZE:
			if filled.get_pixel(x, y).a == 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + step
				var outside := n.x < 0 or n.y < 0 or n.x >= SIZE or n.y >= SIZE
				if outside or filled.get_pixel(n.x, n.y).a == 0.0:
					img.set_pixel(x, y, EDGE)
					break
	return img


## The rect flipped top to bottom within the image.
static func _mirrored(rect: Rect2i) -> Rect2i:
	return Rect2i(rect.position.x, SIZE - rect.end.y, rect.size.x, rect.size.y)
