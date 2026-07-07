extends Resource
class_name DuckSettings

const merge_props = ["delay", "attenuation", "attack", "release", "release_from_start", "release_point"]

var bus: GMCBus
## The name of the audio bus to duck
@export var target_bus: String:
	set = _set_target_bus
## A delay (seconds) before the ducking attack
@export var delay: float
## The volume (as decimal percent) to reduce the target bus by.
## E.g. a value of 0.2 will reduce the target bus volume by 20%,
## and a value of 0.5 will reduce the target bus by 50%.
@export var attenuation: float
## The duration (seconds) over which to reduce the target bus value
@export var attack: float
## The duration (seconds) over which to restore the target bus value
@export var release: float
## The time (seconds) at which the ducking should begin releasing (from the start of the sound)
@export var release_from_start: float
## The time (seconds) at which the ducking should begin releasing (from the end of the sound)
@export var release_point: float
var start_time
var duration: float
var release_time: int

func _init(settings: Dictionary = {}, fallback: DuckSettings = null):
	# The bus comes as a string, convert it to a GMCBus
	if settings.get("bus"):
		if MPF.media and MPF.media.sound:
			self.bus = MPF.media.sound.get_bus(settings["bus"])
	elif fallback and fallback.bus:
		self.bus = fallback.bus
	for p in merge_props:
		if not self.get(p):
			var val = settings.get(p, fallback.get(p) if fallback else 0.0)
			if val:
				self[p] = val

func calculate_release_time(start_time_msecs: int, stream: AudioStream = null) -> float:
	if stream:
		self.duration = max(stream.get_length() - self.release_point, 0.0)
	elif self.release_from_start > 0:
		self.duration = self.release_from_start
	else:
		self.duration = 0.0
	self.release_time = start_time_msecs + int(self.duration * 1000)
	return self.release_time

func _set_target_bus(value: String) -> void:
	target_bus = value
	# The saved bus may have been overridden by _init settings
	# Bind to the bus, but not in editor because it validates on every keystroke
	if not bus and not Engine.is_editor_hint():
		if MPF.media and MPF.media.sound:
			bus = MPF.media.sound.get_bus(value)

func _to_string() -> String:
	var bus_name = "none"
	if bus:
		bus_name = bus.name
	return "<DuckSettings>{ delay: %s, attenuation: %s, attack: %s, release: %s, release_from_start: %s, release_point: %s, bus: %s" % \
		[delay, attenuation, attack, release, release_from_start, release_point, bus_name]
