class_name HeartRules
extends RefCounted
## Hearts on the HUD: two hp per heart, half hearts for odd hp. Also what the Heal card is worth.

const HP_PER_HEART := 2


## What Heal restores: half the max, rounded up to whole hearts (max 6 hp heals 2 hearts, 10
## heals 3), so it competes with a heart container instead of losing to it.
static func heal_amount(max_hp: int) -> int:
	return HP_PER_HEART * ceili(max_hp / float(HP_PER_HEART) / 2.0)


static func layout(hp: int, max_hp: int) -> Array[String]:
	var hearts: Array[String] = []
	var count := ceili(max_hp / float(HP_PER_HEART))
	for i in count:
		var left := clampi(hp - i * HP_PER_HEART, 0, HP_PER_HEART)
		hearts.append("full" if left == HP_PER_HEART else ("half" if left > 0 else "empty"))
	return hearts
