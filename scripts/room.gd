class_name Room
extends Node2D
## The arena, one place for the whole run: tiles and walls solid on every side, the emperor's box
## set into the top wall, and the containers for enemies, projectiles, and spawning. Main sets
## width and height before adding it to the tree and hands its wave runner each round's table.
## The coin piles live here too, so they go with the Room: a new run starts with none.

var width: int = 28
var height: int = 15

@onready var arena: Arena = $Arena
@onready var emperor_box: EmperorBox = $EmperorBox
@onready var piles: Node2D = $Piles
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var spawner: Spawner = $Spawner
@onready var wave_runner: WaveRunner = $WaveRunner


func _ready() -> void:
	arena.build(width, height, [])
	emperor_box.setup(width, height)
	spawner.arena = arena
	spawner.enemies_parent = enemies
	spawner.projectiles_parent = projectiles
	wave_runner.spawner = spawner
	wave_runner.enemies_parent = enemies


func bounds() -> Rect2:
	return arena.bounds()


## bounds() in world space (the Room moves the arena with it), for what places things by world position.
func global_bounds() -> Rect2:
	var local := bounds()
	return Rect2(to_global(local.position), local.size)


func full_rect() -> Rect2:
	return arena.full_rect()


## Where the player stands at the start of a run: the centre of the floor.
func entry_position() -> Vector2:
	return bounds().get_center()
