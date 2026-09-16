class_name Fx
extends Node2D
## Listens to Events and spawns visual effects. Nothing here affects gameplay. The fade curve and
## ramp are shared with Projectile's status trail through fade_scale() and fade_ramp().

## Particles shrink to nothing over their lifetime instead of popping out.
static var _fade_scale: Curve = _build_fade_scale()


static func fade_scale() -> Curve:
	return _fade_scale


static func fade_ramp() -> Gradient:
	return _fade_ramp


static func _build_fade_scale() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return curve


## Particles fade out over their lifetime. CPUParticles2D multiplies color by color_ramp, so the
## ramp stays white and only the alpha changes; a colored ramp would render the burst color squared.
static var _fade_ramp: Gradient = _build_fade_ramp()


static func _build_fade_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1, 1, 1, 0))
	return ramp


func _ready() -> void:
	Events.shot_fired.connect(_on_shot_fired)
	Events.enemy_hit.connect(_on_enemy_hit)
	Events.enemy_died.connect(_on_enemy_died)
	Events.player_died.connect(_on_player_died)
	Events.player_dashed.connect(_on_player_dashed)
	Events.door_sealed.connect(_on_door_sealed)


func _exit_tree() -> void:
	# Godot drops connections to freed objects, but be explicit so a scene reload never leaves
	# the global bus pointing at a dying node.
	if Events.shot_fired.is_connected(_on_shot_fired):
		Events.shot_fired.disconnect(_on_shot_fired)
	if Events.enemy_hit.is_connected(_on_enemy_hit):
		Events.enemy_hit.disconnect(_on_enemy_hit)
	if Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.disconnect(_on_enemy_died)
	if Events.player_died.is_connected(_on_player_died):
		Events.player_died.disconnect(_on_player_died)
	if Events.player_dashed.is_connected(_on_player_dashed):
		Events.player_dashed.disconnect(_on_player_dashed)
	if Events.door_sealed.is_connected(_on_door_sealed):
		Events.door_sealed.disconnect(_on_door_sealed)


func _on_shot_fired(muzzle_position: Vector2, direction: Vector2, _weapon_id: String) -> void:
	var flash := MuzzleFlash.new()
	add_child(flash)
	flash.global_position = muzzle_position
	flash.rotation = direction.angle()


func _on_enemy_hit(_enemy: Node2D, _damage: float, hit_position: Vector2) -> void:
	_burst(hit_position, 6, Color(1.0, 0.9, 0.5), 70.0, 0.18)


func _on_enemy_died(_enemy: Node2D, death_position: Vector2) -> void:
	_burst(death_position, 18, Color(1.0, 0.45, 0.35), 130.0, 0.4)


func _on_player_died(death_position: Vector2) -> void:
	_burst(death_position, 24, Color(0.6, 0.9, 1.0), 150.0, 0.5)


func _on_player_dashed(at: Vector2, direction: Vector2) -> void:
	# A dust puff at the dash's start point, just behind the body.
	_burst(at - direction * 4.0, 8, Color(0.75, 0.7, 0.65), 45.0, 0.25)


func _on_door_sealed(at: Vector2) -> void:
	# The entry opening bricking up behind the player: a dust puff a little bigger than the dash's.
	_burst(at, 12, Color(0.75, 0.7, 0.65), 50.0, 0.3)


func _burst(at: Vector2, amount: int, color: Color, speed: float, life: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 2.0
	p.damping_max = speed * 3.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.scale_amount_curve = _fade_scale
	p.color_ramp = _fade_ramp
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.emitting = true
