extends GdUnitTestSuite
## StoryPicker: eligibility (trigger and argument, requires and unless across pools, when, a
## played once), the choice among the eligible (priority over file order, unplayed before
## played, rotation by the last play's seq, then file order), the one non-filler talk per return,
## has_new, an `enter` with the right room only, a moment from any pool, and lines(). Pure: a
## Save and a catalog made here.

const CAST := {
	"veteran": {"name": "PLACEHOLDER Veteran"},
	"lanista": {"name": "PLACEHOLDER Lanista"},
	"narrator": {"name": "PLACEHOLDER Narrator", "timed": true},
}
const FLAGS := "met\nmood = calm\n"

var save: Save


func before_test() -> void:
	save = Save.new()


func _catalog(pools: Dictionary) -> StoryCatalog:
	var c := StoryCatalog.from_texts(CAST, FLAGS, pools)
	assert_array(c.errors).is_empty()
	return c


func _context(facts: Dictionary = {}) -> StoryContext:
	return StoryContext.new(save, {"met": false, "mood": "calm"}, facts)


func _pick(c: StoryCatalog, pool: String, trigger := "talk", arg := "", facts: Dictionary = {}) -> String:
	var e := StoryPicker.pick(c, save, _context(facts), pool, trigger, arg)
	return e.id if e != null else ""


func test_the_highest_priority_beats_file_order() -> void:
	var c := _catalog({"veteran": "== plain\n\n== filler\npriority: filler\n\n== urgent\npriority: high\n\n== big\npriority: story\n"})
	assert_str(_pick(c, "veteran")).is_equal("veteran.big")
	save.mark_played("veteran.big")
	assert_str(_pick(c, "veteran")).is_equal("veteran.urgent")
	save.mark_played("veteran.urgent")
	assert_str(_pick(c, "veteran")).is_equal("veteran.plain")
	save.mark_played("veteran.plain")
	assert_str(_pick(c, "veteran")).is_equal("veteran.filler")


func test_within_a_tier_file_order() -> void:
	var c := _catalog({"veteran": "== first\n\n== second\n"})
	assert_str(_pick(c, "veteran")).is_equal("veteran.first")


func test_unplayed_before_played() -> void:
	var c := _catalog({"veteran": "== old\nrepeat\n\n== fresh\nrepeat\n"})
	save.mark_played("veteran.old")
	assert_str(_pick(c, "veteran")).is_equal("veteran.fresh")


func test_two_repeatables_rotate_by_the_last_play() -> void:
	var c := _catalog({"veteran": "== a\nrepeat\npriority: filler\n\n== b\nrepeat\npriority: filler\n"})
	var seen: Array[String] = []
	for i in 4:
		var id := _pick(c, "veteran")
		seen.append(id)
		save.mark_played(id)
	assert_array(seen).is_equal(["veteran.a", "veteran.b", "veteran.a", "veteran.b"])


func test_requires_and_unless_across_pools() -> void:
	var c := _catalog({
		"lanista": "== first\n\n== later\nrequires: veteran.warning\n",
		"veteran": "== warning\nunless: lanista.first\n\n== after\nrequires: lanista.first\npriority: filler\n",
	})
	assert_str(_pick(c, "veteran")).is_equal("veteran.warning")
	save.mark_played("lanista.first")
	assert_str(_pick(c, "veteran")).is_equal("veteran.after")  # the warning is barred, the filler opened
	assert_str(_pick(c, "lanista")).is_equal("")  # later needs the warning, which never played
	save.mark_played("veteran.warning")
	assert_str(_pick(c, "lanista")).is_equal("lanista.later")


func test_a_played_once_is_gone_and_a_repeat_stays() -> void:
	var c := _catalog({"veteran": "== once_only\n\n== again\nrepeat\npriority: filler\n"})
	save.mark_played("veteran.once_only")
	assert_str(_pick(c, "veteran")).is_equal("veteran.again")
	save.mark_played("veteran.again")
	assert_str(_pick(c, "veteran")).is_equal("veteran.again")


func test_when_gates_on_the_context() -> void:
	var c := _catalog({"veteran": "== after_a_death\nwhen: deaths >= 1 and not met\n"})
	assert_str(_pick(c, "veteran")).is_equal("")
	save.flags["deaths"] = 1
	assert_str(_pick(c, "veteran")).is_equal("veteran.after_a_death")
	save.set_story_flag("met", true)
	assert_str(_pick(c, "veteran")).is_equal("")


