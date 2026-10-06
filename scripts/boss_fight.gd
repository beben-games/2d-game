class_name BossFight
extends RefCounted
## A boss fight may be several bodies (M7): the bodies of the group `boss` in the tree, placed by
## one wave of their round (RoundDef.validate refuses a round whose bodies are split across waves).
## The fight goes on while any body stands, and what ends it (the piles, the fight's clock, the
## profile's kill, the summons' death, the favour's last kill) waits for the last body. A body
## stands while its Health is not dead (a corpse stays in the group; a node with no Health is no
## body). A body's scene carries the group in its file (is_boss_scene reads it there, never
## instancing the scene: the wave's seats, the round's health); RoundDef.validate refuses a scene
## that runs the boss's script without it.
## Duck-typed on the group and the Health child (never naming a Node class), so the autoloads
## (Profile, Audio) may ask it.

const GROUP := "boss"
## The boss's script's global name: a scene whose root runs it is a boss's body.
const BOSS_SCRIPT_NAME := &"Boss"


## The standing bodies of the fight, `except` left out (the body dying now, or the asker).
static func living(tree: SceneTree, except: Node = null) -> Array[Node2D]:
	var out: Array[Node2D] = []
	if tree == null:
		return out
	for node in tree.get_nodes_in_group(GROUP):
		if node == except or not node is Node2D or node.is_queued_for_deletion():
			continue
		var health := node.get_node_or_null("Health")
		if health != null and not bool(health.get("dead")):
			out.append(node)
	return out


## True when no body but `body` stands: its death ends the fight (out of the tree, nothing to
## compare: true).
static func is_last(body: Node) -> bool:
	return living(body.get_tree() if body.is_inside_tree() else null, body).is_empty()


## True when another body of the fight is already active (harmful): its arrival opened the fight.
static func another_active(body: Node) -> bool:
	if not body.is_inside_tree():
		return false
	for other in living(body.get_tree(), body):
		if other.has_method("is_harmful") and other.call("is_harmful"):
			return true
	return false


## True when `scene`'s root is in the group `boss` in its file (or in a scene it inherits).
static func is_boss_scene(scene: PackedScene) -> bool:
	var state := scene.get_state() if scene != null else null
	while state != null:
		if state.get_node_count() > 0 and state.get_node_groups(0).has(GROUP):
			return true
		state = state.get_base_scene_state()
	return false


## True when `scene`'s root runs the boss's script (or a script extending it), in its file or a
## scene it inherits.
static func runs_the_boss_script(scene: PackedScene) -> bool:
	var script := _root_property(scene, &"script") as Script
	while script != null:
		if script.get_global_name() == BOSS_SCRIPT_NAME:
			return true
		script = script.get_base_script()
	return false


## How many of `scenes` are a boss's body (is_boss_scene): a wave's fight, seated by the Spawner.
static func boss_count(scenes: Array[PackedScene]) -> int:
	var n := 0
	for scene in scenes:
		if is_boss_scene(scene):
			n += 1
	return n


## The summed max hp of the boss bodies a round's table sends (each body's def, read from its
## scene's file): the fight's health from the round's start. 0 for a round with none.
static func table_max_hp(table: WaveTable) -> float:
	var summed := 0.0
	if table == null:
		return summed
	for wave in table.waves:
		if wave == null:
			continue
		for group in wave.groups:
			if group == null or not is_boss_scene(group.enemy):
				continue
			var def := _root_property(group.enemy, &"def") as Resource
			if def != null:
				summed += float(def.get("max_hp")) * group.count
	return summed


## The value the root node of `scene` sets for `property`, from its file or a scene it inherits
## (the nearest wins); null when none does.
static func _root_property(scene: PackedScene, property: StringName) -> Variant:
	var state := scene.get_state() if scene != null else null
	while state != null:
		if state.get_node_count() > 0:
			for i in state.get_node_property_count(0):
				if state.get_node_property_name(0, i) == property:
					return state.get_node_property_value(0, i)
		state = state.get_base_scene_state()
	return null
