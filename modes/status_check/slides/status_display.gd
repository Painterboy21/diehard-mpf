extends MPFSlide

const BACKDROP_PATH := "res://modes/status_check/slides/status.png"
const DIEHARD_FONT_PATH := "res://godot-media/fonts/DieHardVPX-Regular.ttf"

const USE_TEST_DATA := false

var diehard_font: Font
var title_labels: Array[Label] = []
var value_labels: Array[Label] = []

var refresh_time := 0.0
var refresh_speed := 0.25


func _ready() -> void:
	print("STATUS MPF SLIDE LOADED")

	set_anchors_preset(Control.PRESET_FULL_RECT)

	_clear_scene_children()
	_load_font()
	_make_background()
	_make_rows()

	call_deferred("_refresh_rows")


func _process(delta: float) -> void:
	refresh_time += delta

	if refresh_time >= refresh_speed:
		refresh_time = 0.0
		_refresh_rows()


func _clear_scene_children() -> void:
	for child in get_children():
		child.queue_free()

	title_labels.clear()
	value_labels.clear()


func _load_font() -> void:
	if ResourceLoader.exists(DIEHARD_FONT_PATH):
		diehard_font = load(DIEHARD_FONT_PATH)
		print("Die Hard font loaded")
	else:
		diehard_font = null
		print("Die Hard font not found, using default font")


func _make_background() -> void:
	print("Checking backdrop path: ", BACKDROP_PATH)
	print("Backdrop exists: ", ResourceLoader.exists(BACKDROP_PATH))

	if not ResourceLoader.exists(BACKDROP_PATH):
		print("STATUS BACKDROP NOT FOUND: ", BACKDROP_PATH)
		return

	var tex := load(BACKDROP_PATH) as Texture2D

	if tex == null:
		print("BACKGROUND LOAD FAILED: ", BACKDROP_PATH)
		return

	print("Backdrop loaded OK: ", tex.get_width(), " x ", tex.get_height())

	var bg := TextureRect.new()
	bg.name = "StatusBackdrop"
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 0
	bg.offset_top = 0
	bg.offset_right = 0
	bg.offset_bottom = 0
	bg.z_index = 0

	add_child(bg)
	move_child(bg, 0)


func _make_rows() -> void:
	var start_y := 340
	var row_gap := 46
	var block_width := 720
	var screen_width := get_viewport_rect().size.x
	var x := int((screen_width - block_width) / 2)

	_add_status_row("LOOPS", "---", x, start_y + row_gap * 0)
	_add_status_row("AIRPLANE", "---", x, start_y + row_gap * 1)
	_add_status_row("CENTRAL PARK", "---", x, start_y + row_gap * 2)
	_add_status_row("MULTIBALLS", "---", x, start_y + row_gap * 3)
	_add_status_row("VILLAINS", "---", x, start_y + row_gap * 4)
	_add_status_row("PLAYFIELD X", "---", x, start_y + row_gap * 5)
	_add_status_row("BONUS X", "---", x, start_y + row_gap * 6)
	_add_status_row("BULLETS", "---", x, start_y + row_gap * 7)
	_add_status_row("MYSTERY", "---", x, start_y + row_gap * 8)
	_add_status_row("SUPER JETS", "---", x, start_y + row_gap * 9)
	_add_status_row("SPINNERS", "---", x, start_y + row_gap * 10)


func _add_status_row(row_title: String, row_value: String, x: int, y: int) -> void:
	var title := _make_label(
		row_title,
		Vector2(x, y),
		Vector2(420, 44),
		38,
		Color(1.0, 0.0, 0.0),
		HORIZONTAL_ALIGNMENT_LEFT
	)

	var value := _make_label(
		row_value,
		Vector2(x + 460, y),
		Vector2(260, 44),
		38,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_RIGHT
	)

	title.z_index = 10
	value.z_index = 10

	title_labels.append(title)
	value_labels.append(value)

	add_child(title)
	add_child(value)


func _make_label(
	text: String,
	pos: Vector2,
	size: Vector2,
	font_size: int,
	color: Color,
	align: HorizontalAlignment
) -> Label:

	var label := Label.new()

	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = false

	if diehard_font:
		label.add_theme_font_override("font", diehard_font)

	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)

	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 6)
	label.add_theme_constant_override("shadow_offset_y", 6)

	return label


func _get_player_int(var_name: String, default_value: int = 0) -> int:
	if USE_TEST_DATA:
		return _get_test_value(var_name, default_value)

	if not MPF.game.player:
		return default_value

	if var_name in MPF.game.player:
		return int(MPF.game.player[var_name])

	return default_value


func _get_test_value(var_name: String, default_value: int = 0) -> int:
	match var_name:
		"airplane_virtual_locks":
			return 2
		"central_park_virtual_locks":
			return 1
		"played_nakatomi_multiball":
			return 1
		"airplane_mb_played":
			return 1
		"central_park_played":
			return 0
		"hans_complete":
			return 1
		"karl_complete":
			return 1
		"katya_complete":
			return 0
		"simon_complete":
			return 1
		"col_stuart_complete":
			return 0
		"loops_this_ball":
			return 0
		"current_loop_streak":
			return 3
		"best_loop_streak_this_game":
			return 4
		"playfield_x_qualified":
			return 0
		"playfield_multiplier":
			return 3
		"bonus_multiplier":
			return 2
		"bullet_hits":
			return 12
		"mystery_ho_level":
			return 2
		"mystery_h_hits":
			return 1
		"mystery_o_hits":
			return 0
		"super_jets_active":
			return 0
		"super_jets_hits":
			return 14
		"super_jets_goal":
			return 20
		"super_spinners":
			return 0
		"super_spinners_hits":
			return 35
		"super_spinners_goal":
			return 50
		_:
			return default_value


