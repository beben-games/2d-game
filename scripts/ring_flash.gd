class_name RingFlash
extends Node2D
## A white ring that grows and fades: the boss's ring attack and its death flash. Frees itself.
## The radius is tweened and redrawn rather than the node scaled, so the 2 px stroke stays 2 px
## and the segment count follows the radius instead of faceting as it grows.

var radius := 12.0
var color := Color(1, 1, 1, 0.8)
var grow := 8.0  ## the radius multiplies by this over duration
var duration := 0.15


func _ready() -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)  # the death flash plays through the kill freeze
	tween.set_parallel(true)
	tween.tween_method(_set_radius, radius, radius * grow, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)


func _set_radius(r: float) -> void:
	radius = r
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, maxi(32, int(radius)), color, 2.0)
