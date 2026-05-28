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
	"Super Spinners",      # 9
	"Playfield X",         # 10
	"Ambush",              # 11
	"Light Extra Ball",    # 12
	"Add a Ball",          # 13
]


@onready var flash_timer: Timer = $Timer
@onready var award_label: Label = $"../VBoxContainer/VaultAward"

# Change this path if your Godot widget node is somewhere else.
@onready var bonus_x_held_widget: CanvasItem = $"../VBoxContainer/BonusXHeldWidget"


var current_index := 0
var flashing := false
var last_award_index := -1

var scroll_award_indexes: Array[int] = []
var scroll_position := 0


func _ready() -> void:
	self.finished.connect(_on_video_finished)
	flash_timer.timeout.connect(_on_timer_timeout)

	MPF.server.add_event_handler("mystery_awarded", self._mystery_awarded)
	MPF.server.add_event_handler("show_bonus_x_held_widget", self._show_bonus_x_held_widget)
	MPF.server.add_event_handler("hide_bonus_x_held_widget", self._hide_bonus_x_held_widget)

	MPF.game.connect("player_update", self._on_player_update)

	if bonus_x_held_widget:
		bonus_x_held_widget.visible = false

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

	var bullets_full := int(_get_player_var("bullet_hits", 0)) >= 15
	var super_spinners_awarded := int(_get_player_var("super_spinners", 0)) == 1

	for i in range(award_names.size()):
		# Index 4 = Bullets.
		# Skip from roulette if bullets are already full.
		if bullets_full and i == 4:
			continue

		# Index 9 = Super Spinners.
		# Skip from roulette if Super Spinners already awarded.
		if super_spinners_awarded and i == 9:
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


func _show_bonus_x_held_widget(payload: Dictionary = {}) -> void:
	if bonus_x_held_widget:
		bonus_x_held_widget.visible = true
		print("Bonus X Held widget shown")


func _hide_bonus_x_held_widget(payload: Dictionary = {}) -> void:
	if bonus_x_held_widget:
		bonus_x_held_widget.visible = false
		print("Bonus X Held widget hidden")


func _get_player_var(var_name: String, default_value: Variant = null) -> Variant:
	if MPF.game.player == null:
		return default_value

	var value = MPF.game.player.get(var_name)

	if value == null:
		return default_value

	return value


func _on_video_finished() -> void:
	print("Video Finished")
