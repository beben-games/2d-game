extends CanvasLayer
## Hearts, dash pips, round, wave, kills, and the build strip (weapon icon, then every owned
## upgrade with its rank). Reads the player once at ready, then follows the bus.

const HEART_SCALE := 3.0
const ICON_SCALE := 3.0
const PIP_SIZE := Vector2(18, 10)
const PIP_LIT := Color(0.6, 0.9, 1.0)
const PIP_DIM := Color(0.25, 0.3, 0.35)
const RANK_FONT_SIZE := 16  ## the pixel font on its 16 px grid
const BOSS_BAR_SIZE := Vector2(480, 48)  ## a multiple of the nine-patch scale
const BOSS_BAR_TOP := 0.0  ## the 48 px bar sits exactly on the 48 px ledge row, leaving the emperor's box clear
const BOSS_BAR_SCALE := 4.0
const BOSS_BAR_INSET := 12.0
const BOSS_BAR_FILL := Color(0.75, 0.15, 0.15)
const BOSS_BAR_TWEEN := 0.15
const VIGNETTE_ALPHA := 0.35
const VIGNETTE_TIME := 0.25

## Placeholders until Main's _ready emits round_started and wave_started; the HUD is a child of Main, so it is connected first.
var _round := 0
var _rounds := 1
var _wave := 0
var _waves := 1
## The boss bar: shown on boss_spawned, tracking its Health, hidden on its death or a new run.
var boss_bar: Control
var _boss: Node2D
var _boss_health: Health
var _boss_fill: ColorRect
var _boss_name: Label
var _fill_tween: Tween
## A red radial gradient over the whole screen, shown for a beat on a hit.
var vignette: TextureRect
var _vignette_tween: Tween

@onready var hearts: HBoxContainer = $Hearts
@onready var dashes: HBoxContainer = $Dashes
@onready var info: Label = $Info
@onready var build_strip: HBoxContainer = $BuildStrip


func _ready() -> void:
	_build_vignette()
	Events.player_hit.connect(_on_player_hit)
	Events.player_healed.connect(_on_player_healed)
	Events.wave_started.connect(_on_wave_started)
	Events.round_started.connect(_on_round_started)
	Events.enemy_died.connect(_on_enemy_died)
	Events.build_changed.connect(_refresh_build)
	Events.dash_charges_changed.connect(_set_dashes)
	Events.boss_spawned.connect(_on_boss_spawned)
	Events.run_started.connect(_on_run_started)
	var player: Player = get_tree().get_first_node_in_group("player")
	if player != null:
		_set_hearts(player.hp, player.max_hp)
		_set_dashes(player.dash_charges, player.max_dash_charges)
	_build_boss_bar()
	_refresh_info()
	_refresh_build()


func _exit_tree() -> void:
	for pair: Array in [
		[Events.player_hit, _on_player_hit], [Events.player_healed, _on_player_healed],
		[Events.wave_started, _on_wave_started], [Events.round_started, _on_round_started],
		[Events.enemy_died, _on_enemy_died], [Events.build_changed, _refresh_build],
		[Events.dash_charges_changed, _set_dashes], [Events.boss_spawned, _on_boss_spawned],
		[Events.run_started, _on_run_started],
	]:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


func _set_hearts(hp: int, max_hp: int) -> void:
	UiTheme.clear_children(hearts)
	var layout := HeartRules.layout(hp, max_hp)
	for i in layout.size():
		var heart := TextureRect.new()
		heart.name = "%s%d" % [layout[i], i]
		heart.texture = SpriteAtlas.texture("ui_heart_%s" % layout[i])
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Containers reset a child's scale, so the 3x comes from the min size and STRETCH_SCALE.
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_SCALE
		heart.custom_minimum_size = SpriteAtlas.region("ui_heart_full").size * HEART_SCALE
		hearts.add_child(heart)


func _set_dashes(charges: int, max_charges: int) -> void:
	UiTheme.clear_children(dashes)
	for i in max_charges:
		var pip := ColorRect.new()
		var lit := i < charges
		pip.name = "%s%d" % ["lit" if lit else "dim", i]
		pip.custom_minimum_size = PIP_SIZE
		pip.color = PIP_LIT if lit else PIP_DIM
		dashes.add_child(pip)


## The weapon icon, then each owned weapon upgrade, then each player upgrade, with rank digits
## on the cards that have more than one rank.
func _refresh_build() -> void:
	UiTheme.clear_children(build_strip)
	var build := RunState.build
	var catalog := UpgradeCatalog.upgrades()
	var weapon := IconAtlas.rect(UpgradeCatalog.weapon(build.weapon_id).icon, ICON_SCALE)
	weapon.name = "Weapon"
	build_strip.add_child(weapon)
	for id in build.owned_weapon_ids():
		build_strip.add_child(_slot("W_" + id, catalog[id].icon, build.rank_of(id), catalog[id].max_rank))
	for id in build.owned_player_ids():
		build_strip.add_child(_slot("P_" + id, catalog[id].icon, build.rank_of(id), catalog[id].max_rank))


