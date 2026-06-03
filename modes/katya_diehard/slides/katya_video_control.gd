
extends Control

@onready var background_video = $"../MPFVideoPlayer"
@onready var katya_hit_video: VideoStreamPlayer = $"../KatyaDieHarderHitVideo"
@onready var katya_variable: Label = $KatyaDieHarderShotsVariable

var last_shots: int = -1

const HIT_VIDEO_PATH: String = "res://modes/katya_diehard/slides/Katya%d.ogv"


func _ready() -> void:
	if katya_hit_video != null:
		katya_hit_video.visible = false
		katya_hit_video.loop = false
		katya_hit_video.autoplay = false

		if not katya_hit_video.finished.is_connected(_on_katya_hit_video_finished):
			katya_hit_video.finished.connect(_on_katya_hit_video_finished)


func _process(_delta: float) -> void:
	if katya_variable == null:
		return

	var clean_text: String = katya_variable.text.strip_edges()

	if clean_text == "":
		return

	if not clean_text.is_valid_int():
		return

	var shots: int = int(clean_text)

	if shots == last_shots:
		return

	last_shots = shots

	if shots >= 1:
		play_katya_hit_video(shots)


func play_katya_hit_video(shots: int) -> void:
	var video_number: int = clamp(shots, 1, 8)
	var path: String = HIT_VIDEO_PATH % video_number
	var video_file: VideoStream = load(path) as VideoStream

	if video_file == null:
		push_warning("Missing Katya Die Harder hit video: %s" % path)
		return

	if background_video != null:
		if background_video.has_method("stop"):
			background_video.stop()
		background_video.visible = false

	if katya_hit_video != null:
		katya_hit_video.stop()
		katya_hit_video.stream = video_file
		katya_hit_video.visible = true
		katya_hit_video.play()


func _on_katya_hit_video_finished() -> void:
	if katya_hit_video != null:
		katya_hit_video.stop()
		katya_hit_video.visible = false

	if background_video != null:
		background_video.visible = true
		if background_video.has_method("play"):
			background_video.play()
