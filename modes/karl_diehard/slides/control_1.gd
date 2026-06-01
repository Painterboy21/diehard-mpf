extends Control

@onready var karl_health: TextureRect = $karlhealth
@onready var karl_damage_variable: Label = $KarlDamageVariable

# These are siblings of Control1 under karl_diehard_background.
@onready var karl_background_video: VideoStreamPlayer = $"../KarlBackgroundVideo"
@onready var karl_fight: VideoStreamPlayer = $"../KarlFight"

var last_damage := -1
var last_fight_number := -1
var last_karl_health_frame := -1

const RANDOM_FIGHT_COUNT := 29
const FIGHT_PATH := "res://modes/karl_diehard/slides/KarlFight%d.ogv"


func _ready() -> void:
	randomize()

	if karl_fight != null:
		karl_fight.visible = false
		karl_fight.loop = false
		karl_fight.autoplay = false

		if not karl_fight.finished.is_connected(_on_karl_fight_finished):
			karl_fight.finished.connect(_on_karl_fight_finished)


func _process(_delta: float) -> void:
	handle_karl_damage()


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

	var new_health_frame := update_karl_health(damage)

	# VPW-style:
	# Only play a random fight video when Karl's health image drops.
	if damage > 0 and damage < 100:
		if last_karl_health_frame != -1 and new_health_frame < last_karl_health_frame:
			play_random_karl_fight_video()

	last_karl_health_frame = new_health_frame


func update_karl_health(damage: int) -> int:
	var frame_number := 12 - int(float(damage) * 0.12)
	frame_number = clamp(frame_number, 1, 12)

	var path := "res://modes/karl_diehard/widgets/karl%d.png" % frame_number
	var texture_file := load(path)

	if texture_file == null:
		push_warning("Missing Karl health frame: %s" % path)
		return frame_number

	karl_health.texture = texture_file
	return frame_number


func play_random_karl_fight_video() -> void:
	if karl_fight == null:
		return

	var fight_number := randi_range(1, RANDOM_FIGHT_COUNT)

	if fight_number == last_fight_number:
		fight_number += 1
		if fight_number > RANDOM_FIGHT_COUNT:
			fight_number = 1

	last_fight_number = fight_number

	var path := FIGHT_PATH % fight_number
	var video_file := load(path)

	if video_file == null:
		push_warning("Missing Karl fight video: %s" % path)
		return

	# Hide only the normal background video.
	if karl_background_video != null:
		karl_background_video.stop()
		karl_background_video.visible = false

	# Play the hit video in the background layer.
	karl_fight.stop()
	karl_fight.stream = video_file
	karl_fight.visible = true
	karl_fight.play()


func _on_karl_fight_finished() -> void:
	if karl_fight != null:
		karl_fight.stop()
		karl_fight.visible = false

	# Bring the normal background video back.
	if karl_background_video != null:
		karl_background_video.visible = true
		karl_background_video.play()
