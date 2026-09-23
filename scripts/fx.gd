class_name Fx
extends Node2D
## Listens to Events and spawns visual effects. Nothing here affects gameplay. The fade curve and
## ramp are shared with Projectile's status trail through fade_scale() and fade_ramp().

const SMOKE := Color(0.5, 0.5, 0.55, 0.8)
const DUST := Color(0.75, 0.7, 0.65)
const SPARK := Color(1.0, 0.95, 0.6)
const WALL_SPARKS := 4
const BOUNCE_SPARKS := 6
const AFTERIMAGES := 3
const AFTERIMAGE_GAP := 0.05
const AFTERIMAGE_LIFE := 0.2
const AFTERIMAGE_TINT := Color(0.6, 0.9, 1.0, 0.6)
const BOSS_DEATH_STAGE := 0.2  ## seconds between the three death bursts

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
	Events.shot_hit_wall.connect(_on_shot_hit_wall)
	Events.shot_bounced.connect(_on_shot_bounced)
	Events.door_opened.connect(_on_door_opened)
	Events.boss_attacked.connect(_on_boss_attacked)


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
	if Events.shot_hit_wall.is_connected(_on_shot_hit_wall):
		Events.shot_hit_wall.disconnect(_on_shot_hit_wall)
	if Events.shot_bounced.is_connected(_on_shot_bounced):
		Events.shot_bounced.disconnect(_on_shot_bounced)
	if Events.door_opened.is_connected(_on_door_opened):
		Events.door_opened.disconnect(_on_door_opened)
	if Events.boss_attacked.is_connected(_on_boss_attacked):
		Events.boss_attacked.disconnect(_on_boss_attacked)


func _on_shot_fired(muzzle_position: Vector2, direction: Vector2, _weapon_id: String) -> void:
	var flash := MuzzleFlash.new()
	add_child(flash)
	flash.global_position = muzzle_position
	flash.rotation = direction.angle()


func _on_enemy_hit(_enemy: Node2D, _damage: float, hit_position: Vector2) -> void:
	_burst(hit_position, 6, Color(1.0, 0.9, 0.5), 70.0, 0.18)


func _on_enemy_died(enemy: Node2D, death_position: Vector2) -> void:
	var def: Resource = enemy.get("def")
	var color: Color = def.get("death_color") if def != null and def.get("death_color") != null else Color(1.0, 0.45, 0.35)
	_burst(death_position, 18, color, 130.0, 0.4)
	_puff(death_position)
	if enemy.is_in_group("boss"):
		_boss_death(death_position, color)


func _on_player_died(death_position: Vector2) -> void:
	_burst(death_position, 24, Color(0.6, 0.9, 1.0), 150.0, 0.5)


func _on_player_dashed(at: Vector2, direction: Vector2) -> void:
	# A dust puff at the dash's start point, just behind the body.
	_burst(at - direction * 4.0, 8, Color(0.75, 0.7, 0.65), 45.0, 0.25)
	# The player is found as a Node2D and its sprite by name: naming Player here would close a
	# load cycle (player.gd preloads the projectile scene, whose script names Fx).
	_afterimages(get_tree().get_first_node_in_group("player") as Node2D)


## Three ghosts of the player's current frame, AFTERIMAGE_GAP apart, each fading over
## AFTERIMAGE_LIFE. Cosmetic timers, so a kill freeze slows them like everything else.
func _afterimages(player: Node2D) -> void:
	for i in AFTERIMAGES:
		if i > 0:
			await get_tree().create_timer(AFTERIMAGE_GAP).timeout
		if not is_inside_tree() or not is_instance_valid(player):
			return
		var source := player.get_node_or_null("Sprite") as AnimatedSprite2D
		if source == null or source.sprite_frames == null:
			return
		var ghost := Sprite2D.new()
		ghost.texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
		ghost.flip_h = source.flip_h
		ghost.offset = source.offset
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.modulate = AFTERIMAGE_TINT
		add_child(ghost)
		ghost.global_position = player.global_position
		var tween := create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, AFTERIMAGE_LIFE)
		tween.tween_callback(ghost.queue_free)


func _on_door_sealed(at: Vector2) -> void:
	# The entry opening bricking up behind the player: a dust puff a little bigger than the dash's.
	_burst(at, 12, Color(0.75, 0.7, 0.65), 50.0, 0.3)


func _on_boss_attacked(pattern: String, at: Vector2) -> void:
	match pattern:
		"ring":
			_ring_flash(at, 12.0, 8.0, 0.15)
		"charge_wall":
			_burst(at, 12, DUST, 60.0, 0.3)


func _ring_flash(at: Vector2, radius: float, grow: float, duration: float) -> RingFlash:
	var ring := RingFlash.new()
	ring.radius = radius
	ring.grow = grow
	ring.duration = duration
	add_child(ring)
	ring.global_position = at
	return ring


## Three bursts of growing size BOSS_DEATH_STAGE apart under a big ring flash. Real time: the kill
## freeze is 0.12 s and the stages must not stall under it.
func _boss_death(at: Vector2, color: Color) -> void:
	_ring_flash(at, 20.0, 10.0, 0.5)
	for i in 2:
		await get_tree().create_timer(BOSS_DEATH_STAGE, true, false, true).timeout
		if not is_inside_tree():
			return
		_burst(at, 24 + i * 8, color, 140.0 + i * 40.0, 0.5)
		_ring_flash(at, 16.0, 6.0 + i * 2.0, 0.3)


## The exit opening: dust falls from the lintel.
func _on_door_opened(at: Vector2) -> void:
	var p := _burst(at, 10, DUST, 20.0, 0.4)
	p.direction = Vector2.DOWN
	p.spread = 25.0
	p.gravity = Vector2(0, 60)


func _on_shot_hit_wall(at: Vector2) -> void:
	_burst(at, WALL_SPARKS, SPARK, 60.0, 0.15)


func _on_shot_bounced(at: Vector2) -> void:
	_burst(at, BOUNCE_SPARKS, Color(1.0, 1.0, 0.85), 90.0, 0.15)


## A grey puff that rises and fades: the smoke a death leaves.
func _puff(at: Vector2) -> void:
	var p := _burst(at, 8, SMOKE, 25.0, 0.5)
	p.direction = Vector2.UP
	p.spread = 30.0
	p.gravity = Vector2(0, -30)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5


## The burst is emitting when it returns; a caller may still reshape it (the particles are
## generated on the first process tick, after this frame's handlers).
func _burst(at: Vector2, amount: int, color: Color, speed: float, life: float) -> CPUParticles2D:
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
	return p
