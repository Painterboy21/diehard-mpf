extends MPFWidget

@onready var timer_text: Label = $timer_text

func _ready() -> void:
	timer_text.text = "60"
	if MPF.game:
		MPF.game.connect("player_update", _on_player_update)

func _on_player_update(var_name: String, value: Variant) -> void:
	if var_name == "wizard_mode_wizard_mode_timer_tick":
		timer_text.text = str(int(value))
