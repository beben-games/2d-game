class_name StoryLintInputs
extends RefCounted
## What StoryLint needs beside the story, gathered from the project's files: the word list (the
## story directory's lint_words.txt), and what it knows of the game: the merchants (a grounds
## station's keeper who stands nowhere as a person), the enemy ids (data/enemies/<id>.tres, the ids
## last_killer reads), and what each grounds door's condition reads. One place for the three that
## lint (tools/story_lint.gd, the Story tab, tests/test_story_data.gd), so StoryLint itself reads no
## file. Names no autoload and no Node class, and reads the rooms' resources by their properties
## (duck-typed `get`), never their methods: in the editor a non-tool resource script is a
## placeholder, whose exported values are there and whose methods are not.

const ENEMIES_DIR := "res://data/enemies"


## The lint of the catalog with the project's inputs, the word list from `story_dir`.
static func lint(catalog: StoryCatalog, story_dir := StoryCatalog.DATA_DIR) -> Dictionary:
	return StoryLint.run(catalog, words(story_dir), game())


## The word list in `story_dir` (StoryLint.parse_words); empty when there is no file.
static func words(story_dir := StoryCatalog.DATA_DIR) -> Array[String]:
	var path := story_dir.path_join(StoryLint.WORDS_FILE)
	return StoryLint.parse_words(FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "")


## StoryLint.run's `game`: {"merchants", "enemies", "reads"} from the rooms in `grounds_dir` (by
## GroundsRooms.IDS) and the enemies in `enemies_dir`.
static func game(grounds_dir := GroundsRooms.DIR, enemies_dir := ENEMIES_DIR) -> Dictionary:
	var keepers: Array[String] = []
	var people := {}
	var reads := {}
	for id in GroundsRooms.IDS:
		var path := "%s/%s.tres" % [grounds_dir, id]
		var room: Resource = load(path) if ResourceLoader.exists(path) else null
		if room == null:
			continue
		var kept: Variant = room.get("keepers")
		if kept is Dictionary:
			for station: Variant in kept:
				var keeper := str(kept[station])
				if not keepers.has(keeper):
					keepers.append(keeper)
		var standing: Variant = room.get("people")
		if standing is Dictionary:
			for person: Variant in standing:
				people[str(person)] = true
		var doors: Variant = room.get("doors")
		if doors is Array:
			for door: Variant in doors:
				_add_door(id, door, reads)
	var merchants: Array[String] = []
	for keeper in keepers:
		if not people.has(keeper):
			merchants.append(keeper)
	return {"merchants": merchants, "enemies": enemy_ids(enemies_dir), "reads": reads}


## Every enemy id: the names of the .tres files in `dir` (an enemy's id is its file's name, as the
## gate screen loads it), sorted.
static func enemy_ids(dir := ENEMIES_DIR) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "tres":
			out.append(file.get_basename())
	out.sort()
	return out


## The names a door's condition reads, under "door <room> -> <to>" (nothing for an empty or a bad
## condition: GroundsRooms reports a bad one).
static func _add_door(room_id: String, door: Variant, reads: Dictionary) -> void:
	if not door is Object:
		return
	var when := str((door as Object).get("when")).strip_edges()
	if when == "":
		return
	var condition: StoryCondition = StoryCondition.parse(when)["condition"]
	if condition == null:
		return
	var names := condition.names()
	for name in condition.right_names():
		if not names.has(name):
			names.append(name)
	reads["door %s -> %s" % [room_id, str((door as Object).get("to"))]] = names
