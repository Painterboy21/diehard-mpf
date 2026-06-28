
extends Node

const SETTINGS_FILE := "user://settings.cfg"

const GODOT_VOLUME_SETTINGS := [
	"Master",
	"music",
	"effects",
	"voice",
	"video",
]

func _ready() -> void:
	print("StartupVolume: running")
	_apply_volume_repeated()


func _apply_volume_repeated() -> void:
	_apply_saved_volumes()

	await get_tree().create_timer(0.25).timeout
	_apply_saved_volumes()

	await get_tree().create_timer(0.75).timeout
	_apply_saved_volumes()

	await get_tree().create_timer(1.5).timeout
	_apply_saved_volumes()

	await get_tree().create_timer(2.5).timeout
	_apply_saved_volumes()

	await get_tree().create_timer(4.0).timeout
	_apply_saved_volumes()


func _apply_saved_volumes() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_FILE)

	if error != OK:
		print("StartupVolume: no saved settings file yet")
		return

	for bus_name in GODOT_VOLUME_SETTINGS:
		var saved_value = config.get_value("audio", bus_name, null)

		if saved_value == null:
			continue

		var percent: int = clamp(int(saved_value), 0, 100)
		_apply_bus_percent(bus_name, percent)


func _apply_bus_percent(bus_name: String, percent: int) -> void:
	var linear_value: float = 0.0

	if percent <= 0:
		linear_value = 0.0
	else:
		linear_value = float(percent) / 100.0

	var db_value: float = -80.0

	if linear_value > 0.0:
		db_value = linear_to_db(linear_value)

	var audio_bus_index: int = AudioServer.get_bus_index(bus_name)

	if audio_bus_index >= 0:
		AudioServer.set_bus_volume_db(audio_bus_index, db_value)

	if bus_name != "Master" and MPF and MPF.media and MPF.media.sound:
		if MPF.media.sound.buses.has(bus_name):
			MPF.media.sound.buses[bus_name].set_bus_volume_full(db_value)

	print("StartupVolume: applied ", bus_name, " = ", percent)
