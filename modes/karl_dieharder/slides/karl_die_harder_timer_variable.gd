extends MPFVariable

# ------------------------------------------------------------
# KARL DIE HARDER - TIMER VARIABLE SCRIPT
# ------------------------------------------------------------
#
# Attach this to:
#
#   Control1/KarlDieHarderTimerVariable
#
# Expected sibling nodes:
#
#   johnDieHarderhealth
#   DieHarder
#
# MPF variable on this node:
#
#   karl_dieharder_karl_dieharder_timer_tick
#
# Normal Karl Die Harder timer = 90 seconds.
# Hans bonus Karl Die Harder timer = 120 seconds.
# ------------------------------------------------------------


@onready var john_health: TextureRect = $"../johnDieHarderhealth"
@onready var hans_bonus_variable: Label = $"../DieHarder"


var last_seconds_left := -1


func _ready() -> void:
	super._ready()

	if john_health != null:
		if john_health.has_method("reset_john_health"):
			john_health.reset_john_health()
	else:
		push_warning("johnDieHarderhealth not found from KarlDieHarderTimerVariable")


func _process(_delta: float) -> void:
	if john_health == null:
		return

	var clean_text := text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		return

	var seconds_left := int(clean_text)

	if seconds_left == last_seconds_left:
		return

	last_seconds_left = seconds_left

	var max_time := 90.0

	if is_hans_bonus_active():
		max_time = 120.0

	if john_health.has_method("set_john_health_by_time"):
		john_health.set_john_health_by_time(seconds_left, max_time)


func is_hans_bonus_active() -> bool:
	if hans_bonus_variable == null:
		return false

	var clean_text := hans_bonus_variable.text.strip_edges()

	if clean_text == "":
		return false

	if not clean_text.is_valid_int():
		return false

	return int(clean_text) == 1
