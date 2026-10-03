@tool
extends EditorPlugin
## The Story tab on the editor's main screen (beside 2D, 3D, Script): the story's events as a
## graph (story_tab.tscn). An editor plugin only: the game never loads it, and `addons/*` is out of
## the exports (export_presets.cfg).

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


func _get_plugin_name() -> String:
	return "Story"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("GraphEdit", "EditorIcons")
