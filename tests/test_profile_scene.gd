extends SceneSuite
## The Profile autoload on the live bus: every stat it fills from the signals, the attacker id
## that player_hit and player_died now carry (from a body's def or a bolt's shooter), and the
## rule that nothing reaches the disk until commit(). SceneSuite points Profile at the scratch
## path before every test and resets it after.

const DAMAGE_HANDGUN := "res://data/upgrades/damage_handgun.tres"
const SWITCH_CROSSBOW := "res://data/upgrades/switch_crossbow.tres"

var _hits: Array[Array] = []
var _deaths: Array[Array] = []


func before_test() -> void:
	super()
	_hits = []
	_deaths = []
	Events.player_hit.connect(_on_player_hit)
	Events.player_died.connect(_on_player_died)


func after_test() -> void:
	Events.player_hit.disconnect(_on_player_hit)
	Events.player_died.disconnect(_on_player_died)
	super()


func _on_player_hit(damage: int, hp: int, max_hp: int, attacker_id: String) -> void:
	_hits.append([damage, hp, max_hp, attacker_id])


func _on_player_died(at: Vector2, attacker_id: String) -> void:
	_deaths.append([at, attacker_id])


func _scratch_exists() -> bool:
	return FileAccess.file_exists(SceneSuite.PROFILE_SCRATCH)


func test_the_profile_starts_from_the_scratch_path_at_defaults() -> void:
	assert_str(Profile.path).is_equal(SceneSuite.PROFILE_SCRATCH)
	assert_bool(_scratch_exists()).is_false()
	assert_int(Profile.save.money).is_equal(0)
	assert_int(Profile.save.stat("dashes")).is_equal(0)


func test_a_shot_fired_counts_under_its_weapon() -> void:
	Events.shot_fired.emit(Vector2(100, 100), Vector2.RIGHT, "handgun")
	Events.shot_fired.emit(Vector2(100, 100), Vector2.RIGHT, "handgun")
	Events.shot_fired.emit(Vector2(100, 100), Vector2.RIGHT, "crossbow")
	assert_int(Profile.save.stat("shots_fired", "handgun")).is_equal(2)
	assert_int(Profile.save.stat("shots_fired", "crossbow")).is_equal(1)


func test_a_kill_counts_under_the_enemy_id_with_its_hit() -> void:
	var main := quiet_main()
	var enemy := active_chaser_on(main, player_of(main).global_position + Vector2(80, 0))
	enemy.health.take_damage(1.0)
	enemy.health.take_damage(100.0)
	assert_int(Profile.save.stat("shots_hit")).is_equal(2)
	assert_int(Profile.save.stat("hits_landed", "chaser")).is_equal(2)
	assert_int(Profile.save.stat("kills", "chaser")).is_equal(1)
	assert_int(Profile.save.stat("kills", "boss")).is_equal(0)
	assert_int(Profile.save.stat("boss_kills")).is_equal(0)


func test_the_boss_death_counts_as_a_boss_kill() -> void:
	var main := quiet_main()
	var boss := active_boss_on(main, player_of(main).global_position + Vector2(150, 0))
	boss.health.take_damage(1000.0)
	assert_int(Profile.save.stat("kills", "boss")).is_equal(1)
	assert_int(Profile.save.stat("boss_kills")).is_equal(1)


func test_a_hit_from_a_chaser_counts_under_chaser_and_player_hit_carries_the_id() -> void:
	var main := quiet_main(3)
	var player := player_of(main)
	active_chaser_on(main, player.global_position + Vector2(4, 0))
	await ticks(10)
	assert_array(_hits).is_equal([[1, Player.MAX_HP - 1, Player.MAX_HP, "chaser"]])
	assert_int(Profile.save.stat("hits_taken", "chaser")).is_equal(1)


func test_a_shooters_bolt_counts_under_shooter() -> void:
	var main := quiet_main(3)
	var player := player_of(main)
	# The bolt leaves about tick 32 (the telegraph) and flies 100 px at 150 px/s: about 40 more.
	active_shooter_on(main, player.global_position + Vector2(100, 0))
	var landed := false
	for i in 120:
		await get_tree().physics_frame
		if player.hp < Player.MAX_HP:
			landed = true
			break
	assert_bool(landed).override_failure_message("the shooter's bolt never landed").is_true()
	assert_array(_hits).is_equal([[1, Player.MAX_HP - 1, Player.MAX_HP, "shooter"]])
	assert_int(Profile.save.stat("hits_taken", "shooter")).is_equal(1)
	assert_int(Profile.save.stat("hits_taken", "chaser")).is_equal(0)


func test_the_boss_bolt_carries_the_boss_id() -> void:
	var main := quiet_main()
	var boss := active_boss_on(main, player_of(main).global_position + Vector2(150, 0))
	boss._fire_bolt(Vector2.RIGHT)
	var bolt: Projectile = projectiles_of(main).get_child(0)
	assert_str(bolt.shooter_id).is_equal("boss")


