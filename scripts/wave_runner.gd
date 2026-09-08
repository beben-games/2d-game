class_name WaveRunner
extends Node
## Drives a room's waves: places enemies through the Spawner on the WaveProgress schedule and
## counts deaths from the bus, but only for enemies in its own room's container.

## Tests set this false right after instancing the main scene to keep the room quiet.
@export var enabled := true

var spawner: Spawner
var enemies_parent: Node
var progress: WaveProgress


func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)


func _exit_tree() -> void:
	if Events.enemy_died.is_connected(_on_enemy_died):
		Events.enemy_died.disconnect(_on_enemy_died)


func start(table: WaveTable) -> void:
	progress = WaveProgress.new(table)
	_announce_wave()


func _physics_process(delta: float) -> void:
	if not enabled or progress == null:
		return
	var scene := progress.tick(delta)
	if scene != null:
		spawner.spawn(scene)


func _on_enemy_died(enemy: Node2D, _death_position: Vector2) -> void:
	if progress == null or enemy.get_parent() != enemies_parent:
		return
	match progress.on_death():
		WaveProgress.Outcome.NEXT_WAVE:
			_announce_wave()
		WaveProgress.Outcome.CLEARED:
			Events.room_cleared.emit()


func _announce_wave() -> void:
	RunState.wave = progress.wave_index
	Events.wave_started.emit(progress.wave_index, progress.table.waves.size())
