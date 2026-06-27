extends MPFSlide

@export var highlight_color: Color = Color(1.0, 0.0, 0.0, 1.0)

@onready var service_background: TextureRect = $ServiceMode

const DIEHARD_FONT_PATH := "res://godot-media/fonts/DieHardVPX-Regular.ttf"

const TRIGGERS := [
	"service_button",
	"service_switch_test_start",
	"service_switch_test_stop",
	"service_coil_test_start",
	"service_coil_test_stop",
	"service_light_test_start",
	"service_light_test_stop",
]

const BALL_STATUS_SWITCHES := [
	["TROUGH 1", "s_trough1"],
	["TROUGH 2", "s_trough2"],
	["TROUGH 3", "s_trough3"],
	["TROUGH 4", "s_trough4"],
	["TROUGH 5", "s_trough5"],
	["TROUGH 6", "s_trough6"],
	["TROUGH JAM", "s_trough_jam"],
	["PLUNGER", "s_plunger_lane"],
	["VAULT KICKER", "s_kickervault1"],
	["RIGHT KICKER", "s_rightkicker"],
	["UPPER RAMP VUK", "s_UrampUp001"],
	["RIGHT VUK", "s_rightvuk"],
	["TOWER VUK", "s_towervuk"],
	["AIRPLANE", "s_captiveball"],
]

const DEVICE_TESTS := [
	["TROUGH EJECT", "service_test_trough_eject"],
	["PLUNGER", "service_test_plunger"],
	["VAULT KICKER", "service_test_vault_kicker"],
	["RIGHT KICKER", "service_test_right_kicker"],
	["UPPER RAMP VUK", "service_test_upper_ramp_vuk"],
	["RIGHT VUK", "service_test_right_vuk"],
	["TOWER VUK", "service_test_tower_vuk"],
	["AIRPLANE CAPTIVE", "service_test_airplane_captive"],
	["LEFT MAGNET", "service_test_left_magnet"],
	["RIGHT MAGNET", "service_test_right_magnet"],
	["SHAKER LIGHT", "service_test_shaker_light"],
	["SHAKER MEDIUM", "service_test_shaker_medium"],
	["SHAKER STRONG", "service_test_shaker_strong"],
	["WIRE RAMP OPEN", "wire_ramp_exit_open"],
	["WIRE RAMP CLOSE", "wire_ramp_exit_closed"],
	["NAKATOMI ENTRANCE OPEN", "nakatomi_entrance_lock_open"],
	["NAKATOMI ENTRANCE CLOSE", "nakatomi_entrance_lock_close"],
	["NAKATOMI LOCK OPEN", "nakatomi_lock_open"],
	["NAKATOMI LOCK CLOSE", "nakatomi_lock_close"],
	["VAULT OPEN", "mystery_open_vault"],
	["VAULT CLOSE", "mystery_close_vault"],
]

var diehard_font: Font
var menu_items: Array[Label] = []
var detail_labels: Array[Label] = []
var selected_index := 0
var device_test_index := 0
var screen_mode := "menu"
var refresh_time := 0.0
var refresh_speed := 0.75
var switch_states := {}


func _ready() -> void:
	MPF.server.service.connect(_on_service)

	for trigger in TRIGGERS:
		MPF.server._send("register_trigger?event=%s" % trigger)

	set_anchors_preset(Control.PRESET_FULL_RECT)

	_load_font()
	_setup_background()
	_make_menu()
	_make_detail_screen()
	_show_menu()


func _exit_tree() -> void:
	for trigger in TRIGGERS:
		MPF.server._send("remove_trigger?event=%s" % trigger)


func _process(delta: float) -> void:
	if screen_mode != "ball_status":
		return

	refresh_time += delta

	if refresh_time >= refresh_speed:
		refresh_time = 0.0
		_request_ball_status()


func _load_font() -> void:
	if ResourceLoader.exists(DIEHARD_FONT_PATH):
		diehard_font = load(DIEHARD_FONT_PATH)
	else:
		diehard_font = null


