class_name StoryMark
extends Node2D
## The mark over a character with something new to say (Story.has_new): a small gold speech
## bubble with three dots, drawn in code on whole world pixels, bobbing a pixel or two. Wordless:
## no letter, no number, no key. Its origin is under the bubble's tail; `rest` puts it over the
## character's head (the Character places it at its prompt position and shows and hides it).
## The bob pauses with the tree (under the box or a menu it holds still).

## The bob: up and back this many world pixels over BOB_PERIOD seconds.
const BOB_HEIGHT := 2.0
const BOB_PERIOD := 1.2
const FILL := Color("f2c14e")
const INK := Color("2b1d16")
## The bubble, local to the origin: 11 x 8 world pixels, its bottom edge 3 over the origin (the
## tail fills the gap).
const BUBBLE := Rect2(-5, -11, 11, 8)

## Where it rests, local to the character: the bob lifts it from here.
var rest := Vector2.ZERO:
	set(value):
		rest = value
		position = value

var _time := 0.0


func _process(delta: float) -> void:
	_time = fmod(_time + delta, BOB_PERIOD)
	position = rest - Vector2(0.0, roundf((0.5 - 0.5 * cos(_time / BOB_PERIOD * TAU)) * BOB_HEIGHT))


func _draw() -> void:
	var b := BUBBLE
	# The outline: four sides, the corners left open so the bubble reads round.
	draw_rect(Rect2(b.position.x + 1, b.position.y, b.size.x - 2, 1), INK)
	draw_rect(Rect2(b.position.x + 1, b.end.y - 1, b.size.x - 2, 1), INK)
	draw_rect(Rect2(b.position.x, b.position.y + 1, 1, b.size.y - 2), INK)
	draw_rect(Rect2(b.end.x - 1, b.position.y + 1, 1, b.size.y - 2), INK)
	draw_rect(b.grow(-1), FILL)
	# The three dots.
	for x: float in [-3.0, 0.0, 3.0]:
		draw_rect(Rect2(x, b.position.y + 3, 1, 2), INK)
	# The tail: a step down and to the left from the bubble's bottom edge.
	draw_rect(Rect2(-1, b.end.y - 1, 2, 1), FILL)
	draw_rect(Rect2(-2, b.end.y - 1, 1, 2), INK)
	draw_rect(Rect2(1, b.end.y - 1, 1, 1), INK)
	draw_rect(Rect2(-1, b.end.y, 2, 1), INK)
	draw_rect(Rect2(-3, b.end.y + 1, 2, 1), INK)
