class_name UpgradeCatalog
extends RefCounted
## Every card and weapon on disk, by id, loaded once. The pool for a build is every card that
## still has a rank left, plus Heal when hurt and a Switch card for each other weapon; the draw
## takes distinct cards uniformly with the RNG it is given, so a seeded stream replays offers.

const UPGRADES_DIR := "res://data/upgrades"
const WEAPONS_DIR := "res://data/weapons"

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


## Cards the build may still take, in id order (a stable order is what makes the draw replayable).
static func pool(build: Build, hp: int, max_hp: int) -> Array[UpgradeDef]:
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
				offer = hp < max_hp
			UpgradeDef.Kind.SWITCH:
				offer = u.weapon_id != build.weapon_id
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
