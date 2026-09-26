class_name Player
extends CharacterBody2D
## The hero: movement, shooting, and taking contact damage.

const PROJECTILE := preload("res://scenes/projectile.tscn")
const MAX_SPEED := 110.0
const ACCEL := 900.0
const FRICTION := 1100.0
const KNOCKBACK_DECAY := 900.0
const MUZZLE_DISTANCE := 8.0
const SPRITE_OFFSET := Vector2(0, -6)  ## Sprite is drawn this far from the body so the feet sit on the collider.
const ANIMATIONS := {"idle": "knight_m_idle_anim", "run": "knight_m_run_anim"}
const MAX_HP := Build.BASE_MAX_HP  ## the starting max; the live one is max_hp
const INVULN_TIME := 0.8
const HIT_KNOCKBACK := 200.0
const HIT_TRAUMA := 0.7
const HIT_HITSTOP := 0.09
const DEATH_TRAUMA := 1.0
const DEATH_HITSTOP := 0.25
const BODY_LAYER := 1
const BODY_MASK := 18  ## walls and enemies
const DASH_MASK := 16  ## walls only: the dash passes through bodies
const DASH_LAYER := 64  ## a dashing player: enemies do not mask it, triggers do

## The weapon fired: RunState.build resolved over the catalog. Re-resolved on build_changed.
var weapon: WeaponDef
var max_hp: int = Build.BASE_MAX_HP

## Where shots are added. Main sets this to its Projectiles container; falls back to the parent.
var projectile_parent: Node

## Tests and the smoke tool set this to aim without a mouse. INF means "use the mouse".
var aim_override: Vector2 = Vector2.INF

var move_vel := Vector2.ZERO
var knockback := Vector2.ZERO
var fire := FireController.new()
var hp: int = MAX_HP
var dead := false
var invuln_left := 0.0
## The attacker id of the last hit that landed ("" unknown): what player_fell names.
var last_attacker_id := ""
var dash_left := 0.0
var dash_cooldown := 0.0  ## the refill clock, running only while below max_dash_charges
var dash_charges: int = Build.BASE_DASH_CHARGES
var max_dash_charges: int = Build.BASE_DASH_CHARGES
var dash_dir := Vector2.RIGHT

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
## Enemy bodies are solid (they block and pin you); contact damage still comes solely from this
## hurtbox. Its radius (8) reaches past the body gap (r 6 + r 5 = 11 px between centers), or a
## chaser pressed against you could never land a hit. The hit knockback is the escape from a pin.
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	Events.build_changed.connect(_on_build_changed)
	Events.run_started.connect(revive)
	_apply_build()
	sprite.sprite_frames = SpriteAtlas.frames(ANIMATIONS)
	sprite.play("idle")


func _exit_tree() -> void:
	if Events.build_changed.is_connected(_on_build_changed):
		Events.build_changed.disconnect(_on_build_changed)
	if Events.run_started.is_connected(revive):
		Events.run_started.disconnect(revive)


func _on_build_changed() -> void:
	_apply_build()


## A whole body again: on run_started (a fresh run's hearts and charges at the build's maxes,
## which the training raises), and when Main puts the fallen gladiator in the grounds. Undoes
## the fall (upright, the hurtbox on, the corpse's solid layer kept as the walking one), clears
## the hit and dash state, reads the build's maxes and fills them. No signal: the HUD re-reads
## the player on run_started after this (a later child of Main, so connected later), and in the
## grounds it is hidden.
func revive() -> void:
	dead = false
	sprite.rotation = 0.0
	sprite.visible = true
	hurtbox.monitoring = true
	invuln_left = 0.0
	knockback = Vector2.ZERO
	move_vel = Vector2.ZERO
	dash_left = 0.0
	dash_cooldown = 0.0
	collision_layer = BODY_LAYER
	collision_mask = BODY_MASK
	last_attacker_id = ""
	var build := RunState.build
	var catalog := UpgradeCatalog.upgrades()
	weapon = build.resolve(UpgradeCatalog.weapon(build.weapon_id), catalog)
	max_dash_charges = build.dash_charges(catalog)
	dash_charges = max_dash_charges
	max_hp = build.max_hp(catalog)
	hp = max_hp


