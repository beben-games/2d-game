class_name UpgradeCatalog
extends RefCounted
## Every card and weapon on disk, by id, loaded once. The pool for a build is every card that
## still has a rank left and a Switch card for each weapon the run has not used yet (a weapon
## used this run is never offered again, so a switch is one-way), never Heal; the draw takes
## distinct cards uniformly with the RNG it is given, so a seeded stream replays offers, and
## offers() puts the heal card on the right while the right slot is held (right_slot_held).

const UPGRADES_DIR := "res://data/upgrades"
const WEAPONS_DIR := "res://data/weapons"
## The crowd at a Boo takes a boon, never the gladiator's life: true spares the heal card (the
## held right slot's card, and any Heal) from the lock; false lets the crowd take any card,
## the heal card included (lock_candidates).
const LOCK_SPARES_HEAL := true
## A lock is made only when at least this many cards stay pickable after it.
const LOCK_MIN_PICKABLE := 2

static var _upgrades: Dictionary = {}
static var _weapons: Dictionary = {}
static var _loaded := false


static func upgrades() -> Dictionary:
	_ensure_loaded()
	return _upgrades


static func upgrade(id: String) -> UpgradeDef:
	_ensure_loaded()
	assert(_upgrades.has(id), "UpgradeCatalog: no upgrade '%s'" % id)
	return _upgrades[id]


static func weapon(id: String) -> WeaponDef:
	_ensure_loaded()
	assert(_weapons.has(id), "UpgradeCatalog: no weapon '%s'" % id)
	return _weapons[id]


## Cards the build may still take, Heal excluded, in id order (a stable order is what makes the
## draw replayable). Heal joins the offers through offers(), never the pool.
static func pool(build: Build) -> Array[UpgradeDef]:
	_ensure_loaded()
	var ids := _upgrades.keys()
	ids.sort()
	var cards: Array[UpgradeDef] = []
	for id in ids:
		var u: UpgradeDef = _upgrades[id]
		var offer := false
		match u.kind:
			UpgradeDef.Kind.WEAPON:
				offer = u.weapon_id == build.weapon_id and build.rank_of(u.id) < u.max_rank
			UpgradeDef.Kind.PLAYER:
				offer = build.rank_of(u.id) < u.max_rank
			UpgradeDef.Kind.HEAL:
				offer = false
			UpgradeDef.Kind.SWITCH:
				offer = not build.has_used(u.weapon_id)
		if offer:
			cards.append(u)
	return cards


## Up to count distinct cards from the pool, uniformly. Fewer when the pool is smaller.
static func draw(from: Array[UpgradeDef], rng: RandomNumberGenerator, count: int = 3) -> Array[UpgradeDef]:
	var left := from.duplicate()
	var picked: Array[UpgradeDef] = []
	while picked.size() < count and not left.is_empty():
		picked.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
	return picked


## The cards for a clear: a draw of `count` from the Heal-free pool (three, one more on a Roar
## or per Offer rank) and, while the right slot is held (right_slot_held: no container owned yet,
## or the player hurt), the heal card in the last slot (the right card, so the eye knows where it
## is). A seed replays the other cards regardless of the slot's state. When the heal card is a
## container the draw already holds, it moves right and the card it displaces takes its slot, so
## no card shows twice.
static func offers(build: Build, hurt: bool, rng: RandomNumberGenerator, count: int = 3) -> Array[UpgradeDef]:
	var cards := draw(pool(build), rng, count)
	if not right_slot_held(build, hurt) or cards.is_empty():
		return cards
	var right := heal_card(build)
	var last := cards.size() - 1
	var at := cards.find(right)
	if at >= 0:
		cards[at] = cards[last]
	cards[last] = right
	return cards


