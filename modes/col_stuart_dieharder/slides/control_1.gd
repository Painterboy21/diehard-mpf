extends Control

# ------------------------------------------------------------
# SIMON DIE HARD - BACKGROUND CONTROL
# ------------------------------------------------------------
# Handles random Simon hit videos.
# MPF posts simon_diehard_play_random_hit_video on every correct hit.
# Videos are Simon1.ogv through Simon24.ogv.
# ------------------------------------------------------------

@onready var background_video: VideoStreamPlayer = $"../MPFVideoPlayer"
@onready var hit_video: VideoStreamPlayer = $"../SimonHitVideo"

const HIT_VIDEO_PATH: String = "res://modes/simon_diehard/slides/Simon%d.ogv"


func _ready() -> void:
	randomize()

	if hit_video == null:
		push_warning("Simon Die Hard: SimonHitVideo node not found")
		return

	hit_video.visible = false
	hit_video.autoplay = false

	if not hit_video.finished.is_connected(_on_hit_video_finished):
		hit_video.finished.connect(_on_hit_video_finished)


func play_random_simon_hit_video() -> void:
	if hit_video == null:
		return

	var video_number: int = randi_range(1, 24)
	var video_path: String = HIT_VIDEO_PATH % video_number
	var video_stream: VideoStream = load(video_path) as VideoStream

	if video_stream == null:
		push_warning("Simon Die Hard: Could not load video: " + video_path)
		return

	hit_video.stream = video_stream
	hit_video.visible = true
	hit_video.play()


func _on_hit_video_finished() -> void:
	if hit_video == null:
		return

	hit_video.stop()
	hit_video.visible = false


func _on_mpf_event(event_name: String, event_args: Dictionary) -> void:
	if event_name == "simon_diehard_play_random_hit_video":
		play_random_simon_hit_video()