## Reads the weapon, the dash charges, and the max HP from the build. The weapon is always
## re-resolved; each player stat gates its own signal, emitted only when its max changed. A bigger
## dash max adds the new charges ready to use; a bigger max HP heals the difference (a heart
## container is a full new heart); a smaller max of either clamps.
func _apply_build() -> void:
	var build := RunState.build
	var catalog := UpgradeCatalog.upgrades()
	weapon = build.resolve(UpgradeCatalog.weapon(build.weapon_id), catalog)
	var new_dashes := build.dash_charges(catalog)
	if new_dashes != max_dash_charges:
		dash_charges = clampi(dash_charges + (new_dashes - max_dash_charges), 0, new_dashes)
		max_dash_charges = new_dashes
		Events.dash_charges_changed.emit(dash_charges, max_dash_charges)
	var new_max := build.max_hp(catalog)
	if new_max != max_hp:
		if new_max > max_hp and not dead:
			hp += new_max - max_hp
		max_hp = new_max
		hp = mini(hp, max_hp)
		Events.player_healed.emit(hp, max_hp)  # a redraw signal: the HUD rebuilds its hearts on it


func _physics_process(delta: float) -> void:
	if dead:
		return
	var aim_dir := aim_direction()
	var wish := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var refilled := DashRules.refill(dash_charges, max_dash_charges, dash_cooldown, delta)
	dash_cooldown = float(refilled[1])
	if int(refilled[0]) != dash_charges:
		dash_charges = int(refilled[0])
		Events.dash_charges_changed.emit(dash_charges, max_dash_charges)
	if Input.is_action_just_pressed("dash") and DashRules.can_start(dash_charges, dash_left > 0.0):
		_start_dash(DashRules.direction(wish, aim_dir))
	if dash_left > 0.0:
		dash_left -= delta
		move_vel = dash_dir * DashRules.SPEED
	else:
		if collision_layer == DASH_LAYER:
			_end_dash()  # first tick after the last fast tick
		move_vel = Movement.step(move_vel, wish, MAX_SPEED, ACCEL, FRICTION, delta)
	knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	velocity = move_vel + knockback
	move_and_slide()

	sprite.flip_h = aim_dir.x < 0.0
	muzzle.position = SPRITE_OFFSET + aim_dir * MUZZLE_DISTANCE
	sprite.play("run" if Movement.is_moving(move_vel) else "idle")

	fire.tick(delta)
	if Input.is_action_pressed("shoot") and fire.try_fire(weapon.fire_rate):
		_shoot(aim_dir)

	# Real time: hitstop shrinks delta, and a run of kill freezes must not stretch the i-frames.
	invuln_left = maxf(invuln_left - Juice.unscaled_physics_delta(), 0.0)
	sprite.visible = PlayerHitRules.blink_visible(invuln_left)
	_check_contact()


func aim_position() -> Vector2:
	if aim_override != Vector2.INF:
		return aim_override
	return get_global_mouse_position()


func aim_direction() -> Vector2:
	var dir := aim_position() - global_position
	return dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT


## The dash drops the enemy bit from the body mask so bodies do not block us, and moves the body
## to its own layer (DASH_LAYER, 64): enemies mask 19 and never pair with it, so they neither
## block us nor get shoved (their own move_and_slide would otherwise depenetrate from us every
## tick and we would bulldoze them along instead of passing through), while Area2D triggers that
## mask 65 see the dashing player the same tick it enters. The hurtbox keeps its own layer and
## mask, so contact and bolts still land (no i-frames by design).
func _start_dash(dir: Vector2) -> void:
	dash_dir = dir
	dash_left = DashRules.DURATION
	if dash_cooldown <= 0.0:
		dash_cooldown = DashRules.COOLDOWN  # no refill clock is running: this spend starts it
	dash_charges -= 1
	Events.dash_charges_changed.emit(dash_charges, max_dash_charges)
	collision_layer = DASH_LAYER
	collision_mask = DASH_MASK
	Events.player_dashed.emit(global_position, dir)


## Restores the body layer and mask. move_vel keeps the dash velocity: it is Movement.step's input
## on this same tick, so run speed carries out of the dash instead of stopping dead.
func _end_dash() -> void:
	dash_left = 0.0
	collision_layer = BODY_LAYER
	collision_mask = BODY_MASK