func _set_value(row: int, value: String) -> void:
	if row < 0:
		return

	if row >= value_labels.size():
		return

	value_labels[row].text = value


func _refresh_rows() -> void:
	if value_labels.size() < 11:
		return

	var loops_this_ball := _get_player_int("loops_this_ball", 0)
	var current_loop_streak := _get_player_int("current_loop_streak", 0)
	var best_loop_streak := _get_player_int("best_loop_streak_this_game", 0)

	if loops_this_ball < current_loop_streak:
		loops_this_ball = current_loop_streak

	if loops_this_ball < best_loop_streak:
		loops_this_ball = best_loop_streak

	var airplane_locks := _get_player_int("airplane_virtual_locks", 0)
	var central_park_locks := _get_player_int("central_park_virtual_locks", 0)

	var multiballs_played := 0
	multiballs_played += _get_player_int("played_nakatomi_multiball", 0)
	multiballs_played += _get_player_int("airplane_mb_played", 0)
	multiballs_played += _get_player_int("central_park_played", 0)

	if multiballs_played > 3:
		multiballs_played = 3

	var villains_defeated := 0
	villains_defeated += _get_player_int("hans_complete", 0)
	villains_defeated += _get_player_int("karl_complete", 0)
	villains_defeated += _get_player_int("katya_complete", 0)
	villains_defeated += _get_player_int("simon_complete", 0)
	villains_defeated += _get_player_int("col_stuart_complete", 0)

	if villains_defeated > 5:
		villains_defeated = 5

	var playfield_x_ready := _get_player_int("playfield_x_qualified", 0)
	var playfield_x_multiplier := _get_player_int("playfield_multiplier", 1)

	if playfield_x_multiplier < 1:
		playfield_x_multiplier = 1

	var bonus_x := _get_player_int("bonus_multiplier", 1)

	if bonus_x < 1:
		bonus_x = 1

	var bullet_hits := _get_player_int("bullet_hits", 0)
	var bullets_left := 15 - bullet_hits

	if bullets_left < 0:
		bullets_left = 0

	var mystery_level := _get_player_int("mystery_ho_level", 1)
	var mystery_left_hits := _get_player_int("mystery_h_hits", 0)
	var mystery_right_hits := _get_player_int("mystery_o_hits", 0)

	if mystery_level < 1:
		mystery_level = 1

	if mystery_level > 3:
		mystery_level = 3

	var left_hits_left := mystery_level - mystery_left_hits
	var right_hits_left := mystery_level - mystery_right_hits

	if left_hits_left < 0:
		left_hits_left = 0

	if right_hits_left < 0:
		right_hits_left = 0

	var mystery_total_left := left_hits_left + right_hits_left

	var super_jets_active := _get_player_int("super_jets_active", 0)
	var super_jets_hits := _get_player_int("super_jets_hits", 0)
	var super_jets_goal := _get_player_int("super_jets_goal", 20)
	var jets_left := super_jets_goal - super_jets_hits

	if jets_left < 0:
		jets_left = 0

	var super_spinners_active := _get_player_int("super_spinners", 0)
	var super_spinners_hits := _get_player_int("super_spinners_hits", 0)
	var super_spinners_goal := _get_player_int("super_spinners_goal", 50)
	var spinners_left := super_spinners_goal - super_spinners_hits

	if spinners_left < 0:
		spinners_left = 0

	_set_value(0, str(loops_this_ball))
	_set_value(1, "%d / 3" % airplane_locks)
	_set_value(2, "%d / 3" % central_park_locks)
	_set_value(3, "%d / 3" % multiballs_played)
	_set_value(4, "%d / 5" % villains_defeated)

	if playfield_x_multiplier > 1:
		_set_value(5, "%dX" % playfield_x_multiplier)
	elif playfield_x_ready == 1:
		_set_value(5, "READY")
	else:
		_set_value(5, "OFF")

	_set_value(6, "%dX" % bonus_x)

	if bullets_left == 0:
		_set_value(7, "READY")
	else:
		_set_value(7, "%d LEFT" % bullets_left)

	if mystery_total_left == 0:
		_set_value(8, "READY")
	else:
		_set_value(8, "%d LEFT" % mystery_total_left)

	if super_jets_active == 1:
		_set_value(9, "ACTIVE")
	elif jets_left == 0:
		_set_value(9, "READY")
	else:
		_set_value(9, "%d LEFT" % jets_left)

	if super_spinners_active == 1:
		_set_value(10, "ACTIVE")
	elif spinners_left == 0:
		_set_value(10, "READY")
	else:
		_set_value(10, "%d LEFT" % spinners_left)
