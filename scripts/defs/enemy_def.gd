class_name EnemyDef
extends Resource
## Data for one enemy type. Behavior lives in enemy.gd; numbers and sprite names live here.

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


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if max_hp <= 0.0:
		errors.append("max_hp must be > 0")
	if speed < 0.0:
		errors.append("speed must be >= 0")
	if accel <= 0.0:
		errors.append("accel must be > 0")
	if spawn_delay < 0.0:
		errors.append("spawn_delay must be >= 0")
	return errors
