extends VideoStreamPlayer

var intro_video: String = "res://videos/attractvideos/DieHardTrilogyOpener.ogv"
var gameover_video: String = "res://videos/attractvideos/GameOver.ogv"
var instruction_video: String = "res://videos/attractvideos/Instruction.ogv"

var normal_volume_db: float = 0.0
var silent_volume_db: float = -80.0
var attract_sound_asleep: bool = false

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

@onready var vboxMultiballHero = get_node_or_null("../MultiballHero")
@onready var lblMultiballHeroTitle = get_node_or_null("../MultiballHero/Title")
@onready var lblMultiballHeroName = get_node_or_null("../MultiballHero/Name")
@onready var lblMultiballHeroValue = get_node_or_null("../MultiballHero/Value")

@onready var vboxVillainMVP = get_node_or_null("../VillainMVP")
@onready var lblVillainMVPTitle = get_node_or_null("../VillainMVP/Title")
@onready var lblVillainMVPName = get_node_or_null("../VillainMVP/Name")
@onready var lblVillainMVPValue = get_node_or_null("../VillainMVP/Value")

@onready var vboxMultiplayerMadness = get_node_or_null("../MultiplayerMadness")
@onready var multiplayerMadnessVideos: Array = [
	get_node_or_null("../MultiplayerMadness/Panels/NakatomiPanel/NakatomiVideo"),
	get_node_or_null("../MultiplayerMadness/Panels/CentralParkPanel/CentralParkVideo"),
	get_node_or_null("../MultiplayerMadness/Panels/AirplanePanel/AirplaneVideo"),
]

@onready var vboxVpinWorkshop = get_node_or_null("../VPinWorkshop")
@onready var vpinWorkshopBackground = get_node_or_null("../VPinWorkshop/Background")
@onready var vpinWorkshopLogo = get_node_or_null("../VPinWorkshop/Logo")
@onready var vpinWorkshopLabels: Array = [
	get_node_or_null("../VPinWorkshop/Logo"),
	get_node_or_null("../VPinWorkshop/Title"),
	get_node_or_null("../VPinWorkshop/Body"),
]

@onready var vboxFastPinball = get_node_or_null("../FastPinball")
@onready var fastPinballScreen = get_node_or_null("../FastPinball/Screen")
@onready var fastPinballLogo = get_node_or_null("../FastPinball/Content/Logo")

@onready var iscoredLeaderboard = get_node_or_null("../iscored_leaderboard")

var loop_videos: Array[String] = [
	"res://videos/attractvideos/HSBackground3.ogv",
	"res://videos/attractvideos/HSBackground1.ogv",
	"res://videos/attractvideos/HSBackground2.ogv",
	"res://videos/attractvideos/HSBackground3.ogv",
	"res://videos/attractvideos/HSBackground1.ogv",
	"res://videos/attractvideos/HSBackground2.ogv",
	"res://videos/attractvideos/HSBackground3.ogv",
	"res://videos/attractvideos/Instruction.ogv",
]

const LOOP_CHAMPION_PAGE_INDEX := 3
const MULTIBALL_HERO_PAGE_INDEX := 4
const VILLAIN_MVP_PAGE_INDEX := 5
const ISCORED_PAGE_INDEX := 6

var current_index: int = -1
var player_scores_index: int = -1
var multiplayer_madness_page_index: int = -1
var vpin_workshop_page_index: int = -1
var fast_pinball_page_index: int = -1
var instruction_page_index: int = -1
var iscored_refresh_elapsed: float = 0.0
var vpin_workshop_tween: Tween
var vpin_workshop_label_home_positions: Dictionary = {}


