class_name ThumbSign
extends Node2D
## The emperor's thumb over the box at the verdict. PLACEHOLDER: the tileset has no thumb, so a
## 16x16 Image is drawn in code (a 10x8 fist with a 3x6 thumb above it for up or below it for
## down, a fill and a one-pixel edge) on a nearest-filtered Sprite2D at SCALE, until M8's art.
## Hidden until show_thumb(up); hidden again at round_started and run_started. A child of the
## Room, placed over the emperor's box by place_over: its top flush with the box's (the arena's
## top edge, and the screen's), centred on the box, so the whole sign is on screen.

const SIZE := 16
const SCALE := 3.0
const FILL := Color("e8b48a")
const EDGE := Color("3b2a22")
const FIST := Rect2i(3, 8, 10, 8)  ## the fist for a thumb up; mirrored to the top for down
const THUMB := Rect2i(4, 2, 3, 6)  ## above the fist for up; mirrored below it for down

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


## The 16x16 sign: the fist and the thumb filled, then every filled pixel that borders an empty
## one (or the edge of the image) turned to EDGE.
static func image(thumb_up: bool) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for rect: Rect2i in [FIST, THUMB]:
		var r := rect if thumb_up else _mirrored(rect)
		img.fill_rect(r, FILL)
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