func _slot(slot_name: String, icon: String, rank: int, max_rank: int) -> Control:
	var slot := IconAtlas.rect(icon, ICON_SCALE)
	slot.name = slot_name
	if max_rank <= 1:
		return slot  # one rank: the icon alone says it all
	var rank_label := UiTheme.label(str(rank), RANK_FONT_SIZE, Color.WHITE)
	rank_label.name = "Rank"
	rank_label.add_theme_color_override("font_outline_color", Color.BLACK)
	rank_label.add_theme_constant_override("outline_size", 4)
	rank_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	rank_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rank_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slot.add_child(rank_label)
	return slot


func _refresh_info() -> void:
	info.text = "Round %d/%d   Wave %d/%d   Kills %d" % [_round + 1, _rounds, _wave + 1, _waves, RunState.kills]


func _on_player_hit(_damage: int, hp: int, max_hp: int) -> void:
	_set_hearts(hp, max_hp)
	_flash_vignette()


func _on_player_healed(hp: int, max_hp: int) -> void:
	_set_hearts(hp, max_hp)


func _on_wave_started(index: int, total: int) -> void:
	_wave = index
	_waves = total
	_refresh_info()


func _on_round_started(index: int, total: int) -> void:
	_round = index
	_rounds = total
	_refresh_info()


## RunState (an autoload) connected to enemy_died before this node, so kills is already incremented here.
func _on_enemy_died(enemy: Node2D, _at: Vector2) -> void:
	_refresh_info()
	if enemy == _boss:
		_hide_boss_bar()


func _build_vignette() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.0, 0.0, 0.0))
	gradient.set_color(1, Color(0.8, 0.0, 0.0, 1.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 144
	vignette = TextureRect.new()
	vignette.name = "Vignette"
	vignette.texture = texture
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	add_child(vignette)
	move_child(vignette, 0)


func _flash_vignette() -> void:
	if _vignette_tween != null and _vignette_tween.is_valid():
		_vignette_tween.kill()
	vignette.modulate.a = VIGNETTE_ALPHA
	_vignette_tween = create_tween()
	_vignette_tween.set_ignore_time_scale(true)  # the hit's own hitstop must not hold it
	_vignette_tween.tween_property(vignette, "modulate:a", 0.0, VIGNETTE_TIME)


func _build_boss_bar() -> void:
	var holder := CenterContainer.new()
	holder.name = "BossBarHolder"
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = BOSS_BAR_TOP
	holder.offset_bottom = BOSS_BAR_TOP + BOSS_BAR_SIZE.y
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	boss_bar = Control.new()
	boss_bar.name = "BossBar"
	boss_bar.custom_minimum_size = BOSS_BAR_SIZE
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.visible = false
	UiTheme.framed_panel(boss_bar, BOSS_BAR_SIZE, BOSS_BAR_SCALE)
	_boss_fill = ColorRect.new()
	_boss_fill.name = "Fill"
	_boss_fill.color = BOSS_BAR_FILL
	_boss_fill.position = Vector2(BOSS_BAR_INSET, BOSS_BAR_INSET)
	_boss_fill.size = Vector2(0.0, BOSS_BAR_SIZE.y - BOSS_BAR_INSET * 2.0)
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.add_child(_boss_fill)
	_boss_name = UiTheme.title("", UiTheme.FONT_SMALL, UiTheme.PAPER)
	_boss_name.name = "Name"
	_boss_name.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_boss_name.add_theme_constant_override("outline_size", 4)
	boss_bar.add_child(_boss_name)
	holder.add_child(boss_bar)


func _on_boss_spawned(boss: Node2D) -> void:
	_boss = boss
	var def: Resource = boss.get("def")
	_boss_name.text = str(def.get("display_name")) if def != null else "Boss"
	_boss_health = boss.get_node_or_null("Health") as Health
	if _boss_health != null and not _boss_health.damaged.is_connected(_on_boss_damaged):
		_boss_health.damaged.connect(_on_boss_damaged)
	_set_boss_fill(1.0, false)
	boss_bar.visible = true


func _on_boss_damaged(_amount: float, _knockback: Vector2) -> void:
	if not is_instance_valid(_boss_health):
		return
	_set_boss_fill(_boss_health.hp / _boss_health.max_hp, true)


## The fill's width for the HP ratio; the kill freeze must not stall the last step.
func _set_boss_fill(ratio: float, animate: bool) -> void:
	var width := (BOSS_BAR_SIZE.x - BOSS_BAR_INSET * 2.0) * clampf(ratio, 0.0, 1.0)
	if _fill_tween != null and _fill_tween.is_valid():
		_fill_tween.kill()
	if not animate:
		_boss_fill.size.x = width
		return
	_fill_tween = create_tween()
	_fill_tween.set_ignore_time_scale(true)
	_fill_tween.tween_property(_boss_fill, "size:x", width, BOSS_BAR_TWEEN)


func boss_fill_ratio() -> float:
	return _boss_fill.size.x / (BOSS_BAR_SIZE.x - BOSS_BAR_INSET * 2.0)


func _hide_boss_bar() -> void:
	boss_bar.visible = false
	if is_instance_valid(_boss_health) and _boss_health.damaged.is_connected(_on_boss_damaged):
		_boss_health.damaged.disconnect(_on_boss_damaged)
	_boss_health = null
	_boss = null


func _on_run_started() -> void:
	_hide_boss_bar()
