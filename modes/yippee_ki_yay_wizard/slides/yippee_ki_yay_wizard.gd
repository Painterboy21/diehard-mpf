
extends MPFSlide

# ------------------------------------------------------------
# YIPPEE KI YAY WIZARD - PHASE 1 ONLY
# ------------------------------------------------------------
# Phase1Video plays while locking balls.
# DiaHard1Kill plays when MPF posts:
#   yippee_ki_yay_phase_1_play_kill_video
#
# When DiaHard1Kill finishes, this posts:
#   dia_hard_1_kill_finished
#
# MPF also has a timed fallback release, so the physical lock
# cannot stay stuck if Godot does not send the finished event.
# ------------------------------------------------------------

@onready var phase_1_video = get_node_or_null("Phase1Video")
@onready var dia_hard_1_kill = get_node_or_null("DiaHard1Kill")
@onready var phase_title_label: Label = get_node_or_null("PhaseTitleLabel")
@onready var phase_objective_label: Label = get_node_or_null("PhaseObjectiveLabel")
@onready var phase_progress_label: Label = get_node_or_null("PhaseProgressLabel")

var phase_1_balls_locked: int = 0
var kill_video_started: bool = false


func _ready() -> void:
	_setup_videos()
	_register_mpf_events()
	_show_phase_1()
	_update_phase_1_text()


func _register_mpf_events() -> void:
	if MPF == null:
		return

	if MPF.has_method("register_event"):
		MPF.register_event("yippee_ki_yay_phase_1_play_kill_video", Callable(self, "_on_play_kill_video"))
	elif MPF.server != null and MPF.server.has_method("register_event"):
		MPF.server.register_event("yippee_ki_yay_phase_1_play_kill_video", Callable(self, "_on_play_kill_video"))


func set_machine_var(name: String, value) -> void:
	match name:
		"yippee_ki_yay_phase_1_balls_locked":
			phase_1_balls_locked = int(value)
			_update_phase_1_text()


func _on_play_kill_video(_kwargs := {}) -> void:
	_show_dia_hard_1_kill()


func _setup_videos() -> void:
	if phase_1_video != null:
		phase_1_video.visible = true

	if dia_hard_1_kill != null:
		dia_hard_1_kill.visible = false

		if dia_hard_1_kill.has_method("stop"):
			dia_hard_1_kill.stop()

		if dia_hard_1_kill.has_signal("finished") and not dia_hard_1_kill.finished.is_connected(_on_dia_hard_1_kill_finished):
			dia_hard_1_kill.finished.connect(_on_dia_hard_1_kill_finished)


func _show_phase_1() -> void:
	kill_video_started = false

	if dia_hard_1_kill != null:
		if dia_hard_1_kill.has_method("stop"):
			dia_hard_1_kill.stop()
		dia_hard_1_kill.visible = false

	if phase_1_video != null:
		phase_1_video.visible = true
		if phase_1_video.has_method("play"):
			phase_1_video.play()

	_set_label_text(phase_title_label, "YIPPEE KI YAY")
	_update_phase_1_text()


func _show_dia_hard_1_kill() -> void:
	if kill_video_started:
		return

	kill_video_started = true

	if phase_1_video != null:
		if phase_1_video.has_method("stop"):
			phase_1_video.stop()
		phase_1_video.visible = false

	if dia_hard_1_kill != null:
		dia_hard_1_kill.visible = true
		dia_hard_1_kill.move_to_front()

		if dia_hard_1_kill.has_method("stop"):
			dia_hard_1_kill.stop()

		if dia_hard_1_kill.has_method("play"):
			dia_hard_1_kill.play()

	_set_label_text(phase_title_label, "PHASE 1 COMPLETE")
	_set_label_text(phase_objective_label, "DIE HARD")
	_set_label_text(phase_progress_label, "3 / 3 LOCKED")


func _on_dia_hard_1_kill_finished() -> void:
	if MPF != null and MPF.server != null:
		MPF.server.send_event("dia_hard_1_kill_finished")


func _update_phase_1_text() -> void:
	if kill_video_started:
		return

	var clamped_locked: int = clamp(phase_1_balls_locked, 0, 3)

	_set_label_text(phase_title_label, "YIPPEE KI YAY")
	_set_label_text(phase_objective_label, "LOCK 3 BALLS IN THE TOWER")
	_set_label_text(phase_progress_label, str(clamped_locked) + " / 3 LOCKED")


func _set_label_text(label_node: Label, text_value: String) -> void:
	if label_node == null:
		return

	label_node.text = text_value
