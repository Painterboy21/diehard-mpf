
extends Control

# ------------------------------------------------------------
# KARL DIE HARD - CONTROL SCRIPT
# ------------------------------------------------------------
#
# Expected scene layout:
#
# karl_diehard_background
# ├── KarlBackgroundVideo
# ├── KarlFight
# └── Control1
#     ├── johnhealth
#     ├── karlhealth
#     ├── KarlTimerVariable
#     ├── KarlDamageVariable
#     └── KarlHansBonusVariable
#
# MPF variables should be bound in Godot/GMC:
#
#   KarlTimerVariable      -> karl_diehard_remaining
#   KarlDamageVariable     -> karl_health_display
#   KarlHansBonusVariable  -> hans_bonus / karl_hans_bonus_active
#
# Karl fight video:
#   KarlFight should already have its stream set in the scene.
# ------------------------------------------------------------


@onready var john_health: TextureRect = $johnhealth
@onready var karl_health: TextureRect = $karlhealth

@onready var karl_timer_variable: Label = $KarlTimerVariable
@onready var karl_damage_variable: Label = $KarlDamageVariable
@onready var karl_hans_bonus_variable: Label = $KarlHansBonusVariable

@onready var karl_fight_video: VideoStreamPlayer = $"../KarlFight"


var last_timer: int = -1
var last_damage: int = -1


func _ready() -> void:
	print("KARL DIE HARD CONTROL READY")

	if john_health == null:
		push_warning("Karl Die Hard: johnhealth node not found")

	if karl_health == null:
		push_warning("Karl Die Hard: karlhealth node not found")

	if karl_timer_variable == null:
		push_warning("Karl Die Hard: KarlTimerVariable node not found")

	if karl_damage_variable == null:
		push_warning("Karl Die Hard: KarlDamageVariable node not found")

	if karl_hans_bonus_variable == null:
		push_warning("Karl Die Hard: KarlHansBonusVariable node not found")

	if karl_fight_video != null:
		print("KarlFight found")
		karl_fight_video.visible = false
		karl_fight_video.loop = false

		if not karl_fight_video.finished.is_connected(_on_karl_fight_video_finished):
			karl_fight_video.finished.connect(_on_karl_fight_video_finished)
	else:
		push_warning("Karl Die Hard: KarlFight video node not found from Control1")


func _process(_delta: float) -> void:
	handle_john_timer()
	handle_karl_damage()


# ------------------------------------------------------------
# JOHN HEALTH FROM TIMER
# ------------------------------------------------------------

func handle_john_timer() -> void:
	if john_health == null:
		return

	if karl_timer_variable == null:
		return

	var clean_text: String = karl_timer_variable.text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		return

	var seconds_left: int = int(clean_text)

	if seconds_left == last_timer:
		return

	last_timer = seconds_left

	var max_time: float = 93.0

	if is_hans_bonus_active():
		max_time = 123.0

	if john_health.has_method("set_john_health_by_time"):
		john_health.set_john_health_by_time(seconds_left, max_time)


func is_hans_bonus_active() -> bool:
	if karl_hans_bonus_variable == null:
		return false

	var clean_text: String = karl_hans_bonus_variable.text.strip_edges()

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

	var clean_text: String = karl_damage_variable.text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		return

	var damage: int = int(clean_text)

	if damage == last_damage:
		return

	print("Karl Die Hard damage changed: ", damage, " last was: ", last_damage)

	# Initial read just sets health. Later increases play fight video.
	if last_damage >= 0 and damage > last_damage:
		print("Playing KarlFight video")
		play_karl_fight_video()

	last_damage = damage

	update_karl_health(damage)


func update_karl_health(damage: int) -> void:
	var frame_number: int = 12 - int(float(damage) * 0.12)
	frame_number = clamp(frame_number, 1, 12)

	var path: String = "res://modes/karl_diehard/widgets/karl%d.png" % frame_number
	var texture_file: Texture2D = load(path) as Texture2D

	if texture_file == null:
		push_warning("Karl Die Hard: Missing Karl health frame: %s" % path)
		return

	karl_health.texture = texture_file


# ------------------------------------------------------------
# KARL FIGHT VIDEO
# ------------------------------------------------------------

func play_karl_fight_video() -> void:
	if karl_fight_video == null:
		push_warning("Karl Die Hard: Cannot play Karl fight video because node is null")
		return

	if karl_fight_video.stream == null:
		push_warning("Karl Die Hard: KarlFight has no video stream set")
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
