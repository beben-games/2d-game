class_name View
extends RefCounted
## "On screen" for the arena's fairness rules: the visible world rect, read from the viewport (the
## only place the rules touch it; ViewRules does the geometry). Three choices, each so that a rule
## never depends on something cosmetic:
## - The shake is not in it: the camera's offset (Juice's shake, drawn from the global RNG) is
##   taken back out, so where a shot dies or bounces never depends on a cosmetic draw, and tier 1's
##   walls stay inside the edge at the largest shake (see MARGIN).
## - Through the verdict's drift and zoom it is the view as the drift began (Camera.held_view):
##   no shot dies because the camera zoomed in on the emperor's box.
## - The lean (the aim) is in it: the view follows the aim, and so does the edge.
## A hitstop changes nothing here (the canvas does not move with time scale); under a pause nothing
## steps, so nothing reads it.

## The rules' edge sits a tile outside the screen. Tier 1's arena is 448 px wide and the view
## 426.7, so with the camera at either side the far edge of the screen is 21.3 px inside the
## arena's edge, 5.3 px inside the wall tile's face: the margin puts the wall face back inside the
## rules' view by 10.7 px, so the wall's raycast still takes every shot there.
const MARGIN := 16.0
## How far past the screen's edge a body's centre still counts as on the screen for rule 2
## (on_screen), px. Tier 1 needs at least 0.34 px: a body pressed on a side wall has its centre at
## x 21 (the wall's face at 16 plus its radius) while the screen's left edge can sit at 21.33 (the
## camera at the right limit); 4 px keeps such a body on screen with room, and keeps a wind-up from
## beginning with the body a tile off the screen, as the margin would.
const SIGHT_SLACK := 4.0


## The rules' view of `node`'s viewport: bare_rect grown by MARGIN on every side. A node outside
## the tree has none: the empty rect, not grown, which contains nothing (ViewRules.contains), so a
## caller must be in the tree.
static func rect(node: Node) -> Rect2:
	var bare := bare_rect(node)
	return bare.grow(MARGIN) if bare.has_area() else bare


## Rule 2's "on the screen": `node`'s centre inside bare_rect grown by `slack` (the screen itself,
## unshaken, held through the drift), not View.rect's margin, so nothing winds up from a tile past
## the screen's edge. False for a node outside the tree (its view is empty).
static func on_screen(node: Node2D, slack := SIGHT_SLACK) -> bool:
	var bare := bare_rect(node)
	if not bare.has_area():
		return false
	return ViewRules.contains(bare.grow(slack), node.global_position)


## The visible world rect of `node`'s viewport, unshaken (the camera's offset taken out), the view
## as the drift began while the camera drifts. With no camera, the canvas transform's rect as it
## is. A node outside the tree has no view: the empty rect, which contains nothing.
static func bare_rect(node: Node) -> Rect2:
	var viewport := node.get_viewport()
	if viewport == null:
		return Rect2()
	var camera := viewport.get_camera_2d()
	# Duck-typed (camera.gd names Player, whose scene preloads the projectile that reads this).
	if camera != null and camera.get("drifting") == true:
		return camera.get("held_view")
	var seen := viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()
	if camera != null:
		seen.position -= camera.offset
	return seen
