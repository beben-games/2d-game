class_name BossFight
extends RefCounted
## A boss fight may be several bodies (M7): the bodies of the group `boss` in the tree. The fight
## goes on while any body stands, and what ends it (the piles, the fight's clock, the profile's
## kill, the summons' death, the favour's last kill) waits for the last body. A body stands while
## its Health is not dead (a corpse stays in the group; a node with no Health is no body).
## Duck-typed on the group and the Health child (never naming a Node class), so the autoloads
## (Profile, Audio) may ask it.

const GROUP := "boss"


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
