class_name WaveRunner
extends Node
## Drives a round's waves: places enemies through the Spawner on the WaveProgress schedule and
## counts deaths from the bus, but only for enemies in its own Room's container. Main hands it
## each round's table through start().

## Off, the runner neither places nor counts: tests keep the arena quiet with it, and Main turns
## it off on death so a bolt in flight cannot clear a round for a corpse.
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
	# Counts any death in this Room's container except the boss's summons, which never advance a
	# wave (they die with the boss).
	if not enabled or progress == null or enemy.get_parent() != enemies_parent or enemy.is_in_group("summoned"):
		return
	match progress.on_death():
		WaveProgress.Outcome.NEXT_WAVE:
			_announce_wave()
		WaveProgress.Outcome.CLEARED:
			Events.round_cleared.emit()


func _announce_wave() -> void:
	RunState.wave = progress.wave_index
	Events.wave_started.emit(progress.wave_index, progress.table.waves.size())
