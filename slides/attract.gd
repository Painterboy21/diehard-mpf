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
	MPF.server.add_event_handler("rotate_attract_left", self._on_rotate_attract_left)
	MPF.server.add_event_handler("rotate_attract_right", self._on_rotate_attract_right)
	MPF.server.add_event_handler("play_show_xmas", self._on_timer_attract_idle_complete)
	self.finished.connect(_on_video_finished)
	_play_next(0)

func _exit_tree():
	MPF.server.remove_event_handler("rotate_attract_left", self._on_rotate_attract_left)
	MPF.server.remove_event_handler("rotate_attract_right", self._on_rotate_attract_right)
	MPF.server.remove_event_handler("play_show_xmas", self._on_timer_attract_idle_complete)
	

func _on_rotate_attract_left(payload: Dictionary) -> void:
	print(payload)
	_play_next(0)

func _on_rotate_attract_right(payload: Dictionary) -> void:
	print(payload)
	_play_next(1)

func _on_timer_attract_idle_complete(payload: Dictionary) -> void:	
	print(payload)
	current_index = -1
	_play_next(0)

func _play_next(increment: bool) -> void:
	var path: String

	if current_index == -1:
		# Play intro video first
		path = intro_video
		current_index = 0
	else:
		# Play looping videos
		if increment:
			current_index = (current_index + 1) % loop_videos.size()
		else:
			current_index = (current_index - 1) % loop_videos.size()
			if current_index == -1:
				current_index = loop_videos.size() -1
		path = loop_videos[current_index]
		
	var stream: VideoStream = load(path)
	if stream == null:
		push_warning("Could not load video: %s" % path)
		return

	self.stream = stream
	self.play()

func _on_video_finished() -> void:
	_play_next(1)
