extends Area2D
## The room-clear reward: heals one heart on touch. Stays until taken, so a full player can
## leave it and come back after the next hit (within the same room).

const HEAL := 2  ## one heart; HeartRules draws two hp per heart
const POP_TIME := 0.2

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	sprite.texture = SpriteAtlas.texture("ui_heart_full")
	body_entered.connect(_on_body_entered)
	sprite.scale = Vector2(0.2, 0.2)
	var pop := create_tween()
	pop.tween_property(sprite, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player != null and player.heal(HEAL):
		set_deferred("monitoring", false)
		queue_free()
