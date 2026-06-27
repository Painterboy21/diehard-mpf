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

var diehard_font: Font
var menu_items: Array[Label] = []
var selected_index := 0


func _ready() -> void:
	MPF.server.service.connect(_on_service)

	for trigger in TRIGGERS:
		MPF.server._send("register_trigger?event=%s" % trigger)

	set_anchors_preset(Control.PRESET_FULL_RECT)

	_load_font()
	_setup_background()
	_make_menu()
	_update_menu()


func _exit_tree() -> void:
	for trigger in TRIGGERS:
		MPF.server._send("remove_trigger?event=%s" % trigger)


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
	var start_y := 330
	var row_gap := 58
	var block_width := 760
	var screen_width := get_viewport_rect().size.x
	var x := int((screen_width - block_width) / 2)

	_add_menu_item("SWITCH TEST", x, start_y + row_gap * 0)
	_add_menu_item("COIL TEST", x, start_y + row_gap * 1)
	_add_menu_item("LIGHT TEST", x, start_y + row_gap * 2)
	_add_menu_item("LIGHT CHAIN TEST", x, start_y + row_gap * 3)
	_add_menu_item("EXIT SERVICE", x, start_y + row_gap * 4)

	_add_hint()


func _add_menu_item(text: String, x: int, y: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(x, y)
	label.size = Vector2(760, 54)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 10

	if diehard_font:
		label.add_theme_font_override("font", diehard_font)

	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 5)
	label.add_theme_constant_override("shadow_offset_y", 5)

	menu_items.append(label)
	add_child(label)


func _add_hint() -> void:
	var hint := Label.new()
	hint.text = "SERVICE UP/DOWN MOVE    SERVICE ENTER SELECT    SERVICE ESC BACK"
	hint.position = Vector2(0, get_viewport_rect().size.y - 58)
	hint.size = Vector2(get_viewport_rect().size.x, 42)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.z_index = 10

	if diehard_font:
		hint.add_theme_font_override("font", diehard_font)

	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color.WHITE)
	hint.add_theme_constant_override("outline_size", 5)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 4)
	hint.add_theme_constant_override("shadow_offset_y", 4)

	add_child(hint)


func _update_menu() -> void:
	for i in menu_items.size():
		var label := menu_items[i]

		if i == selected_index:
			label.text = "> %s <" % _clean_menu_text(label.text)
			label.add_theme_color_override("font_color", highlight_color)
			label.add_theme_font_size_override("font_size", 48)
		else:
			label.text = _clean_menu_text(label.text)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_font_size_override("font_size", 42)


func _clean_menu_text(text: String) -> String:
	var cleaned := text
	cleaned = cleaned.replace("> ", "")
	cleaned = cleaned.replace(" <", "")
	return cleaned


func _on_service(payload: Dictionary) -> void:
	if not payload.has("button"):
		return

	match payload.button:
		"UP":
			_move_selection(-1)

		"DOWN":
			_move_selection(1)

		"ENTER":
			_select_current()

		"ESC":
			_go_back()

		"START":
			_exit_service()


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
			MPF.server.send_event("service_trigger&action=switch_test")

		1:
			MPF.server.send_event("service_trigger&action=coil_test")

		2:
			MPF.server.send_event("service_trigger&action=light_test")

		3:
			MPF.server.send_event("service_trigger&action=light_chain_test")

		4:
			_exit_service()


func _go_back() -> void:
	_exit_service()


func _exit_service() -> void:
	MPF.server.send_event("service_trigger&action=service_exit")