func _ready() -> void:
	normal_volume_db = self.volume_db

	MPF.server.add_event_handler("rotate_attract_left", self._on_rotate_attract_left)
	MPF.server.add_event_handler("rotate_attract_right", self._on_rotate_attract_right)
	MPF.server.add_event_handler("play_show_xmas", self._on_timer_attract_idle_complete)
	MPF.server.add_event_handler("attract_sound_sleep", self._on_attract_sound_sleep)
	MPF.server.add_event_handler("attract_sound_wake", self._on_attract_sound_wake)
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

	if vboxMultiballHero:
		vboxMultiballHero.hide()
		vboxMultiballHero.z_index = 100
		print("MultiballHero node found")
	else:
		push_warning("MultiballHero node not found. Add it as a sibling of this VideoStreamPlayer.")

	if vboxVillainMVP:
		vboxVillainMVP.hide()
		vboxVillainMVP.z_index = 100
		print("VillainMVP node found")
	else:
		push_warning("VillainMVP node not found. Add it as a sibling of this VideoStreamPlayer.")

	if vboxMultiplayerMadness:
		vboxMultiplayerMadness.hide()
		vboxMultiplayerMadness.z_index = 100
		print("MultiplayerMadness node found")
	else:
		push_warning("MultiplayerMadness node not found. Add it as a sibling of this VideoStreamPlayer.")

	if vboxVpinWorkshop:
		vboxVpinWorkshop.hide()
		vboxVpinWorkshop.z_index = 100
		print("VPinWorkshop node found")
	else:
		push_warning("VPinWorkshop node not found. Add it as a sibling of this VideoStreamPlayer.")

	if vboxFastPinball:
		vboxFastPinball.hide()
		vboxFastPinball.z_index = 100
		print("FastPinball node found")
	else:
		push_warning("FastPinball node not found. Add it as a sibling of this VideoStreamPlayer.")

	loop_videos.erase(instruction_video)

	if MPF.game.machine_vars.has("last_game_players") and MPF.game.machine_vars["last_game_players"] != null and int(MPF.game.machine_vars["last_game_players"]) > 0:
		current_index = -2

		match int(MPF.game.machine_vars["last_game_players"]):
			1:
				loop_videos.append("res://videos/attractvideos/pl1gameover.ogv")
			2:
				loop_videos.append("res://videos/attractvideos/pl2gameover.ogv")
			3:
				loop_videos.append("res://videos/attractvideos/pl3gameover.ogv")
			4:
				loop_videos.append("res://videos/attractvideos/pl4gameover.ogv")

		player_scores_index = loop_videos.size() - 1

	loop_videos.append("res://videos/attractvideos/HSBackground3.ogv")
	multiplayer_madness_page_index = loop_videos.size() - 1

	loop_videos.append("res://videos/attractvideos/HSBackground2.ogv")
	vpin_workshop_page_index = loop_videos.size() - 1

	loop_videos.append("res://videos/attractvideos/HSBackground1.ogv")
	fast_pinball_page_index = loop_videos.size() - 1

	loop_videos.append(instruction_video)
	instruction_page_index = loop_videos.size() - 1

	_play_next(false)


func _exit_tree() -> void:
	MPF.server.remove_event_handler("rotate_attract_left", self._on_rotate_attract_left)
	MPF.server.remove_event_handler("rotate_attract_right", self._on_rotate_attract_right)
	MPF.server.remove_event_handler("play_show_xmas", self._on_timer_attract_idle_complete)
	MPF.server.remove_event_handler("attract_sound_sleep", self._on_attract_sound_sleep)
	MPF.server.remove_event_handler("attract_sound_wake", self._on_attract_sound_wake)


func _process(delta: float) -> void:
	if iscoredLeaderboard and iscoredLeaderboard.visible:
		iscored_refresh_elapsed += delta

		if iscored_refresh_elapsed >= 1.0:
			iscored_refresh_elapsed = 0.0
			_update_iscored_leaderboard()


func _on_attract_sound_sleep(_payload: Dictionary) -> void:
	print("Attract video sound asleep")
	attract_sound_asleep = true
	_apply_video_volume()


func _on_attract_sound_wake(_payload: Dictionary) -> void:
	print("Attract video sound awake")
	attract_sound_asleep = false
	_apply_video_volume()


func _apply_video_volume() -> void:
	if attract_sound_asleep:
		self.volume_db = silent_volume_db
		return

	if current_index == instruction_page_index:
		self.volume_db = silent_volume_db
	else:
		self.volume_db = normal_volume_db


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
	self.show()

	lblP1Score.hide()
	lblP2Score.hide()
	lblP3Score.hide()
	lblP4Score.hide()

	vboxHighScore1.hide()
	vboxHighScore2.hide()
	vboxHighScore3.hide()

	if vboxLoopChampion:
		vboxLoopChampion.hide()

	if vboxMultiballHero:
		vboxMultiballHero.hide()

	if vboxVillainMVP:
		vboxVillainMVP.hide()

	if vboxMultiplayerMadness:
		vboxMultiplayerMadness.hide()
		_stop_multiplayer_madness_videos()

	if vboxVpinWorkshop:
		vboxVpinWorkshop.hide()
		_reset_vpin_workshop_labels()

	if vboxFastPinball:
		vboxFastPinball.hide()

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

		if current_index == MULTIBALL_HERO_PAGE_INDEX:
			_show_multiball_hero()

		if current_index == VILLAIN_MVP_PAGE_INDEX:
			_show_villain_mvp()

		if current_index == ISCORED_PAGE_INDEX:
			_show_iscored_leaderboard()

		if current_index == multiplayer_madness_page_index:
			_show_multiplayer_madness()

		if current_index == vpin_workshop_page_index:
			_show_vpin_workshop()

		if current_index == fast_pinball_page_index:
			_show_fast_pinball()

	_apply_video_volume()

	var video_stream: VideoStream = load(path)

	if video_stream == null:
		push_warning("Could not load video: %s" % path)
		return

	if player_scores_index >= 0 and current_index == player_scores_index:
		_show_last_game_player_scores()

	self.stream = video_stream
	self.play()


