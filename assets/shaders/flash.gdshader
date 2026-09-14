shader_type canvas_item;

// 0 = normal sprite, 1 = solid white silhouette. Juice tweens this on hit.
// COLOR arrives as the texture times the sprite's modulate, so the spawn fade (alpha) and the
// status tints (rgb) show through; the flash whitens the rgb and keeps the alpha.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR = vec4(mix(COLOR.rgb, vec3(1.0), flash), COLOR.a);
}
