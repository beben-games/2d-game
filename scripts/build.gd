class_name Build
extends RefCounted
## The run's loadout: the weapon and every upgrade rank taken. Pure: resolve() folds the weapon
## upgrades over a base WeaponDef into a fresh copy, and max_hp()/dash_charges() fold the player
## upgrades over the base numbers. Nothing here touches the tree or mutates a .tres.
## Catalogs are Dictionaries of upgrade id -> UpgradeDef (UpgradeCatalog.upgrades(), or a test's).
## resolve trusts a validated catalog: an unknown stat name would be a silent no-op through
## Object.set, and UpgradeDef.validate plus the catalog's load-time validation are what prevent it.

const BASE_MAX_HP := 6
const BASE_DASH_CHARGES := 1
const STARTING_WEAPON := "handgun"

var weapon_id: String = STARTING_WEAPON
## Insertion-ordered: upgrade id -> rank. Godot Dictionaries keep insertion order.
var weapon_ranks: Dictionary = {}
var player_ranks: Dictionary = {}


func rank_of(id: String) -> int:
	return int(weapon_ranks.get(id, player_ranks.get(id, 0)))


## Raises the card's rank by one, up to its cap. HEAL and SWITCH cards never enter the build.
func add_rank(upgrade: UpgradeDef) -> void:
	if upgrade.kind == UpgradeDef.Kind.HEAL or upgrade.kind == UpgradeDef.Kind.SWITCH:
		return
	var ranks := player_ranks if upgrade.kind == UpgradeDef.Kind.PLAYER else weapon_ranks
	var current := int(ranks.get(upgrade.id, 0))
	if current < upgrade.max_rank:
		ranks[upgrade.id] = current + 1


## Total weapon upgrade ranks: what a switch refunds.
func weapon_upgrade_count() -> int:
	var n := 0
	for id in weapon_ranks:
		n += int(weapon_ranks[id])
	return n


## Swaps the weapon and forgets its upgrades. Returns how many picks the caller owes the player.
func switch_weapon(new_weapon_id: String) -> int:
	var refund := weapon_upgrade_count()
	weapon_ranks = {}
	weapon_id = new_weapon_id
	return refund


func owned_weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in weapon_ranks:
		ids.append(id)
	return ids


func owned_player_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in player_ranks:
		ids.append(id)
	return ids


## The weapon the player fires: base with every owned weapon upgrade folded in, rank by rank.
func resolve(base: WeaponDef, catalog: Dictionary) -> WeaponDef:
	var def: WeaponDef = base.duplicate()
	for id in weapon_ranks:
		var upgrade: UpgradeDef = catalog[id]
		for _r in int(weapon_ranks[id]):
			for m in upgrade.modifiers:
				var value := _apply(float(def.get(m.stat)), m)
				def.set(m.stat, roundi(value) if m.stat in Modifier.INT_STATS else value)
	var errors := def.validate()
	assert(errors.is_empty(), "Build.resolve produced an invalid weapon: %s" % ", ".join(errors))
	return def


func max_hp(catalog: Dictionary) -> int:
	return _fold_player("max_hp", BASE_MAX_HP, catalog)


func dash_charges(catalog: Dictionary) -> int:
	return _fold_player("dash_charges", BASE_DASH_CHARGES, catalog)


func _fold_player(stat: String, base: int, catalog: Dictionary) -> int:
	var value := float(base)
	for id in player_ranks:
		var upgrade: UpgradeDef = catalog[id]
		for _r in int(player_ranks[id]):
			for m in upgrade.modifiers:
				if m.stat == stat:
					value = _apply(value, m)
	return int(value)


## One modifier on one value, rounded when the stat is an int.
func _apply(value: float, m: Modifier) -> float:
	var v := m.apply(value)
	return float(roundi(v)) if m.stat in Modifier.INT_STATS else v
