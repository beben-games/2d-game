extends SceneTree
## Builds a BMFont (ui_font.png + ui_font.fnt) from the 0x72 dungeon UI sheet's glyph rows.
## Usage: source tools/godot.sh && perl -e 'alarm 120; exec @ARGV' "$GODOT_BIN" --headless --path . -s tools/gen_ui_font.gd </dev/null
## The sheet has three rows of white-on-transparent glyphs (they are invisible on a white
## background): digits at y 302, lowercase on baseline y 328, uppercase on baseline y 352.
## Glyphs are runs of opaque columns inside each band; u and v abut with no blank column, so run
## 20 of the lowercase band is split at the midpoint (u is the first half, v the rest).
## Punctuation is not in the sheet: + - . , : / % ' are drawn here in 1 px.
## Godot imports the .fnt as a FontFile with integer scaling (ui_font.fnt.import), so any font
## size renders at a whole multiple of 16; use multiples of 16 for whole-pixel scaling.

const SHEET := "res://assets/dungeon_ui/dungeonui.png"
const OUT_DIR := "res://assets/dungeon_ui"
## [chars, band top, band bottom (exclusive), baseline y, run indices to split at the midpoint]
const BANDS := [
	["0123456789", 300, 314, 312, []],
	["abcdefghijklmnopqrstuvwxyz", 316, 336, 328, [20]],
	["ABCDEFGHIJKLMNOPQRSTUVWXYZ", 338, 358, 352, []],
]
const LINE_HEIGHT := 16
const BASE := 12  ## baseline from the line top: 10 px caps above it, 3 px descenders below
const SPACE_ADVANCE := 4
## Extra glyphs as rows of strings; '#' is a white pixel. Their bottom row sits on the baseline,
## moved down by EXTRA_DROP or up by EXTRA_LIFT.
const EXTRA := {
	"+": ["..#..", "..#..", "#####", "..#..", "..#.."],
	"-": ["###"],
	".": ["##", "##"],
	",": ["##", "##", ".#", "#."],
	":": ["##", "##", "..", "..", "##", "##"],
	"/": ["....#", "...#.", "..#..", ".#...", "#...."],
	"%": ["##...#", "##..#.", "...#..", "..#...", ".#..##", "#...##"],
	"'": ["#", "#"],
}
const EXTRA_DROP := {",": 2}
const EXTRA_LIFT := {"-": 3, "'": 8}


func _initialize() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	if sheet == null:
		push_error("cannot load " + SHEET)
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var glyphs := []  # [char, src rect, yoffset]
	for band in BANDS:
		var chars: String = band[0]
		var runs := _runs(sheet, band[1], band[2])
		var split := []
		for i in runs.size():
			var r: Rect2i = runs[i]
			if i in band[4]:
				var half: int = r.size.x / 2
				split.append(Rect2i(r.position, Vector2i(half, r.size.y)))
				split.append(Rect2i(Vector2i(r.position.x + half, r.position.y), Vector2i(r.size.x - half, r.size.y)))
			else:
				split.append(r)
		if split.size() != chars.length():
			push_error("band %s: found %d glyph runs, expected %d" % [chars, split.size(), chars.length()])
			quit(1)
			return
		for i in chars.length():
			var rect: Rect2i = _tight(sheet, split[i])
			glyphs.append([chars[i], rect, rect.position.y - (band[3] - BASE)])
	var width := 1
	var height := LINE_HEIGHT + 2
	for g in glyphs:
		width += g[1].size.x + 1
	for ch in EXTRA:
		width += EXTRA[ch][0].length() + 1
	width += 1
	var atlas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var lines := []
	lines.append('info face="0x72 dungeon ui" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0' % LINE_HEIGHT)
	lines.append('common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4' % [LINE_HEIGHT, BASE, width, height])
	lines.append('page id=0 file="ui_font.png"')
	var char_lines := []
	var x := 1
	for g in glyphs:
		var rect: Rect2i = g[1]
		atlas.blit_rect(sheet, rect, Vector2i(x, 1))
		char_lines.append(_char_line(g[0], x, 1, rect.size.x, rect.size.y, g[2]))
		x += rect.size.x + 1
	for ch in EXTRA:
		var rows: Array = EXTRA[ch]
		var w: int = rows[0].length()
		var h: int = rows.size()
		for ry in h:
			for rx in w:
				if rows[ry][rx] == "#":
					atlas.set_pixel(x + rx, 1 + ry, Color.WHITE)
		var bottom: int = BASE + int(EXTRA_DROP.get(ch, 0)) - int(EXTRA_LIFT.get(ch, 0))
		char_lines.append(_char_line(ch, x, 1, w, h, bottom - h))
		x += w + 1
	char_lines.append('char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15' % SPACE_ADVANCE)
	lines.append("chars count=%d" % char_lines.size())
	lines.append_array(char_lines)
	var out_abs := ProjectSettings.globalize_path(OUT_DIR)
	if atlas.save_png(out_abs + "/ui_font.png") != OK:
		push_error("cannot write " + OUT_DIR + "/ui_font.png")
		quit(1)
		return
	var f := FileAccess.open(out_abs + "/ui_font.fnt", FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + OUT_DIR + "/ui_font.fnt")
		quit(1)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("wrote %d glyphs to %s (atlas %dx%d)" % [char_lines.size(), OUT_DIR, width, height])
	quit(0)


func _char_line(ch: String, x: int, y: int, w: int, h: int, yoffset: int) -> String:
	return "char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=%d xadvance=%d page=0 chnl=15" % [ch.unicode_at(0), x, y, w, h, yoffset, w + 1]


## Runs of columns with any opaque pixel inside the band, as rects spanning the band.
func _runs(img: Image, y0: int, y1: int) -> Array:
	var runs := []
	var start := -1
	for x in img.get_width():
		var opaque := false
		for y in range(y0, y1):
			if img.get_pixel(x, y).a > 0.0:
				opaque = true
				break
		if opaque and start < 0:
			start = x
		elif not opaque and start >= 0:
			runs.append(Rect2i(start, y0, x - start, y1 - y0))
			start = -1
	return runs


## Shrinks a rect to its opaque pixels.
func _tight(img: Image, r: Rect2i) -> Rect2i:
	var minx := r.end.x
	var maxx := r.position.x - 1
	var miny := r.end.y
	var maxy := r.position.y - 1
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if img.get_pixel(x, y).a > 0.0:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	return Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
