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


var award_names: Array[String] = [
	"Award Points",        # 0
	"Advance Nakatomi",    # 1
	"Advance Airplane",    # 2
	"Advance Park",        # 3
	"Bullets",             # 4
	"Ball Save",           # 5
	"Bonus X",             # 6
	"Hold Bonus X",        # 7
	"Super Jets",          # 8
	"Super Spinner",       # 9
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

# Used for the roulette text.
# This lets us remove Bullets from the scroll if bullet_hits is already full.
var scroll_award_indexes: Array[int] = []
var scroll_position := 0


func _ready() -> void:
	self.finished.connect(_on_video_finished)
	flash_timer.timeout.connect(_on_timer_timeout)

	MPF.server.add_event_handler("mystery_awarded", self._mystery_awarded)
	MPF.game.connect("player_update", self._on_player_update)

	var stream: VideoStream = load(available_videos.pick_random())
	self.stream = stream
	self.play()

	start_award_flash()


func start_award_flash() -> void:
	flashing = true
	current_index = 0
	scroll_position = 0
	last_award_index = -1

	_build_scroll_award_indexes()

	if award_label and scroll_award_indexes.size() > 0:
		award_label.text = award_names[scroll_award_indexes[0]]

	flash_timer.start()


func _build_scroll_award_indexes() -> void:
	scroll_award_indexes.clear()

	var bullets_full := false
	var bullet_value = _get_player_var("bullet_hits", 0)

	if int(bullet_value) >= 15:
		bullets_full = true

	for i in range(award_names.size()):
		# Index 4 is Bullets.
		# Skip it from the roulette if bullets are already full.
		if bullets_full and i == 4:
			continue

		scroll_award_indexes.append(i)


func _on_timer_timeout() -> void:
	if not flashing:
		return

	if scroll_award_indexes.size() == 0:
		return

	var award_index := scroll_award_indexes[scroll_position]
	award_label.text = award_names[award_index]

	scroll_position = (scroll_position + 1) % scroll_award_indexes.size()


func _on_player_update(var_name: String, value: Variant) -> void:
	if var_name == "mystery_awarded_index":
		last_award_index = int(value)

		if not flashing:
			_show_award_by_index(last_award_index)


func _mystery_awarded(payload: Dictionary) -> void:
	flashing = false
	flash_timer.stop()

	if last_award_index >= 0:
		_show_award_by_index(last_award_index)
		return

	var index = _get_player_var("mystery_awarded_index", -1)
	_show_award_by_index(int(index))


func _show_award_by_index(index: int) -> void:
	if index < 0 or index >= award_names.size():
		print("Mystery award index out of range: ", index)
		return

	award_label.text = award_names[index]
	print("Mystery final award: ", award_names[index])


func _get_player_var(var_name: String, default_value: Variant = null) -> Variant:
	if MPF.game.player == null:
		return default_value

	# MPF.game.player normally supports get().
	var value = MPF.game.player.get(var_name)

	if value == null:
		return default_value

	return value


func _on_video_finished() -> void:
	print("Video Finished")
