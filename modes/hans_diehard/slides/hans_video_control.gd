
extends Control

@onready var background_video = $"../MPFVideoPlayer"
@onready var hit_video: VideoStreamPlayer = $"../HansDieHarderHitVideo"
@onready var remaining_variable: Label = $HansDieHarderRemainingVariable

var last_remaining := -1

# Reuses the normal Hans hit videos:
# res://modes/hans_diehard/slides/Hans1.ogv
# res://modes/hans_diehard/slides/Hans2.ogv
# ...
# res://modes/hans_diehard/slides/Hans8.ogv
const HIT_VIDEO_PATH := "res://modes/hans_diehard/slides/Hans%d.ogv"


func _ready() -> void:
	print("HANS DIE HARDER VIDEO CONTROL READY")

	if hit_video != null:
		hit_video.visible = false
		hit_video.loop = false
		hit_video.autoplay = false

		if not hit_video.finished.is_connected(_on_hit_video_finished):
			hit_video.finished.connect(_on_hit_video_finished)


func _process(_delta: float) -> void:
	if remaining_variable == null:
		return

	var clean_text := remaining_variable.text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		return

	var remaining := int(clean_text)

	if remaining == last_remaining:
		return

	last_remaining = remaining

	# hans_dieharder_remaining starts at 8 and counts down:
	# 8 = no hit video
	# 7 = Hans1.ogv
	# 6 = Hans2.ogv
	# 5 = Hans3.ogv
	# 4 = Hans4.ogv
	# 3 = Hans5.ogv
	# 2 = Hans6.ogv
	# 1 = Hans7.ogv
	# 0 = Hans8.ogv
	var hit_number := 8 - remaining

	if hit_number >= 1 and hit_number <= 8:
		play_hit_video(hit_number)


func play_hit_video(hit_number: int) -> void:
	var path := HIT_VIDEO_PATH % hit_number
	var video_file := load(path)

	if video_file == null:
		push_warning("Missing Hans Die Harder hit video: %s" % path)
		return

	# Hide only the normal background video.
	if background_video != null:
		if background_video.has_method("stop"):
			background_video.stop()

		background_video.visible = false

	# Play the Hans hit video in the background layer.
	if hit_video != null:
		hit_video.stop()
		hit_video.stream = video_file
		hit_video.visible = true
		hit_video.play()


func _on_hit_video_finished() -> void:
	if hit_video != null:
		hit_video.stop()
		hit_video.visible = false

	# Bring the normal background video back.
	if background_video != null:
		background_video.visible = true

		if background_video.has_method("play"):
			background_video.play()
