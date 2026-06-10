extends TextureRect

var john_frames: Array[Texture2D] = []


func _ready() -> void:
	load_john_frames()
	reset_john_health()


func load_john_frames() -> void:
	john_frames.clear()

	for i in range(1, 13):
		var path := "res://modes/karl_diehard/widgets/john%d.png" % i
		var texture_file := load(path)

		if texture_file == null:
			push_warning("Missing John health frame: %s" % path)
		else:
			john_frames.append(texture_file)


func set_john_health_frame(frame_number: int) -> void:
	if john_frames.is_empty():
		push_warning("John health frames not loaded.")
		return

	frame_number = clamp(frame_number, 1, 12)

	# john1.png = nearly defeated
	# john12.png = full health
	texture = john_frames[frame_number - 1]


func set_john_health_by_time(seconds_left: int, max_time: float = 90.0) -> void:
	# VPW-style:
	# Normal Karl: 90 seconds, health frame drops over 12 frames.
	# Hans Bonus Karl: 120 seconds, health frame drops over 12 frames.
	if max_time <= 0:
		max_time = 90.0

	var frame_number := int(ceil(float(seconds_left) / (max_time / 12.0)))
	frame_number = clamp(frame_number, 1, 12)

	set_john_health_frame(frame_number)


func reset_john_health() -> void:
	set_john_health_frame(12)


func clear_john_health() -> void:
	texture = null
