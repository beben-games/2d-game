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


## The rules' view of `node`'s viewport: bare_rect grown by MARGIN on every side.
static func rect(node: Node) -> Rect2:
	return bare_rect(node).grow(MARGIN)


## The visible world rect of `node`'s viewport, unshaken (the camera's offset taken out), the view
## as the drift began while the camera drifts. With no camera, the canvas transform's rect as it
## is. A node outside the tree has no view: an empty rect at the origin.
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
