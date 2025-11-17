extends Node

const CONFIG_FILE = "user://settings.cfg"

func _ready():
	load_window_settings()
	MPF.server.add_event_handler("windowtitle", self._on_hello)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_window_settings()

func _on_hello(payload: Dictionary) -> void:
	DisplayServer.window_set_title("pygame")

func save_window_settings():
	var config = ConfigFile.new()

	var window = get_window()

	config.set_value("window", "size", window.size)
	config.set_value("window", "position", window.position)

	var error = config.save(CONFIG_FILE)
	if error != OK:
		print("Failed to save window settings: ", error)

func load_window_settings():
	var config = ConfigFile.new()
	var error = config.load(CONFIG_FILE)

	if error == OK:
		var size = config.get_value("window", "size", Vector2i(800, 600))  # Default size
		var position = config.get_value("window", "position", Vector2i(100, 100))  # Default position
		var borderless = config.get_value("window", "borderless", false)  # Default to false

		var window = get_window()
		window.size = size
		window.position = position
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)

	else:
		print("No settings file found or other error: ", error)
