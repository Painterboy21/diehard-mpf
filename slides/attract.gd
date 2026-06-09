extends VideoStreamPlayer

var intro_video: String = "res://videos/attractvideos/DieHardTrilogyOpener.ogv"
var gameover_video: String = "res://videos/attractvideos/GameOver.ogv"

@onready var lblP1Score = $"../P1Score"
@onready var lblP2Score = $"../P2Score"
@onready var lblP3Score = $"../P3Score"
@onready var lblP4Score = $"../P4Score"

@onready var vboxHighScore1 = $"../HighScore1"
@onready var vboxHighScore2 = $"../HighScore2"
@onready var vboxHighScore3 = $"../HighScore3"

@onready var vboxLoopChampion = get_node_or_null("../LoopChampion")
@onready var lblLoopChampionTitle = get_node_or_null("../LoopChampion/Title")
@onready var lblLoopChampionName = get_node_or_null("../LoopChampion/Name")
@onready var lblLoopChampionValue = get_node_or_null("../LoopChampion/Value")

@onready var iscoredLeaderboard = get_node_or_null("../iscored_leaderboard")


# Playlist of video files.
# 0 = HighScore3
# 1 = HighScore1
# 2 = HighScore2
# 3 = Loop Champion
# 4 = iScored leaderboard
var loop_videos: Array[String] = [
	"res://videos/attractvideos/HSBackground3.ogv",
	"res://videos/attractvideos/HSBackground1.ogv",
	"res://videos/attractvideos/HSBackground2.ogv",
	"res://videos/attractvideos/HSBackground3.ogv",
	"res://videos/attractvideos/HSBackground3.ogv",
]

const LOOP_CHAMPION_PAGE_INDEX := 3
const ISCORED_PAGE_INDEX := 4

var current_index: int = -1   # -1 = intro not played yet
var player_scores_index: int = -1
var iscored_refresh_elapsed: float = 0.0


func _ready() -> void:
	MPF.server.add_event_handler("rotate_attract_left", self._on_rotate_attract_left)
	MPF.server.add_event_handler("rotate_attract_right", self._on_rotate_attract_right)
	MPF.server.add_event_handler("play_show_xmas", self._on_timer_attract_idle_complete)

	self.finished.connect(_on_video_finished)

	if iscoredLeaderboard:
		iscoredLeaderboard.hide()
		iscoredLeaderboard.z_index = 100
		print("iScored leaderboard node found")
	else:
		push_warning("iscored_leaderboard node not found. Add it as a sibling of this VideoStreamPlayer.")

	if vboxLoopChampion:
		vboxLoopChampion.hide()
		vboxLoopChampion.z_index = 100
		print("LoopChampion node found")
	else:
		push_warning("LoopChampion node not found. Add it as a sibling of this VideoStreamPlayer.")

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

		player_scores_index = loop_videos.size() - 1

	_play_next(false)


func _exit_tree() -> void:
	MPF.server.remove_event_handler("rotate_attract_left", self._on_rotate_attract_left)
	MPF.server.remove_event_handler("rotate_attract_right", self._on_rotate_attract_right)
	MPF.server.remove_event_handler("play_show_xmas", self._on_timer_attract_idle_complete)


func _process(delta: float) -> void:
	if iscoredLeaderboard and iscoredLeaderboard.visible:
		iscored_refresh_elapsed += delta

		if iscored_refresh_elapsed >= 1.0:
			iscored_refresh_elapsed = 0.0
			_update_iscored_leaderboard()


func _on_rotate_attract_left(payload: Dictionary) -> void:
	print(payload)
	_play_next(false)


func _on_rotate_attract_right(payload: Dictionary) -> void:
	print(payload)
	_play_next(true)


func _on_timer_attract_idle_complete(payload: Dictionary) -> void:
	print(payload)
	current_index = -1
	_play_next(false)


func _hide_all_overlays() -> void:
	lblP1Score.hide()
	lblP2Score.hide()
	lblP3Score.hide()
	lblP4Score.hide()

	vboxHighScore1.hide()
	vboxHighScore2.hide()
	vboxHighScore3.hide()

	if vboxLoopChampion:
		vboxLoopChampion.hide()

	if iscoredLeaderboard:
		iscoredLeaderboard.hide()


func _close_nakatomi_lock_on_game_over() -> void:
	print("Game Over: closing Nakatomi entrance lock")
	MPF.server.send_event("nakatomi_entrance_lock_close")


