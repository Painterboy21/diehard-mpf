extends Control

# ------------------------------------------------------------
# COL / STUART BACKGROUND SLIDE SCRIPT
# ------------------------------------------------------------
# Put this on the root node:
#   col_stuart_background
#
# It only changes the text on:
#   ColStuartProgressShotLabel
#
# You control the font, colour, size, outline, and position in Godot.
# ------------------------------------------------------------

@onready var progress_shot_label: Label = $ColStuartProgressShotLabel

var col_stuart_progress: int = 0
var col_stuart_last_shot: int = 0
var col_stuart_result_display: int = 0


func _ready() -> void:
	_update_progress_shot_text()


func set_machine_var(name: String, value) -> void:
	match name:
		"col_stuart_progress":
			col_stuart_progress = int(value)
			_update_progress_shot_text()

		"col_stuart_last_shot":
			col_stuart_last_shot = int(value)
			_update_progress_shot_text()

		"col_stuart_result_display":
			col_stuart_result_display = int(value)
			_update_progress_shot_text()


func _update_progress_shot_text() -> void:
	if progress_shot_label == null:
		return

	if col_stuart_result_display == 1:
		progress_shot_label.text = "COL DEFEATED"
		return

	if col_stuart_result_display == 2:
		progress_shot_label.text = "COL ESCAPED"
		return

	if col_stuart_progress <= 0:
		progress_shot_label.text = "HIT ANY YELLOW SHOT"
		return

	if col_stuart_progress == 1:
		progress_shot_label.text = _get_repeat_shot_text()
		return

	if col_stuart_progress >= 2:
		progress_shot_label.text = "MISSION COMPLETE"
		return


func _get_repeat_shot_text() -> String:
	match col_stuart_last_shot:
		1:
			return "HIT LEFT ORBIT AGAIN"
		2:
			return "HIT LEFT RAMP AGAIN"
		3:
			return "HIT RIGHT RAMP AGAIN"
		4:
			return "HIT UPPER LOOP AGAIN"
		5:
			return "HIT RIGHT ORBIT AGAIN"
		_:
			return "HIT THAT SHOT AGAIN"
