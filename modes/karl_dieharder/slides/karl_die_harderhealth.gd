extends TextureRect

# ------------------------------------------------------------
# KARL DIE HARDER - KARL HEALTH BAR
# ------------------------------------------------------------
#
# Attach this to:
#
#   Control1/karlDieHarderhealth
#
# Reuses the existing Karl health images:
#
#   res://modes/karl_diehard/widgets/karl1.png
#   ...
#   res://modes/karl_diehard/widgets/karl12.png
# ------------------------------------------------------------


var karl_frames: Array[Texture2D] = []


func _ready() -> void:
	load_karl_frames()
	reset_karl_health()


func load_karl_frames() -> void:
	karl_frames.clear()

	for i in range(1, 13):
		var path := "res://modes/karl_diehard/widgets/karl%d.png" % i
		var texture_file := load(path)

		if texture_file == null:
			push_warning("Missing Karl health frame: %s" % path)
		else:
			karl_frames.append(texture_file)


func set_karl_health_frame(frame_number: int) -> void:
	if karl_frames.is_empty():
		push_warning("Karl health frames not loaded.")
		return

	frame_number = clamp(frame_number, 1, 12)

	texture = karl_frames[frame_number - 1]


func set_karl_health_by_damage(karl_damage: int) -> void:
	var frame_number := 12 - int(float(karl_damage) * 0.12)
	frame_number = clamp(frame_number, 1, 12)

	set_karl_health_frame(frame_number)


func reset_karl_health() -> void:
	set_karl_health_frame(12)


func clear_karl_health() -> void:
	texture = null
