class_name HeartRules
extends RefCounted
## Hearts on the HUD: two hp per heart, half hearts for odd hp.


static func layout(hp: int, max_hp: int) -> Array[String]:
	var hearts: Array[String] = []
	var count := int(ceil(max_hp / 2.0))
	for i in count:
		var left := clampi(hp - i * 2, 0, 2)
		hearts.append("full" if left == 2 else ("half" if left == 1 else "empty"))
	return hearts
