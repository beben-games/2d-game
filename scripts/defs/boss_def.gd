class_name BossDef
extends Resource
## Numbers for the boss: the body, the timings per stage, the three attacks, the stage-two summon.
## Behaviour lives in boss.gd and boss_brain.gd; a second boss is another .tres. A fight may be
## several bodies (M7): each its own def, the cycles, the chain, the line, the range, the partner's
## enrage, the second stage's charge speed, and the summon at the enrage below; every one of them
## defaults to tier 1's boss as it was.

@export var id: String = "boss"
@export var display_name: String = "Imp Lord"
@export var max_hp: float = 300.0  ## 60 died in two seconds to a seven-upgrade build (playtest 1)
@export var speed: float = 50.0
@export var accel: float = 400.0
@export var contact_damage: int = 1
@export var score: int = 200
@export var coins: int = 0  ## thrown on the floor where it falls, never flown to the counter
@export var spawn_delay: float = 1.2  ## seconds of fade-in before it can move or hurt
@export var idle_anim: String = "big_demon_idle_anim"  ## SpriteAtlas name
@export var run_anim: String = "big_demon_run_anim"
@export var sprite_offset: Vector2 = Vector2(0, -14)  ## seats the feet on the collision circle
@export var sprite_scale: float = 2.0
@export var death_color: Color = Color(0.6, 0.1, 0.1)  ## the death burst (Fx)
## Stage 1 timings.
@export var approach_time: float = 1.0
@export var telegraph_time: float = 0.6
@export var recover_time: float = 0.8
## The speed factor the boss walks at the player with through every recover (both stages): 1.0
## its full speed, as while approaching; 0.0 stands it still there, as before M6's playtest 2.
@export var recover_move: float = 1.0
## The attacks.
@export var ring_count: int = 12
@export var volley_count: int = 5
@export var volley_spread_degrees: float = 40.0
@export var charge_speed: float = 320.0
@export var charge_time: float = 0.5
@export var bolt: WeaponDef  ## the shaman bolt's numbers
## The patterns each stage cycles through, in order, by BossBrain's action names ("ring",
## "volley", "charge", "summon"); stage one's first is the first wound up. Tier 1's: stage one is
## a prefix of stage two, so the flip keeps the cycle's place (BossBrain).
@export var stage1_cycle: Array[String] = ["ring", "volley", "charge"]
@export var stage2_cycle: Array[String] = ["ring", "volley", "charge", "summon"]
## A charge is a chain of this many runs, each with its own wind-up (1: tier 1's single charge).
@export var charge_chain: int = 1
## Draw ChargeLine through each charge's wind-up, the lane fixed at the wind-up's start; off, the
## lane is locked as the run starts and nothing is drawn (tier 1's boss).
@export var charge_line: bool = false
## The distance the body keeps from the player while it moves (backing away inside it, closing
## outside it, as a shooter keeps its range); 0 walks at the player (tier 1's boss).
@export var keep_range: float = 0.0
## Its partner's death (another body of the fight) asks for stage two (Boss.partner_died).
@export var enrage_on_partner: bool = false
## Stage 2 begins the first time HP falls to this fraction of max, at the next phase edge; 0 never
## by health (allowed only with enrage_on_partner: a body with neither has no stage two).
@export var phase2_fraction: float = 0.5
@export var phase2_telegraph_time: float = 0.45
@export var phase2_recover_time: float = 0.5
@export var phase2_ring_count: int = 16
## A charge's speed in stage 2 (BossBrain.charge_speed); 0 keeps charge_speed (tier 1's boss).
@export var phase2_charge_speed: float = 0.0
@export var summon_count: int = 2
@export var summon_scene: PackedScene  ## the chaser; none needed by a def that never summons
## At the enrage (stage 2's arrival), summon once (summon_count of summon_scene, as the "summon"
## pattern does), whatever the cycles hold: the handler's call when the beast falls.
@export var summon_on_enrage: bool = false
## Stun and chill durations are multiplied by this (burn is taken in full).
@export var status_scale: float = 0.5
## Seconds after a stun wears off during which new stuns are ignored, so a fast Shock build cannot
## hold the boss off its attacks (playtest 2); longer than approach plus telegraph, so an attack lands.
@export var stun_immunity: float = 2.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == "":
		errors.append("id must be set")
	if max_hp <= 0.0:
		errors.append("max_hp must be > 0")
	if speed < 0.0:
		errors.append("speed must be >= 0")
	if accel <= 0.0:
		errors.append("accel must be > 0")
	if contact_damage < 0:
		errors.append("contact_damage must be >= 0")
	if spawn_delay < 0.0:
		errors.append("spawn_delay must be >= 0")
	if coins < 0:
		errors.append("coins must be >= 0")
	if sprite_scale <= 0.0:
		errors.append("sprite_scale must be > 0")
	for name: String in ["approach_time", "telegraph_time", "recover_time", "charge_time", "phase2_telegraph_time", "phase2_recover_time"]:
		if float(get(name)) < 0.0:
			errors.append("%s must be >= 0" % name)
	if ring_count < 1:
		errors.append("ring_count must be >= 1")
	if phase2_ring_count < 1:
		errors.append("phase2_ring_count must be >= 1")
	if volley_count < 1:
		errors.append("volley_count must be >= 1")
	if volley_spread_degrees < 0.0:
		errors.append("volley_spread_degrees must be >= 0")
	if charge_speed < 0.0:
		errors.append("charge_speed must be >= 0")
	if phase2_charge_speed < 0.0:
		errors.append("phase2_charge_speed must be >= 0")
	if enrage_on_partner:
		if phase2_fraction < 0.0 or phase2_fraction >= 1.0:
			errors.append("phase2_fraction must be in [0, 1)")
	elif phase2_fraction <= 0.0 or phase2_fraction >= 1.0:
		errors.append("phase2_fraction must be in (0, 1)")
	if summon_count < 0:
		errors.append("summon_count must be >= 0")
	if summon_count > 2:
		errors.append("summon_count must be <= 2")  # the two wall midpoints are the only summon points
	if summon_on_enrage and summon_count < 1:
		errors.append("summon_on_enrage needs summon_count >= 1")
	if status_scale <= 0.0:
		errors.append("status_scale must be > 0")
	if recover_move < 0.0:
		errors.append("recover_move must be >= 0")
	if stun_immunity < 0.0:
		errors.append("stun_immunity must be >= 0")
	for cycle_name: String in ["stage1_cycle", "stage2_cycle"]:
		var cycle: Array[String] = get(cycle_name)
		if cycle.is_empty():
			errors.append("%s must not be empty" % cycle_name)
		for pattern in cycle:
			if not BossBrain.ACTIONS.values().has(pattern):
				errors.append("%s: no pattern '%s'" % [cycle_name, pattern])
	if charge_chain < 1:
		errors.append("charge_chain must be >= 1")
	if keep_range < 0.0:
		errors.append("keep_range must be >= 0")
	if bolt == null:
		errors.append("bolt must be set")
	else:
		if bolt.damage < 1.0:
			errors.append("bolt.damage must be >= 1")  # Player.hurt truncates the damage to an int
		for error in bolt.validate():
			errors.append("bolt: " + error)
	if summon_scene == null and (summon_count != 0 or summon_on_enrage):
		errors.append("summon_scene must be set")
	return errors