func _setup_background() -> void:
	if not service_background:
		return

	service_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	service_background.offset_left = 0
	service_background.offset_top = 0
	service_background.offset_right = 0
	service_background.offset_bottom = 0
	service_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	service_background.stretch_mode = TextureRect.STRETCH_SCALE
	service_background.z_index = 0


func _make_menu() -> void:
	var start_y := 275
	var row_gap := 50
	var block_width := 760
	var screen_width := get_viewport_rect().size.x
	var x := int((screen_width - block_width) / 2)

	_add_menu_item("BALL STATUS", x, start_y + row_gap * 0)
	_add_menu_item("DEVICE TEST", x, start_y + row_gap * 1)
	_add_menu_item("SWITCH TEST", x, start_y + row_gap * 2)
	_add_menu_item("COIL TEST", x, start_y + row_gap * 3)
	_add_menu_item("LIGHT TEST", x, start_y + row_gap * 4)
	_add_menu_item("LIGHT CHAIN TEST", x, start_y + row_gap * 5)
	_add_menu_item("EXIT SERVICE", x, start_y + row_gap * 6)

	_add_hint("SERVICE UP/DOWN MOVE    SERVICE ENTER SELECT    SERVICE ESC BACK")


func _add_menu_item(text: String, x: int, y: int) -> void:
	var label := _make_label(text, Vector2(x, y), Vector2(760, 48), 38, Color.WHITE)
	menu_items.append(label)
	add_child(label)


func _make_detail_screen() -> void:
	var x := 230
	var start_y := 270
	var row_gap := 43

	for i in range(15):
		var label := _make_label("", Vector2(x, start_y + row_gap * i), Vector2(1240, 42), 31, Color.WHITE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.visible = false
		detail_labels.append(label)
		add_child(label)


func _add_hint(text: String) -> void:
	var hint := _make_label(
		text,
		Vector2(0, get_viewport_rect().size.y - 58),
		Vector2(get_viewport_rect().size.x, 42),
		24,
		Color.WHITE
	)
	hint.name = "ServiceHint"
	add_child(hint)


func _make_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 10

	if diehard_font:
		label.add_theme_font_override("font", diehard_font)

	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 5)
	label.add_theme_constant_override("shadow_offset_y", 5)

	return label


func _show_menu() -> void:
	screen_mode = "menu"

	for label in menu_items:
		label.visible = true

	for label in detail_labels:
		label.visible = false

	_update_menu()


func _show_detail(title: String, lines: Array[String]) -> void:
	for label in menu_items:
		label.visible = false

	for label in detail_labels:
		label.visible = false

	if detail_labels.size() == 0:
		return

	detail_labels[0].visible = true
	detail_labels[0].text = title
	detail_labels[0].add_theme_color_override("font_color", highlight_color)
	detail_labels[0].add_theme_font_size_override("font_size", 42)

	var max_lines := detail_labels.size() - 1

	for i in range(min(lines.size(), max_lines)):
		detail_labels[i + 1].visible = true
		detail_labels[i + 1].text = lines[i]
		detail_labels[i + 1].add_theme_color_override("font_color", Color.WHITE)
		detail_labels[i + 1].add_theme_font_size_override("font_size", 30)


func _request_ball_status() -> void:
	MPF.server.send_service("list_switches", ["name", "label", "state"])
	_show_ball_status()


func _show_ball_status() -> void:
	screen_mode = "ball_status"

	var lines: Array[String] = []

	for item in BALL_STATUS_SWITCHES:
		var display_label: String = str(item[0])
		var switch_name: String = str(item[1])
		var state: String = _get_ball_switch_state_text(switch_name)
		lines.append("%s: %s" % [display_label, state])

	_show_detail("BALL STATUS", lines)