## Shots live outside the player so they do not move with it. One jitter per volley keeps a
## multishot fan coherent.
func _shoot(dir: Vector2) -> void:
	var parent := projectile_parent if projectile_parent != null else get_parent()
	var jitter := deg_to_rad(weapon.inaccuracy_degrees)
	var base_angle := dir.angle() + RunState.rng.randf_range(-jitter, jitter)
	for offset in WeaponDef.spread_offsets(weapon.projectile_count, deg_to_rad(weapon.spread_degrees)):
		var shot: Projectile = PROJECTILE.instantiate()
		shot.setup(weapon, Vector2.from_angle(base_angle + offset))
		parent.add_child(shot)
		shot.global_position = muzzle.global_position
	knockback -= dir * weapon.recoil
	Events.shot_fired.emit(muzzle.global_position, dir, weapon.id)


## Polls overlaps every physics frame so an enemy that stays on top of us keeps hurting after
## i-frames end. Enemy bolts are areas on layer 8. A bolt that lands is spent; during i-frames it
## passes through, like body contact. An immortal player (the permawhat? cheat) still stops a
## bolt: it is spent with no damage, no i-frames, and no hurt sound, rather than collected and
## carried along under the body.
func _check_contact() -> void:
	for body in hurtbox.get_overlapping_bodies():
		if not body.has_method("is_harmful") or not body.call("is_harmful"):
			continue
		var def: Resource = body.get("def")
		if def != null and hurt(int(def.get("contact_damage")), body.global_position, _id_of(def)):
			return
	for area in hurtbox.get_overlapping_areas():
		var bolt := area as Projectile
		if bolt == null:
			continue
		if hurt(int(bolt.damage), bolt.global_position, bolt.shooter_id):
			bolt.despawn()
			return
		if RunState.cheats.get("immortal", false):
			bolt.despawn()


## The one way to damage the player. Returns false when the hit was ignored (dead, invulnerable,
## no damage, or the permawhat? cheat is on). attacker_id is the def id of what hit ("" unknown):
## player_hit carries it for the profile, and a killing hit's goes out with player_fell.
func hurt(damage: int, from: Vector2, attacker_id: String = "") -> bool:
	if dead or damage <= 0 or not PlayerHitRules.can_take_hit(invuln_left):
		return false
	if RunState.cheats.get("immortal", false):
		return false  # the only place the cheat is read: every hit comes through here
	hp = maxi(hp - damage, 0)
	invuln_left = INVULN_TIME
	knockback = PlayerHitRules.knockback_from(global_position, from, HIT_KNOCKBACK)
	Juice.add_trauma(HIT_TRAUMA)
	Juice.hitstop(HIT_HITSTOP)
	last_attacker_id = attacker_id
	Events.player_hit.emit(damage, hp, max_hp, attacker_id)
	if hp == 0:
		_fall()
	return true


## Restores hp, capped at max_hp. Returns false when nothing changed (dead or already full).
func heal(amount: int) -> bool:
	if dead or amount <= 0 or hp >= max_hp:
		return false
	hp = mini(hp + amount, max_hp)
	Events.player_healed.emit(hp, max_hp)
	return true


## The def's id as a String, "" when the def has none (a stub in a test).
func _id_of(def: Resource) -> String:
	var id: Variant = def.get("id")
	return str(id) if id != null else ""


## The final hit: the gladiator goes down, not dead (the verdict decides that). The sprite stays,
## laid flat a quarter turn about its centre (SPRITE_OFFSET above the feet, so the 16x28 frame
## lies 28 wide with its lower edge near where the feet stood; no new art), and the blink is
## left on (_physics_process stops here). `dead` stays the flag's name: the body is inert.
func _fall() -> void:
	dead = true
	sprite.visible = true
	sprite.rotation = -PI / 2
	hurtbox.monitoring = false
	# A corpse from a mid-dash death is solid like any other.
	dash_left = 0.0
	collision_layer = BODY_LAYER
	collision_mask = BODY_MASK
	Juice.add_trauma(DEATH_TRAUMA)
	Juice.hitstop(DEATH_HITSTOP)
	Events.player_fell.emit(global_position, last_attacker_id)
