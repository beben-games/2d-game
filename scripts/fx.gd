extends Node2D
## Listens to Events and spawns visual effects. Nothing here affects gameplay.


func _ready() -> void:
	Events.shot_fired.connect(_on_shot_fired)
	Events.enemy_hit.connect(_on_enemy_hit)
	Events.enemy_died.connect(_on_enemy_died)


func _exit_tree() -> void:
	# Godot drops connections to freed objects, but be explicit so a scene reload never leaves
	# the global bus pointing at a dying node.
	if Events.shot_fired.is_connected(_on_shot_fired):
		Events.shot_fired.disconnect(_on_shot_fired)
	if Events.enemy_hit.is_connected(_on_enemy_hit):
		Events.enemy_hit.disconnect(_on_enemy_hit)
	if Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.disconnect(_on_enemy_died)


func _on_shot_fired(muzzle_position: Vector2, direction: Vector2) -> void:
	var flash := MuzzleFlash.new()
	add_child(flash)
	flash.global_position = muzzle_position
	flash.rotation = direction.angle()


func _on_enemy_hit(_enemy: Node2D, _damage: float, hit_position: Vector2) -> void:
	_burst(hit_position, 6, Color(1.0, 0.9, 0.5), 70.0, 0.18)


func _on_enemy_died(_enemy: Node2D, death_position: Vector2) -> void:
	_burst(death_position, 18, Color(1.0, 0.45, 0.35), 130.0, 0.4)


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
	add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.emitting = true
