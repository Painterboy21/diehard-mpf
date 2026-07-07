extends MPFSlide

@onready var final_score_label: Label = $final_score_label

func _ready() -> void:
	final_score_label.visible = false
	final_score_label.text = ""

func show_final_score(_event_args := {}) -> void:
	var final_score := 0
	if MPF.game and MPF.game.player:
		final_score = int(MPF.game.player.get("score", 0))
	final_score_label.text = _format_score(final_score)
	final_score_label.visible = true

func _format_score(value: int) -> String:
	var text := str(value)
	var result := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		result = text[i] + result
		count += 1
		if count == 3 and i != 0:
			result = "," + result
			count = 0
	return result
