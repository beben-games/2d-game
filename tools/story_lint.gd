extends SceneTree
## The story's lint, headless: loads the story (data/story, or the res:// directory given after
## `--`), runs StoryLint with the project's inputs (StoryLintInputs: the word list, the stations'
## keepers, the enemy ids, the doors' conditions), and prints the catalog's errors, the warnings,
## the flag map, and the placeholder count, then the summary line `STORY_LINT errors=<n>
## warnings=<n> placeholders=<n>/<n>`. Quits 1 when the story has an error, 0 otherwise (warnings
## alone are not a failure). Usage: tools/story_lint.sh [res://dir]. Names only the pure story
## classes (no autoload, no Node class: it runs before the autoloads), and quits on every path.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if not args.is_empty() else StoryCatalog.DATA_DIR
	if not DirAccess.dir_exists_absolute(dir):
		push_error("story_lint: no directory %s" % dir)
		quit(1)
		return
	var catalog := StoryCatalog.load_dir(dir)
	var result := StoryLintInputs.lint(catalog, dir)
	var errors: Array = result["errors"]
	var warnings: Array = result["warnings"]
	var flag_map: Dictionary = result["flag_map"]
	print("Story: %s, %d events" % [dir, catalog.events.size()])
	print("")
	print("Errors (%d)" % errors.size())
	for message: String in errors:
		print("  " + message)
	print("")
	print("Warnings (%d)" % warnings.size())
	for warning: Dictionary in warnings:
		print("  [%s] %s" % [warning["kind"], warning["message"]])
	print("")
	print("Flags (%d)" % flag_map.size())
	for flag: String in flag_map:
		print("  %s = %s" % [flag, str(catalog.flags.get(flag))])
		print("    set by: " + _list(flag_map[flag]["set"]))
		print("    read by: " + _list(flag_map[flag]["read"]))
	print("")
	print("Placeholders: %d of %d lines and choices" % [result["placeholders"], result["texts"]])
	print("STORY_LINT errors=%d warnings=%d placeholders=%d/%d" % [errors.size(), warnings.size(), result["placeholders"], result["texts"]])
	quit(1 if not errors.is_empty() else 0)


static func _list(ids: Array) -> String:
	return ", ".join(PackedStringArray(ids)) if not ids.is_empty() else "nothing"
