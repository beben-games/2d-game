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
## A fight of several bodies: a bar each, side by side at the screen's top, narrower so two clear
## the hearts and the info (a multiple of the nine-patch scale), BOSS_BAR_GAP apart.
const BOSS_BAR_PAIR_WIDTH := 256.0
const BOSS_BAR_GAP := 16.0
const VIGNETTE_ALPHA := 0.35
const VIGNETTE_TIME := 0.25
## The two rows under the hearts, each named by an icon at its left (UI may name): the boot
## (dash_charge) beside the dash pips, the crowd beside the favour meter, at the hearts' scale,
## stacked under the Hearts row hud.tscn places at (16, 16); the row's pips or bar sit to the
## icon's right, centred on it. The rows' places are computed in _build_row_icons (hud.tscn's
## Dashes carries no offsets). PLACEHOLDER: the Raven sheet has no crowd, so the favour icon
## is two round heads drawn in code (crowd_placeholder) until M8's art or the bar's removal.
const ROW_ICON_SCALE := 3.0
const ROW_ICON_GAP := 8.0  ## between the icon and its row
const ROW_STACK_GAP := 4.0  ## between the hearts, the dash row, and the favour row
const CROWD_FILL := Color("e8b48a")
const CROWD_EDGE := Color("3b2a22")
## The two heads of the crowd placeholder: a left head and a right head, each a filled disc with
## its edge, the right one a shade lower.
const CROWD_HEADS: Array[Vector3] = [Vector3(5, 7, 4.2), Vector3(11, 9, 4.2)]  ## (x, y, radius)
## The favour meter: the beige panel as the frame at the hearts' scale, a dark trough, and the
## fill in the band's colour. No label: the icon names it and the crowd's sound explains it.
const FAVOUR_BAR_SIZE := Vector2(132, 30)  ## a multiple of the scale
const FAVOUR_BAR_SCALE := 3.0
const FAVOUR_BAR_INSET := 6.0
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
## The boss bars: one per body of the fight, each shown on its body's boss_spawned, tracking its
## Health, hidden at its death (its place kept while another bar is up) or a new run. boss_bar is
## the first (tier 1's one bar); boss_bars the row that holds them, shown while any bar is up
## (the arrows' top edge).
var boss_bar: Control
var boss_bars: HBoxContainer
## Per bar slot, in the row's order: the slot holding its place, the bar, its fill, its name, the
## body and its Health (null while free), the handler connected to that Health, the fill's tween.
var _slots: Array[Control] = []
var _bars: Array[Control] = []
var _fills: Array[ColorRect] = []
var _names: Array[Label] = []
var _bodies: Array[Node2D] = []
var _healths: Array[Health] = []
var _on_damaged: Array[Callable] = []
var _fill_tweens: Array[Tween] = []
## A red radial gradient over the whole screen, shown for a beat on a hit.
var vignette: TextureRect
var _vignette_tween: Tween
## The favour meter, following favour_changed.
var favour_bar: Control
var _favour_fill: ColorRect
## The icons naming the dash row and the favour row.
var dash_icon: TextureRect
var favour_icon: TextureRect
## The coin counter, following coins_changed; the flights land on the icon.
var coin_icon: TextureRect
var coin_label: Label
## The arrows at the screen's edge for the enemies out of view, drawn over every other part.
var arrows: OffscreenArrows
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
	_build_row_icons()  # after the favour bar: it places the bar and the Dashes row beside their icons
	_build_coin_counter()
	_build_arrows()  # last: over every part, the hearts and the boss bar included
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
		heart.custom_minimum_size = heart_size()
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
	var i := _bodies.find(enemy)
	if i >= 0:
		_hide_boss_bar(i)


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
	boss_bars = HBoxContainer.new()
	boss_bars.name = "BossBars"
	boss_bars.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_bars.offset_top = BOSS_BAR_TOP
	boss_bars.offset_bottom = BOSS_BAR_TOP + BOSS_BAR_SIZE.y
	boss_bars.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_bars.add_theme_constant_override("separation", int(BOSS_BAR_GAP))
	boss_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bars.visible = false
	add_child(boss_bars)
	_add_bar_slot()
	boss_bar = _bars[0]


## A slot in the row and its bar (hidden, free), framed at the single bar's width.
func _add_bar_slot() -> void:
	var slot := Control.new()
	slot.name = "Slot%d" % _slots.size()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.visible = false
	var bar := Control.new()
	bar.name = "BossBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = BOSS_BAR_FILL
	fill.position = Vector2(BOSS_BAR_INSET, BOSS_BAR_INSET)
	fill.size = Vector2(0.0, BOSS_BAR_SIZE.y - BOSS_BAR_INSET * 2.0)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	var title := UiTheme.title("", UiTheme.FONT_SMALL, UiTheme.PAPER)
	title.name = "Name"
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	bar.add_child(title)
	slot.add_child(bar)
	boss_bars.add_child(slot)
	_slots.append(slot)
	_bars.append(bar)
	_fills.append(fill)
	_names.append(title)
	_bodies.append(null)
	_healths.append(null)
	_on_damaged.append(_on_boss_damaged.bind(_slots.size() - 1))
	_fill_tweens.append(null)
	_frame_bar(_slots.size() - 1, BOSS_BAR_SIZE.x)


