extends GdUnitTestSuite
## The icon index covers every card and weapon, and the UI font has the glyphs the cards need.


func test_every_card_and_weapon_icon_is_in_the_atlas() -> void:
	for id in UpgradeCatalog.upgrades():
		var icon: String = UpgradeCatalog.upgrades()[id].icon
		assert_bool(IconAtlas.has(icon)).override_failure_message("upgrade %s icon '%s'" % [id, icon]).is_true()
	for weapon_id: String in ["handgun", "crossbow"]:
		assert_bool(IconAtlas.has(UpgradeCatalog.weapon(weapon_id).icon)).is_true()


func test_icons_are_16_square_and_textured() -> void:
	for name in IconAtlas.entries():
		var region := IconAtlas.region(name)
		assert_vector(region.size).override_failure_message("icon %s" % name).is_equal(Vector2(16, 16))
		assert_object(IconAtlas.texture(name).atlas).is_not_null()


func test_ui_font_has_the_glyphs_cards_use() -> void:
	var font := UiTheme.FONT
	assert_object(font).is_not_null()
	for ch in "Aa0+%/-.,:' ":
		assert_bool(font.has_char(ch.unicode_at(0))).override_failure_message("glyph '%s'" % ch).is_true()
	assert_float(font.get_string_size("Rank 1 of 3", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x).is_greater(0.0)


func test_theme_helpers_build_scaled_controls() -> void:
	var frame: NinePatchRect = auto_free(UiTheme.nine_patch(UiTheme.FRAME, UiTheme.FRAME_MARGIN, Vector2(320, 400), 4.0))
	assert_vector(frame.size).is_equal(Vector2(80, 100))
	assert_vector(frame.scale).is_equal(Vector2(4, 4))
	assert_int(frame.patch_margin_left).is_equal(UiTheme.FRAME_MARGIN)
	var label: Label = auto_free(UiTheme.label("Heavy rounds", 48))
	assert_str(label.text).is_equal("Heavy rounds")
	assert_object(label.get_theme_font("font")).is_same(UiTheme.FONT)
	assert_int(label.get_theme_font_size("font_size")).is_equal(48)


func test_title_uses_the_title_font() -> void:
	var title: Label = auto_free(UiTheme.title("Crossbow"))
	assert_str(title.text).is_equal("Crossbow")
	assert_object(title.get_theme_font("font")).is_same(UiTheme.TITLE_FONT)
	assert_object(UiTheme.TITLE_FONT).is_not_same(UiTheme.FONT)
	assert_int(title.get_theme_font_size("font_size")).is_equal(UiTheme.FONT_TITLE)
	assert_int(UiTheme.FONT_TITLE % 16).is_equal(0)  # a pixel font is crisp only at multiples of its 16 px grid
	assert_int(title.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	var small: Label = auto_free(UiTheme.title("Handgun", UiTheme.FONT_SMALL, UiTheme.PAPER))
	assert_int(small.get_theme_font_size("font_size")).is_equal(UiTheme.FONT_SMALL)
	assert_object(small.get_theme_color("font_color")).is_equal(UiTheme.PAPER)


## The body font prints names, descriptions (the cards) and summaries at every rank (the build
## screen rows); the title font prints names (the cards and the weapon row).
func test_ui_font_has_every_glyph_the_cards_and_weapons_print() -> void:
	var font := UiTheme.FONT
	var title_font := UiTheme.TITLE_FONT
	for id in UpgradeCatalog.upgrades():
		var card: UpgradeDef = UpgradeCatalog.upgrades()[id]
		var texts: Array[String] = [card.name, card.description]
		for rank in range(1, card.max_rank + 1):
			texts.append(card.summary(rank))
		for text: String in texts:
			for ch in text:
				assert_bool(font.has_char(ch.unicode_at(0))).override_failure_message("card %s: glyph '%s' in '%s'" % [id, ch, text]).is_true()
		for ch in card.name:
			assert_bool(title_font.has_char(ch.unicode_at(0))).override_failure_message("card %s: title glyph '%s' in '%s'" % [id, ch, card.name]).is_true()
	for weapon_id: String in ["handgun", "crossbow"]:
		var text := UpgradeCatalog.weapon(weapon_id).display_name
		for ch in text:
			assert_bool(font.has_char(ch.unicode_at(0))).override_failure_message("weapon %s: glyph '%s' in '%s'" % [weapon_id, ch, text]).is_true()
			assert_bool(title_font.has_char(ch.unicode_at(0))).override_failure_message("weapon %s: title glyph '%s' in '%s'" % [weapon_id, ch, text]).is_true()


func test_icon_rect_is_sized_for_a_container() -> void:
	var r: TextureRect = auto_free(IconAtlas.rect("damage", 6.0))
	assert_vector(r.custom_minimum_size).is_equal(Vector2(96, 96))
	assert_int(r.expand_mode).is_equal(TextureRect.EXPAND_IGNORE_SIZE)
	assert_int(r.stretch_mode).is_equal(TextureRect.STRETCH_SCALE)
	assert_object((r.texture as AtlasTexture).region).is_equal(IconAtlas.region("damage"))


func test_button_helper_builds_a_framed_button_with_a_centred_label() -> void:
	var b: Button = auto_free(UiTheme.button("Play", Vector2(320, 88)))
	assert_vector(b.custom_minimum_size).is_equal(Vector2(320, 88))
	assert_bool(b.flat).is_true()
	var patch: NinePatchRect = b.get_child(0)
	assert_object(patch.region_rect).is_equal(UiTheme.BUTTON_RED)
	assert_vector(patch.size * patch.scale).is_equal(Vector2(320, 88))
	var text: Label = b.get_node("Text")
	assert_str(text.text).is_equal("Play")
	assert_int(text.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_CENTER)
	assert_object(text.get_theme_color("font_color")).is_equal(UiTheme.PAPER)


## The user's packs cover every name in the table; a new name without a file fails here.
func test_every_listed_sound_file_exists() -> void:
	assert_array(Audio.missing).override_failure_message("missing sounds: %s (a public clone lacks the restricted packs, see docs/ASSETS.md)" % [Audio.missing]).is_empty()


func test_framed_panel_adds_the_paper_under_the_frame() -> void:
	var host: Control = auto_free(Control.new())
	UiTheme.framed_panel(host, Vector2(320, 400), 4.0)
	assert_int(host.get_child_count()).is_equal(2)
	var paper: NinePatchRect = host.get_node("Paper")
	assert_object(paper.region_rect).is_equal(UiTheme.PANEL)
	assert_vector(paper.position).is_equal(Vector2(12, 12))
	assert_vector(paper.size * paper.scale).is_equal(Vector2(296, 376))
	var frame: NinePatchRect = host.get_node("Frame")
	assert_object(frame.region_rect).is_equal(UiTheme.FRAME)
	assert_vector(frame.size * frame.scale).is_equal(Vector2(320, 400))
	UiTheme.clear_children(host)
	assert_int(host.get_child_count()).is_equal(0)


## A public clone has no Raven or pistol sheet (docs/ASSETS.md): every icon falls back to a 16x16
## placeholder instead of failing to load, and the game still boots.
func test_a_missing_icon_sheet_falls_back_to_a_placeholder() -> void:
	var saved: Dictionary = IconAtlas.sheet_paths.duplicate()
	IconAtlas.sheet_paths["raven"] = "res://assets/nowhere/missing_sheet.png"
	IconAtlas.reset()
	var tex := IconAtlas.texture("damage")
	IconAtlas.sheet_paths = saved
	IconAtlas.reset()
	assert_object(tex.atlas).is_same(IconAtlas.placeholder())
	assert_object(tex.region).is_equal(Rect2(0, 0, 16, 16))
	assert_vector(Vector2(tex.atlas.get_size())).is_equal(Vector2(16, 16))
	assert_object(IconAtlas.texture("damage").atlas).is_not_same(IconAtlas.placeholder())
