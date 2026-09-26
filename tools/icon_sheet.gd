extends SceneTree
## Renders every icon in data/icons.json at 6x into reports/icons.png, in the order printed, so
## a wrong cell choice is caught by eye. Usage: as gen_guns.gd, with -s tools/icon_sheet.gd.

const SCALE := 6
const GAP := 12


func _initialize() -> void:
	var names := IconAtlas.entries().keys()
	names.sort()
	var cell := 16 * SCALE + GAP
	var out := Image.create(names.size() * cell, cell, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.15, 0.15, 0.2))
	for i in names.size():
		var texture := IconAtlas.texture(names[i])
		var icon := texture.atlas.get_image().get_region(Rect2i(texture.region))
		icon.convert(Image.FORMAT_RGBA8)
		icon.resize(16 * SCALE, 16 * SCALE, Image.INTERPOLATE_NEAREST)
		out.blend_rect(icon, Rect2i(0, 0, 16 * SCALE, 16 * SCALE), Vector2i(i * cell + GAP / 2, GAP / 2))
		print("%d: %s" % [i, names[i]])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	out.save_png(ProjectSettings.globalize_path("res://reports/icons.png"))
	print("wrote reports/icons.png")
	quit(0)
