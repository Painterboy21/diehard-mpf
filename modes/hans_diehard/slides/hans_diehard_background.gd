extends Control

@onready var background_video = $"../MPFVideoPlayer"
@onready var hit_video: VideoStreamPlayer = $"../HansHitVideo"

var last_remaining: int = 8
var mode_initialised: bool = false

const HIT_VIDEO_PATH: String = "res://modes/hans_diehard/slides/Hans%d.ogv"


func _ready() -> void:
	if hit_video == null:
		push_error("Hans Die Hard: HansHitVideo node was not found")
		return

	hit_video.visible = false
	hit_video.autoplay = false
	hit_video.loop = false

	if not hit_video.finished.is_connected(_on_hit_video_finished):
		hit_video.finished.connect(_on_hit_video_finished)


func _process(_delta: float) -> void:
	if MPF.game == null:
		return

	if MPF.game.player == null:
		return

	var remaining: int = int(
		MPF.game.player.get("hans_diehard_remaining", 8)
	)

	remaining = clampi(remaining, 0, 8)

	# Store the starting value without playing a hit video.
	if not mode_initialised:
		last_remaining = remaining
		mode_initialised = true
		return

	if remaining == last_remaining:
		return

	# Only play a video when the remaining count goes down.
	if remaining < last_remaining:
		var hit_number: int = 8 - remaining

		if hit_number >= 1 and hit_number <= 8:
			play_hit_video(hit_number)

	last_remaining = remaining


func play_hit_video(hit_number: int) -> void:
	var path: String = HIT_VIDEO_PATH % hit_number

	if not ResourceLoader.exists(path):
		push_error("Hans Die Hard: Missing video: %s" % path)
		return

	var video_file: VideoStream = load(path) as VideoStream

	if video_file == null:
		push_error("Hans Die Hard: Could not load video: %s" % path)
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
