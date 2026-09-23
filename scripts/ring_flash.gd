class_name RingFlash
extends Node2D
## A white ring that scales out and fades: the boss's ring attack and its death flash. Frees itself.

var radius := 12.0
var color := Color(1, 1, 1, 0.8)
var grow := 8.0
var duration := 0.15


func _ready() -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)  # the death flash plays through the kill freeze
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(grow, grow), duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 2.0)
