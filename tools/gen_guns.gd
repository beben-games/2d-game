extends SceneTree
## Downsamples the user's 10x pistol sheet to 1x and cuts the handgun into a 16x16 cell.
## Usage: source tools/godot.sh && perl -e 'alarm 120; exec @ARGV' "$GODOT_BIN" --headless --path . -s tools/gen_guns.gd </dev/null
## The sheet is exactly 10x (every pixel run is a multiple of 10) with twelve guns off any grid;
## pistols.png keeps all twelve at 1x for later slicing, handgun.png is the top-left one.

const SOURCE := "res://assets/guns/pistols_10x.png"
const SCALE := 10
const SHEET_OUT := "res://assets/guns/pistols.png"
const HANDGUN_OUT := "res://assets/guns/handgun.png"
const HANDGUN_BOX := Rect2i(10, 2, 15, 11)  ## the top-left dark pistol at 1x
const CELL := 16


func _initialize() -> void:
	var big := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if big == null:
		push_error("cannot load " + SOURCE)
		quit(1)
		return
	big.convert(Image.FORMAT_RGBA8)
	var small := big.duplicate()
	small.resize(big.get_width() / SCALE, big.get_height() / SCALE, Image.INTERPOLATE_NEAREST)
	if small.save_png(ProjectSettings.globalize_path(SHEET_OUT)) != OK:
		push_error("cannot write " + SHEET_OUT)
		quit(1)
		return
	var cell := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	cell.fill(Color(0, 0, 0, 0))
	var offset := Vector2i((CELL - HANDGUN_BOX.size.x) / 2, (CELL - HANDGUN_BOX.size.y) / 2)
	cell.blit_rect(small, HANDGUN_BOX, offset)
	if cell.save_png(ProjectSettings.globalize_path(HANDGUN_OUT)) != OK:
		push_error("cannot write " + HANDGUN_OUT)
		quit(1)
		return
	print("wrote %s (%dx%d) and %s" % [SHEET_OUT, small.get_width(), small.get_height(), HANDGUN_OUT])
	quit(0)
