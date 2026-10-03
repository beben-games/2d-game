@tool
extends EditorPlugin
## The Story tab on the editor's main screen (beside 2D, 3D, Script): the story's events as a
## graph (story_tab.tscn). An editor plugin only: the game never loads it, and `addons/*` is out of
## the exports (export_presets.cfg).
##
## The tab's unsaved edits are the editor's too: on quit the editor lists them with its own unsaved
## scenes (_get_unsaved_status); its save (Ctrl+S, Save All, before running the project, "Save &
## Quit") saves the story too (_save_external_data: the unsaved pools written; text not applied is
## the writer's to Apply, never applied by a save), so the game plays what the tab's pools hold. Disabling the plugin with unsaved edits warns,
## naming them, rather than dropping them silently.

const StoryTab := preload("res://addons/story_graph/story_tab.tscn")

var _tab: Control = null


func _enter_tree() -> void:
	_tab = StoryTab.instantiate()
	_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(_tab)
	_make_visible(false)


func _exit_tree() -> void:
	if is_instance_valid(_tab):
		_tab.queue_free()
	_tab = null


func _has_main_screen() -> bool:
	return true


## The graph is built on the tab's first showing, never at the editor's start (the test runner's
## and check_boot's import step start the editor).
func _make_visible(visible: bool) -> void:
	if is_instance_valid(_tab):
		_tab.visible = visible
		if visible:
			_tab.call("ensure_built")


## The tab's unsaved pools and text not applied, asked on the editor's quit ("" for a scene
## closing: the story is not a scene).
func _get_unsaved_status(for_scene: String) -> String:
	if for_scene != "" or not is_instance_valid(_tab):
		return ""
	return str(_tab.call("unsaved_status"))


func _save_external_data() -> void:
	if is_instance_valid(_tab):
		_tab.call("save_external")


func _disable_plugin() -> void:
	if is_instance_valid(_tab):
		var status := str(_tab.call("unsaved_status"))
		if status != "":
			push_warning("Story plugin disabled with edits not saved: " + status)


func _get_plugin_name() -> String:
	return "Story"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("GraphEdit", "EditorIcons")