func _show_device_test() -> void:
	screen_mode = "device_test"

	var selected_name: String = str(DEVICE_TESTS[device_test_index][0])

	_show_detail("DEVICE TEST", [
		"SELECTED: %s" % selected_name,
		"",
		"SERVICE UP/DOWN: CHANGE DEVICE",
		"SERVICE ENTER: FIRE SINGLE PULSE",
		"SERVICE ESC: BACK TO MENU",
		"",
		"WARNING: ONLY TEST WITH PLAYFIELD CLEAR",
	])


func _fire_selected_device_test() -> void:
	var event_name: String = str(DEVICE_TESTS[device_test_index][1])
	var selected_name: String = str(DEVICE_TESTS[device_test_index][0])

	MPF.server.send_event(event_name)

	_show_detail("DEVICE TEST", [
		"FIRED: %s" % selected_name,
		"",
		"SERVICE UP/DOWN: CHANGE DEVICE",
		"SERVICE ENTER: FIRE AGAIN",
		"SERVICE ESC: BACK TO MENU",
	])


func _update_switch_state_cache(payload: Dictionary) -> void:
	if not payload.has("switches"):
		return

	for switch_data in payload.switches:
		if switch_data.size() < 3:
			continue

		var switch_name: String = str(switch_data[0])
		var switch_state = switch_data[2]
		switch_states[switch_name] = switch_state

	if screen_mode == "ball_status":
		_show_ball_status()


func _get_ball_switch_state_text(switch_name: String) -> String:
	if not switch_states.has(switch_name):
		return "WAITING"

	var value = switch_states[switch_name]
	var active := false

	if typeof(value) == TYPE_BOOL:
		active = value
	elif typeof(value) == TYPE_INT:
		active = int(value) != 0
	elif typeof(value) == TYPE_FLOAT:
		active = float(value) != 0.0
	else:
		var text := str(value).to_upper()
		active = text == "1" or text == "TRUE" or text == "ACTIVE"

	if active:
		return "BALL"

	return "EMPTY"


func _update_menu() -> void:
	for i in range(menu_items.size()):
		var label := menu_items[i]
		var clean_text := _clean_menu_text(label.text)

		if i == selected_index:
			label.text = "> %s <" % clean_text
			label.add_theme_color_override("font_color", highlight_color)
			label.add_theme_font_size_override("font_size", 44)
		else:
			label.text = clean_text
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_font_size_override("font_size", 38)


func _clean_menu_text(text: String) -> String:
	var cleaned := text
	cleaned = cleaned.replace("> ", "")
	cleaned = cleaned.replace(" <", "")
	return cleaned


func _on_service(payload: Dictionary) -> void:
	if payload.has("cmd") and payload.cmd == "list_switches":
		_update_switch_state_cache(payload)
		return

	if payload.has("name"):
		_on_service_event(payload)

	if payload.has("button"):
		if screen_mode == "menu":
			_on_menu_button(payload.button)
		elif screen_mode == "ball_status":
			_on_ball_status_button(payload.button)
		elif screen_mode == "device_test":
			_on_device_test_button(payload.button)


func _on_service_event(payload: Dictionary) -> void:
	match payload.name:
		"service_switch_test_start":
			screen_mode = "switch_test"
			_show_switch_test(payload)

		"service_switch_test_stop":
			_show_menu()

		"service_coil_test_start":
			screen_mode = "coil_test"
			_show_coil_test(payload)

		"service_coil_test_stop":
			_show_menu()

		"service_light_test_start":
			screen_mode = "light_test"
			_show_light_test(payload)

		"service_light_test_stop":
			_show_menu()


func _show_switch_test(payload: Dictionary) -> void:
	var switch_name := str(payload.get("switch_name", ""))
	var switch_label := str(payload.get("switch_label", ""))
	var switch_num := str(payload.get("switch_num", ""))
	var switch_state := str(payload.get("switch_state", ""))

	if switch_label == "":
		switch_label = switch_name

	_show_detail("SWITCH TEST", [
		"SWITCH: %s" % switch_label,
		"NAME: %s" % switch_name,
		"NUMBER: %s" % switch_num,
		"STATE: %s" % switch_state.to_upper(),
		"PRESS SERVICE ESC TO RETURN",
	])