func _show_loop_champion() -> void:
	if not vboxLoopChampion:
		push_warning("LoopChampion node not found")
		return

	var champion_name := "---"
	var champion_text := "---"

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


func _show_multiball_hero() -> void:
	if not vboxMultiballHero:
		push_warning("MultiballHero node not found")
		return

	var hero_name := "---"
	var hero_text := "---"
	var hero_mode := "---"

	if MPF.game.machine_vars.has("record_multiball_hero_name"):
		hero_name = str(MPF.game.machine_vars["record_multiball_hero_name"])
	elif MPF.game.machine_vars.has("machine_var_record_multiball_hero_name"):
		hero_name = str(MPF.game.machine_vars["machine_var_record_multiball_hero_name"])

	if MPF.game.machine_vars.has("record_multiball_hero_text"):
		hero_text = str(MPF.game.machine_vars["record_multiball_hero_text"])
	elif MPF.game.machine_vars.has("machine_var_record_multiball_hero_text"):
		hero_text = str(MPF.game.machine_vars["machine_var_record_multiball_hero_text"])

	if MPF.game.machine_vars.has("record_multiball_hero_mode"):
		hero_mode = str(MPF.game.machine_vars["record_multiball_hero_mode"])
	elif MPF.game.machine_vars.has("machine_var_record_multiball_hero_mode"):
		hero_mode = str(MPF.game.machine_vars["machine_var_record_multiball_hero_mode"])

	if lblMultiballHeroTitle:
		lblMultiballHeroTitle.text = "MULTIBALL HERO"

	if lblMultiballHeroName:
		lblMultiballHeroName.text = hero_name

	if lblMultiballHeroValue:
		if hero_mode != "---" and hero_text != "---":
			lblMultiballHeroValue.text = hero_text + "\n" + hero_mode
		else:
			lblMultiballHeroValue.text = hero_text

	vboxMultiballHero.show()
	vboxMultiballHero.z_index = 100

	print("Showing Multiball Hero: ", hero_name, " ", hero_text, " ", hero_mode)


func _show_villain_mvp() -> void:
	if not vboxVillainMVP:
		push_warning("VillainMVP node not found")
		return

	var villain_name := "---"
	var villain_text := "---"
	var villain_mode := "---"

	if MPF.game.machine_vars.has("record_villain_mvp_name"):
		villain_name = str(MPF.game.machine_vars["record_villain_mvp_name"])
	elif MPF.game.machine_vars.has("machine_var_record_villain_mvp_name"):
		villain_name = str(MPF.game.machine_vars["machine_var_record_villain_mvp_name"])

	if MPF.game.machine_vars.has("record_villain_mvp_text"):
		villain_text = str(MPF.game.machine_vars["record_villain_mvp_text"])
	elif MPF.game.machine_vars.has("machine_var_record_villain_mvp_text"):
		villain_text = str(MPF.game.machine_vars["machine_var_record_villain_mvp_text"])

	if MPF.game.machine_vars.has("record_villain_mvp_mode"):
		villain_mode = str(MPF.game.machine_vars["record_villain_mvp_mode"])
	elif MPF.game.machine_vars.has("machine_var_record_villain_mvp_mode"):
		villain_mode = str(MPF.game.machine_vars["machine_var_record_villain_mvp_mode"])

	if lblVillainMVPTitle:
		lblVillainMVPTitle.text = "VILLAIN MVP"

	if lblVillainMVPName:
		lblVillainMVPName.text = villain_name

	if lblVillainMVPValue:
		if villain_mode != "---" and villain_text != "---":
			lblVillainMVPValue.text = villain_text + "\n" + villain_mode
		else:
			lblVillainMVPValue.text = villain_text

	vboxVillainMVP.show()
	vboxVillainMVP.z_index = 100

	print("Showing Villain MVP: ", villain_name, " ", villain_text, " ", villain_mode)


func _show_multiplayer_madness() -> void:
	if not vboxMultiplayerMadness:
		push_warning("MultiplayerMadness node not found")
		return

	vboxMultiplayerMadness.show()
	vboxMultiplayerMadness.z_index = 100
	_play_multiplayer_madness_videos()

	print("Showing Multiplayer Madness")


func _play_multiplayer_madness_videos() -> void:
	for video in multiplayerMadnessVideos:
		if video:
			video.stop()
			video.play()


func _stop_multiplayer_madness_videos() -> void:
	for video in multiplayerMadnessVideos:
		if video:
			video.stop()


