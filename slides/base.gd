extends MPFSlide

@onready var main_score = $Control2/main_score

func _ready() -> void:
	_refresh_main_score_visibility()

func hide_main_score(_event_args := {}) -> void:
	main_score.visible = false

func show_main_score(_event_args := {}) -> void:
	main_score.visible = true

func _refresh_main_score_visibility() -> void:
	main_score.visible = true
	if MPF.game and MPF.game.player:
		var wizard_running = int(MPF.game.player.get("wizard_mode_running", 0))
		var wizard_blackout = int(MPF.game.player.get("wizard_mode_blackout", 0))
		if wizard_running == 1 or wizard_blackout == 1:
			main_score.visible = false