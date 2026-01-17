@tool
class_name MPFRandomVideoPlayer
extends VideoStreamPlayer
## Renders a VideoStreamPlayer with options for end behavior and events.

enum HideBehavior {
	## Stop playback when hidden and restart when visible
	RESTART,
	## Pause playback when hidden and resume when visible
	PAUSE,
	## Continue playback even when hidden
	CONTINUE,
}

enum EndBehavior {
	## No special behavior after the video ends
	NOTHING,
	## Remove the parent MPFSlide (or MPFWidget) that holds this VideoPlayer
	REMOVE_SLIDE,
	## Call a custom method on this node
	CUSTOM_METHOD,
	## Call a custom method on the parent MPFSlide (or MPFWidget) that holds this VideoPlayer
	PARENT_METHOD,
}

## The action to take when this video node (or a parent) is hidden
@export var hide_behavior: HideBehavior
## The action to take after this video finishes playing.
@export var end_behavior: EndBehavior
## An event (or comma-separated list of events) to be posted to MPF when the video finishes.
@export var events_when_stopped: String
## The name of the method to call when the video finishes when end behavior is a method.
@export var end_method: String
## Ducking Settings
@export var ducking: DuckSettings
## If true, render the video in the editor (first frame)
@export var preview_in_editor: bool = false

@export_dir var folder_path: String = "res://videos"

@warning_ignore("shadowed_global_identifier")
var log: GMCLogger

var _rng := RandomNumberGenerator.new()

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	self.log = preload("res://addons/mpf-gmc/scripts/log.gd").new("VideoPlayer<%s>" % self.name)

	_rng.randomize()
	var files := _get_video_files(folder_path, ["ogv"])
#
	if files.is_empty():
		self.log.debug("No video files found in: %s (allowed: %s)" % [folder_path, ["ogv"]])
		return
#
	var chosen_path := files[_rng.randi_range(0, files.size() - 1)]
	print(chosen_path)
	_set_stream_from_path(chosen_path)

	if not self.is_visible_in_tree() and self.hide_behavior != HideBehavior.CONTINUE:
		self.stop()

func _ready() -> void:

	if Engine.is_editor_hint():
		if self.preview_in_editor:
			self.play()
		return

	self.finished.connect(self._on_finished)
	self.visibility_changed.connect(self._on_visibility)
	if self.is_playing() and self.ducking:
		self.ducking.calculate_release_time(Time.get_ticks_msec())
		#self.ducking.bus.duck(self.ducking)
		MPF.media.sound.buses[self.ducking.target_bus].duck(self.ducking)

func _play() -> void:
	self.play()
	if self.ducking:
		self.ducking.calculate_release_time(Time.get_ticks_msec())
		self.ducking.bus.duck(self.ducking)

func _on_visibility() -> void:
	var do_show: bool = self.is_visible_in_tree() and self.autoplay and not Engine.is_editor_hint()
	self.log.debug("Visibility change, visible is now %s", do_show)
	print("fg")
	match self.hide_behavior:
		HideBehavior.RESTART:
			if do_show:
				self._play()
			else:
				self.stop()
		HideBehavior.PAUSE:
			self.paused = not do_show
			self.log.debug("Pause state set to %s", self.paused)
			if not self.paused and not self.is_playing():
				self._play()
		HideBehavior.CONTINUE:
			if do_show and not self.is_playing():
				self._play()

func _on_finished() -> void:
	if end_behavior == EndBehavior.REMOVE_SLIDE:
		self._remove_self()
	elif end_behavior == EndBehavior.CUSTOM_METHOD:
		self[end_method].call()
	elif end_behavior == EndBehavior.PARENT_METHOD:
		self._get_parent()[end_method].call()

	if events_when_stopped:
		# TBD: Will the events come as a string or an array?
		for e in events_when_stopped.split(","):
			MPF.server.send_event(e.strip_edges())

func _remove_self():
	var parent = self._get_parent()
	var grandparent = parent.get_parent()
	while grandparent:
		if parent is MPFSlide and grandparent is MPFDisplay:
			break
		elif parent is MPFWidget and grandparent is MPFSlide:
			break
		grandparent = grandparent.get_parent()
	if not grandparent:
		return
	grandparent.action_remove(parent)

func _get_parent():
	var parent = self
	while parent:
		if parent is MPFSlide or parent is MPFWidget:
			return parent
		parent = parent.get_parent()
	if not parent:
		printerr("No parent slide or widget found?")
		return

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
		print(path)
		stream = load(path)
		if self.autoplay:
			play();
	else:
		self.log.debug("Unsupported extension for built-in playback: %s (%s)" % [ext, path])
