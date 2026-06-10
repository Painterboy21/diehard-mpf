

extends Control

# ------------------------------------------------------------
# SIMON DIE HARD - BACKGROUND CONTROL
# ------------------------------------------------------------
# Plays random Simon hit videos.
#
# Works from BOTH:
#   1. SimonHitVideoTriggerVariable changing 0 -> 1 -> 2 -> 3 -> 4
#   2. MPFEventHandler calling play_random_simon_hit_video
#
# Videos only play for hits 1-4.
# Hit 5 is left for Simon Defeated slide.
# ------------------------------------------------------------

@onready var hit_video: VideoStreamPlayer = $SimonHitVideo
@onready var hit_video_trigger_variable = $SimonHitVideoTriggerVariable

const HIT_VIDEO_PATH: String = "res://modes/simon_diehard/slides/Simon%d.ogv"

var last_hit_video_trigger: int = -999
var trigger_ready: bool = false
var last_video_time_msec: int = 0


func _ready() -> void:
	randomize()

	print("SIMON CONTROL1 RANDOM VIDEO SCRIPT READY")

	if hit_video == null:
		print("SIMON ERROR: SimonHitVideo not found")
		return

	if hit_video_trigger_variable == null:
		print("SIMON ERROR: SimonHitVideoTriggerVariable not found")
		return

	hit_video.visible = false
	hit_video.autoplay = false

	if not hit_video.finished.is_connected(_on_hit_video_finished):
		hit_video.finished.connect(_on_hit_video_finished)


func _process(_delta: float) -> void:
	if hit_video_trigger_variable == null:
		return

	var trigger_text: String = str(hit_video_trigger_variable.text).strip_edges()

	if trigger_text == "":
		return

	var current_trigger: int = int(trigger_text)

	if not trigger_ready:
		last_hit_video_trigger = current_trigger
		trigger_ready = true
		print("Simon trigger ready: ", last_hit_video_trigger)

		if current_trigger > 0 and current_trigger < 5:
			play_random_simon_hit_video()

		return

	if current_trigger != last_hit_video_trigger:
		print("Simon trigger changed from ", last_hit_video_trigger, " to ", current_trigger)

		last_hit_video_trigger = current_trigger

		if current_trigger > 0 and current_trigger < 5:
			play_random_simon_hit_video()


func play_random_simon_hit_video(_settings: Dictionary = {}, _kwargs: Dictionary = {}) -> void:
	var now_msec: int = Time.get_ticks_msec()

	# Stops double-playing if both the MPF event and variable trigger fire together.
	if now_msec - last_video_time_msec < 300:
		print("Simon video ignored duplicate trigger")
		return

	last_video_time_msec = now_msec

	if hit_video == null:
		print("SIMON ERROR: hit_video is null")
		return

	var video_number: int = randi_range(1, 24)
	var video_path: String = HIT_VIDEO_PATH % video_number
	var video_stream: VideoStream = load(video_path) as VideoStream

	print("Simon trying video: ", video_path)

	if video_stream == null:
		print("SIMON ERROR: Could not load video: ", video_path)
		return

	hit_video.stop()
	hit_video.stream = video_stream
	hit_video.visible = true
	hit_video.show()
	hit_video.play()

	print("Simon playing video: ", video_path)


func _on_hit_video_finished() -> void:
	if hit_video == null:
		return

	hit_video.stop()
	hit_video.visible = false
