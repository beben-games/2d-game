class_name UiTheme
extends RefCounted
## The 0x72 dungeon UI sheet (the frame, the beige panel, the red button) and the UI fonts.
## Regions were measured on the sheet (assets/dungeon_ui/README.md). Nine-patches are drawn at
## an integer scale so the pixels stay chunky. Two fonts (assets/fonts): Pixel Operator for body
## text and Alagard, a display face, for titles. Both are TrueType pixel fonts drawn on a 16 px
## grid and imported without antialiasing or hinting, so they render crisp only at multiples of
## 16: keep every size at 32, 48, or 64. Alagard is wide (about 1.2x Pixel Operator), so a card
## title at FONT_TITLE may wrap to two lines instead of dropping to a smaller size.

const SHEET: Texture2D = preload("res://assets/dungeon_ui/dungeonui.png")
const FONT: FontFile = preload("res://assets/fonts/PixelOperator.ttf")
const TITLE_FONT: FontFile = preload("res://assets/fonts/alagard.ttf")
const FRAME := Rect2(16, 40, 40, 24)  ## orange frame with corner nubs
const FRAME_MARGIN := 7
const PANEL := Rect2(80, 104, 24, 24)  ## beige panel
const PANEL_MARGIN := 4
const BUTTON_RED := Rect2(16, 160, 32, 22)
const BUTTON_MARGIN := 6
const INK := Color("3b2a22")  ## text on the beige panel
const PAPER := Color("e8dcc8")  ## text on a dark dim
const FONT_SMALL := 32
const FONT_BODY := 48
const FONT_TITLE := 48


## A nine-patch of `region` drawn at `scale`, covering `size` pixels on screen. The node sets
## `scale`, which containers reset, so it must not be a container child: place it as a free
## background behind one. `size` must be a multiple of `scale` so the patch lands on whole pixels.
static func nine_patch(region: Rect2, margin: int, size: Vector2, scale: float) -> NinePatchRect:
	assert(size == (size / scale).floor() * scale, "UiTheme.nine_patch: size must be a multiple of scale")
	var n := NinePatchRect.new()
	n.texture = SHEET
	n.region_rect = region
	n.patch_margin_left = margin
	n.patch_margin_top = margin
	n.patch_margin_right = margin
	n.patch_margin_bottom = margin
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.size = size / scale
	n.scale = Vector2(scale, scale)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


## A Label on the body font at `size` (a multiple of 16), nearest-filtered, ignoring the mouse.
static func label(text: String, size: int, color: Color = INK) -> Label:
	return _label(FONT, text, size, color)


## A Label on the title font: card names and the build screen's weapon row.
static func title(text: String, size: int = FONT_TITLE, color: Color = INK) -> Label:
	return _label(TITLE_FONT, text, size, color)


static func _label(font: FontFile, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
