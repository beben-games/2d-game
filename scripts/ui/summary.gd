class_name Summary
extends CanvasLayer
## End-of-run card: what happened, "R restart, Esc title". Main shows it on death or win and
## returns to the title on quit_requested.

signal quit_requested

@onready var title: Label = $Center/Box/Title
@onready var body_label: Label = $Center/Box/Body


func show_run(title_text: String, won: bool) -> void:
	title.text = title_text
	body_label.text = body(RunState.rooms_cleared, RunState.rooms_total, RunState.kills, RunState.elapsed, RunState.seed_value)
	visible = true
	Events.menu_opened.emit("summary_won" if won else "summary_lost")


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("pause"):
		quit_requested.emit()


static func format_time(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


static func body(rooms_cleared: int, rooms_total: int, kills: int, elapsed: float, seed_value: int) -> String:
	return "Rooms cleared %d/%d\nKills %d\nTime %s\nSeed %d" % [rooms_cleared, rooms_total, kills, format_time(elapsed), seed_value]
