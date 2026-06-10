extends Control

@onready var background_video = $"../MPFVideoPlayer"
@onready var hit_video: VideoStreamPlayer = $"../HansDieHarderHitVideo"
@onready var remaining_variable: Label = $HansDieHarderRemainingVariable

var last_remaining: int = -999

# Reuses the normal Hans hit videos:
# res://modes/hans_diehard/slides/Hans1.ogv
# res://modes/hans_diehard/slides/Hans2.ogv
# ...
# res://modes/hans_diehard/slides/Hans8.ogv
const HIT_VIDEO_PATH: String = "res://modes/hans_diehard/slides/Hans%d.ogv"


func _ready() -> void:
	if hit_video == null:
		push_warning("Hans Die Harder: HansDieHarderHitVideo node not found")
		return

	if remaining_variable == null:
		push_warning("Hans Die Harder: HansDieHarderRemainingVariable node not found")
		return

	hit_video.visible = false
	hit_video.autoplay = false
	hit_video.loop = false

	if not hit_video.finished.is_connected(_on_hit_video_finished):
		hit_video.finished.connect(_on_hit_video_finished)


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

	last_remaining = remaining

	# hans_dieharder_remaining starts at 8 and counts down:
	# 8 = no video
	# 7 = Hans1.ogv
	# 6 = Hans2.ogv
	# 5 = Hans3.ogv
	# 4 = Hans4.ogv
	# 3 = Hans5.ogv
	# 2 = Hans6.ogv
	# 1 = Hans7.ogv
	# 0 = Hans8.ogv
	if remaining >= 0 and remaining <= 7:
		var hit_number: int = 8 - remaining
		play_hit_video(hit_number)


func play_hit_video(hit_number: int) -> void:
	var path: String = HIT_VIDEO_PATH % hit_number
	var video_file: VideoStream = load(path) as VideoStream

	if video_file == null:
		push_warning("Hans Die Harder: Missing video: %s" % path)
		return

	if background_video != null:
		if background_video.has_method("stop"):
			background_video.stop()
		background_video.visible = false

	hit_video.stop()
	hit_video.stream = video_file
	hit_video.visible = true
	hit_video.play()


func _on_hit_video_finished() -> void:
	if hit_video != null:
		hit_video.stop()
		hit_video.visible = false

	if background_video != null:
		background_video.visible = true
		if background_video.has_method("play"):
			background_video.play()
