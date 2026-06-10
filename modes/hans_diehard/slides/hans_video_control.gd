extends Control

@onready var background_video = $"../MPFVideoPlayer"
@onready var hit_video: VideoStreamPlayer = $"../HansHitVideo"
@onready var remaining_variable: Label = $HansRemainingVariable

var last_remaining: int = -999

const HIT_VIDEO_PATH: String = "res://modes/hans_diehard/slides/Hans%d.ogv"


func _ready() -> void:
	print("====================================")
	print("HANS DIE HARD VIDEO CONTROL READY")
	print("background_video: ", background_video)
	print("hit_video: ", hit_video)
	print("remaining_variable: ", remaining_variable)
	print("====================================")

	if hit_video == null:
		push_warning("Hans Die Hard: HansHitVideo node not found")
		return

	if remaining_variable == null:
		push_warning("Hans Die Hard: HansRemainingVariable node not found")
		return

	hit_video.visible = false
	hit_video.autoplay = false

	if not hit_video.finished.is_connected(_on_hit_video_finished):
		hit_video.finished.connect(_on_hit_video_finished)

	var test_path: String = HIT_VIDEO_PATH % 1
	var test_video: VideoStream = load(test_path) as VideoStream

	if test_video == null:
		push_warning("Hans Die Hard: TEST LOAD FAILED: %s" % test_path)
	else:
		print("Hans Die Hard: TEST LOAD OK: ", test_path)


func _process(_delta: float) -> void:
	if remaining_variable == null:
		return

	var clean_text: String = remaining_variable.text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		return

	var remaining: int = int(clean_text)

	if remaining == last_remaining:
		return

	print("Hans Die Hard: remaining changed from ", last_remaining, " to ", remaining)

	last_remaining = remaining

	if remaining >= 0 and remaining <= 7:
		var hit_number: int = 8 - remaining
		print("Hans Die Hard: hit_number = ", hit_number)
		play_hit_video(hit_number)


func play_hit_video(hit_number: int) -> void:
	var path: String = HIT_VIDEO_PATH % hit_number
	print("Hans Die Hard: trying video path: ", path)

	var video_file: VideoStream = load(path) as VideoStream

	if video_file == null:
		push_warning("Hans Die Hard: Missing video: %s" % path)
		return

	if background_video != null:
		if background_video.has_method("stop"):
			background_video.stop()
		background_video.visible = false

	hit_video.stop()
	hit_video.stream = video_file
	hit_video.visible = true
	hit_video.play()

	print("Hans Die Hard: video play called")


func _on_hit_video_finished() -> void:
	print("Hans Die Hard: hit video finished")

	if hit_video != null:
		hit_video.stop()
		hit_video.visible = false

	if background_video != null:
		background_video.visible = true
		if background_video.has_method("play"):
			background_video.play()
