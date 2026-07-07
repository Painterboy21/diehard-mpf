extends MPFWidget

@onready var timer_text: Label = $timer_text
@onready var yippee_text: Label = $yippee_text

var flash_on: bool = true
var flash_timer: float = 0.0

func _ready() -> void:
	timer_text.text = "60"
	yippee_text.visible = true
	if MPF.game:
		MPF.game.connect("player_update", _on_player_update)

func _process(delta: float) -> void:
	flash_timer += delta
	if flash_timer >= 0.25:
		flash_timer = 0.0
		flash_on = !flash_on
		yippee_text.visible = flash_on

func _on_player_update(var_name: String, value: Variant) -> void:
	if var_name == "wizard_mode_wizard_mode_timer_tick":
		timer_text.text = str(int(value))