## Frames bar `i` at `width` (the paper and the frame under its fill and name), its slot holding
## that place; the fill keeps its ratio.
func _frame_bar(i: int, width: float) -> void:
	var bar := _bars[i]
	var ratio := boss_fill_ratio(i) if bar.size.x > 0.0 else 0.0
	for part in ["Paper", "Frame"]:
		var old := bar.get_node_or_null(part)
		if old != null:
			bar.remove_child(old)
			old.queue_free()
	var size := Vector2(width, BOSS_BAR_SIZE.y)
	UiTheme.framed_panel(bar, size, BOSS_BAR_SCALE)
	bar.move_child(bar.get_node("Paper"), 0)
	bar.move_child(bar.get_node("Frame"), 1)
	bar.custom_minimum_size = size
	bar.size = size
	_slots[i].custom_minimum_size = size
	_fills[i].size.x = _inner_width(i) * ratio


## The width of bar `i` for a fight of `count` bodies: the single bar's for one, narrower for more.
static func boss_bar_width(count: int) -> float:
	return BOSS_BAR_SIZE.x if count <= 1 else BOSS_BAR_PAIR_WIDTH


func _inner_width(i: int) -> float:
	return _bars[i].custom_minimum_size.x - BOSS_BAR_INSET * 2.0


## A body of the fight became active: its own bar, in the next free slot (a new one past the
## last), every bar of the fight at the width for the fight's bodies (BossFight: the standing ones
## and those with a bar), the row up. A body already with a bar keeps it.
func _on_boss_spawned(boss: Node2D) -> void:
	if _bodies.has(boss):
		return
	var i := _bodies.find(null)
	if i < 0:
		_add_bar_slot()
		i = _slots.size() - 1
	_bodies[i] = boss
	var def: Resource = boss.get("def")
	_names[i].text = str(def.get("display_name")) if def != null else "Boss"
	var health := boss.get_node_or_null("Health") as Health
	_healths[i] = health
	if health != null and not health.damaged.is_connected(_on_damaged[i]):
		health.damaged.connect(_on_damaged[i])
	var in_fight := 0
	for body in _bodies:
		if body != null:
			in_fight += 1
	var width := boss_bar_width(maxi(in_fight, BossFight.living(get_tree()).size()))
	for j in _bodies.size():
		if _bodies[j] != null and _bars[j].custom_minimum_size.x != width:
			_frame_bar(j, width)
	_set_boss_fill(i, 1.0, false)
	_slots[i].visible = true
	_bars[i].visible = true
	boss_bars.visible = true


func _on_boss_damaged(_amount: float, _knockback: Vector2, i: int) -> void:
	if not is_instance_valid(_healths[i]):
		return
	_set_boss_fill(i, _healths[i].hp / _healths[i].max_hp, true)


## Bar `i`'s fill for the HP ratio; the kill freeze must not stall the last step.
func _set_boss_fill(i: int, ratio: float, animate: bool) -> void:
	var width := _inner_width(i) * clampf(ratio, 0.0, 1.0)
	if _fill_tweens[i] != null and _fill_tweens[i].is_valid():
		_fill_tweens[i].kill()
	if not animate:
		_fills[i].size.x = width
		return
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_fills[i], "size:x", width, BOSS_BAR_TWEEN)
	_fill_tweens[i] = tween


## The bars of the fight under way (shown, or kept in place for a body fallen while another stands).
func boss_bar_count() -> int:
	var n := 0
	for body in _bodies:
		if body != null:
			n += 1
	return n


## Bar `i` (the row's order); boss_bar is bar 0.
func boss_bar_at(i: int) -> Control:
	return _bars[i]


## The bar of `body`, or -1 when it has none.
func boss_bar_index(body: Node2D) -> int:
	return _bodies.find(body)


func boss_fill_ratio(i := 0) -> float:
	return _fills[i].size.x / _inner_width(i)


## Bar `i`'s body fell: its bar hides, its place kept while another bar is up; with none up the
## fight is over and every slot is freed (the row hidden).
func _hide_boss_bar(i: int) -> void:
	_bars[i].visible = false
	_let_go(i)
	for bar in _bars:
		if bar.visible:
			return
	_clear_boss_bars()


