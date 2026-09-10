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