func _show_coil_test(payload: Dictionary) -> void:
	var coil_name := str(payload.get("coil_name", ""))
	var coil_label := str(payload.get("coil_label", ""))
	var coil_num := str(payload.get("coil_num", ""))
	var board_name := str(payload.get("board_name", ""))

	if coil_label == "":
		coil_label = coil_name

	_show_detail("COIL TEST", [
		"COIL: %s" % coil_label,
		"NAME: %s" % coil_name,
		"NUMBER: %s" % coil_num,
		"BOARD: %s" % board_name,
		"ENTER PULSES    UP/DOWN MOVES",
		"PRESS SERVICE ESC TO RETURN",
	])


func _show_light_test(payload: Dictionary) -> void:
	var light_name := str(payload.get("light_name", ""))
	var light_label := str(payload.get("light_label", ""))
	var light_num := str(payload.get("light_num", ""))
	var board_name := str(payload.get("board_name", ""))
	var test_color := str(payload.get("test_color", ""))

	if light_label == "":
		light_label = light_name

	_show_detail("LIGHT TEST", [
		"LIGHT: %s" % light_label,
		"NAME: %s" % light_name,
		"NUMBER: %s" % light_num,
		"BOARD: %s" % board_name,
		"COLOR: %s" % test_color.to_upper(),
		"ENTER CHANGES COLOR    UP/DOWN MOVES",
	])


func _on_menu_button(button: String) -> void:
	match button:
		"UP":
			_move_selection(-1)

		"DOWN":
			_move_selection(1)

		"ENTER":
			_select_current()

		"ESC":
			_exit_service()

		"START":
			_exit_service()


func _on_ball_status_button(button: String) -> void:
	match button:
		"UP":
			_show_menu()

		"DOWN":
			_show_menu()

		"ESC":
			_show_menu()

		"START":
			_show_menu()

		"ENTER":
			_show_menu()


func _on_device_test_button(button: String) -> void:
	match button:
		"UP":
			device_test_index -= 1
			if device_test_index < 0:
				device_test_index = DEVICE_TESTS.size() - 1
			_show_device_test()

		"DOWN":
			device_test_index += 1
			if device_test_index >= DEVICE_TESTS.size():
				device_test_index = 0
			_show_device_test()

		"ENTER":
			_fire_selected_device_test()

		"ESC":
			_show_menu()

		"START":
			_show_menu()


func _move_selection(direction: int) -> void:
	selected_index += direction

	if selected_index < 0:
		selected_index = menu_items.size() - 1

	if selected_index >= menu_items.size():
		selected_index = 0

	_update_menu()


func _select_current() -> void:
	match selected_index:
		0:
			screen_mode = "ball_status"
			_show_detail("BALL STATUS", ["WAITING FOR SWITCH DATA..."])
			_request_ball_status()

		1:
			screen_mode = "device_test"
			_show_device_test()

		2:
			screen_mode = "switch_test"
			_show_detail("SWITCH TEST", ["WAITING FOR SWITCH DATA..."])
			MPF.server.send_event("service_trigger&action=switch_test")

		3:
			screen_mode = "coil_test"
			_show_detail("COIL TEST", ["WAITING FOR COIL DATA..."])
			MPF.server.send_event("service_trigger&action=coil_test")

		4:
			screen_mode = "light_test"
			_show_detail("LIGHT TEST", ["WAITING FOR LIGHT DATA..."])
			MPF.server.send_event("service_trigger&action=light_test")

		5:
			screen_mode = "light_test"
			_show_detail("LIGHT CHAIN TEST", ["WAITING FOR LIGHT CHAIN DATA..."])
			MPF.server.send_event("service_trigger&action=light_chain_test")

		6:
			_exit_service()


func _exit_service() -> void:
	MPF.server.send_event("service_trigger&action=service_exit")
