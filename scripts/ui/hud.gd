class_name Hud
extends CanvasLayer
## Hearts, dash pips, the favour meter, the coin counter, round, wave, kills, and the build strip
## (weapon icon, then every owned upgrade with its rank). Reads the player once at ready, then
## follows the bus.

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
## The favour meter under the dash pips: the beige panel as the frame at the hearts' scale, a
## dark trough, and the fill in the band's colour. No label: the crowd's sound explains it.
const FAVOUR_BAR_SIZE := Vector2(132, 30)  ## a multiple of the scale
const FAVOUR_BAR_SCALE := 3.0
const FAVOUR_BAR_INSET := 6.0
const FAVOUR_BAR_POSITION := Vector2(16, 78)  ## 8 px under the Dashes row hud.tscn places at y 60 (pips 10 tall)
const FAVOUR_TROUGH := Color(0.16, 0.12, 0.1)
const FAVOUR_FILL := {
	FavourRules.BOO: Color(0.45, 0.45, 0.5),
	FavourRules.QUIET: Color.WHITE,
	FavourRules.CHEER: Color(1.0, 0.85, 0.3),
	FavourRules.ROAR: Color(0.9, 0.2, 0.2),
}
## The coin counter at the right under the build strip, at the Info label's inset (both read from
## hud.tscn at build time): the coin at the hearts' scale with the number to its left, so the coin
## stays put as the number widens and the flights land on it. No label: the flights and the
## piles say what it counts.
const COIN_ICON_SCALE := 3.0
const COIN_FONT_SIZE := 32  ## the pixel font's grid, twice
const COIN_COUNTER_GAP := 8.0  ## under the build strip, and between the number and the coin
const COIN_LABEL_WIDTH := 160.0  ## room for the number, right-aligned against the coin

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
## The favour meter, following favour_changed.
var favour_bar: Control
var _favour_fill: ColorRect
## The coin counter, following coins_changed; the flights land on the icon.
var coin_icon: TextureRect
var coin_label: Label
## The player, read at ready and again at run_started (Player.revive fills its hearts and
## charges first: an earlier child of Main, connected earlier).
var _player: Player

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
	Events.favour_changed.connect(_on_favour_changed)
	Events.coins_changed.connect(_set_coins)
	_player = get_tree().get_first_node_in_group("player")
	_read_player()
	_build_boss_bar()
	_build_favour_bar()
	_build_coin_counter()
	_refresh_info()
	_refresh_build()


