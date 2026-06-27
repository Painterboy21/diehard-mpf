extends MPFSlide

@export var highlight_color: Color = Color(1.0, 0.0, 0.0, 1.0)

const DIEHARD_FONT_PATH := "res://godot-media/fonts/DieHardVPX-Regular.ttf"
const SETTINGS_FILE := "user://settings.cfg"

const TRIGGERS := [
	"service_button",
	"service_switch_test_start",
	"service_switch_test_stop",
	"service_coil_test_start",
	"service_coil_test_stop",
	"service_light_test_start",
	"service_light_test_stop",
]

const MENU_ITEMS := [
	"VOLUME SETTINGS",
	"BALL STATUS",
	"DEVICE TEST",
	"SWITCH TEST",
	"LIGHTS",
	"FREE PLAY",
	"RESET GAME",
	"CLOSE DOOR TO RESUME",
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
	["FULL MECH CHECK", "service_test_full_mech_check"],
]

const LAMP_GROUP_TESTS := [
	["INSERTS RED", "service_test_lamps_inserts"],
	["GI WHITE", "service_test_lamps_gi"],
	["FLASHERS WHITE", "service_test_lamps_flashers"],
	["CABINET RED", "service_test_lamps_cabinet"],
	["ALL WHITE", "service_test_lamps_all_white"],
	["ALL RED", "service_test_lamps_all_red"],
	["ALL GREEN", "service_test_lamps_all_green"],
	["ALL BLUE", "service_test_lamps_all_blue"],
	["ALL OFF", "service_test_lamps_all_off"],
]

const GODOT_VOLUME_SETTINGS := [
	["MASTER", "Master"],
	["MUSIC", "music"],
	["EFFECTS", "effects"],
	["VOICE", "voice"],
	["VIDEO", "video"],
]

const HARDWARE_VOLUME_SETTINGS := [
	["BACK SPEAKERS", "fast_audio_main_volume", "increase_main_volume", "decrease_main_volume", 30],
	["BASS / SUB", "fast_audio_sub_volume", "increase_sub_volume", "decrease_sub_volume", 60],
	["HEADPHONES", "fast_audio_headphones_volume", "increase_headphones_volume", "decrease_headphones_volume", 10],
]

var service_background: TextureRect
var diehard_font: Font
var menu_items: Array[Label] = []
var detail_labels: Array[Label] = []
var selected_index := 0
var page_index := 0
var screen_mode := "menu"
var refresh_time := 0.0
var refresh_speed := 0.75
var switch_states := {}
var last_switch_name := "NONE"
var last_switch_state := "NONE"


func _ready() -> void:
	service_background = get_node_or_null("ServiceMode")
	if not service_background:
		service_background = get_node_or_null("servicemode")

	MPF.server.service.connect(_on_service)

	for trigger in TRIGGERS:
		MPF.server._send("register_trigger?event=%s" % trigger)

	set_anchors_preset(Control.PRESET_FULL_RECT)

	_load_font()
	_load_godot_volume_settings()
	_setup_background()
	_make_menu()
	_make_detail_screen()
	_show_menu()
	_request_switches()


func _exit_tree() -> void:
	for trigger in TRIGGERS:
		MPF.server._send("remove_trigger?event=%s" % trigger)


func _process(delta: float) -> void:
	if screen_mode != "ball_status":
		return

	refresh_time += delta

	if refresh_time >= refresh_speed:
		refresh_time = 0.0
		_request_switches()


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
	var start_y := 310
	var row_gap := 54
	var block_width := 760
	var screen_width := get_viewport_rect().size.x
	var x := int((screen_width - block_width) / 2)

	for i in range(MENU_ITEMS.size()):
		_add_menu_item(MENU_ITEMS[i], x, start_y + row_gap * i)

	_add_hint("SERVICE UP/DOWN MOVE    SERVICE ENTER SELECT    SERVICE ESC BACK")


func _add_menu_item(text: String, x: int, y: int) -> void:
	var label := _make_label(text, Vector2(x, y), Vector2(760, 48), 38, Color.WHITE)
	menu_items.append(label)
	add_child(label)


func _make_detail_screen() -> void:
	var x := 165
	var start_y := 305
	var row_gap := 48

	for i in range(16):
		var label := _make_label("", Vector2(x, start_y + row_gap * i), Vector2(1390, 42), 30, Color.WHITE)
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


func _request_switches() -> void:
	MPF.server.send_service("list_switches", ["name", "label", "state"])


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