func test_a_spoken_pool_offers_only_filler() -> void:
	var c := _catalog({"veteran": "== news\n\n== more_news\n\n== bark\npriority: filler\nrepeat\n\n== arrive\ntrigger: enter ludus\n"})
	save.mark_spoken("veteran")
	assert_str(_pick(c, "veteran")).is_equal("veteran.bark")
	assert_str(_pick(c, "veteran", "enter", "ludus")).is_equal("veteran.arrive")  # the rule is for talk only
	save.clear_spoken()
	assert_str(_pick(c, "veteran")).is_equal("veteran.news")


func test_has_new_is_true_until_the_pool_speaks() -> void:
	var c := _catalog({"veteran": "== news\n\n== bark\npriority: filler\nrepeat\n"})
	assert_bool(StoryPicker.has_new(c, save, _context(), "veteran")).is_true()
	save.mark_played("veteran.news")
	save.mark_spoken("veteran")
	assert_bool(StoryPicker.has_new(c, save, _context(), "veteran")).is_false()
	save.clear_spoken()
	assert_bool(StoryPicker.has_new(c, save, _context(), "veteran")).is_false()  # only the bark is left


func test_has_new_ignores_filler_and_other_triggers() -> void:
	var c := _catalog({"veteran": "== bark\npriority: filler\nrepeat\n\n== arrive\ntrigger: enter ludus\n", "lanista": "== news\n"})
	assert_bool(StoryPicker.has_new(c, save, _context(), "veteran")).is_false()
	assert_bool(StoryPicker.has_new(c, save, _context(), "lanista")).is_true()
	save.mark_spoken("lanista")
	assert_bool(StoryPicker.has_new(c, save, _context(), "lanista")).is_false()


func test_enter_plays_in_the_right_room_only() -> void:
	var c := _catalog({"veteran": "== arrive\ntrigger: enter ludus\n\n== talk_one\n"})
	assert_str(_pick(c, "veteran", "enter", "ludus")).is_equal("veteran.arrive")
	assert_str(_pick(c, "veteran", "enter", "hypogeum")).is_equal("")
	assert_str(_pick(c, "veteran", "talk")).is_equal("veteran.talk_one")


func test_an_empty_pool_finds_a_moment_in_any_pool() -> void:
	var c := _catalog({
		"veteran": "== chat\n",
		"narrator": "== wait\ntrigger: verdict_wait\nrepeat\n\n== down\ntrigger: verdict_down\nwhen: last_band == boo\n",
	})
	assert_str(_pick(c, "", "verdict_wait")).is_equal("narrator.wait")
	assert_str(_pick(c, "", "verdict_down")).is_equal("")
	save.log_run({"outcome": "fall", "verdict": "down", "bands": [0]})
	assert_str(_pick(c, "", "verdict_down")).is_equal("narrator.down")
	assert_str(_pick(c, "", "pick")).is_equal("")


func test_lines_drops_a_false_line_substitutes_and_strips_the_marker() -> void:
	var c := _catalog({"veteran": "== e\n\nVETERAN: PLACEHOLDER {wins} nights.\n[last_verdict == down] VETERAN: PLACEHOLDER Carried.\n[last_verdict == none] VETERAN: Fresh.\n? PLACEHOLDER Nod.\n    set: met\n    [met] VETERAN: Again.\n    VETERAN: PLACEHOLDER {mood}.\n"})
	save.flags["wins"] = 4
	var lines := StoryPicker.lines(c.by_id["veteran.e"], _context())
	assert_int(lines.size()).is_equal(3)
	assert_that(lines[0]).is_equal({"kind": "line", "speaker": "veteran", "text": "4 nights."})
	assert_that(lines[1]).is_equal({"kind": "line", "speaker": "veteran", "text": "Fresh."})
	assert_that(lines[2]).is_equal({
		"kind": "choice", "text": "Nod.",
		"effects": [{"verb": "set", "flag": "met", "value": true, "line": 7}],
		"lines": [{"kind": "line", "speaker": "veteran", "text": "calm."}],
	})


func test_eligible_without_the_trigger() -> void:
	var c := _catalog({"veteran": "== needs\nrequires: veteran.first\n\n== first\n"})
	var needs: StoryEvent = c.by_id["veteran.needs"]
	assert_bool(StoryPicker.eligible(needs, save, _context())).is_false()
	save.mark_played("veteran.first")
	assert_bool(StoryPicker.eligible(needs, save, _context())).is_true()


func test_apply_effects_writes_the_story_flags() -> void:
	StoryEvent.apply_effects([{"verb": "set", "flag": "met", "value": true}, {"verb": "set", "flag": "mood", "value": "warm"}], save)
	assert_bool(save.story_flag("met", false)).is_true()
	assert_str(save.story_flag("mood", "calm")).is_equal("warm")
