class_name IconAtlas
extends RefCounted
## Card and HUD icons by name from data/icons.json (tools/gen_icons.py). An entry names its
## sheet; every icon is a 16x16 cell drawn at 3x on the HUD and 6x on a card.

const JSON_PATH := "res://data/icons.json"
const SHEETS := {
	"raven": preload("res://assets/raven_icons/raven_16.png"),
	"guns": preload("res://assets/guns/handgun.png"),
}
const SIZE := 16

static var _entries: Dictionary = {}
static var _loaded := false


static func entries() -> Dictionary:
	if not _loaded:
		var text := FileAccess.get_file_as_string(JSON_PATH)
		assert(text != "", "IconAtlas: cannot read " + JSON_PATH + " (run tools/gen_icons.py)")
		_entries = JSON.parse_string(text)
		_loaded = true
	return _entries


static func has(name: String) -> bool:
	return entries().has(name)


static func entry(name: String) -> Dictionary:
	assert(has(name), "IconAtlas: no icon named '" + name + "'")
	return entries()[name]


static func region(name: String) -> Rect2:
	var e := entry(name)
	return Rect2(e.x, e.y, e.w, e.h)


static func texture(name: String) -> AtlasTexture:
	var e := entry(name)
	assert(SHEETS.has(e.sheet), "IconAtlas: '%s' names unknown sheet '%s'" % [name, e.sheet])
	var tex := AtlasTexture.new()
	tex.atlas = SHEETS[e.sheet]
	tex.region = region(name)
	return tex


## A TextureRect showing the icon at scale, sized for a container (containers reset child scale,
## so the size comes from the min size and STRETCH_SCALE).
static func rect(name: String, scale: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture(name)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(SIZE, SIZE) * scale
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