func _show_ball_status() -> void:
	screen_mode = "ball_status"

	var lines: Array[String] = []

	for item in BALL_STATUS_SWITCHES:
		var display_label: String = str(item[0])
		var switch_name: String = str(item[1])
		lines.append("%s: %s" % [display_label, _get_ball_switch_state_text(switch_name)])

	_show_detail("BALL STATUS", lines)


func _show_indexed_test(title: String, rows: Array) -> void:
	var selected_name: String = str(rows[page_index][0])

	_show_detail(title, [
		"SELECTED: %s" % selected_name,
		"",
		"SERVICE UP/DOWN: CHANGE ITEM",
		"SERVICE ENTER: RUN TEST",
		"SERVICE ESC: BACK TO MENU",
		"",
		"WARNING: ONLY TEST WITH PLAYFIELD CLEAR",
	])


func _fire_indexed_test(rows: Array, title: String) -> void:
	var event_name: String = str(rows[page_index][1])
	var selected_name: String = str(rows[page_index][0])

	MPF.server.send_event(event_name)

	_show_detail(title, [
		"FIRED: %s" % selected_name,
		"",
		"SERVICE UP/DOWN: CHANGE ITEM",
		"SERVICE ENTER: FIRE AGAIN",
		"SERVICE ESC: BACK TO MENU",
	])


func _show_volume_settings() -> void:
	screen_mode = "volume_settings"
	page_index = 0
	_show_volume_page()


func _show_volume_page() -> void:
	var lines: Array[String] = []
	var row_number := 0

	lines.append("SERVICE UP/DOWN: SELECT    ENTER: UP    START: DOWN    ESC: BACK")
	lines.append("")

	for item in _available_godot_volume_rows():
		var label: String = str(item[0])
		var bus_name: String = str(item[1])
		var value: int = _get_godot_bus_percent(bus_name)
		lines.append(_volume_row_text(row_number, label, value, 100))
		row_number += 1

	for item in HARDWARE_VOLUME_SETTINGS:
		var label: String = str(item[0])
		var var_name: String = str(item[1])
		var fallback: int = int(item[4])
		var value: int = _get_machine_volume(var_name, fallback)
		lines.append(_volume_row_text(row_number, label, value, 63))
		row_number += 1

	_show_detail("VOLUME SETTINGS", lines)


func _show_free_play() -> void:
	screen_mode = "free_play"
	_show_detail("FREE PLAY", [
		"STATUS: ENABLED",
		"",
		"THIS BUILD DOES NOT USE THE MPF CREDITS MODE",
		"START BUTTON CAN START A GAME WITHOUT COINS",
		"",
		"SERVICE ESC: BACK TO MENU",
	])


func _update_switch_state_cache(payload: Dictionary) -> void:
	if not payload.has("switches"):
		return

	for switch_data in payload.switches:
		var switch_name: String = _payload_value(switch_data, 0, "name")
		var switch_state = _payload_raw_value(switch_data, 2, "state")
		switch_states[switch_name] = switch_state

	if screen_mode == "ball_status":
		_show_ball_status()


func _payload_value(item, array_index: int, dict_key: String) -> String:
	var value = _payload_raw_value(item, array_index, dict_key)
	return str(value)


func _payload_raw_value(item, array_index: int, dict_key: String):
	if typeof(item) == TYPE_DICTIONARY and item.has(dict_key):
		return item[dict_key]

	if typeof(item) == TYPE_ARRAY and item.size() > array_index:
		return item[array_index]

	return ""


func _get_ball_switch_state_text(switch_name: String) -> String:
	if not switch_states.has(switch_name):
		return "WAITING"

	if _switch_active(switch_name):
		return "BALL"

	return "EMPTY"


func _switch_active(switch_name: String) -> bool:
	if not switch_states.has(switch_name):
		return false

	var value = switch_states[switch_name]

	if typeof(value) == TYPE_BOOL:
		return value
	elif typeof(value) == TYPE_INT:
		return int(value) != 0
	elif typeof(value) == TYPE_FLOAT:
		return float(value) != 0.0

	var text := str(value).to_upper()
	return text == "1" or text == "TRUE" or text == "ACTIVE"


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
	if payload.has("cmd") and str(payload.cmd) == "list_switches":
		_update_switch_state_cache(payload)
		return

	if payload.has("switch"):
		last_switch_name = str(payload.switch)
		if payload.has("state"):
			last_switch_state = str(payload.state)
		_request_switches()

	if payload.has("name"):
		_on_service_event(payload)

	if payload.has("button"):
		_on_button(str(payload.button))


