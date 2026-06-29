extends Node

const SETTINGS_FILE := "user://settings.cfg"

const GODOT_VOLUME_SETTINGS := [
	"Master",
	"music",
	"effects",
	"voice",
	"video",
]

var apply_time_left := 90.0
var apply_interval := 0.25
var apply_elapsed := 0.0


func _ready() -> void:
	_apply_saved_volumes()


func _process(delta: float) -> void:
	if apply_time_left <= 0.0:
		return

	apply_time_left -= delta
	apply_elapsed += delta

	if apply_elapsed >= apply_interval:
		apply_elapsed = 0.0
		_apply_saved_volumes()


func _apply_saved_volumes() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_FILE)

	if error != OK:
		return

	for bus_name in GODOT_VOLUME_SETTINGS:
		var saved_value = config.get_value("audio", bus_name, null)
		if saved_value == null:
			continue

		var percent: int = clamp(int(saved_value), 0, 100)
		_apply_bus_percent(bus_name, percent)


func _apply_bus_percent(bus_name: String, percent: int) -> void:
	var linear_value := 0.0

	if percent > 0:
		linear_value = float(percent) / 100.0

	var db_value := -80.0

	if linear_value > 0.0:
		db_value = linear_to_db(linear_value)

	var audio_bus_index := AudioServer.get_bus_index(bus_name)

	if audio_bus_index >= 0:
		AudioServer.set_bus_volume_db(audio_bus_index, db_value)

	if bus_name != "Master" and MPF and MPF.media and MPF.media.sound:
		if MPF.media.sound.buses.has(bus_name):
			MPF.media.sound.buses[bus_name].set_bus_volume_full(db_value)