func _play_next(increment: bool) -> void:
	var path: String

	_hide_all_overlays()

	if current_index == -1:
		path = intro_video
		current_index = 0

	elif current_index == -2:
		path = gameover_video
		_close_nakatomi_lock_on_game_over()

		if player_scores_index >= 0:
			current_index = player_scores_index - 1
		else:
			current_index = ISCORED_PAGE_INDEX - 1

	else:
		if increment:
			current_index = (current_index + 1) % loop_videos.size()
		else:
			current_index = (current_index - 1) % loop_videos.size()

			if current_index == -1:
				current_index = loop_videos.size() - 1

		path = loop_videos[current_index]

		if current_index == 0:
			vboxHighScore3.show()

		if current_index == 1:
			vboxHighScore1.show()

		if current_index == 2:
			vboxHighScore2.show()

		if current_index == LOOP_CHAMPION_PAGE_INDEX:
			_show_loop_champion()

		if current_index == ISCORED_PAGE_INDEX:
			_show_iscored_leaderboard()

	var stream: VideoStream = load(path)

	if stream == null:
		push_warning("Could not load video: %s" % path)
		return

	if player_scores_index >= 0 and current_index == player_scores_index:
		_show_last_game_player_scores()

	self.stream = stream
	self.play()


func _show_loop_champion() -> void:
	if not vboxLoopChampion:
		push_warning("LoopChampion node not found")
		return

	var champion_name := "---"
	var champion_text := "---"

	print("Checking Loop Champion machine vars...")

	for key in MPF.game.machine_vars.keys():
		if str(key).contains("loop") or str(key).contains("record"):
			print("Machine var: ", key, " = ", MPF.game.machine_vars[key])

	if MPF.game.machine_vars.has("record_loop_champion_name"):
		champion_name = str(MPF.game.machine_vars["record_loop_champion_name"])
	elif MPF.game.machine_vars.has("machine_var_record_loop_champion_name"):
		champion_name = str(MPF.game.machine_vars["machine_var_record_loop_champion_name"])

	if MPF.game.machine_vars.has("record_loop_champion_text"):
		champion_text = str(MPF.game.machine_vars["record_loop_champion_text"])
	elif MPF.game.machine_vars.has("machine_var_record_loop_champion_text"):
		champion_text = str(MPF.game.machine_vars["machine_var_record_loop_champion_text"])

	if lblLoopChampionTitle:
		lblLoopChampionTitle.text = "LOOP CHAMPION"

	if lblLoopChampionName:
		lblLoopChampionName.text = champion_name

	if lblLoopChampionValue:
		lblLoopChampionValue.text = champion_text

	vboxLoopChampion.show()
	vboxLoopChampion.z_index = 100

	print("Showing Loop Champion: ", champion_name, " ", champion_text)


func _show_iscored_leaderboard() -> void:
	if not iscoredLeaderboard:
		push_warning("iscored_leaderboard node not found")
		return

	print("Showing iScored leaderboard page")

	iscoredLeaderboard.show()
	iscoredLeaderboard.z_index = 100
	iscored_refresh_elapsed = 0.0

	_update_iscored_leaderboard()


func _update_iscored_leaderboard() -> void:
	if not iscoredLeaderboard:
		return

	if not iscoredLeaderboard.has_method("set_machine_var"):
		push_warning("iscored_leaderboard does not have set_machine_var()")
		return

	print("Updating iScored leaderboard from MPF machine vars")

	for i in range(1, 11):
		_send_iscored_var("iscored_%s_rank" % i)
		_send_iscored_var("iscored_%s_name" % i)
		_send_iscored_var("iscored_%s_score" % i)
		_send_iscored_var("iscored_%s_score_text" % i)


func _send_iscored_var(key: String) -> void:
	var value = null
	var found := false

	if MPF.game.machine_vars.has(key):
		value = MPF.game.machine_vars[key]
		found = true

	elif MPF.game.machine_vars.has("machine_var_" + key):
		value = MPF.game.machine_vars["machine_var_" + key]
		found = true

	if found:
		print("Sending iScored var to board: ", key, " = ", value)
		iscoredLeaderboard.set_machine_var(key, value)
	else:
		print("Missing iScored var: ", key)


func _show_last_game_player_scores() -> void:
	if MPF.game.machine_vars.has("player1_score"):
		lblP1Score.text = MPF.util.comma_sep(MPF.game.machine_vars["player1_score"])

	if MPF.game.machine_vars.has("player2_score"):
		lblP2Score.text = MPF.util.comma_sep(MPF.game.machine_vars["player2_score"])

	if MPF.game.machine_vars.has("player3_score"):
		lblP3Score.text = MPF.util.comma_sep(MPF.game.machine_vars["player3_score"])

	if MPF.game.machine_vars.has("player4_score"):
		lblP4Score.text = MPF.util.comma_sep(MPF.game.machine_vars["player4_score"])

	if MPF.game.machine_vars.has("last_game_players") and MPF.game.machine_vars["last_game_players"] > 0:
		print("showing last game player scores")

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


func _on_video_finished() -> void:
	_play_next(true)