## Which offered card the crowd takes at a Boo (FavourRules.lock_count gives `count`), as an
## index into `offers`, or -1 for none. The rule: no lock when `count` is 0 or below, or when
## fewer than LOCK_MIN_PICKABLE cards would stay pickable after it (so never with two cards or
## fewer, the heal card counted among the pickable); otherwise one card drawn uniformly from
## lock_candidates with `rng` (one draw; a count above one still locks one). A seeded stream
## replays it; the caller's stream is the lock's own, so the offers' draw is untouched.
## `right_held` is right_slot_held for the offer's build. Pure.
static func locked_index(offers: Array[UpgradeDef], count: int, rng: RandomNumberGenerator, right_held := false) -> int:
	if count <= 0 or offers.size() - 1 < LOCK_MIN_PICKABLE:
		return -1
	var candidates := lock_candidates(offers, right_held, LOCK_SPARES_HEAL)
	if candidates.is_empty():
		return -1
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## The slots the crowd may lock, in order. With `spare_heal` the heal card is never one: the
## right slot while it is held (`right_held`, right_slot_held; offers() keeps the heal card
## there: a heart container or Heal) and any Heal card wherever it sits; without it every slot
## is a candidate. Pure.
static func lock_candidates(offers: Array[UpgradeDef], right_held: bool, spare_heal: bool) -> Array[int]:
	var result: Array[int] = []
	for i in offers.size():
		var heal_card := offers[i].kind == UpgradeDef.Kind.HEAL or (right_held and i == offers.size() - 1)
		if spare_heal and heal_card:
			continue
		result.append(i)
	return result


## Whether the right slot holds the heal card: always until the build owns a heart container
## (the container sits there at every pick, hurt or not, until it is taken from any slot), and
## after that while the player is `hurt` (Heal). The one rule offers(), lock_candidates (through
## locked_index), UpgradeMenu.crowd_slot, and Main share, so they cannot disagree. Pure.
static func right_slot_held(build: Build, hurt: bool) -> bool:
	return hurt or build.rank_of("heart_container") == 0


## The right slot's card: a heart container until the build owns one (from any slot), so the
## first choice is never "heal or grow"; Heal after. Further containers stay regular cards in the
## pool (playtest 2).
static func heal_card(build: Build) -> UpgradeDef:
	var container := upgrade("heart_container")
	if build.rank_of(container.id) == 0:
		return container
	return upgrade("heal")


## An exported build converts every .tres to binary and lists it as `name.tres.remap`, so the
## suffix is stripped before the .tres check and `load` resolves the original path through the
## remap. Without the trim_suffix the catalog is empty in an export.
static func _ensure_loaded() -> void:
	if _loaded:
		return
	for file in DirAccess.get_files_at(UPGRADES_DIR):
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var u := load(UPGRADES_DIR.path_join(name)) as UpgradeDef
		assert(u != null, "UpgradeCatalog: %s is not an UpgradeDef" % name)
		var errors := u.validate()
		assert(errors.is_empty(), "UpgradeCatalog: %s: %s" % [name, ", ".join(errors)])
		assert(not _upgrades.has(u.id), "UpgradeCatalog: duplicate upgrade id '%s'" % u.id)
		_upgrades[u.id] = u
	for file in DirAccess.get_files_at(WEAPONS_DIR):
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var w := load(WEAPONS_DIR.path_join(name)) as WeaponDef
		assert(w != null, "UpgradeCatalog: %s is not a WeaponDef" % name)
		var errors := w.validate()
		assert(errors.is_empty(), "UpgradeCatalog: %s: %s" % [name, ", ".join(errors)])
		assert(not _weapons.has(w.id), "UpgradeCatalog: duplicate weapon id '%s'" % w.id)
		_weapons[w.id] = w
	for id in _upgrades:
		var u: UpgradeDef = _upgrades[id]
		if u.weapon_id != "":
			assert(_weapons.has(u.weapon_id), "UpgradeCatalog: %s names unknown weapon '%s'" % [id, u.weapon_id])
	_upgrades.make_read_only()
	_weapons.make_read_only()
	_loaded = true
