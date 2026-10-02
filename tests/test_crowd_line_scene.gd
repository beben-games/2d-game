extends SceneSuite
## The crowd's line at the pick, on the SHIPPED crowd pool (data/story/crowd.txt): the one suite
## that reads it, by event id and never by sentence, so the writer may change every word. The
## contract is the ids' structure: at Boo and Quiet a judgement of the round's main loss
## (`<band>_<loss>`) or, with nothing lost, the band's plain line (`<band>`); at Cheer and Roar
## the band's praise (`<band>`), whatever was lost. A case may hold variants (`<id>_<n>`). The line
## shows under the heading at the round's first open, is begun once, and stays through a reroll
## and a refund round; with no crowd event the heading is alone.

const SHIPPED := "res://data/story"
const FIXTURE := "res://tests/support/story"

## The meter a round ends at in each band (no clean round: a hit is counted in the round).
const BAND_FAVOUR := {"boo": 10.0, "quiet": 35.0, "cheer": 60.0, "roar": 90.0}

var _started: Array[String] = []


func before_test() -> void:
	super()
	_started = []
	Events.event_started.connect(_on_started)


func after_test() -> void:
	Events.event_started.disconnect(_on_started)
	await super()


func _on_started(id: String) -> void:
	_started.append(id)


## The id pattern the case answers to: the band's judgement of the loss at the two low bands
## (the band's plain line when nothing was lost), the band's praise at the two high ones.
func _expected(band: String, loss: String) -> RegEx:
	var name := band
	if band in ["boo", "quiet"] and loss != FavourRules.LOSS_NONE:
		name = "%s_%s" % [band, loss]
	return RegEx.create_from_string("^crowd\\.%s(_[0-9]+)?$" % name)


## A round ends in `band` with `loss` the largest of its tallies (another source under it, so the
## pick is the largest, not the only), and the picker opens; returns the menu.
func _end_round(main: Main, band: String, loss: String) -> UpgradeMenu:
	var favour := main.favour
	RunState.hits_this_round = 1  # no clean round: the meter stays where it is set
	RunState.favour = BAND_FAVOUR[band]
	favour.round_losses = {}
	if loss != FavourRules.LOSS_NONE:
		for source: String in FavourRules.LOSS_SOURCES:
			favour.round_losses[source] = 20.0 if source == loss else 4.0
	else:
		favour.round_losses = {"slow": FavourRules.LOSS_FLOOR / 2.0}  # under the floor: nothing lost
	assert_str(favour.round_loss()).is_equal(loss)
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	var menu := main.upgrade_menu
	assert_bool(menu.is_open()).is_true()
	return menu


## The case's event: begun once at the open, its id the case's, its first line (as the story
## shows it, the marker stripped) under the heading.
func _assert_line(menu: UpgradeMenu, band: String, loss: String) -> void:
	var what := "%s with %s lost" % [band, loss]
	assert_int(_started.size()).override_failure_message("%s: %s begun" % [what, _started]).is_equal(1)
	var id := _started[0]
	assert_object(_expected(band, loss).search(id)).override_failure_message("%s: %s" % [what, id]).is_not_null()
	var event: StoryEvent = Story.catalog.by_id[id]
	var facts := {"round_band": band, "round_loss": loss}
	var first: Dictionary = Story.lines(event, facts)[0]
	assert_bool(menu.crowd_label.visible).is_true()
	assert_str(menu.crowd_label.text).is_equal(first["text"])
	assert_str(menu.heading_label.text).is_equal(UpgradeMenu.HEADING)


func _case(band: String, loss: String) -> void:
	var main: Main = quiet_main_with_series(tiny_series(2))
	_started = []
	var menu := await _end_round(main, band, loss)
	_assert_line(menu, band, loss)
	menu.close()
	main.queue_free()
	await get_tree().process_frame


func test_a_boo_round_judges_its_main_loss_or_says_its_plain_line() -> void:
	use_story(SHIPPED)
	for loss: String in ["hit", "fled", "slow", "none"]:
		await _case("boo", loss)


