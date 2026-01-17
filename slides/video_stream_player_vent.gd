extends VideoStreamPlayer

@export_dir var folder_path: String = "res://videos"

@warning_ignore("shadowed_global_identifier")
var log: GMCLogger

var _rng := RandomNumberGenerator.new()
var files := _get_video_files("res://videos/vent", ["ogv"])

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	self.log = preload("res://addons/mpf-gmc/scripts/log.gd").new("VideoPlayer<%s>" % self.name)

	self.finished.connect(self._on_finished)


func _ready() -> void:
	self.finished.connect(self._on_finished)


func _on_finished() -> void:
	self.visible = false;



func play_random(payload: Dictionary) -> void:
	_rng.randomize()

	if files.is_empty():
		self.log.debug("No video files found in: %s (allowed: %s)" % [folder_path, ["ogv"]])
		return
#
	var chosen_path := files[_rng.randi_range(0, files.size() - 1)]
	print(chosen_path)
	self.visible = true;
	_set_stream_from_path(chosen_path)

func _get_video_files(dir_path: String, exts: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		self.log.debug("Could not open folder: %s" % dir_path)
		return out

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue

		var ext := name.get_extension().to_lower()
		if exts.has(ext):
			out.append(dir_path.path_join(name))
	dir.list_dir_end()

	return out

func _set_stream_from_path(path: String) -> void:
	# For .ogv (Theora), create a VideoStreamTheora and set its file.
	# If you use other formats, you may need a different VideoStream resource type/plugin.
	var ext := path.get_extension().to_lower()
	print(ext)
	if ext == "ogv":
		stream = load(path)
		play();
	else:
		self.log.debug("Unsupported extension for built-in playback: %s (%s)" % [ext, path])