func _on_service_event(payload: Dictionary) -> void:
	match str(payload.name):
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


func _on_button(button: String) -> void:
	match screen_mode:
		"menu":
			_on_menu_button(button)
		"ball_status":
			_on_back_only_button(button)
		"device_test":
			_on_indexed_button(button, DEVICE_TESTS, "DEVICE TEST")
		"lamp_groups":
			_on_indexed_button(button, LAMP_GROUP_TESTS, "LIGHTS")
		"volume_settings":
			_on_volume_button(button)
		"free_play":
			_on_back_only_button(button)
		"reset_game_confirm":
			_on_reset_game_confirm_button(button)
		_:
			if button == "ESC" or button == "START":
				_show_menu()


func _on_menu_button(button: String) -> void:
	match button:
		"UP":
			_move_selection(-1)

		"DOWN":
			_move_selection(1)

		"ENTER":
			_select_current()

		"ESC", "START":
			_exit_service()


func _on_back_only_button(button: String) -> void:
	match button:
		"UP", "DOWN", "ESC", "START", "ENTER":
			_show_menu()


func _on_indexed_button(button: String, rows: Array, title: String) -> void:
	match button:
		"UP":
			page_index -= 1
			if page_index < 0:
				page_index = rows.size() - 1
			_show_indexed_test(title, rows)

		"DOWN":
			page_index += 1
			if page_index >= rows.size():
				page_index = 0
			_show_indexed_test(title, rows)

		"ENTER":
			_fire_indexed_test(rows, title)

		"ESC", "START":
			_show_menu()


func _on_volume_button(button: String) -> void:
	var row_count := HARDWARE_VOLUME_SETTINGS.size() + _available_godot_volume_rows().size()

	if row_count <= 0:
		_show_menu()
		return

	match button:
		"UP":
			page_index -= 1
			if page_index < 0:
				page_index = row_count - 1
			_show_volume_page()

		"DOWN":
			page_index += 1
			if page_index >= row_count:
				page_index = 0
			_show_volume_page()

		"ENTER":
			_adjust_selected_volume(1)
			_show_volume_page()

		"START":
			_adjust_selected_volume(-1)
			_show_volume_page()

		"ESC":
			_show_menu()


func _adjust_selected_volume(direction: int) -> void:
	var godot_rows := _available_godot_volume_rows()

	if page_index < godot_rows.size():
		var bus_name: String = str(godot_rows[page_index][1])
		_adjust_godot_bus(bus_name, direction * 5)
		return

	var hardware_index := page_index - godot_rows.size()

	if hardware_index < HARDWARE_VOLUME_SETTINGS.size():
		var item = HARDWARE_VOLUME_SETTINGS[hardware_index]
		var var_name: String = str(item[1])
		var up_event: String = str(item[2])
		var down_event: String = str(item[3])
		var fallback: int = int(item[4])

		if direction > 0:
			MPF.server.send_event(up_event)
		else:
			MPF.server.send_event(down_event)

		var new_value: int = clamp(_get_machine_volume(var_name, fallback) + direction, 0, 63)
		_set_machine_volume_cache(var_name, new_value)


func _volume_row_text(row_number: int, label: String, value: int, max_value: int) -> String:
	var marker := "  "

	if row_number == page_index:
		marker = "> "

	return "%s%s  %d/%d  %s" % [marker, label, value, max_value, _volume_bar(value, max_value)]


func _volume_bar(value: int, max_value: int) -> String:
	var width := 18
	var safe_max: int = max(max_value, 1)
	var safe_value: int = clamp(value, 0, safe_max)
	var filled := int(round(float(safe_value) / float(safe_max) * float(width)))
	var output := "["

	for i in range(width):
		if i < filled:
			output += "#"
		else:
			output += "-"

	output += "]"
	return output


func _get_machine_volume(var_name: String, fallback: int) -> int:
	var machine_vars = MPF.game.machine_vars
	var value = fallback

	if machine_vars.has(var_name):
		value = machine_vars[var_name]
	elif machine_vars.has("machine_var_" + var_name):
		value = machine_vars["machine_var_" + var_name]

	if typeof(value) == TYPE_DICTIONARY and value.has("value"):
		value = value["value"]

	return clamp(int(value), 0, 63)


