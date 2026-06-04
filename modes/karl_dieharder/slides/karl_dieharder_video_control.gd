extends Control

# ------------------------------------------------------------
# KARL DIE HARDER - CONTROL SCRIPT
# ------------------------------------------------------------
#
# Expected scene layout:
#
# karl_dieharder_background
# ├── KarlBackgroundVideo
# ├── KarlDieHarderFight
# └── Control1
#     ├── johnDieHarderhealth
#     ├── karlDieHarderhealth
#     ├── KarlDieHarderTimerVariable
#     ├── KarlDieHarderDamageVariable
#     ├── DieHarder
#     └── KarlDieHarderResultVariable
#
# MPF variables:
#
#   KarlDieHarderTimerVariable   -> karl_dieharder_karl_dieharder_timer_tick
#   KarlDieHarderDamageVariable  -> karl_health_display
#   DieHarder                    -> karl_hans_bonus_active
#   KarlDieHarderResultVariable  -> karl_result_display
#
# Result values:
#
#   0 = fight running
#   1 = Karl defeated
#   3 = KarlPlayerDied / fail
# ------------------------------------------------------------


@onready var john_health: TextureRect = $johnDieHarderhealth
@onready var karl_health: TextureRect = $karlDieHarderhealth

@onready var karl_timer_variable: Label = $KarlDieHarderTimerVariable
@onready var karl_damage_variable: Label = $KarlDieHarderDamageVariable
@onready var karl_hans_bonus_variable: Label = $DieHarder
@onready var karl_result_variable: Label = $KarlDieHarderResultVariable

@onready var karl_fight_video: VideoStreamPlayer = $"../KarlDieHarderFight"


var last_timer := -1
var last_damage := -1
var last_result := 0


func _ready() -> void:
	print("KARL DIE HARDER CONTROL READY")

	if karl_fight_video != null:
		print("KarlDieHarderFight found")
		karl_fight_video.visible = false
		karl_fight_video.loop = false

		if not karl_fight_video.finished.is_connected(_on_karl_fight_video_finished):
			karl_fight_video.finished.connect(_on_karl_fight_video_finished)
	else:
		push_warning("KarlDieHarderFight video node NOT found from Control1")


func _process(_delta: float) -> void:
	handle_result_state()
	handle_john_timer()
	handle_karl_damage()


# ------------------------------------------------------------
# RESULT STATE
# ------------------------------------------------------------

func handle_result_state() -> void:
	if karl_result_variable == null:
		return

	var clean_text := karl_result_variable.text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		return

	var result := int(clean_text)

	if result == last_result:
		return

	last_result = result

	print("Karl Die Harder result changed: ", result)

	if result == 0:
		return

	stop_karl_fight_video()

	# Karl defeated.
	if result == 1:
		set_john_health_full()
		update_karl_health(100)

	# KarlPlayerDied / fail.
	elif result == 3:
		set_john_health_empty()


func is_result_active() -> bool:
	return last_result == 1 or last_result == 3


# ------------------------------------------------------------
# JOHN HEALTH FROM TIMER
# ------------------------------------------------------------

func handle_john_timer() -> void:
	if john_health == null:
		return

	if karl_timer_variable == null:
		return

	var clean_text := karl_timer_variable.text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		return

	var seconds_left := int(clean_text)

	if seconds_left == last_timer:
		return

	last_timer = seconds_left

	var max_time := 90.0

	if is_hans_bonus_active():
		max_time = 120.0

	if john_health.has_method("set_john_health_by_time"):
		john_health.set_john_health_by_time(seconds_left, max_time)


func is_hans_bonus_active() -> bool:
	if karl_hans_bonus_variable == null:
		return false

	var clean_text := karl_hans_bonus_variable.text.strip_edges()

	if clean_text == "":
		return false

	if not clean_text.is_valid_int():
		return false

	return int(clean_text) == 1


# ------------------------------------------------------------
# KARL HEALTH FROM DAMAGE
# ------------------------------------------------------------

func handle_karl_damage() -> void:
	if karl_health == null:
		return

	if karl_damage_variable == null:
		return

	var clean_text := karl_damage_variable.text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		return

	var damage := int(clean_text)

	if damage == last_damage:
		return

	print("Karl Die Harder damage changed: ", damage, " last was: ", last_damage)

	# Initial read just sets health. Later increases play fight video.
	if last_damage >= 0 and damage > last_damage and not is_result_active():
		print("Playing KarlDieHarderFight video")
		play_karl_fight_video()

	last_damage = damage

	update_karl_health(damage)


func update_karl_health(damage: int) -> void:
	var frame_number := 12 - int(float(damage) * 0.12)
	frame_number = clamp(frame_number, 1, 12)

	var path := "res://modes/karl_diehard/widgets/karl%d.png" % frame_number
	var texture_file := load(path)

	if texture_file == null:
		push_warning("Missing Karl health frame: %s" % path)
		return

	karl_health.texture = texture_file


# ------------------------------------------------------------
# KARL HIT VIDEO
# ------------------------------------------------------------

func play_karl_fight_video() -> void:
	if karl_fight_video == null:
		push_warning("Cannot play Karl fight video because node is null")
		return

	if karl_fight_video.stream == null:
		push_warning("KarlDieHarderFight has no video stream set")
		return

	karl_fight_video.visible = true
	karl_fight_video.stop()
	karl_fight_video.play()


func stop_karl_fight_video() -> void:
	if karl_fight_video == null:
		return

	karl_fight_video.stop()
	karl_fight_video.visible = false


func _on_karl_fight_video_finished() -> void:
	if karl_fight_video == null:
		return

	karl_fight_video.visible = false


# ------------------------------------------------------------
# RESULT HEALTH HELPERS
# ------------------------------------------------------------

func set_john_health_empty() -> void:
	if john_health == null:
		return

	if john_health.has_method("set_john_health_by_time"):
		john_health.set_john_health_by_time(0, 90.0)


func set_john_health_full() -> void:
	if john_health == null:
		return

	if john_health.has_method("set_john_health_by_time"):
		john_health.set_john_health_by_time(90, 90.0)