## Every slot free and hidden, the row down: the fight's end, or a new run.
func _clear_boss_bars() -> void:
	for j in _bars.size():
		_let_go(j)
		_bars[j].visible = false
		_slots[j].visible = false
		_bodies[j] = null
	boss_bars.visible = false


## Bar `i` stops following its body's Health.
func _let_go(i: int) -> void:
	var health := _healths[i]
	if is_instance_valid(health) and health.damaged.is_connected(_on_damaged[i]):
		health.damaged.disconnect(_on_damaged[i])
	_healths[i] = null


## A run started from the gate has no scene reload: everything the run owns (the strip, the
## counter, the meter) is read again from the fresh RunState here.
func _on_run_started() -> void:
	_clear_boss_bars()
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


## A heart on the HUD: the tileset's 13x12 sprite at HEART_SCALE.
static func heart_size() -> Vector2:
	return SpriteAtlas.region("ui_heart_full").size * HEART_SCALE


## The boot at the left of the dash pips and the crowd at the left of the favour meter, the two
## rows stacked under the hearts and each centred on its icon.
func _build_row_icons() -> void:
	var icon_size := IconAtlas.SIZE * ROW_ICON_SCALE
	var left := hearts.position.x
	dash_icon = IconAtlas.rect("dash_charge", ROW_ICON_SCALE)
	dash_icon.name = "DashIcon"
	dash_icon.position = Vector2(left, hearts.position.y + heart_size().y + ROW_STACK_GAP)
	add_child(dash_icon)
	dashes.position = Vector2(left + icon_size + ROW_ICON_GAP, dash_icon.position.y + (icon_size - PIP_SIZE.y) * 0.5)
	favour_icon = IconAtlas.rect_of(crowd_placeholder(), ROW_ICON_SCALE)
	favour_icon.name = "FavourIcon"
	favour_icon.position = Vector2(left, dash_icon.position.y + icon_size + ROW_STACK_GAP)
	add_child(favour_icon)
	favour_bar.position = Vector2(left + icon_size + ROW_ICON_GAP, favour_icon.position.y + (icon_size - FAVOUR_BAR_SIZE.y) * 0.5)


## PLACEHOLDER: the crowd as two round heads side by side (CROWD_HEADS), one fill and a one-pixel
## edge, on a 16x16 image; until M8's art.
static func crowd_placeholder() -> ImageTexture:
	var img := Image.create(IconAtlas.SIZE, IconAtlas.SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for head: Vector3 in CROWD_HEADS:
		for y in IconAtlas.SIZE:
			for x in IconAtlas.SIZE:
				if Vector2(x, y).distance_to(Vector2(head.x, head.y)) <= head.z:
					img.set_pixel(x, y, CROWD_FILL)
	var filled := img.duplicate() as Image
	for y in IconAtlas.SIZE:
		for x in IconAtlas.SIZE:
			if filled.get_pixel(x, y).a == 0.0:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + step
				var outside := n.x < 0 or n.y < 0 or n.x >= IconAtlas.SIZE or n.y >= IconAtlas.SIZE
				if outside or filled.get_pixel(n.x, n.y).a == 0.0:
					img.set_pixel(x, y, CROWD_EDGE)
					break
	return ImageTexture.create_from_image(img)


func _build_favour_bar() -> void:
	favour_bar = Control.new()
	favour_bar.name = "FavourBar"
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


## The off-screen arrows, the HUD's last child, so drawn over its parts: an arrow is small and
## faint past the edge, and a heart under one still reads. They keep under the boss bar while it
## is up (OffscreenArrows reads its rect). A flight added later (fly_coin) draws over them.
func _build_arrows() -> void:
	arrows = OffscreenArrows.new()
	arrows.name = "Arrows"
	arrows.boss_bars = boss_bars
	add_child(arrows)


func _set_coins(run_coins: int) -> void:
	coin_label.text = str(run_coins)


func coin_counter_text() -> String:
	return coin_label.text


## The coin's middle in this layer's screen pixels: where a flight lands.
func counter_position() -> Vector2:
	return coin_icon.get_global_rect().get_center()


## A coin from a world position to the counter: the flight lives on this layer, so the start is
## the camera's view of the world in screen pixels, clamped to the screen (a point out of view,
## the emperor's box in a wide arena or a corpse off screen, flies from the screen's edge).
func fly_coin(world_position: Vector2) -> void:
	var flight := CoinFlight.new()
	add_child(flight)
	flight.fly(flight_start(world_position), counter_position())


## Where a flight from `world_position` starts, in this layer's screen pixels.
func flight_start(world_position: Vector2) -> Vector2:
	var screen := get_viewport().get_visible_rect()
	return (get_viewport().get_canvas_transform() * world_position).clamp(screen.position, screen.end)
