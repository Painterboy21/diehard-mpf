extends MPFVariable

@onready var john_health = $"../johnhealth"


func _ready() -> void:
	super._ready()

	if john_health != null:
		john_health.reset_john_health()
	else:
		push_warning("johnhealth not found from KarlTimerVariable")


func _process(_delta: float) -> void:
	if john_health == null:
		return

	var seconds_left := int(text)

	if seconds_left <= 0:
		return

	john_health.set_john_health_by_time(seconds_left)
