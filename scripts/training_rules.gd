class_name TrainingRules
extends RefCounted
## The grounds' training lines, pure: what each rank costs, what a save can buy, what the ranks
## give a run at its start, and a purchase on a Save (money out, the rank up, the coins counted;
## no tree, no disk: the panel commits). A line is a row of LINES: its rank cap, the price of
## each rank, the first rank first, and its text (the short line the panel shows under the row's
## icon, naming what a rank buys: UI may name, never narrate). The three lines: hearts (a heart
## a rank), breath (a dash charge a rank), renown (starting favour a rank). Build.starting and
## RunState.start_run read apply(); nothing in a run reads the save again.

const LINES := {
	"hearts": {"ranks": 3, "prices": [50, 100, 200], "text": "One more heart"},
	"breath": {"ranks": 2, "prices": [80, 160], "text": "One more dash"},
	"renown": {"ranks": 3, "prices": [40, 80, 160], "text": "A warmer crowd"},
}
## What one rank gives: hearts are a heart (two hp), renown ten favour at the run's start.
const HP_PER_HEART := 2
const FAVOUR_PER_RENOWN := 10.0


static func max_rank(line: String) -> int:
	assert(LINES.has(line), "TrainingRules: no line '%s'" % line)
	return int(LINES[line]["ranks"])


## The line's text: what a rank buys, as the panel names it.
static func text(line: String) -> String:
	assert(LINES.has(line), "TrainingRules: no line '%s'" % line)
	return String(LINES[line]["text"])


## The price of the `rank`th rank (1 to max_rank).
static func price(line: String, rank: int) -> int:
	assert(rank >= 1 and rank <= max_rank(line), "TrainingRules: %s has no rank %d" % [line, rank])
	var prices: Array = LINES[line]["prices"]
	return int(prices[rank - 1])


## The rank the save holds in the line (0 when none bought).
static func rank(save: Save, line: String) -> int:
	assert(LINES.has(line), "TrainingRules: no line '%s'" % line)
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


## What the save's ranks give a run at its start: {max_hp, dash_charges, favour}.
static func apply(save: Save) -> Dictionary:
	return {
		"max_hp": Build.BASE_MAX_HP + HP_PER_HEART * rank(save, "hearts"),
		"dash_charges": Build.BASE_DASH_CHARGES + rank(save, "breath"),
		"favour": FavourRules.START + FAVOUR_PER_RENOWN * rank(save, "renown"),
	}
