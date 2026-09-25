class_name IconAtlas
extends RefCounted
## Card and HUD icons by name from data/icons.json (tools/gen_icons.py). An entry names its
## sheet; every icon is a 16x16 cell drawn at 3x on the HUD and 6x on a card.
## The Raven and pistol sheets are not in the public repo (their terms forbid reposting, see
## docs/ASSETS.md): a missing sheet draws every icon on it as a placeholder and prints ICON_MISSING once.

const JSON_PATH := "res://data/icons.json"
const SIZE := 16
const PLACEHOLDER_FILL := Color(0.35, 0.3, 0.4)
const PLACEHOLDER_EDGE := Color(0.85, 0.8, 0.9)

static var sheet_paths := {
	"raven": "res://assets/raven_icons/raven_16.png",
	"guns": "res://assets/guns/handgun.png",
}
static var _sheets: Dictionary = {}
static var _placeholder: ImageTexture
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
	assert(sheet_paths.has(e.sheet), "IconAtlas: '%s' names unknown sheet '%s'" % [name, e.sheet])
	var tex := AtlasTexture.new()
	var sheet := _sheet(e.sheet)
	if sheet:
		tex.atlas = sheet
		tex.region = region(name)
	else:
		tex.atlas = placeholder()
		tex.region = Rect2(0, 0, SIZE, SIZE)
	return tex


## The sheet by id, loaded once; null when its file is not in the project.
static func _sheet(id: String) -> Texture2D:
	if not _sheets.has(id):
		var path: String = sheet_paths[id]
		if ResourceLoader.exists(path):
			_sheets[id] = load(path)
		else:
			print("ICON_MISSING %s %s" % [id, path])
			_sheets[id] = null
	return _sheets[id]


## A framed 16x16 square standing in for an icon whose sheet is missing.
static func placeholder() -> ImageTexture:
	if _placeholder == null:
		var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		img.fill(PLACEHOLDER_EDGE)
		img.fill_rect(Rect2i(2, 2, SIZE - 4, SIZE - 4), PLACEHOLDER_FILL)
		_placeholder = ImageTexture.create_from_image(img)
	return _placeholder


## Forgets the loaded sheets, so a changed sheet_paths takes effect (tests).
static func reset() -> void:
	_sheets.clear()


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
