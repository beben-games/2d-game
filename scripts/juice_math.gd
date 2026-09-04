class_name JuiceMath
extends RefCounted
## Pure math behind screen shake. Trauma is 0..1; shake scales with trauma squared so small hits
## barely register and big ones land hard.


static func shake_offset(trauma: float, max_offset: float, rx: float, ry: float) -> Vector2:
	var t := clampf(trauma, 0.0, 1.0)
	return Vector2(rx, ry) * max_offset * t * t


static func decay(trauma: float, rate: float, delta: float) -> float:
	return maxf(trauma - rate * delta, 0.0)