func _exit_tree() -> void:
	for pair: Array in [
		[Events.player_hit, _on_player_hit], [Events.player_healed, _on_player_healed],
		[Events.wave_started, _on_wave_started], [Events.round_started, _on_round_started],
		[Events.enemy_died, _on_enemy_died], [Events.build_changed, _refresh_build],
		[Events.dash_charges_changed, _set_dashes], [Events.boss_spawned, _on_boss_spawned],
		[Events.run_started, _on_run_started], [Events.favour_changed, _on_favour_changed],
		[Events.coins_changed, _set_coins],
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


func _on_player_hit(_damage: int, hp: int, max_hp: int, _attacker_id: String) -> void:
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


## A run started from the gate has no scene reload: everything the run owns (the strip, the
## counter, the meter) is read again from the fresh RunState here.
func _on_run_started() -> void:
	_hide_boss_bar()
	_read_player()
	_refresh_build()
	_set_favour_fill(RunState.favour, FavourRules.band(RunState.favour))
	_set_coins(RunState.coins)


## The hearts and the dash pips from the player's live numbers (none without a player: a test's bare HUD).
func _read_player() -> void:
	if not is_instance_valid(_player):
		return
	_set_hearts(_player.hp, _player.max_hp)
	_set_dashes(_player.dash_charges, _player.max_dash_charges)


func _build_favour_bar() -> void:
	favour_bar = Control.new()
	favour_bar.name = "FavourBar"
	favour_bar.position = FAVOUR_BAR_POSITION
	favour_bar.custom_minimum_size = FAVOUR_BAR_SIZE
	favour_bar.size = FAVOUR_BAR_SIZE
	favour_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := UiTheme.nine_patch(UiTheme.PANEL, UiTheme.PANEL_MARGIN, FAVOUR_BAR_SIZE, FAVOUR_BAR_SCALE)
	frame.name = "Frame"
	favour_bar.add_child(frame)
	var trough := ColorRect.new()
	trough.name = "Trough"
	trough.color = FAVOUR_TROUGH
	trough.position = Vector2(FAVOUR_BAR_INSET, FAVOUR_BAR_INSET)
	trough.size = FAVOUR_BAR_SIZE - Vector2(FAVOUR_BAR_INSET, FAVOUR_BAR_INSET) * 2.0
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	favour_bar.add_child(trough)
	_favour_fill = ColorRect.new()
	_favour_fill.name = "Fill"
	_favour_fill.position = trough.position
	_favour_fill.size = Vector2(0.0, trough.size.y)
	_favour_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	favour_bar.add_child(_favour_fill)
	add_child(favour_bar)
	_set_favour_fill(RunState.favour, FavourRules.band(RunState.favour))


func _on_favour_changed(value: float, band: int, _act: String) -> void:
	_set_favour_fill(value, band)


func _set_favour_fill(value: float, band: int) -> void:
	_favour_fill.size.x = (FAVOUR_BAR_SIZE.x - FAVOUR_BAR_INSET * 2.0) * clampf(value / FavourRules.MAX, 0.0, 1.0)
	_favour_fill.color = FAVOUR_FILL[band]


func favour_fill_ratio() -> float:
	return _favour_fill.size.x / (FAVOUR_BAR_SIZE.x - FAVOUR_BAR_INSET * 2.0)


func favour_fill_colour() -> Color:
	return _favour_fill.color


func _build_coin_counter() -> void:
	var icon_size := SpriteAtlas.region("coin_anim").size * COIN_ICON_SCALE
	var top := build_strip.offset_bottom + COIN_COUNTER_GAP
	var right_inset := -info.offset_right
	coin_icon = SpriteAtlas.rect("coin_anim", COIN_ICON_SCALE)
	coin_icon.name = "CoinIcon"
	coin_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var icon_top := top + (COIN_FONT_SIZE - icon_size.y) * 0.5  # centred on the number's line
	coin_icon.offset_left = -right_inset - icon_size.x
	coin_icon.offset_right = -right_inset
	coin_icon.offset_top = icon_top
	coin_icon.offset_bottom = icon_top + icon_size.y
	add_child(coin_icon)
	coin_label = UiTheme.label("0", COIN_FONT_SIZE, UiTheme.PAPER)
	coin_label.name = "CoinCount"
	coin_label.add_theme_color_override("font_outline_color", Color.BLACK)
	coin_label.add_theme_constant_override("outline_size", 4)
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coin_label.offset_right = coin_icon.offset_left - COIN_COUNTER_GAP
	coin_label.offset_left = coin_label.offset_right - COIN_LABEL_WIDTH
	coin_label.offset_top = top
	coin_label.offset_bottom = top + COIN_FONT_SIZE
	add_child(coin_label)
	_set_coins(RunState.coins)


func _set_coins(run_coins: int) -> void:
	coin_label.text = str(run_coins)


func coin_counter_text() -> String:
	return coin_label.text


## The coin's middle in this layer's screen pixels: where a flight lands.
func counter_position() -> Vector2:
	return coin_icon.get_global_rect().get_center()


## A coin from a world position to the counter: the flight lives on this layer, so the start is
## the camera's view of the world in screen pixels.
func fly_coin(world_position: Vector2) -> void:
	var flight := CoinFlight.new()
	add_child(flight)
	flight.fly(get_viewport().get_canvas_transform() * world_position, counter_position())
