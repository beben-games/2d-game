class_name BossDef
extends Resource
## Numbers for the boss: the body, the timings per stage, the three attacks, the stage-two summon.
## Behaviour lives in boss.gd and boss_brain.gd; a second boss is another .tres.

@export var id: String = "boss"
@export var display_name: String = "Imp Lord"
@export var max_hp: float = 60.0
@export var speed: float = 50.0
@export var accel: float = 400.0
@export var contact_damage: int = 1
@export var score: int = 200
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
## The attacks.
@export var ring_count: int = 12
@export var volley_count: int = 5
@export var volley_spread_degrees: float = 40.0
@export var charge_speed: float = 320.0
@export var charge_time: float = 0.5
@export var bolt: WeaponDef  ## the shaman bolt's numbers
## Stage 2 begins the first time HP falls to this fraction of max, at the next phase edge.
@export var phase2_fraction: float = 0.5
@export var phase2_telegraph_time: float = 0.45
@export var phase2_recover_time: float = 0.5
@export var phase2_ring_count: int = 16
@export var summon_count: int = 2
@export var summon_scene: PackedScene  ## the chaser
## Stun and chill durations are multiplied by this (burn is taken in full).
@export var status_scale: float = 0.5


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
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
	if sprite_scale <= 0.0:
		errors.append("sprite_scale must be > 0")
	for pair: Array in [["approach_time", approach_time], ["telegraph_time", telegraph_time], ["recover_time", recover_time],
			["charge_time", charge_time], ["phase2_telegraph_time", phase2_telegraph_time], ["phase2_recover_time", phase2_recover_time]]:
		if float(pair[1]) < 0.0:
			errors.append("%s must be >= 0" % pair[0])
	if ring_count < 1:
		errors.append("ring_count must be >= 1")
	if phase2_ring_count < 1:
		errors.append("phase2_ring_count must be >= 1")
	if volley_count < 1:
		errors.append("volley_count must be >= 1")
	if charge_speed < 0.0:
		errors.append("charge_speed must be >= 0")
	if phase2_fraction <= 0.0 or phase2_fraction >= 1.0:
		errors.append("phase2_fraction must be in (0, 1)")
	if summon_count < 0:
		errors.append("summon_count must be >= 0")
	if status_scale <= 0.0:
		errors.append("status_scale must be > 0")
	if bolt == null:
		errors.append("bolt must be set")
	else:
		for error in bolt.validate():
			errors.append("bolt: " + error)
	if summon_scene == null:
		errors.append("summon_scene must be set")
	return errors