func _show_vpin_workshop() -> void:
	if not vboxVpinWorkshop:
		push_warning("VPinWorkshop node not found")
		return

	self.stop()
	self.hide()
	_ensure_vpin_workshop_textures()

	vboxVpinWorkshop.show()
	vboxVpinWorkshop.z_index = 100
	call_deferred("_animate_vpin_workshop")

	print("Showing VPin Workshop attract page")


func _load_texture_from_file(path: String) -> Texture2D:
	var image := Image.load_from_file(path)

	if image == null or image.is_empty():
		push_warning("Could not load attract image: %s" % path)
		return null

	return ImageTexture.create_from_image(image)


func _ensure_vpin_workshop_textures() -> void:
	if vpinWorkshopBackground and not vpinWorkshopBackground.texture:
		vpinWorkshopBackground.texture = _load_texture_from_file("res://slides/vpw_attract_assets/vpw_background.jpg")

	if vpinWorkshopLogo and not vpinWorkshopLogo.texture:
		vpinWorkshopLogo.texture = _load_texture_from_file("res://slides/vpw_attract_assets/vpw_logo.png")


func _show_fast_pinball() -> void:
	if not vboxFastPinball:
		push_warning("FastPinball node not found")
		return

	self.stop()
	self.hide()
	_ensure_fast_pinball_textures()

	vboxFastPinball.show()
	vboxFastPinball.z_index = 100

	print("Showing Powered by Fast Pinball")


func _ensure_fast_pinball_textures() -> void:
	if fastPinballScreen:
		fastPinballScreen.texture = _load_texture_from_file("res://slides/fast_pinball_assets/fast_pinball_fullscreen.png")
	else:
		push_warning("Fast Pinball screen node not found")

	if fastPinballLogo:
		fastPinballLogo.texture = _load_texture_from_file("res://slides/fast_pinball_assets/fast_pinball_logo_remade.png")
	else:
		push_warning("Fast Pinball logo node not found")


func _reset_vpin_workshop_labels() -> void:
	if vpin_workshop_tween:
		vpin_workshop_tween.kill()
		vpin_workshop_tween = null

	for label in vpinWorkshopLabels:
		if label:
			if vpin_workshop_label_home_positions.has(label):
				label.position = vpin_workshop_label_home_positions[label]
			label.modulate = Color(1, 1, 1, 1)


func _animate_vpin_workshop() -> void:
	await get_tree().process_frame

	if not vboxVpinWorkshop or not vboxVpinWorkshop.visible:
		return

	if vpin_workshop_tween:
		vpin_workshop_tween.kill()

	var label_data := []

	for label in vpinWorkshopLabels:
		if label:
			if not vpin_workshop_label_home_positions.has(label):
				vpin_workshop_label_home_positions[label] = label.position

			var final_position: Vector2 = vpin_workshop_label_home_positions[label]
			label.modulate = Color(1, 1, 1, 0)
			label.position = Vector2(final_position.x, -label.size.y - 40.0)
			label_data.append([label, final_position])

	vpin_workshop_tween = create_tween()
	vpin_workshop_tween.set_parallel(true)

	var delay := 0.0

	for item in label_data:
		var label := item[0] as Control
		var final_position: Vector2 = item[1]
		vpin_workshop_tween.tween_property(label, "position", final_position, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		vpin_workshop_tween.tween_property(label, "modulate:a", 1.0, 0.25).set_delay(delay)
		delay += 0.18


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
	if MPF.game.machine_vars.has("player1_score") and MPF.game.machine_vars["player1_score"] != null:
		lblP1Score.text = MPF.util.comma_sep(int(MPF.game.machine_vars["player1_score"]))
	else:
		lblP1Score.text = "0"

	if MPF.game.machine_vars.has("player2_score") and MPF.game.machine_vars["player2_score"] != null:
		lblP2Score.text = MPF.util.comma_sep(int(MPF.game.machine_vars["player2_score"]))
	else:
		lblP2Score.text = "0"

	if MPF.game.machine_vars.has("player3_score") and MPF.game.machine_vars["player3_score"] != null:
		lblP3Score.text = MPF.util.comma_sep(int(MPF.game.machine_vars["player3_score"]))
	else:
		lblP3Score.text = "0"

	if MPF.game.machine_vars.has("player4_score") and MPF.game.machine_vars["player4_score"] != null:
		lblP4Score.text = MPF.util.comma_sep(int(MPF.game.machine_vars["player4_score"]))
	else:
		lblP4Score.text = "0"

	if MPF.game.machine_vars.has("last_game_players") and MPF.game.machine_vars["last_game_players"] != null and int(MPF.game.machine_vars["last_game_players"]) > 0:
		print("showing last game player scores")

		match int(MPF.game.machine_vars["last_game_players"]):
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
	if current_index == multiplayer_madness_page_index:
		await get_tree().create_timer(2.0).timeout

		if current_index != multiplayer_madness_page_index:
			return

	_play_next(true)
