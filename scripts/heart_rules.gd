class_name HeartRules
extends RefCounted
## Hearts on the HUD: two hp per heart, half hearts for odd hp.

const HP_PER_HEART := 2


static func layout(hp: int, max_hp: int) -> Array[String]:
	var hearts: Array[String] = []
	var count := int(ceil(max_hp / float(HP_PER_HEART)))
	for i in count:
		var left := clampi(hp - i * HP_PER_HEART, 0, HP_PER_HEART)
		hearts.append("full" if left == HP_PER_HEART else ("half" if left == 1 else "empty"))
	return hearts