## A hit with no source (a test's bare hurt, a stub enemy) still counts, under "unknown".
func test_a_hit_or_a_kill_without_an_id_counts_under_unknown() -> void:
	var main := quiet_main()
	player_of(main).hurt(1, Vector2.ZERO)
	assert_array(_hits).is_equal([[1, Player.MAX_HP - 1, Player.MAX_HP, ""]])
	assert_int(Profile.save.stat("hits_taken", Save.UNKNOWN_ID)).is_equal(1)
	Events.enemy_died.emit(auto_free(Node2D.new()), Vector2(200, 200))
	assert_int(Profile.save.stat("kills", Save.UNKNOWN_ID)).is_equal(1)


func test_the_killing_hit_names_its_attacker_on_player_died() -> void:
	var main := quiet_main(3)
	var player := player_of(main)
	player.hp = 1
	active_chaser_on(main, player.global_position + Vector2(4, 0))
	await ticks(5)
	assert_bool(player.dead).is_true()
	assert_int(_deaths.size()).is_equal(1)
	assert_str(_deaths[0][1]).is_equal("chaser")
	assert_str(player.last_attacker_id).is_equal("chaser")


func test_a_card_taken_counts_and_a_switch_counts_twice() -> void:
	var damage: UpgradeDef = load(DAMAGE_HANDGUN)
	var switch_card: UpgradeDef = load(SWITCH_CROSSBOW)
	Events.upgrade_chosen.emit(damage, 1)
	Events.upgrade_chosen.emit(damage, 2)
	Events.upgrade_chosen.emit(switch_card, 0)
	assert_int(Profile.save.stat("cards_taken", "damage_handgun")).is_equal(2)
	assert_int(Profile.save.stat("cards_taken", "switch_crossbow")).is_equal(1)
	assert_int(Profile.save.stat("switches")).is_equal(1)


## The bus alone, no Main: rounds, bands, clean rounds, dashes, daring, the peak, and piles.
func test_rounds_dashes_favour_and_piles_count() -> void:
	Events.round_cleared.emit()
	assert_int(Profile.save.stat("rounds_cleared")).is_equal(1)
	RunState.hits_this_round = 0
	Events.round_ended.emit(FavourRules.ROAR)
	RunState.hits_this_round = 2
	Events.round_ended.emit(FavourRules.BOO)
	assert_int(Profile.save.stat("rounds_by_band", "roar")).is_equal(1)
	assert_int(Profile.save.stat("rounds_by_band", "boo")).is_equal(1)
	assert_int(Profile.save.stat("rounds_by_band", "quiet")).is_equal(0)
	assert_int(Profile.save.stat("clean_rounds")).is_equal(1)
	Events.player_dashed.emit(Vector2(100, 100), Vector2.RIGHT)
	assert_int(Profile.save.stat("dashes")).is_equal(1)
	Events.favour_changed.emit(60.0, FavourRules.CHEER, "daring")
	Events.favour_changed.emit(40.0, FavourRules.QUIET, "hit")
	assert_int(Profile.save.stat("dashes_through_danger")).is_equal(1)
	assert_float(Profile.save.stat("favour_peak")).is_equal(60.0)
	Events.pile_collected.emit(Vector2(100, 100), 8)
	assert_int(Profile.save.stat("piles_collected")).is_equal(1)


func test_time_played_accumulates_only_while_unpaused() -> void:
	var before := float(Profile.save.stat("time_played"))
	await get_tree().process_frame
	await get_tree().process_frame
	var after := float(Profile.save.stat("time_played"))
	assert_float(after).is_greater(before)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(float(Profile.save.stat("time_played"))).is_equal(after)
	get_tree().paused = false


func test_nothing_reaches_the_disk_until_commit() -> void:
	var main := quiet_main()
	var enemy := active_chaser_on(main, player_of(main).global_position + Vector2(80, 0))
	enemy.health.take_damage(100.0)
	Events.player_dashed.emit(Vector2(100, 100), Vector2.RIGHT)
	assert_bool(_scratch_exists()).is_false()
	assert_int(Profile.commit()).is_equal(OK)
	assert_bool(_scratch_exists()).is_true()
	var back := Save.load_from(SceneSuite.PROFILE_SCRATCH)
	assert_int(back.stat("kills", "chaser")).is_equal(1)
	assert_int(back.stat("dashes")).is_equal(1)
	# reset() reloads from the path: the committed file, here; nothing, once after_test removed it.
	Events.player_dashed.emit(Vector2(100, 100), Vector2.RIGHT)
	Profile.reset()
	assert_int(Profile.save.stat("dashes")).is_equal(1)


func test_the_scratch_file_is_gone_and_the_profile_empty_after_a_committing_test() -> void:
	assert_bool(_scratch_exists()).is_false()
	assert_int(Profile.save.stat("kills", "chaser")).is_equal(0)
