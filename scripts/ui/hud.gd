extends CanvasLayer
## Hearts, dash pips, room, wave, kills, and the build strip (weapon icon, then every owned
## upgrade with its rank). Reads the player once at ready, then follows the bus.

const HEART_SCALE := 3.0
const ICON_SCALE := 3.0
const PIP_SIZE := Vector2(18, 10)
const PIP_LIT := Color(0.6, 0.9, 1.0)
const PIP_DIM := Color(0.25, 0.3, 0.35)
const RANK_FONT_SIZE := 18

## Placeholders until Main's _ready emits room_entered and wave_started; the HUD is a child of Main, so it is connected first.
var _room := 0
var _rooms := 1
var _wave := 0
var _waves := 1

@onready var hearts: HBoxContainer = $Hearts
@onready var dashes: HBoxContainer = $Dashes
@onready var info: Label = $Info
@onready var build_strip: HBoxContainer = $BuildStrip


func _ready() -> void:
	Events.player_hit.connect(_on_player_hit)
	Events.player_healed.connect(_on_player_healed)
	Events.wave_started.connect(_on_wave_started)
	Events.room_entered.connect(_on_room_entered)
	Events.enemy_died.connect(_on_enemy_died)
	Events.build_changed.connect(_refresh_build)
	Events.dash_charges_changed.connect(_set_dashes)
	var player: Player = get_tree().get_first_node_in_group("player")
	if player != null:
		_set_hearts(player.hp, player.max_hp)
		_set_dashes(player.dash_charges, player.max_dash_charges)
	_refresh_info()
	_refresh_build()


func _exit_tree() -> void:
	for pair: Array in [
		[Events.player_hit, _on_player_hit], [Events.player_healed, _on_player_healed],
		[Events.wave_started, _on_wave_started], [Events.room_entered, _on_room_entered],
		[Events.enemy_died, _on_enemy_died], [Events.build_changed, _refresh_build],
		[Events.dash_charges_changed, _set_dashes],
	]:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)


func _set_hearts(hp: int, max_hp: int) -> void:
	_clear(hearts)
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
	_clear(dashes)
	for i in max_charges:
		var pip := ColorRect.new()
		var lit := i < charges
		pip.name = "%s%d" % ["lit" if lit else "dim", i]
		pip.custom_minimum_size = PIP_SIZE
		pip.color = PIP_LIT if lit else PIP_DIM
		dashes.add_child(pip)


## The weapon icon, then each owned weapon upgrade, then each player upgrade, with rank digits.
func _refresh_build() -> void:
	_clear(build_strip)
	var build := RunState.build
	var catalog := UpgradeCatalog.upgrades()
	var weapon := IconAtlas.rect(UpgradeCatalog.weapon(build.weapon_id).icon, ICON_SCALE)
	weapon.name = "Weapon"
	build_strip.add_child(weapon)
	for id in build.owned_weapon_ids():
		build_strip.add_child(_slot("W_" + id, catalog[id].icon, build.rank_of(id)))
	for id in build.owned_player_ids():
		build_strip.add_child(_slot("P_" + id, catalog[id].icon, build.rank_of(id)))


func _slot(slot_name: String, icon: String, rank: int) -> Control:
	var slot := IconAtlas.rect(icon, ICON_SCALE)
	slot.name = slot_name
	var rank_label := Label.new()
	rank_label.name = "Rank"
	rank_label.text = str(rank)
	rank_label.add_theme_font_size_override("font_size", RANK_FONT_SIZE)
	rank_label.add_theme_color_override("font_outline_color", Color.BLACK)
	rank_label.add_theme_constant_override("outline_size", 4)
	rank_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	rank_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rank_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slot.add_child(rank_label)
	return slot


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _refresh_info() -> void:
	info.text = "Room %d/%d   Wave %d/%d   Kills %d" % [_room + 1, _rooms, _wave + 1, _waves, RunState.kills]


func _on_player_hit(_damage: int, hp: int, max_hp: int) -> void:
	_set_hearts(hp, max_hp)


func _on_player_healed(hp: int, max_hp: int) -> void:
	_set_hearts(hp, max_hp)


func _on_wave_started(index: int, total: int) -> void:
	_wave = index
	_waves = total
	_refresh_info()


func _on_room_entered(index: int, total: int) -> void:
	_room = index
	_rooms = total
	_refresh_info()


## RunState (an autoload) connected to enemy_died before this node, so kills is already incremented here.
func _on_enemy_died(_enemy: Node2D, _at: Vector2) -> void:
	_refresh_info()
