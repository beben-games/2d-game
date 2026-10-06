class_name BannerRing
extends Node2D
## The standard-bearer's banner, seen: a soft ring on the floor of the banner's radius, and the
## banner it carries on a pole over its head. No text: the ring shows the reach, the tint on the
## covered (StatusEffects.HASTE_TINT) shows who is inside it.
##
## The ring is laid on the floor under every body: the bearer puts it beside itself, first among
## its siblings (Enemy._lay_ring), and it follows the bearer each frame. The carried banner is the
## bearer's own child (carried()), drawn over its sprite.

const CLOTH := Color8(218, 78, 56)  ## the banner's red (wall_banner_red's cloth)
const RING_ALPHA := 0.4  ## the ring's line
const DISC_ALPHA := 0.06  ## the faint floor inside it
const RING_WIDTH := 1.0  ## world px (3 screen px at the 3x zoom)
const RING_POINTS := 96
## The carried banner: a pole from the hand up past the head, the cloth hung from its top.
const POLE_FOOT := Vector2(-6, 2)
const POLE_TOP := Vector2(-6, -27)
const POLE_COLOR := Color8(92, 62, 44)
const POLE_WIDTH := 1.0
const CLOTH_AT := Vector2(-6, -20)  ## the cloth's centre (its sprite's 16 px tile; the cloth hangs within it)
## Keeping wall_banner_red's cloth and pins off its wall: a pixel is kept when saturated or light.
const KEY_SATURATION := 60.0 / 255.0
const KEY_LIGHT := 150.0 / 255.0
const OUTLINE := Color8(34, 34, 34)

var radius := 140.0
var bearer: Node2D  ## followed each frame; the ring frees itself when it is gone


func _process(_delta: float) -> void:
	if not is_instance_valid(bearer):
		queue_free()
		return
	global_position = bearer.global_position


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(CLOTH, DISC_ALPHA))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, RING_POINTS, Color(CLOTH, RING_ALPHA), RING_WIDTH)


## The banner the bearer carries: a pole and the cloth, facing right (scale.x -1 faces left).
static func carried() -> Node2D:
	var banner := Node2D.new()
	banner.name = "Banner"
	var pole := Line2D.new()
	pole.points = PackedVector2Array([POLE_FOOT, POLE_TOP])
	pole.width = POLE_WIDTH
	pole.default_color = POLE_COLOR
	banner.add_child(pole)
	var cloth := Sprite2D.new()
	cloth.texture = cloth_texture()
	cloth.position = CLOTH_AT
	banner.add_child(cloth)
	return banner


## wall_banner_red without its wall: the cloth's and the pins' pixels kept, a dark outline round
## them, the rest clear. Built from the tileset's tile by name for each bearer (a 16 px tile).
static func cloth_texture() -> Texture2D:
	var tile := SpriteAtlas.texture("wall_banner_red")
	var source := tile.atlas.get_image()
	if source.is_compressed():
		source.decompress()
	var region := Rect2i(tile.region)
	var size := region.size
	var keep := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var kept := {}
	for y in size.y:
		for x in size.x:
			var c := source.get_pixel(region.position.x + x, region.position.y + y)
			var saturation := maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b))
			if saturation > KEY_SATURATION or minf(c.r, minf(c.g, c.b)) > KEY_LIGHT:
				keep.set_pixel(x, y, c)
				kept[Vector2i(x, y)] = true
	for y in size.y:
		for x in size.x:
			if kept.has(Vector2i(x, y)):
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if kept.has(Vector2i(x, y) + d):
					keep.set_pixel(x, y, OUTLINE)
					break
	return ImageTexture.create_from_image(keep)
