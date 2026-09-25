class_name CoinFlight
extends Sprite2D
## A coin on the HUD layer flying from where it was earned (a corpse, the emperor's box) to the
## counter. Cosmetic: the coins were counted when it left; its arrival is the coin_get sound. It
## flies through a kill freeze (the time scale is ignored) and pauses with the tree like the
## rest of the HUD.

const FLIGHT_TIME := 0.45
const SCALE := 3.0  ## the counter's own scale, so the coin lands at its size


func _init() -> void:
	texture = SpriteAtlas.texture("coin_anim")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(SCALE, SCALE)


## From `from` to `to`, both in the HUD's screen pixels, gathering speed on the way. Call once
## the node is in the tree.
func fly(from: Vector2, to: Vector2) -> void:
	position = from
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(self, "position", to, FLIGHT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_arrive)


func _arrive() -> void:
	Events.coin_landed.emit()
	queue_free()
