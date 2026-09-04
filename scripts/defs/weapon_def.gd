class_name WeaponDef
extends Resource
## Data for one weapon. Upgrades will later mutate a copy of this.

@export var damage: float = 1.0
@export var fire_rate: float = 6.0  ## shots per second
@export var projectile_speed: float = 320.0
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0  ## total arc across all projectiles when count > 1
@export var inaccuracy_degrees: float = 2.0  ## random jitter per shot
@export var lifetime: float = 1.2  ## seconds before a projectile despawns
@export var knockback: float = 120.0  ## applied to the enemy hit
@export var recoil: float = 25.0  ## applied to the shooter
@export var pierce: int = 0  ## extra enemies a projectile passes through


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if damage <= 0.0:
		errors.append("damage must be > 0")
	if fire_rate <= 0.0:
		errors.append("fire_rate must be > 0")
	if projectile_count < 1:
		errors.append("projectile_count must be >= 1")
	if projectile_speed <= 0.0:
		errors.append("projectile_speed must be > 0")
	if lifetime <= 0.0:
		errors.append("lifetime must be > 0")
	return errors


## Angle offsets (radians) for count projectiles fanned evenly across spread_radians.
static func spread_offsets(count: int, spread_radians: float) -> Array[float]:
	var offsets: Array[float] = []
	if count <= 1:
		offsets.append(0.0)
		return offsets
	for i in count:
		offsets.append((float(i) / float(count - 1) - 0.5) * spread_radians)
	return offsets
