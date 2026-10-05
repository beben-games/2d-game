class_name Tiers
extends RefCounted
## The tiers by id, each a shipped series at data/series/tier_<id>.tres, loaded once. The ids are
## a list here, not a directory listing (an exported build reads its resources by name): a new
## tier is added there. The first load checks every tier (its series loads, validates, and says it
## is that tier) and pushes each fault, so check_boot fails on bad content. An id not listed is no
## tier: has() is false and series() null, with nothing pushed (the caller decides). Pure: no
## autoload, no Node class.

const DIR := "res://data/series"
const IDS: Array[int] = [1]

static var _series: Dictionary = {}
static var _loaded := false


## Where tier `tier`'s series lives (whether or not it exists).
static func path(tier: int) -> String:
	return "%s/tier_%d.tres" % [DIR, tier]


static func has(tier: int) -> bool:
	return tier in IDS and series(tier) != null


## Tier `tier`'s series, or null for an id that is no tier (or whose file failed to load).
static func series(tier: int) -> SeriesDef:
	if not tier in IDS:
		return null
	_ensure_loaded()
	return _series.get(tier) as SeriesDef


## What is wrong with the shipped tiers (empty when nothing is).
static func check() -> PackedStringArray:
	_ensure_loaded()
	var out := PackedStringArray()
	for id in IDS:
		out.append_array(errors_of(id, _series.get(id) as SeriesDef))
	return out


## What is wrong with `def` as tier `tier`'s series: missing, invalid, or naming another tier.
static func errors_of(tier: int, def: SeriesDef) -> PackedStringArray:
	var out := PackedStringArray()
	if def == null:
		out.append("tier %d: no series at %s" % [tier, path(tier)])
		return out
	for e in def.validate():
		out.append("tier %d: %s" % [tier, e])
	if def.tier != tier:
		out.append("tier %d: the series says tier %d" % [tier, def.tier])
	return out


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for id in IDS:
		var def := load(path(id)) as SeriesDef
		if def != null:
			_series[id] = def
	for e in check():
		push_error("Tiers: %s" % e)
