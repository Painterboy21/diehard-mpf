extends Control

@onready var background_video = $"../MPFVideoPlayer"
@onready var hans_hit_video: VideoStreamPlayer = $"../HansHitVideo"
@onready var remaining_variable: Label = $HansRemainingVariable

var last_remaining := -1

# Your actual file names are:
# Hans1.ogv, Hans2.ogv, Hans3.ogv ... Hans8.ogv
const HIT_VIDEO_PATH := "res://modes/hans_diehard/slides/Hans%d.ogv"


func _ready() -> void:
	print("HANS VIDEO CONTROL READY")
	print("background_video = ", background_video)
	print("hans_hit_video = ", hans_hit_video)
	print("remaining_variable = ", remaining_variable)

	if hans_hit_video != null:
		hans_hit_video.visible = false
		hans_hit_video.loop = false
		hans_hit_video.autoplay = false

		if not hans_hit_video.finished.is_connected(_on_hans_hit_video_finished):
			hans_hit_video.finished.connect(_on_hans_hit_video_finished)


func _process(_delta: float) -> void:
	if remaining_variable == null:
		return

	var clean_text := remaining_variable.text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		print("HANS REMAINING NOT INT: ", clean_text)
		return

	var remaining := int(clean_text)

	if remaining == last_remaining:
		return

	last_remaining = remaining

	print("HANS REMAINING CHANGED: ", remaining)

	# hans_diehard_remaining starts at 8 and counts down:
	# 8 = no hit video yet
	# 7 = Hans1.ogv
	# 6 = Hans2.ogv
	# 5 = Hans3.ogv
	# 4 = Hans4.ogv
	# 3 = Hans5.ogv
	# 2 = Hans6.ogv
	# 1 = Hans7.ogv
	# 0 = Hans8.ogv
	var hit_number := 8 - remaining

	print("HANS HIT NUMBER: ", hit_number)

	if hit_number >= 1 and hit_number <= 8:
		play_hans_hit_video(hit_number)


func play_hans_hit_video(hit_number: int) -> void:
	var path := HIT_VIDEO_PATH % hit_number

	print("TRYING HANS VIDEO PATH: ", path)

	var video_file := load(path)

	if video_file == null:
		push_warning("Missing Hans hit video: %s" % path)
		return

	print("LOADED HANS VIDEO: ", video_file)

	# Hide only the normal background video.
	if background_video != null:
		print("HIDING BACKGROUND VIDEO")

		if background_video.has_method("stop"):
			background_video.stop()

		background_video.visible = false

	# Play Hans hit video in the background layer.
	if hans_hit_video != null:
		print("PLAYING HANS HIT VIDEO")

		hans_hit_video.stop()
		hans_hit_video.stream = video_file
		hans_hit_video.visible = true
		hans_hit_video.play()


func _on_hans_hit_video_finished() -> void:
	print("HANS HIT VIDEO FINISHED")

	if hans_hit_video != null:
		hans_hit_video.stop()
		hans_hit_video.visible = false

	# Bring normal background video back.
	if background_video != null:
		print("RESTORING BACKGROUND VIDEO")

		background_video.visible = true

		if background_video.has_method("play"):
			background_video.play()
