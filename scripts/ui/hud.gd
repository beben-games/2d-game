extends CanvasLayer
## Hearts, room, wave, and kills. Reads the player once at ready, then follows the bus.

const HEART_SCALE := 3.0

## Placeholders until Main's _ready emits room_entered and wave_started; the HUD is a child of Main, so it is connected first.
var _room := 0
var _rooms := 1
var _wave := 0
var _waves := 1

@onready var hearts: HBoxContainer = $Hearts
@onready var info: Label = $Info


func _ready() -> void:
	Events.player_hit.connect(_on_player_hit)
	Events.player_healed.connect(_on_player_healed)
	Events.wave_started.connect(_on_wave_started)
	Events.room_entered.connect(_on_room_entered)
	Events.enemy_died.connect(_on_enemy_died)
	var player: Player = get_tree().get_first_node_in_group("player")
	if player != null:
		_set_hearts(player.hp, Player.MAX_HP)
	_refresh_info()


func _exit_tree() -> void:
	if Events.player_hit.is_connected(_on_player_hit):
		Events.player_hit.disconnect(_on_player_hit)
	if Events.player_healed.is_connected(_on_player_healed):
		Events.player_healed.disconnect(_on_player_healed)
	if Events.wave_started.is_connected(_on_wave_started):
		Events.wave_started.disconnect(_on_wave_started)
	if Events.room_entered.is_connected(_on_room_entered):
		Events.room_entered.disconnect(_on_room_entered)
	if Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.disconnect(_on_enemy_died)


func _set_hearts(hp: int, max_hp: int) -> void:
	for child in hearts.get_children():
		hearts.remove_child(child)
		child.queue_free()
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
