class_name Boss
extends CharacterBody2D
## Room 8's boss: a big demon with the shooter's parts (Health, StatusEffects, the flash shader,
## the shaman bolt) and its own pure BossBrain. Emits enemy_hit and enemy_died like any enemy so
## kills, the effects, and the wave runner keep working; boss_spawned, boss_phase_changed, and
## boss_attacked carry the moments only a boss has. States as Enemy's: SPAWNING (fade in,
## harmless) -> ACTIVE (the brain's cycle) -> DEAD (the corpse stays). The stage-two summons
## carry the `summoned` group the wave runner ignores.

enum State { SPAWNING, ACTIVE, DEAD }

const FLASH_SHADER := preload("res://assets/shaders/flash.gdshader")
const ENEMY_BOLT := preload("res://scenes/enemies/enemy_bolt.tscn")
const KNOCKBACK_DECAY := 700.0
const KNOCKBACK_SCALE := 0.25  ## a boss barely budges under a hit
const HIT_TRAUMA := 0.15
const DEATH_TRAUMA := 0.8
const DEATH_HITSTOP := 0.12
const SPAWN_TRAUMA := 0.4
const PHASE_TRAUMA := 0.5
const WALL_TRAUMA := 0.3
const TELEGRAPH_FLASH := 0.6
const BOLT_MUZZLE := 24.0
const ENRAGED_TINT := Color(1.3, 0.9, 0.9)
const CORPSE_TINT := Color(0.45, 0.45, 0.45)
const CORPSE_FLASH_HOLD := 0.3  ## the white pose after the kill freeze, before the corpse dims
const CHARGE_DUST_AMOUNT := 16

@export var def: BossDef

var target: Node2D
## Where bolts go. The Spawner injects the room's container; a hand-placed boss falls back to the
## group lookup.
var projectile_parent: Node
var state := State.SPAWNING
var brain := BossBrain.new()
var move_vel := Vector2.ZERO
var knockback := Vector2.ZERO
var charge_dir := Vector2.RIGHT  ## locked when the charge starts
var flash_material: ShaderMaterial

var _state_time := 0.0
var _charge_dust: CPUParticles2D  ## the trail at the feet while charging
var _fade_tween: Tween
var _flash_tween: Tween
var _pulse_tween: Tween

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health: Health = $Health
@onready var status: StatusEffects = $Status


func _ready() -> void:
	assert(def != null, "Boss needs a BossDef")
	var errors := def.validate()
	assert(errors.is_empty(), "Invalid boss def: %s" % ", ".join(errors))
	health.setup(def.max_hp)
	status.duration_scale = def.status_scale
	sprite.sprite_frames = SpriteAtlas.frames({"idle": def.idle_anim, "run": def.run_anim})
	sprite.offset = def.sprite_offset
	sprite.scale = Vector2(def.sprite_scale, def.sprite_scale)
	sprite.play("idle")
	flash_material = ShaderMaterial.new()
	flash_material.shader = FLASH_SHADER
	flash_material.set_shader_parameter("flash", 0.0)  # a tween needs the uniform to exist already
	sprite.material = flash_material
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if target == null:
		target = get_tree().get_first_node_in_group("player")
	if projectile_parent == null:
		projectile_parent = get_tree().get_first_node_in_group("projectiles")
	if projectile_parent == null:
		projectile_parent = get_parent()
	_charge_dust = CPUParticles2D.new()
	_charge_dust.name = "ChargeDust"
	_charge_dust.emitting = false
	_charge_dust.local_coords = false
	_charge_dust.amount = CHARGE_DUST_AMOUNT
	_charge_dust.lifetime = 0.3
	_charge_dust.spread = 180.0
	_charge_dust.initial_velocity_min = 10.0
	_charge_dust.initial_velocity_max = 30.0
	_charge_dust.scale_amount_min = 2.0
	_charge_dust.scale_amount_max = 3.0
	_charge_dust.color = Color(0.75, 0.7, 0.65)
	_charge_dust.scale_amount_curve = Fx.fade_scale()
	_charge_dust.color_ramp = Fx.fade_ramp()
	_charge_dust.position = Vector2(0, 16)  # at the feet
	add_child(_charge_dust)
	sprite.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(sprite, "modulate:a", 1.0, def.spawn_delay)
	Juice.add_trauma(SPAWN_TRAUMA)


