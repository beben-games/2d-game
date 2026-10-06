class_name EnemyDef
extends Resource
## Data for one enemy type. Behavior lives in enemy.gd; numbers and sprite names live here.

enum Behavior { CHASER, SHOOTER, CHARGER }

@export var id: String = "enemy"
@export var display_name: String = ""  ## the name the UI says (the gate screen's portrait line); never empty
@export var max_hp: float = 3.0
@export var speed: float = 70.0
@export var accel: float = 600.0
@export var contact_damage: int = 1
@export var spawn_delay: float = 0.5  ## seconds of fade-in before it can move or hurt
@export var idle_anim: String = "imp_idle_anim"  ## SpriteAtlas name
@export var run_anim: String = "imp_run_anim"  ## SpriteAtlas name
@export var sprite_offset: Vector2 = Vector2.ZERO  ## shifts the sprite relative to the collision circle
@export var score: int = 10
@export var coins: int = 0  ## paid to the run on a kill, flown to the HUD counter
@export var death_color: Color = Color(1.0, 0.45, 0.35)  ## the death burst (Fx)
@export var behavior: EnemyDef.Behavior = Behavior.CHASER  # qualified: a bare enum annotation breaks external test scripts in 4.7.2
## Shooter only.
@export var preferred_range: float = 130.0  ## fires once the player is this close
@export var too_close_range: float = 80.0  ## backs away inside this
@export var telegraph_time: float = 0.5  ## wind-up before the bolt
@export var recover_time: float = 0.8  ## pause after the bolt
@export var bolt: WeaponDef  ## the bolt's numbers (speed, damage, lifetime)
## Charger only (ChargerBrain): on screen and this close it winds up, then crosses along a line
## fixed at the wind-up's start (charge_speed * charge_time px, unless a wall stops it), skids,
## and stands open from behind.
@export var charge_range: float = 160.0  ## winds up once the player is this close (and it is on screen)
@export var windup_time: float = 0.7  ## the line on the floor, before the run
@export var charge_speed: float = 380.0  ## px/s along the line
@export var charge_time: float = 0.6  ## the run's length in time, unless a wall ends it
@export var skid_time: float = 1.0  ## standing after the run
@export var back_damage_scale: float = 2.0  ## a shot into its back during the skid does this much more
@export var back_arc_degrees: float = 120.0  ## the back's angle, centred behind the charge's direction
## The shield (playtest 1): a front arc that stops player shots below Enemy.SHIELD_PIERCE.
@export var shield: bool = false
@export var shield_arc_degrees: float = 120.0  ## the covered angle, centred on the facing (180, the front half, was the first cut; playtest 1 found it too big)
@export var shield_turn_degrees: float = 60.0  ## per second: how fast the facing follows the enemy's movement (180 the first cut, too few shots per dash; then 90, which playtest 1 found too quick)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name == "":
		errors.append("display_name must be set")
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
	if behavior == Behavior.SHOOTER:
		if bolt == null:
			errors.append("bolt must be set for a shooter")
		else:
			if bolt.damage < 1.0:
				errors.append("bolt.damage must be >= 1")
			for error in bolt.validate():
				errors.append("bolt: " + error)
		if too_close_range >= preferred_range:
			errors.append("too_close_range must be < preferred_range")
		if telegraph_time < 0.0:
			errors.append("telegraph_time must be >= 0")
		if recover_time < 0.0:
			errors.append("recover_time must be >= 0")
	if behavior == Behavior.CHARGER:
		if charge_range <= 0.0:
			errors.append("charge_range must be > 0")
		if windup_time < 0.0:
			errors.append("windup_time must be >= 0")
		if charge_speed <= 0.0:
			errors.append("charge_speed must be > 0")
		if charge_time <= 0.0:
			errors.append("charge_time must be > 0")
		if skid_time < 0.0:
			errors.append("skid_time must be >= 0")
		if back_damage_scale < 1.0:
			errors.append("back_damage_scale must be >= 1")
		if back_arc_degrees < 0.0 or back_arc_degrees > 360.0:
			errors.append("back_arc_degrees must be within 0..360")
	if shield_arc_degrees < 0.0 or shield_arc_degrees > 360.0:
		errors.append("shield_arc_degrees must be within 0..360")
	if shield_turn_degrees < 0.0:
		errors.append("shield_turn_degrees must be >= 0")
	return errors
