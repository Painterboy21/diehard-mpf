extends VideoStreamPlayer

var intro_video: String = "res://videos/attractvideos/DieHardTrilogyOpener.ogv"
var gameover_video: String = "res://videos/attractvideos/GameOver.ogv"

@onready var lblP1Score = $"../P1Score"
@onready var lblP2Score = $"../P2Score"
@onready var lblP3Score = $"../P3Score"
@onready var lblP4Score = $"../P4Score"

# Playlist of video files (local resources)
var loop_videos: Array[String] = [
	"res://videos/attractvideos/HSBackground3.ogv",
	"res://videos/attractvideos/HSBackground1.ogv",
	"res://videos/attractvideos/HSBackground2.ogv",
]

var current_index: int = -1   # -1 = intro not played yet

func _ready() -> void:
	MPF.server.add_event_handler("rotate_attract_left", self._on_rotate_attract_left)
	MPF.server.add_event_handler("rotate_attract_right", self._on_rotate_attract_right)
	MPF.server.add_event_handler("play_show_xmas", self._on_timer_attract_idle_complete)
	self.finished.connect(_on_video_finished)
	
	if MPF.game.machine_vars.has("last_game_players") and MPF.game.machine_vars["last_game_players"] > 0:
		current_index = -2
		match MPF.game.machine_vars["last_game_players"]:
			1:
				loop_videos.append("res://videos/attractvideos/pl1gameover.ogv")
			2:
				loop_videos.append("res://videos/attractvideos/pl2gameover.ogv")
			3:
				loop_videos.append("res://videos/attractvideos/pl3gameover.ogv")
			4:
				loop_videos.append("res://videos/attractvideos/pl4gameover.ogv")
				
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
	
	lblP1Score.hide()
	lblP2Score.hide()
	lblP3Score.hide()
	lblP4Score.hide()

	if current_index == -1:
		# Play intro video first
		path = intro_video
		current_index = 0
	elif current_index == -2:
		path = gameover_video
		current_index = 2
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

	if current_index == 3:
		
		if MPF.game.machine_vars.has("player1_score"):
			lblP1Score.text = MPF.util.comma_sep(MPF.game.machine_vars["player1_score"])
		if MPF.game.machine_vars.has("player2_score"):
			lblP2Score.text = MPF.util.comma_sep(MPF.game.machine_vars["player2_score"])
		if MPF.game.machine_vars.has("player3_score"):
			lblP3Score.text = MPF.util.comma_sep(MPF.game.machine_vars["player3_score"])
		if MPF.game.machine_vars.has("player4_score"):
			lblP4Score.text = MPF.util.comma_sep(MPF.game.machine_vars["player4_score"])
		
		if MPF.game.machine_vars.has("last_game_players") and MPF.game.machine_vars["last_game_players"] > 0:
			print("here")
			match MPF.game.machine_vars["last_game_players"]:
				1:
					lblP1Score.show()
				2:
					lblP1Score.show()
					lblP2Score.show()
				3:
					lblP1Score.show()
					lblP2Score.show()
					lblP3Score.show()
				4:
					lblP1Score.show()
					lblP2Score.show()
					lblP3Score.show()
					lblP4Score.show()

	self.stream = stream
	self.play()

func _on_video_finished() -> void:
	_play_next(1)
