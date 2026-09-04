class_name MuzzleFlash
extends Node2D
## A bright blob at the muzzle that shrinks away over a few frames.

const DURATION := 0.06


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), DURATION)
	tween.tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2(3, 0), 5.0, Color(1.0, 0.85, 0.4, 0.9))
	draw_circle(Vector2(3, 0), 2.5, Color(1.0, 1.0, 1.0))
