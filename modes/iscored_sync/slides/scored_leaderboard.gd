extends Control

const ROW_COUNT := 10

const BACKDROP_PATH := "res://modes/iscored_sync/slides/monthly_leaderboard_ft1.png"
const DIEHARD_FONT_PATH := "res://godot-media/fonts/DieHardVPX-Regular.ttf"

# Live MPF use.
const USE_TEST_DATA := false

var diehard_font: Font

var rank_labels: Array[Label] = []
var name_labels: Array[Label] = []
var score_labels: Array[Label] = []

var machine_vars := {}
var mpf_event_handlers := {}


func _ready() -> void:
	print("iScored leaderboard scene loaded")

	set_anchors_preset(Control.PRESET_FULL_RECT)

	_load_font()
	_make_background()
	_make_rows()
	_register_mpf_machine_var_events()

	if USE_TEST_DATA:
		_load_test_data()

	_pull_existing_mpf_vars()
	_refresh_rows()


func _exit_tree() -> void:
	for event_name in mpf_event_handlers.keys():
		MPF.server.remove_event_handler(event_name, mpf_event_handlers[event_name])

	mpf_event_handlers.clear()


func _load_font() -> void:
	if ResourceLoader.exists(DIEHARD_FONT_PATH):
		diehard_font = load(DIEHARD_FONT_PATH)
		print("Die Hard font loaded")
	else:
		diehard_font = null
		print("Die Hard font not found, using default Godot font")


func _make_background() -> void:
	var bg := TextureRect.new()
	bg.name = "MonthlyLeaderboardBackdrop"
	bg.texture = load(BACKDROP_PATH)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE

	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.offset_left = 0
	bg.offset_top = 0
	bg.offset_right = 0
	bg.offset_bottom = 0

	bg.z_index = 0

	add_child(bg)


func _make_rows() -> void:
	var start_y := 205
	var row_gap := 62

	for i in range(ROW_COUNT):
		var row := i + 1
		var y := start_y + (i * row_gap)

		var rank := _make_label(
			str(row),
			Vector2(245, y),
			Vector2(90, 60),
			58,
			Color.WHITE,
			HORIZONTAL_ALIGNMENT_RIGHT
		)

		var name := _make_label(
			"---",
			Vector2(350, y),
			Vector2(570, 60),
			58,
			Color(1.0, 0.0, 0.0),
			HORIZONTAL_ALIGNMENT_LEFT
		)

		var score := _make_label(
			"---",
			Vector2(880, y),
			Vector2(540, 60),
			54,
			Color.WHITE,
			HORIZONTAL_ALIGNMENT_RIGHT
		)

		rank.z_index = 10
		name.z_index = 10
		score.z_index = 10

		rank_labels.append(rank)
		name_labels.append(name)
		score_labels.append(score)

		add_child(rank)
		add_child(name)
		add_child(score)


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


func _register_mpf_machine_var_events() -> void:
	for i in range(1, ROW_COUNT + 1):
		_add_mpf_var_handler(
			"machine_var_iscored_%s_rank" % i,
			"iscored_%s_rank" % i
		)

		_add_mpf_var_handler(
			"machine_var_iscored_%s_name" % i,
			"iscored_%s_name" % i
		)

		_add_mpf_var_handler(
			"machine_var_iscored_%s_score" % i,
			"iscored_%s_score" % i
		)

		_add_mpf_var_handler(
			"machine_var_iscored_%s_score_text" % i,
			"iscored_%s_score_text" % i
		)


func _add_mpf_var_handler(event_name: String, clean_name: String) -> void:
	var callback := Callable(self, "_on_iscored_machine_var_event").bind(clean_name)

	mpf_event_handlers[event_name] = callback
	MPF.server.add_event_handler(event_name, callback)


func _on_iscored_machine_var_event(payload: Dictionary, clean_name: String) -> void:
	if not payload.has("value"):
		return

	var value = payload["value"]

	print("iScored live var: ", clean_name, " = ", value)

	set_machine_var(clean_name, value)


func _pull_existing_mpf_vars() -> void:
	for i in range(1, ROW_COUNT + 1):
		_pull_mpf_var("iscored_%s_rank" % i)
		_pull_mpf_var("iscored_%s_name" % i)
		_pull_mpf_var("iscored_%s_score" % i)
		_pull_mpf_var("iscored_%s_score_text" % i)


func _pull_mpf_var(key: String) -> void:
	if MPF.game.machine_vars.has(key):
		set_machine_var(key, MPF.game.machine_vars[key])
		return

	if MPF.game.machine_vars.has("machine_var_" + key):
		set_machine_var(key, MPF.game.machine_vars["machine_var_" + key])
		return


func set_machine_var(var_name: String, value) -> void:
	machine_vars[var_name] = value

	if var_name.begins_with("iscored_"):
		_refresh_rows()


func machine_var_changed(var_name: String, value) -> void:
	set_machine_var(var_name, value)


func _refresh_rows() -> void:
	if rank_labels.size() < ROW_COUNT:
		return

	for i in range(ROW_COUNT):
		var row := i + 1

		var rank_value := str(machine_vars.get("iscored_%s_rank" % row, row))
		var name_value := str(machine_vars.get("iscored_%s_name" % row, "---"))
		var score_value := str(machine_vars.get("iscored_%s_score_text" % row, "---"))

		rank_labels[i].text = rank_value
		name_labels[i].text = name_value
		score_labels[i].text = score_value


func _load_test_data() -> void:
	machine_vars["iscored_1_rank"] = "1"
	machine_vars["iscored_1_name"] = "Stephen Dowdle"
	machine_vars["iscored_1_score_text"] = "75,986,330"

	machine_vars["iscored_2_rank"] = "2"
	machine_vars["iscored_2_name"] = "ABC"
	machine_vars["iscored_2_score_text"] = "378,320"

	machine_vars["iscored_3_rank"] = "3"
	machine_vars["iscored_3_name"] = "SMD"
	machine_vars["iscored_3_score_text"] = "182,120"

	for i in range(4, 11):
		machine_vars["iscored_%s_rank" % i] = str(i)
		machine_vars["iscored_%s_name" % i] = "---"
		machine_vars["iscored_%s_score_text" % i] = "---"
