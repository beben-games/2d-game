class_name UiTheme
extends RefCounted
## The 0x72 dungeon UI sheet: the frame, the beige panel, the red button, and its pixel font.
## Regions were measured on the sheet (assets/dungeon_ui/README.md). Nine-patches are drawn at
## an integer scale so the pixels stay chunky; the font's fixed size is 16, so sizes 32, 48, 64
## scale by whole pixels.

const SHEET: Texture2D = preload("res://assets/dungeon_ui/dungeonui.png")
const FONT: FontFile = preload("res://assets/dungeon_ui/ui_font.fnt")
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
const FONT_TITLE := 64


## A nine-patch of `region` drawn at `scale`, covering `size` pixels on screen.
static func nine_patch(region: Rect2, margin: int, size: Vector2, scale: float) -> NinePatchRect:
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


static func label(text: String, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