func _set_machine_volume_cache(var_name: String, value: int) -> void:
	var machine_vars = MPF.game.machine_vars

	if machine_vars.has(var_name):
		machine_vars[var_name] = value
	elif machine_vars.has("machine_var_" + var_name):
		machine_vars["machine_var_" + var_name] = value


func _available_godot_volume_rows() -> Array:
	var rows: Array = []

	for item in GODOT_VOLUME_SETTINGS:
		var bus_name: String = str(item[1])

		if AudioServer.get_bus_index(bus_name) >= 0:
			rows.append(item)

	return rows


func _get_godot_bus_percent(bus_name: String) -> int:
	var bus_index := AudioServer.get_bus_index(bus_name)

	if bus_index < 0:
		return 0

	var db := AudioServer.get_bus_volume_db(bus_index)
	var linear := db_to_linear(db)
	return clamp(int(round(linear * 100.0)), 0, 100)


func _adjust_godot_bus(bus_name: String, change: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)

	if bus_index < 0:
		return

	var new_value: int = clamp(_get_godot_bus_percent(bus_name) + change, 0, 100)

	if new_value <= 0:
		AudioServer.set_bus_volume_db(bus_index, -80.0)
	else:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(float(new_value) / 100.0))

	_save_godot_volume_settings()


func _load_godot_volume_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_FILE)

	if error != OK:
		return

	for item in GODOT_VOLUME_SETTINGS:
		var bus_name: String = str(item[1])
		var bus_index := AudioServer.get_bus_index(bus_name)

		if bus_index < 0:
			continue

		var saved_value = config.get_value("audio", bus_name, null)

		if saved_value == null:
			continue

		var percent: int = clamp(int(saved_value), 0, 100)

		if percent <= 0:
			AudioServer.set_bus_volume_db(bus_index, -80.0)
		else:
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(float(percent) / 100.0))


func _save_godot_volume_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_FILE)

	for item in GODOT_VOLUME_SETTINGS:
		var bus_name: String = str(item[1])
		var bus_index := AudioServer.get_bus_index(bus_name)

		if bus_index < 0:
			continue

		config.set_value("audio", bus_name, _get_godot_bus_percent(bus_name))

	config.save(SETTINGS_FILE)


func _move_selection(direction: int) -> void:
	selected_index += direction

	if selected_index < 0:
		selected_index = menu_items.size() - 1

	if selected_index >= menu_items.size():
		selected_index = 0

	_update_menu()


func _select_current() -> void:
	var item := _clean_menu_text(menu_items[selected_index].text)

	match item:
		"VOLUME SETTINGS":
			_show_volume_settings()

		"BALL STATUS":
			screen_mode = "ball_status"
			_show_detail("BALL STATUS", ["WAITING FOR SWITCH DATA..."])
			_request_switches()

		"DEVICE TEST":
			screen_mode = "device_test"
			page_index = 0
			_show_indexed_test("DEVICE TEST", DEVICE_TESTS)

		"SWITCH TEST":
			screen_mode = "switch_test"
			_show_detail("SWITCH TEST", ["WAITING FOR SWITCH DATA..."])
			MPF.server.send_event("service_trigger&action=switch_test")

		"LIGHTS":
			screen_mode = "lamp_groups"
			page_index = 0
			_show_indexed_test("LIGHTS", LAMP_GROUP_TESTS)

		"FREE PLAY":
			_show_free_play()

		"RESET GAME":
			_show_reset_game_confirm()

		"CLOSE DOOR TO RESUME":
			_exit_service()


func _show_reset_game_confirm() -> void:
	screen_mode = "reset_game_confirm"
	_show_detail("RESET GAME", [
		"END CURRENT GAME AND RETURN TO ATTRACT?",
		"",
		"SERVICE ENTER: RESET GAME",
		"SERVICE ESC: BACK TO MENU",
		"",
		"CLOSE THE DOOR TO CONTINUE THE CURRENT GAME",
	])


func _on_reset_game_confirm_button(button: String) -> void:
	match button:
		"ENTER":
			_reset_game_from_service()

		"ESC", "START", "UP", "DOWN":
			_show_menu()


func _reset_game_from_service() -> void:
	MPF.server.send_event("service_reset_game_requested")


func _exit_service() -> void:
	_show_detail("CLOSE DOOR TO RESUME", [
		"CLOSE THE COIN DOOR TO RESUME THE CURRENT GAME",
		"",
		"RESET GAME IS THE ONLY OPTION THAT ENDS THE GAME",
	])
