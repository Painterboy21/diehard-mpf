extends VideoStreamPlayer


var available_videos: Array[String] = [
	"res://videos/john/john1.ogv",
	"res://videos/john/john2.ogv",
	"res://videos/john/john3.ogv",
	"res://videos/john/john4.ogv",
	"res://videos/john/john5.ogv",
	"res://videos/john/john6.ogv",
	"res://videos/john/john8.ogv",
	"res://videos/john/john10.ogv",
	"res://videos/john/john11.ogv",
	"res://videos/john/john12.ogv",
	"res://videos/john/john13.ogv",
	"res://videos/john/john14.ogv",
	"res://videos/john/john16.ogv",
	"res://videos/john/john17.ogv",
	"res://videos/john/john18.ogv",
	"res://videos/john/john19.ogv",
	"res://videos/john/john21.ogv",
	"res://videos/john/john22.ogv",
	"res://videos/john/john23.ogv",
	"res://videos/john/john24.ogv",
	"res://videos/john/john26.ogv",
	"res://videos/john/john27.ogv",
	"res://videos/john/john29.ogv",
	"res://videos/john/john30.ogv",
	"res://videos/john/john31.ogv",
	"res://videos/john/john33.ogv",
	"res://videos/john/john34.ogv",
	"res://videos/john/john35.ogv",
	"res://videos/john/john37.ogv",
	"res://videos/john/john38.ogv",
	"res://videos/john/john39.ogv",
	"res://videos/john/john40.ogv",
	"res://videos/john/john41.ogv",
	"res://videos/john/john42.ogv",
	"res://videos/john/john43.ogv",
	"res://videos/john/john46.ogv",
	"res://videos/john/john47.ogv",
	"res://videos/john/john48.ogv",
	"res://videos/john/john49.ogv",
	"res://videos/john/john51.ogv",
	"res://videos/john/john52.ogv",
]


# This must match your MPF mystery_awarded_index.
var award_names: Array[String] = [
	"Award Points",        # 0
	"Advance Tower",       # 1
	"Advance Airplane",    # 2
	"Advance Park",        # 3
	"Bullets",             # 4
	"Ball Save",           # 5
	"Bonus X",             # 6
	"Hold Bonus X",        # 7
	"Advance Bumpers",     # 8
	"Advance Spinner",     # 9
	"Playfield X",         # 10
	"Ambush",              # 11
	"Light Extra Ball",    # 12
	"Add a Ball",          # 13
]


@onready var flash_timer: Timer = $Timer
@onready var award_label: Label = $"../VBoxContainer/VaultAward"

var current_index := 0
var flashing := false
var last_award_index := -1


func _ready() -> void:
	self.finished.connect(_on_video_finished)
	flash_timer.timeout.connect(_on_timer_timeout)

	# Keep this simple.
	# Old working Mystery YAML fires mystery_awarded and updates mystery_awarded_index.
	MPF.server.add_event_handler("mystery_awarded", self._mystery_awarded)
	MPF.game.connect("player_update", self._on_player_update)

	var stream: VideoStream = load(available_videos.pick_random())
	self.stream = stream
	self.play()

	start_award_flash()


func start_award_flash() -> void:
	flashing = true
	current_index = 0
	last_award_index = -1

	if award_label:
		award_label.text = award_names[0]

	flash_timer.start()


func _on_timer_timeout() -> void:
	if not flashing:
		return

	# This is only the roulette animation.
	# It is not the real award.
	award_label.text = award_names[current_index]
	current_index = (current_index + 1) % award_names.size()


func _on_player_update(var_name: String, value: Variant) -> void:
	if var_name == "mystery_awarded_index":
		last_award_index = int(value)

		# If the scroll has already stopped, update the label immediately.
		if not flashing:
			_show_award_by_index(last_award_index)


func _mystery_awarded(payload: Dictionary) -> void:
	flashing = false
	flash_timer.stop()

	if last_award_index >= 0:
		_show_award_by_index(last_award_index)
		return

	# Backup: pull the value straight from MPF player vars.
	if MPF.game.player != null:
		var index = MPF.game.player.get("mystery_awarded_index")
		if index != null:
			_show_award_by_index(int(index))


func _show_award_by_index(index: int) -> void:
	if index < 0 or index >= award_names.size():
		print("Mystery award index out of range: ", index)
		return

	award_label.text = award_names[index]
	print("Mystery final award: ", award_names[index])


func _on_video_finished() -> void:
	print("Video Finished")
