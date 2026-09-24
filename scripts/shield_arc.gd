class_name ShieldArc
extends Node2D
## The drawn side of an enemy's shield: a thick arc of pale steel across the covered angle, at a
## radius just outside the body, so the player reads which side is safe to shoot. Enemy adds it
## as a child and turns its rotation with `facing`; `arc_degrees` is the def's. Cosmetic only:
## the blocking is Enemy.blocks_shot. The user may supply a shield sprite later to replace it.

const RADIUS := 9.0  ## the body circle is 5 px; the imp sprite about 8
const WIDTH := 2.0
const COLOR := Color(0.8, 0.85, 0.9)
const RIM := Color(0.45, 0.5, 0.6)  ## a darker line on the outside so the arc reads on the pale floor
const POINTS := 24

var arc_degrees := 180.0:
	set(value):
		arc_degrees = value
		queue_redraw()


func _draw() -> void:
	var half := deg_to_rad(arc_degrees) / 2.0
	draw_arc(Vector2.ZERO, RADIUS + WIDTH * 0.75, -half, half, POINTS, RIM, 1.0)
	draw_arc(Vector2.ZERO, RADIUS, -half, half, POINTS, COLOR, WIDTH)