func is_harmful() -> bool:
	return state == State.ACTIVE


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_time += delta
	match state:
		State.SPAWNING:
			if _state_time >= def.spawn_delay:
				_enter(State.ACTIVE)
				Events.boss_spawned.emit(self)
		State.ACTIVE:
			_act(delta)
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	velocity = move_vel + knockback
	move_and_slide()
	if brain.charging() and _hit_wall():
		_end_charge_on_wall()


## Only a wall ends a charge. Floating motion mode reports every collision as a wall, so the slide
## collisions are filtered to StaticBody2D colliders (the arena's walls and the door's bodies;
## every other body is a CharacterBody2D). The player's body does not end a charge: contact damage
## lands through the player's own hurtbox regardless, and the boss recovers and approaches like a
## chaser instead of sticking to the player. Task 7's summons are bodies too and never end it.
func _hit_wall() -> bool:
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is StaticBody2D:
			return true
	return false


## One ACTIVE tick: the brain runs unless a stun holds it (a charge runs through a stun), the
## action lands, and the body moves on the wish, or on the locked charge direction.
func _act(delta: float) -> void:
	var to_target := Vector2.ZERO
	if is_instance_valid(target):
		to_target = target.global_position - global_position
	var wish := Vector2.ZERO
	if status.stunned() and not brain.charging():
		if brain.phase == BossBrain.Phase.TELEGRAPH:
			_interrupt_telegraph()
	else:
		var phase_before := brain.phase
		var stage_before := brain.stage
		var action := brain.tick(delta, def)
		if brain.phase == BossBrain.Phase.TELEGRAPH and phase_before != brain.phase:
			_telegraph_fx()
		if brain.stage != stage_before:
			_enrage_fx()
		_perform(action, to_target)
		wish = brain.wish(to_target)
	if brain.charging():
		move_vel = charge_dir * def.charge_speed * status.speed_multiplier()
	else:
		var speed := def.speed * status.speed_multiplier()
		move_vel = Movement.step(move_vel, wish, speed, def.accel, def.accel, delta)
	var face := charge_dir if brain.charging() else to_target  # a charge faces its lane, not the player
	if face.x != 0.0:
		sprite.flip_h = face.x < 0.0
	sprite.play("run" if Movement.is_moving(move_vel) else "idle")
	_charge_dust.emitting = brain.charging()


func _perform(action: String, to_target: Vector2) -> void:
	match action:
		BossBrain.ACTION_RING:
			_fire_ring()
		BossBrain.ACTION_VOLLEY:
			_fire_volley(to_target)
		BossBrain.ACTION_CHARGE:
			if to_target != Vector2.ZERO:
				charge_dir = to_target.normalized()
			Events.boss_attacked.emit("charge", global_position)
		BossBrain.ACTION_CHARGE_END:
			move_vel = Vector2.ZERO
			Events.boss_attacked.emit("charge_end", global_position)
		BossBrain.ACTION_SUMMON:
			_summon()


func _fire_ring() -> void:
	var count := brain.ring_count(def)
	for i in count:
		_fire_bolt(Vector2.from_angle(TAU * float(i) / float(count)))
	Events.boss_attacked.emit("ring", global_position)


func _fire_volley(to_target: Vector2) -> void:
	var base := to_target.angle() if to_target != Vector2.ZERO else charge_dir.angle()
	for offset in WeaponDef.spread_offsets(def.volley_count, deg_to_rad(def.volley_spread_degrees)):
		_fire_bolt(Vector2.from_angle(base + float(offset)))
	Events.boss_attacked.emit("volley", global_position)


func _fire_bolt(dir: Vector2) -> void:
	var bolt: Projectile = ENEMY_BOLT.instantiate()
	bolt.setup(def.bolt, dir)
	projectile_parent.add_child(bolt)
	bolt.global_position = global_position + dir * BOLT_MUZZLE


