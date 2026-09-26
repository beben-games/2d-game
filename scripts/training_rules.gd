class_name TrainingRules
extends RefCounted
## The grounds' training lines, pure: what each rank costs, what a save can buy, what the ranks
## give a run at its start, and a purchase on a Save (money out, the rank up, the coins counted;
## no tree, no disk: the panel commits). A line is a row of LINES: its rank cap, the price of
## each rank, the first rank first, its text (the short line the panel shows under the row's
## icon, naming what a rank buys: UI may name, never narrate), and its icon's name. The lines
## buy what a run cannot give (playtest 1, note 11): offer (one more card in every offer),
## reroll (a re-draw of an offer, once a run per rank), mercy (the emperor spares you once a
## run: the fall becomes one heart), reach (a wider coin pull). RunState.start_run reads
## apply(); nothing in a run reads the save again. A save from rc1 may still hold the old
## lines (hearts, breath, renown): rank() reads any key and finds nothing for one not in LINES.

const LINES := {
	"offer": {"ranks": 2, "prices": [120, 240], "text": "One more card to choose from", "icon": "card"},
	"reroll": {"ranks": 2, "prices": [100, 200], "text": "Change the cards once a run", "icon": "clover"},
	"mercy": {"ranks": 1, "prices": [300], "text": "Fall once and fight on", "icon": "heal"},
	"reach": {"ranks": 3, "prices": [40, 80, 160], "text": "Coins come from further", "icon": "coin"},
}
## The icon name that means the tileset's coin (a sprite, not a Raven icon): the panel draws it
## through SpriteAtlas, every other name through IconAtlas.
const COIN_ICON := "coin"
## What one Reach rank adds to the pull's reach (PileRules.PULL_RADIUS), in pixels.
const REACH_STEP := 32.0


static func max_rank(line: String) -> int:
	assert(LINES.has(line), "TrainingRules: no line '%s'" % line)
	return int(LINES[line]["ranks"])


## The line's text: what a rank buys, as the panel names it.
static func text(line: String) -> String:
	assert(LINES.has(line), "TrainingRules: no line '%s'" % line)
	return String(LINES[line]["text"])


## The line's icon name (COIN_ICON for the tileset's coin).
static func icon(line: String) -> String:
	assert(LINES.has(line), "TrainingRules: no line '%s'" % line)
	return String(LINES[line]["icon"])


## The price of the `rank`th rank (1 to max_rank).
static func price(line: String, rank: int) -> int:
	assert(rank >= 1 and rank <= max_rank(line), "TrainingRules: %s has no rank %d" % [line, rank])
	var prices: Array = LINES[line]["prices"]
	return int(prices[rank - 1])


## The rank the save holds in the line (0 when none bought, and 0 for a line not in LINES: an
## older save's ranks stay on it and count for nothing).
static func rank(save: Save, line: String) -> int:
	if not LINES.has(line):
		return 0
	return int(save.training.get(line, 0))


static func capped(save: Save, line: String) -> bool:
	return rank(save, line) >= max_rank(line)


## The price of the next rank; 0 when the line is capped (nothing to buy).
static func next_price(save: Save, line: String) -> int:
	return 0 if capped(save, line) else price(line, rank(save, line) + 1)


## True when the line has a rank left and the save's money covers it.
static func can_buy(save: Save, line: String) -> bool:
	return not capped(save, line) and save.money >= next_price(save, line)


## Buys the next rank: the price out of the money, the rank up, the coins counted as spent.
## Returns the price paid. Asserts can_buy: the caller checks and refuses first.
static func buy(save: Save, line: String) -> int:
	assert(can_buy(save, line), "TrainingRules: cannot buy %s" % line)
	var paid := next_price(save, line)
	save.money -= paid
	save.training[line] = rank(save, line) + 1
	save.add_stat("coins_spent", paid)
	return paid


## What the save's ranks give a run at its start: {offer_bonus, rerolls, mercies, pull_radius}.
static func apply(save: Save) -> Dictionary:
	return {
		"offer_bonus": rank(save, "offer"),
		"rerolls": rank(save, "reroll"),
		"mercies": rank(save, "mercy"),
		"pull_radius": PileRules.PULL_RADIUS + REACH_STEP * rank(save, "reach"),
	}
