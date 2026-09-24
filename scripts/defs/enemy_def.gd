class_name EnemyDef
extends Resource
## Data for one enemy type. Behavior lives in enemy.gd; numbers and sprite names live here.

enum Behavior { CHASER, SHOOTER }

@export var id: String = "enemy"
@export var max_hp: float = 3.0
@export var speed: float = 70.0
@export var accel: float = 600.0
@export var contact_damage: int = 1
@export var spawn_delay: float = 0.5  ## seconds of fade-in before it can move or hurt
@export var idle_anim: String = "imp_idle_anim"  ## SpriteAtlas name
@export var run_anim: String = "imp_run_anim"  ## SpriteAtlas name
@export var sprite_offset: Vector2 = Vector2.ZERO  ## shifts the sprite relative to the collision circle
@export var score: int = 10
@export var death_color: Color = Color(1.0, 0.45, 0.35)  ## the death burst (Fx)
@export var behavior: EnemyDef.Behavior = Behavior.CHASER  # qualified, see RoomDef.exit_side
## Shooter only.
@export var preferred_range: float = 130.0  ## fires once the player is this close
@export var too_close_range: float = 80.0  ## backs away inside this
@export var telegraph_time: float = 0.5  ## wind-up before the bolt
@export var recover_time: float = 0.8  ## pause after the bolt
@export var bolt: WeaponDef  ## the bolt's numbers (speed, damage, lifetime)
## The shield (playtest 1): a front arc that stops player shots below Enemy.SHIELD_PIERCE.
@export var shield: bool = false
@export var shield_arc_degrees: float = 180.0  ## the covered angle, centred on the facing: 180 is the front half
@export var shield_turn_degrees: float = 90.0  ## per second: how fast the facing follows the enemy's movement (180 was the first cut: too few shots per dash)


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
	if shield_arc_degrees < 0.0 or shield_arc_degrees > 360.0:
		errors.append("shield_arc_degrees must be within 0..360")
	if shield_turn_degrees < 0.0:
		errors.append("shield_turn_degrees must be >= 0")
	return errors
