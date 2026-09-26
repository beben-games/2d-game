class_name ThumbSign
extends Node2D
## The emperor's thumb over the box at the verdict: the Raven sheet's drawn hands (IconAtlas
## thumb_up and thumb_down; the placeholder square when the sheet is missing, as for every
## icon) on a nearest-filtered Sprite2D at SCALE (48 px on screen), until M8's art. Hidden
## until show_thumb(up); hidden again at round_started and run_started. A child of the Room,
## placed over the emperor's box by place_over: its top flush with the box's (the arena's top
## edge, and the screen's), centred on the box, so the whole sign is on screen (a sign above the
## arena's edge would be off it).

const SIZE := IconAtlas.SIZE
const SCALE := 3.0
const ICONS := {true: "thumb_up", false: "thumb_down"}

## The last verdict shown (true is up); meaningful while visible.
var up := true

var sprite: Sprite2D


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
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
	sprite.texture = IconAtlas.texture(ICONS[up])
	visible = true


func _on_round_started(_index: int, _total: int) -> void:
	visible = false


func _on_run_started() -> void:
	visible = false
