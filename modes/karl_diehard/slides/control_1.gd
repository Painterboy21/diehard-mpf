
extends Control

@onready var john_health: TextureRect = $johnhealth
@onready var karl_health: TextureRect = $karlhealth

@onready var karl_timer_variable: Label = $KarlTimerVariable
@onready var karl_damage_variable: Label = $KarlDamageVariable
@onready var karl_hans_bonus_variable: Label = $KarlHansBonusVariable

var last_timer := -1
var last_damage := -1


func _process(_delta: float) -> void:
	handle_john_timer()
	handle_karl_damage()


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
