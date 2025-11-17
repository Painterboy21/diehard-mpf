extends VideoStreamPlayer

var intro_video: String = "res://videos/attractvideos/DieHardTrilogyOpener.ogv"

# Playlist of video files (local resources)
var loop_videos: Array[String] = [
	"res://videos/attractvideos/HSBackground1.ogv",
	"res://videos/attractvideos/HSBackground2.ogv",
	"res://videos/attractvideos/HSBackground3.ogv"
]

var current_index: int = -1   # -1 = intro not played yet

func _ready() -> void:
	self.finished.connect(_on_video_finished)
	_play_next()

func _play_next() -> void:
	var path: String

	if current_index == -1:
		# Play intro video first
		path = intro_video
		current_index = 0
	else:
		# Play looping videos
		path = loop_videos[current_index]
		current_index = (current_index + 1) % loop_videos.size()

	var stream: VideoStream = load(path)
	if stream == null:
		push_warning("Could not load video: %s" % path)
		return

	self.stream = stream
	self.play()

func _on_video_finished() -> void:
	_play_next()