func test_a_quiet_round_judges_its_main_loss_or_says_its_plain_line() -> void:
	use_story(SHIPPED)
	for loss: String in ["hit", "fled", "slow", "none"]:
		await _case("quiet", loss)


## Cheer and Roar praise, whatever was lost.
func test_a_cheer_and_a_roar_round_praise_whatever_was_lost() -> void:
	use_story(SHIPPED)
	for band: String in ["cheer", "roar"]:
		for loss: String in ["hit", "none"]:
			await _case(band, loss)


## The tally Favour keeps is what the story reads: a real hit in a Quiet round is its main loss.
func test_a_real_hit_in_the_round_is_its_judgement_at_the_pick() -> void:
	use_story(SHIPPED)
	var main: Main = quiet_main_with_series(tiny_series(2))
	var player := player_of(main)
	RunState.favour = 60.0
	player.hurt(1, player.global_position + Vector2(4, 0))  # 35: Quiet, 25 lost to the hit
	_started = []
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	_assert_line(main.upgrade_menu, "quiet", "hit")


## A reroll keeps the line: the same sentence, no new event begun.
func test_a_reroll_keeps_the_line() -> void:
	use_story(SHIPPED)
	var main: Main = quiet_main_with_series(tiny_series(2))
	RunState.rerolls_left = 1
	_started = []
	var menu := await _end_round(main, "cheer", "none")
	var line := menu.crowd_label.text
	menu.reroll_button.pressed.emit()
	await get_tree().process_frame
	assert_int(RunState.rerolls_left).is_equal(0)
	assert_bool(menu.crowd_label.visible).is_true()
	assert_str(menu.crowd_label.text).is_equal(line)
	assert_int(_started.size()).is_equal(1)


## A refund round's re-open (after a switch with a weapon rank owned) keeps the line too.
func test_a_refund_round_keeps_the_line() -> void:
	use_story(SHIPPED)
	var main: Main = quiet_main_with_series(tiny_series(2))
	RunState.build.add_rank(UpgradeCatalog.upgrade("damage_handgun"))
	Events.build_changed.emit()
	_started = []
	var menu := await _end_round(main, "quiet", "slow")
	var line := menu.crowd_label.text
	menu.chosen.emit(UpgradeCatalog.upgrade("switch_crossbow"), -1)  # one rank owned: one refund round
	await get_tree().process_frame
	assert_bool(menu.is_open()).is_true()
	assert_str(menu.crowd_label.text).is_equal(line)
	assert_int(_started.size()).is_equal(1)


## The next round's pick says its own line: each round's first open begins one event.
func test_the_next_rounds_pick_says_its_own_line() -> void:
	use_story(SHIPPED)
	var main: Main = quiet_main_with_series(tiny_series(3))
	_started = []
	RunState.favour = BAND_FAVOUR["quiet"]
	main.favour.round_losses = {"fled": 10.0}
	await clear_and_pick(main)
	assert_object(_expected("quiet", "fled").search(_started[0])).is_not_null()
	await wait_for_round(main, 1)
	RunState.hits_this_round = 1
	RunState.favour = BAND_FAVOUR["boo"]
	main.favour.round_losses = {"hit": 25.0}
	Events.round_cleared.emit()
	await real_seconds(Main.PICKER_DELAY + 0.1)
	assert_int(_started.size()).is_equal(2)
	assert_object(_expected("boo", "hit").search(_started[1])).is_not_null()


## With no crowd event (the fixture story has no crowd pool) the heading is alone, where it
## always was, and nothing is begun.
func test_no_crowd_event_leaves_the_heading_alone() -> void:
	use_story(FIXTURE)
	var main: Main = quiet_main_with_series(tiny_series(2))
	_started = []
	var menu := await _end_round(main, "boo", "hit")
	assert_bool(menu.crowd_label.visible).is_false()
	assert_float(menu.heading_label.offset_bottom).is_equal(-(UpgradeMenu.CARD_SIZE.y / 2.0 + UpgradeMenu.HEADING_GAP))
	assert_array(_started).is_empty()