## Stage two's summon: chasers at the wall midpoints, in the `summoned` group so the wave runner
## never counts them; they die with the boss. Placed here rather than through the Spawner so a
## hand-placed boss in a bare tree still works.
func _summon() -> void:
	var points := _summon_points()
	for i in def.summon_count:
		var imp: Node2D = def.summon_scene.instantiate()
		imp.set("target", target)
		imp.set("projectile_parent", projectile_parent)
		imp.add_to_group("summoned")
		get_parent().add_child(imp)
		imp.global_position = points[i % points.size()]
		Events.enemy_spawned.emit(imp)
	Events.boss_attacked.emit("summon", global_position)


## The left and right wall midpoints of the room's floor, a tile in; without a Room above (a bare
## test tree) the points sit either side of the boss.
func _summon_points() -> Array[Vector2]:
	var room := get_parent().get_parent() as Room
	if room == null:
		return [global_position + Vector2(-100, 0), global_position + Vector2(100, 0)]
	var b := room.bounds()
	var y := b.get_center().y
	return [Vector2(b.position.x + ArenaGrid.TILE, y), Vector2(b.end.x - ArenaGrid.TILE, y)]


func _end_charge_on_wall() -> void:
	if brain.end_charge() == BossBrain.ACTION_CHARGE_END:
		move_vel = Vector2.ZERO
		Juice.add_trauma(WALL_TRAUMA)
		Events.boss_attacked.emit("charge_wall", global_position)


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0


func _on_damaged(amount: float, kb: Vector2) -> void:
	knockback += kb * KNOCKBACK_SCALE
	Events.enemy_hit.emit(self, amount, global_position)
	if health.hp > 0.0 and health.hp <= def.max_hp * def.phase2_fraction:
		brain.request_enrage()
	if health.last_hit_quiet:
		return  # a burn tick: no flash, no shake; the tint is the feedback
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_flash_tween = Juice.flash(flash_material)
	Juice.add_trauma(HIT_TRAUMA)


## Two white pulses over the wind-up, like the shooter's (no shiver: at 2x it would read as a glitch).
func _telegraph_fx() -> void:
	Events.enemy_telegraphed.emit(self)
	var half := brain.telegraph_time(def) * 0.5
	_pulse_tween = create_tween()
	for i in 2:
		_pulse_tween.tween_property(flash_material, "shader_parameter/flash", TELEGRAPH_FLASH, half * 0.4)
		_pulse_tween.tween_property(flash_material, "shader_parameter/flash", 0.0, half * 0.6)


func _interrupt_telegraph() -> void:
	brain.interrupt()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		flash_material.set_shader_parameter("flash", 0.0)


## Stage 2: a brighter body, a roar, a shake. The brain already runs on the stage-two numbers.
func _enrage_fx() -> void:
	status.base_tint = ENRAGED_TINT
	Juice.add_trauma(PHASE_TRAUMA)
	Events.boss_phase_changed.emit(brain.stage)


func _on_died() -> void:
	_enter(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")  # a corpse is not a homing target
	set_physics_process(false)
	status.set_physics_process(false)
	status.stop_effects()
	_charge_dust.emitting = false  # a corpse from a mid-charge kill leaves no trail
	move_vel = Vector2.ZERO
	# The fade-in too: the corpse stays, and a fade still running would override its tint.
	for tween: Tween in [_fade_tween, _flash_tween, _pulse_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	sprite.modulate.a = 1.0  # a kill inside the fade-in still leaves a fully lit pose
	flash_material.set_shader_parameter("flash", 1.0)
	sprite.stop()
	Events.enemy_died.emit(self, global_position)
	Juice.add_trauma(DEATH_TRAUMA)
	Juice.hitstop(DEATH_HITSTOP)
	_kill_summons.call_deferred()  # enemy_died arrives inside a shot's body_entered
	await get_tree().create_timer(DEATH_HITSTOP + CORPSE_FLASH_HOLD, true, false, true).timeout
	if is_inside_tree():
		flash_material.set_shader_parameter("flash", 0.0)
		sprite.modulate = CORPSE_TINT


func _kill_summons() -> void:
	for node in get_tree().get_nodes_in_group("summoned"):
		var summon_health := node.get_node_or_null("Health") as Health
		if summon_health != null and not summon_health.dead:
			summon_health.take_damage(1000.0)
